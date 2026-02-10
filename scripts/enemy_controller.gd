class_name EnemyController
extends CharacterBody3D
## Horror enemy (Felipe the goose) – patrols corridors, attracted by player sound & flashlight.
##
## Detection rules:
##   - Flashlight ON → attracts enemy from large radius
##   - Sprinting → attracts enemy from medium radius
##   - Walking quietly + flashlight OFF → enemy cannot detect you
##   - When the enemy loses all stimuli it returns to patrol after a timeout

enum State { PATROL, INVESTIGATE, CHASE }

var state: State = State.PATROL
var gravity: float = 9.8

# Model config (set before adding to scene tree)
var model_path: String = GameConfig.ENEMY2_MODEL_PATH
var model_scale: Vector3 = GameConfig.ENEMY2_MODEL_SCALE
var model_y_offset: float = GameConfig.ENEMY2_MODEL_Y_OFFSET

# Animation names (leave empty to skip animation)
var anim_walk: String = ""
var anim_run: String = ""
var anim_attack: String = ""
var anim_idle: String = ""
var anim_scream: String = ""

# Patrol
var patrol_targets: Array = []
var current_patrol_index: int = 0

# Doors
var doors_ref: Array = []
var _door_open_cooldown: float = 0.0

# Detection
var interest_position := Vector3.ZERO
var interest_timer: float = 0.0
var player_ref: PlayerController = null

# Grid reference (for pathfinding)
var grid_data: Array[Array] = []
var grid_rows: int = 0
var grid_cols: int = 0

# Internal
var _model: Node3D = null
var _anim_player: AnimationPlayer = null
var _skeleton: Skeleton3D = null
var _current_anim: String = ""
var _stuck_timer: float = 0.0
var _last_pos := Vector3.ZERO
var _stuck_count: int = 0
var _growl_audio: AudioStreamPlayer3D = null
var _find_growl_audio: AudioStreamPlayer3D = null
var _growl_timer: float = 0.0

# Smart steering
var _wall_follow_dir: float = 1.0   # 1.0 = try right, -1.0 = try left
var _door_target: Vector3 = Vector3.ZERO  # Current door we're steering toward
var _seeking_door: bool = false
var _blocked_timer: float = 0.0     # How long we've been blocked

# Enemy footstep sounds
var _walk_audio: AudioStreamPlayer3D = null
var _run_audio: AudioStreamPlayer3D = null


func _ready() -> void:
	# Load 3D model
	if ResourceLoader.exists(model_path):
		var scene: PackedScene = load(model_path)
		_model = scene.instantiate()
		_model.scale = model_scale
		_model.position.y = model_y_offset
		add_child(_model)
		# Disable any AnimationTree (it overrides AnimationPlayer)
		_disable_animation_trees(_model)
		# Find AnimationPlayer in the loaded model
		_anim_player = _find_animation_player(_model)
		if _anim_player:
			var anim_list := _anim_player.get_animation_list()
			_skeleton = _find_skeleton(_model)
			if _skeleton:
				_skeleton.show_rest_only = false
			# Print first 3 track targets from walk anim
			var walk_anim_name: String = anim_walk if anim_walk != "" else (anim_list[0] if anim_list.size() > 0 else "")
			if walk_anim_name != "" and _anim_player.has_animation(walk_anim_name):
				var wa: Animation = _anim_player.get_animation(walk_anim_name)
				for t: int in range(mini(wa.get_track_count(), 5)):
					var tp := wa.track_get_path(t)
					var bone_prop: String = String(tp).get_slice(":", 1)
					print("[EnemyController] Track ", t, " -> bone/prop: '", bone_prop, "' full: ", tp)
			print("[EnemyController] callback_mode_process: ", _anim_player.callback_mode_process)
			_play_anim(anim_idle)
		else:
			print("[EnemyController] WARNING: No AnimationPlayer found in model!")
	else:
		# Fallback: red capsule
		var mesh := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.4
		capsule.height = 1.8
		mesh.mesh = capsule
		mesh.position.y = 0.9
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.7, 0.1, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.0, 0.0)
		mat.emission_energy_multiplier = 1.0
		mesh.material_override = mat
		add_child(mesh)
		_model = mesh

	# Collision
	var col_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	col_shape.shape = capsule
	col_shape.position.y = 0.9
	add_child(col_shape)

	floor_max_angle = deg_to_rad(60.0)

	# Growl sounds (3D so player hears them spatially)
	_growl_audio = AudioStreamPlayer3D.new()
	if ResourceLoader.exists(GameConfig.ENEMY_GROWL_SOUND_PATH):
		_growl_audio.stream = load(GameConfig.ENEMY_GROWL_SOUND_PATH)
	_growl_audio.volume_db = 5.0
	_growl_audio.max_distance = 40.0
	_growl_audio.bus = "Monster"
	add_child(_growl_audio)

	_find_growl_audio = AudioStreamPlayer3D.new()
	if ResourceLoader.exists(GameConfig.ENEMY_FIND_GROWL_SOUND_PATH):
		_find_growl_audio.stream = load(GameConfig.ENEMY_FIND_GROWL_SOUND_PATH)
	_find_growl_audio.volume_db = 8.0
	_find_growl_audio.max_distance = 50.0
	_find_growl_audio.bus = "Monster"
	add_child(_find_growl_audio)

	_growl_timer = randf_range(GameConfig.ENEMY_GROWL_INTERVAL_MIN, GameConfig.ENEMY_GROWL_INTERVAL_MAX)

	# Enemy walk/run footstep sounds (looping via finished signal)
	_walk_audio = AudioStreamPlayer3D.new()
	if ResourceLoader.exists("res://songs/walk_1.wav"):
		_walk_audio.stream = load("res://songs/walk_1.wav")
	_walk_audio.volume_db = 0.0
	_walk_audio.max_distance = 25.0
	_walk_audio.bus = "Monster"
	add_child(_walk_audio)
	_walk_audio.finished.connect(_on_walk_audio_finished)

	_run_audio = AudioStreamPlayer3D.new()
	if ResourceLoader.exists("res://songs/run_1.wav"):
		_run_audio.stream = load("res://songs/run_1.wav")
	_run_audio.volume_db = 2.0
	_run_audio.max_distance = 35.0
	_run_audio.bus = "Monster"
	add_child(_run_audio)
	_run_audio.finished.connect(_on_run_audio_finished)


## Initialize with map data and patrol waypoints.
func setup(grid: Array[Array], rows: int, cols: int, waypoints: Array, player: PlayerController, game_doors: Array = []) -> void:
	grid_data = grid
	grid_rows = rows
	grid_cols = cols
	player_ref = player
	doors_ref = game_doors

	# Build patrol route from room positions
	patrol_targets = waypoints.duplicate()
	patrol_targets.shuffle()
	if patrol_targets.size() > 0:
		current_patrol_index = 0


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Door cooldown
	if _door_open_cooldown > 0:
		_door_open_cooldown -= delta

	# Random growl timer
	_growl_timer -= delta
	if _growl_timer <= 0:
		if _growl_audio and _growl_audio.stream and not _growl_audio.playing:
			_growl_audio.play()
		_growl_timer = randf_range(GameConfig.ENEMY_GROWL_INTERVAL_MIN, GameConfig.ENEMY_GROWL_INTERVAL_MAX)

	# Detect player stimuli
	_detect_player(delta)

	# Open nearby doors
	_try_open_nearby_doors()

	# State machine
	match state:
		State.PATROL:
			_do_patrol(delta)
		State.INVESTIGATE:
			_do_investigate(delta)
		State.CHASE:
			_do_chase(delta)

	move_and_slide()

	# Stuck detection: if barely moved in 1.5 seconds, reroute
	_stuck_timer += delta
	if _stuck_timer >= 1.5:
		var moved := global_position.distance_to(_last_pos)
		if moved < 0.3:
			_stuck_count += 1
			# Flip wall-follow direction when stuck
			_wall_follow_dir *= -1.0
			_seeking_door = false
			if state == State.PATROL and patrol_targets.size() > 0:
				var skip := mini(_stuck_count, 3)
				current_patrol_index = (current_patrol_index + skip) % patrol_targets.size()
			elif state == State.INVESTIGATE or state == State.CHASE:
				# Try to find a door to go through
				_try_seek_door()
		else:
			_stuck_count = 0
		_last_pos = global_position
		_stuck_timer = 0.0

	# Check if caught player
	if player_ref and global_position.distance_to(player_ref.global_position) < GameConfig.ENEMY_CATCH_DISTANCE:
		if state == State.CHASE or state == State.INVESTIGATE:
			_catch_player()


# ---------------------------------------------------------------------------
# Wall avoidance – checks the grid before moving
# ---------------------------------------------------------------------------

func _is_wall_at(world_pos: Vector3) -> bool:
	var s: float = GameConfig.SCALE
	var gx: int = int(world_pos.x / s)
	var gz: int = int(world_pos.z / s)
	if gx < 0 or gx >= grid_cols or gz < 0 or gz >= grid_rows:
		return true  # Out of bounds = wall
	var cell: int = grid_data[gz][gx]
	return cell == 1 or cell == 3 or cell == 5 or cell == 6


func _try_open_nearby_doors() -> void:
	if doors_ref.is_empty() or _door_open_cooldown > 0:
		return
	for door: Door in doors_ref:
		if door.is_open or door.is_animating:
			continue
		var dist: float = global_position.distance_to(door.center_pos)
		if dist < 3.0:
			door.toggle()
			_door_open_cooldown = 1.5
			break


# ---------------------------------------------------------------------------
# Detection
# ---------------------------------------------------------------------------

func _detect_player(delta: float) -> void:
	if not player_ref:
		return

	var dist: float = global_position.distance_to(player_ref.global_position)
	var detected := false
	var stimuli_strength: float = 0.0

	# Flashlight detection (strongest signal)
	if player_ref.flashlight_on and player_ref.flashlight.visible and not player_ref.is_recharging:
		var light_range: float = GameConfig.ENEMY_DETECTION_RADIUS * GameConfig.ENEMY_LIGHT_DETECTION_MULT
		if dist < light_range:
			detected = true
			stimuli_strength = maxf(stimuli_strength, 1.0 - dist / light_range)

	# Sound detection: sprinting
	if player_ref.is_sprinting:
		if dist < GameConfig.ENEMY_SOUND_SPRINT_RADIUS:
			detected = true
			stimuli_strength = maxf(stimuli_strength, 1.0 - dist / GameConfig.ENEMY_SOUND_SPRINT_RADIUS)

	# Sound detection: walking (only if moving with footstep audio playing)
	elif player_ref.footstep_audio and player_ref.footstep_audio.playing:
		if dist < GameConfig.ENEMY_SOUND_WALK_RADIUS:
			detected = true
			stimuli_strength = maxf(stimuli_strength, 0.5 * (1.0 - dist / GameConfig.ENEMY_SOUND_WALK_RADIUS))

	if detected:
		interest_position = player_ref.global_position
		interest_timer = GameConfig.ENEMY_LOSE_INTEREST_TIME

		var old_state := state
		if stimuli_strength > 0.6:
			state = State.CHASE
		elif state == State.PATROL:
			state = State.INVESTIGATE
		if state != old_state:
			_seeking_door = false
			_blocked_timer = 0.0
	else:
		interest_timer -= delta
		if interest_timer <= 0:
			if state != State.PATROL:
				state = State.PATROL
				_seeking_door = false
				_blocked_timer = 0.0


# ---------------------------------------------------------------------------
# Grid line-of-sight (Bresenham) – very cheap, no allocations
# ---------------------------------------------------------------------------

func _has_grid_los(from: Vector3, to: Vector3) -> bool:
	## Returns true if no solid wall cell lies between from and to on the grid.
	var s: float = GameConfig.SCALE
	var x0: int = int(from.x / s)
	var y0: int = int(from.z / s)
	var x1: int = int(to.x / s)
	var y1: int = int(to.z / s)

	var dx: int = absi(x1 - x0)
	var dy: int = absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx - dy

	var steps: int = 0
	while steps < 500:  # Safety limit
		steps += 1
		if x0 == x1 and y0 == y1:
			return true
		# Check current cell
		if x0 < 0 or x0 >= grid_cols or y0 < 0 or y0 >= grid_rows:
			return false
		var cell: int = grid_data[y0][x0]
		if cell == 1 or cell == 3 or cell == 5 or cell == 6:
			return false
		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
	return false


# ---------------------------------------------------------------------------
# Wall avoidance helpers
# ---------------------------------------------------------------------------

func _is_blocked(dir: Vector3, speed: float) -> bool:
	for dist_mult: float in [0.2, 0.5, 1.0]:
		var check_pos: Vector3 = global_position + dir * speed * dist_mult
		if _is_wall_at(check_pos):
			return true
	return false


## Check how far we can walk in a direction (returns distance in cells, max 8)
func _clearance_in_dir(dir: Vector3) -> int:
	var s: float = GameConfig.SCALE
	for i: int in range(1, 9):
		var check := global_position + dir * s * float(i)
		if _is_wall_at(check):
			return i - 1
	return 8


## Find the nearest door and set it as navigation target
func _try_seek_door() -> void:
	if doors_ref.is_empty():
		return
	var best_door: Door = null
	var best_score: float = INF
	var player_pos := player_ref.global_position if player_ref else global_position
	for door: Door in doors_ref:
		var dist_to_me: float = global_position.distance_to(door.center_pos)
		if dist_to_me < 1.5 or dist_to_me > 40.0:
			continue
		# Prefer doors that are: 1) visible to us AND 2) closer to the player
		var can_see_door: bool = _has_grid_los(global_position, door.center_pos)
		var dist_to_player: float = door.center_pos.distance_to(player_pos)
		# Heavily penalize doors we can't see (they're behind walls too)
		var visibility_penalty: float = 0.0 if can_see_door else 50.0
		var score: float = dist_to_me * 0.3 + dist_to_player * 0.7 + visibility_penalty
		if score < best_score:
			best_score = score
			best_door = door
	if best_door:
		_door_target = best_door.center_pos
		_seeking_door = true


func _apply_movement(dir: Vector3, speed: float) -> void:
	# If we're seeking a door, override direction toward the door
	if _seeking_door:
		var door_dir: Vector3 = (_door_target - global_position)
		door_dir.y = 0
		if door_dir.length() < 2.0:
			# Reached the door area, stop seeking
			_seeking_door = false
		else:
			dir = door_dir.normalized()

	# Direct path clear
	if not _is_blocked(dir, speed):
		_blocked_timer = 0.0
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_face_direction(dir)
		return

	_blocked_timer += get_physics_process_delta_time()

	# Smart steering: test 16 directions, pick the best walkable one
	# that gets us closest to where we want to go
	var target_pos: Vector3 = global_position + dir * 10.0  # Where we ultimately want to reach
	var best_dir := Vector3.ZERO
	var best_score: float = INF

	for i: int in range(16):
		var angle: float = float(i) * PI * 2.0 / 16.0
		var test_dir := Vector3(cos(angle), 0, sin(angle))
		var clearance: int = _clearance_in_dir(test_dir)
		if clearance < 2:
			continue  # Not enough room

		# Score: how close does moving this way get us to the target?
		var future_pos: Vector3 = global_position + test_dir * GameConfig.SCALE * float(mini(clearance, 4))
		var dist_to_target: float = future_pos.distance_to(target_pos)

		# Bonus: prefer the current wall-follow side
		var cross: float = dir.x * test_dir.z - dir.z * test_dir.x  # Cross product Y
		var side_bonus: float = 0.0
		if cross * _wall_follow_dir > 0:
			side_bonus = -1.0  # Slight preference for the wall-follow side

		var score: float = dist_to_target + side_bonus
		if score < best_score:
			best_score = score
			best_dir = test_dir

	if best_dir.length() > 0.1:
		velocity.x = best_dir.x * speed * 0.8
		velocity.z = best_dir.z * speed * 0.8
		_face_direction(best_dir)
		return

	# Truly stuck: try random nudge
	var nudge := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	velocity.x = nudge.x * speed * 0.5
	velocity.z = nudge.z * speed * 0.5

	# After being blocked a while, try to find a door
	if _blocked_timer > 1.0 and not _seeking_door:
		_try_seek_door()
		_blocked_timer = 0.0


# ---------------------------------------------------------------------------
# Patrol
# ---------------------------------------------------------------------------

func _do_patrol(delta: float) -> void:
	if patrol_targets.is_empty():
		_play_anim(anim_idle)
		_stop_move_sounds()
		return

	var target: Vector3 = patrol_targets[current_patrol_index]
	target.y = global_position.y

	var dir: Vector3 = (target - global_position)
	dir.y = 0
	var dist: float = dir.length()

	if dist < 2.0:
		current_patrol_index = (current_patrol_index + 1) % patrol_targets.size()
		return

	dir = dir.normalized()
	_play_anim(anim_walk)
	_play_move_sound(false)
	_apply_movement(dir, GameConfig.ENEMY_PATROL_SPEED)


# ---------------------------------------------------------------------------
# Investigate
# ---------------------------------------------------------------------------

func _do_investigate(delta: float) -> void:
	var target: Vector3 = interest_position
	target.y = global_position.y

	var dir: Vector3 = (target - global_position)
	dir.y = 0
	var dist: float = dir.length()

	if dist < 2.0:
		velocity.x = 0
		velocity.z = 0
		_play_anim(anim_idle)
		_stop_move_sounds()
		return

	dir = dir.normalized()
	var speed: float = GameConfig.ENEMY_PATROL_SPEED * 1.5
	_play_anim(anim_walk)
	_play_move_sound(false)
	_apply_movement(dir, speed)


# ---------------------------------------------------------------------------
# Chase
# ---------------------------------------------------------------------------

func _do_chase(delta: float) -> void:
	if not player_ref:
		return

	var target: Vector3 = player_ref.global_position
	target.y = global_position.y

	var has_los: bool = _has_grid_los(global_position, player_ref.global_position)

	if has_los:
		# Clear path to player → go direct
		_seeking_door = false
		_blocked_timer = 0.0
		var dir: Vector3 = (target - global_position)
		dir.y = 0
		dir = dir.normalized()
		_play_anim(anim_run)
		_play_move_sound(true)
		velocity.x = dir.x * GameConfig.ENEMY_CHASE_SPEED
		velocity.z = dir.z * GameConfig.ENEMY_CHASE_SPEED
		_face_direction(dir)
	else:
		# Wall between us → navigate via doors
		if not _seeking_door:
			_try_seek_door()

		if _seeking_door:
			var door_dir: Vector3 = (_door_target - global_position)
			door_dir.y = 0
			if door_dir.length() < 2.0:
				# Reached this door, find next one
				_seeking_door = false
				_try_seek_door()
			else:
				var dir: Vector3 = door_dir.normalized()
				_play_anim(anim_run)
				_play_move_sound(true)
				_apply_movement(dir, GameConfig.ENEMY_CHASE_SPEED)
		else:
			# No door found, try direct anyway
			var dir: Vector3 = (target - global_position)
			dir.y = 0
			dir = dir.normalized()
			_play_anim(anim_run)
			_play_move_sound(true)
			_apply_movement(dir, GameConfig.ENEMY_CHASE_SPEED)


# ---------------------------------------------------------------------------
# Catch
# ---------------------------------------------------------------------------

var _caught := false

func _catch_player() -> void:
	if _caught:
		return
	_caught = true
	velocity.x = 0
	velocity.z = 0
	_play_anim(anim_attack)
	_stop_move_sounds()
	# Play the find-me growl
	if _find_growl_audio and _find_growl_audio.stream:
		_find_growl_audio.play()
	# Signal to main to trigger game over
	caught_player.emit()


signal caught_player


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _face_direction(dir: Vector3) -> void:
	if dir.length_squared() > 0.001:
		var target_angle: float = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 0.1)


## Play walk or run footstep sound (3D spatial). Loops automatically.
func _play_move_sound(is_running: bool) -> void:
	if is_running:
		if _walk_audio and _walk_audio.playing:
			_walk_audio.stop()
		if _run_audio and _run_audio.stream and not _run_audio.playing:
			_run_audio.play()
	else:
		if _run_audio and _run_audio.playing:
			_run_audio.stop()
		if _walk_audio and _walk_audio.stream and not _walk_audio.playing:
			_walk_audio.play()


func _stop_move_sounds() -> void:
	if _walk_audio and _walk_audio.playing:
		_walk_audio.stop()
	if _run_audio and _run_audio.playing:
		_run_audio.stop()


func _on_walk_audio_finished() -> void:
	# Loop walk sound if still walking
	if state == State.PATROL or state == State.INVESTIGATE:
		_walk_audio.play()


func _on_run_audio_finished() -> void:
	# Loop run sound if still chasing
	if state == State.CHASE:
		_run_audio.play()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _disable_animation_trees(node: Node) -> void:
	if node is AnimationTree:
		(node as AnimationTree).active = false
	for child in node.get_children():
		_disable_animation_trees(child)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _play_anim(anim_name: String) -> void:
	if anim_name.is_empty() or not _anim_player:
		return
	if _current_anim == anim_name and _anim_player.is_playing():
		return
	var resolved: String = ""
	# Direct match
	if _anim_player.has_animation(anim_name):
		resolved = anim_name
	else:
		# Try matching by suffix (animation libraries may add prefixes)
		for full_name in _anim_player.get_animation_list():
			if full_name.ends_with(anim_name) or full_name == anim_name.replace("|", "/"):
				resolved = full_name
				break
	if resolved.is_empty():
		print("[EnemyController] Animation not found: '", anim_name, "'")
		return
	# Ensure looping animations loop (walk, run, idle)
	var anim: Animation = _anim_player.get_animation(resolved)
	if anim and anim_name in [anim_walk, anim_run, anim_idle]:
		anim.loop_mode = Animation.LOOP_LINEAR
	_anim_player.stop()
	_anim_player.play(resolved)
	_anim_player.advance(0)
	_current_anim = anim_name
