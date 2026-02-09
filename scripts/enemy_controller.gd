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
			if state == State.PATROL and patrol_targets.size() > 0:
				# Skip to a further waypoint when repeatedly stuck
				var skip := mini(_stuck_count, 3)
				current_patrol_index = (current_patrol_index + skip) % patrol_targets.size()
			elif state == State.INVESTIGATE or state == State.CHASE:
				# Try to nudge sideways to get unstuck
				var nudge_dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
				velocity.x = nudge_dir.x * GameConfig.ENEMY_PATROL_SPEED
				velocity.z = nudge_dir.z * GameConfig.ENEMY_PATROL_SPEED
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
	# Solid cells the enemy cannot walk through:
	# 1 = wall, 3 = window, 5 = fence, 6 = coffee machine
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


func _is_blocked(dir: Vector3, speed: float) -> bool:
	## Check if moving in dir would hit a wall, using multiple lookahead distances.
	for dist_mult: float in [0.2, 0.5, 1.0]:
		var check_pos: Vector3 = global_position + dir * speed * dist_mult
		if _is_wall_at(check_pos):
			return true
	return false


func _apply_movement(dir: Vector3, speed: float) -> void:
	## Move in the desired direction, steer around walls, try multiple angles.
	if not _is_blocked(dir, speed):
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_face_direction(dir)
		return

	# Try sliding along X only
	var try_x := Vector3(dir.x, 0, 0).normalized()
	if try_x.length() > 0.1 and not _is_blocked(try_x, speed):
		velocity.x = try_x.x * speed
		velocity.z = 0
		_face_direction(try_x)
		return

	# Try sliding along Z only
	var try_z := Vector3(0, 0, dir.z).normalized()
	if try_z.length() > 0.1 and not _is_blocked(try_z, speed):
		velocity.x = 0
		velocity.z = try_z.z * speed
		_face_direction(try_z)
		return

	# Try diagonal alternatives (45-degree offsets)
	var angles := [PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0, 3.0 * PI / 4.0, -3.0 * PI / 4.0]
	for angle_offset: float in angles:
		var rotated := Vector3(
			dir.x * cos(angle_offset) - dir.z * sin(angle_offset),
			0,
			dir.x * sin(angle_offset) + dir.z * cos(angle_offset)
		).normalized()
		if not _is_blocked(rotated, speed):
			velocity.x = rotated.x * speed * 0.7
			velocity.z = rotated.z * speed * 0.7
			_face_direction(rotated)
			return

	# Fully stuck – stop
	velocity.x = 0
	velocity.z = 0


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

		if stimuli_strength > 0.6:
			state = State.CHASE
		elif state == State.PATROL:
			state = State.INVESTIGATE
	else:
		interest_timer -= delta
		if interest_timer <= 0:
			if state != State.PATROL:
				state = State.PATROL


# ---------------------------------------------------------------------------
# Patrol
# ---------------------------------------------------------------------------

func _do_patrol(delta: float) -> void:
	if patrol_targets.is_empty():
		_play_anim(anim_idle)
		return

	var target: Vector3 = patrol_targets[current_patrol_index]
	target.y = global_position.y  # Stay on same Y

	var dir: Vector3 = (target - global_position)
	dir.y = 0
	var dist: float = dir.length()

	if dist < 2.0:
		# Reached waypoint, go to next
		current_patrol_index = (current_patrol_index + 1) % patrol_targets.size()
		return

	dir = dir.normalized()
	_play_anim(anim_walk)
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
		# Reached investigation point, slow down and wait
		velocity.x = 0
		velocity.z = 0
		_play_anim(anim_idle)
		return

	dir = dir.normalized()
	var speed: float = GameConfig.ENEMY_PATROL_SPEED * 1.5
	_play_anim(anim_walk)
	_apply_movement(dir, speed)


# ---------------------------------------------------------------------------
# Chase
# ---------------------------------------------------------------------------

func _do_chase(delta: float) -> void:
	if not player_ref:
		return

	var target: Vector3 = player_ref.global_position
	target.y = global_position.y

	var dir: Vector3 = (target - global_position)
	dir.y = 0
	dir = dir.normalized()

	_play_anim(anim_run)
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
