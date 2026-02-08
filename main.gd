extends Node3D

# --- Configuration ---
const SCALE := 0.12
const WALL_HEIGHT := 5.0
const THRESHOLD := 128
const MAP_PATH := "res://map3.png"
const WALK_SPEED := 5.0
const SPRINT_SPEED := 9.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.002

# --- Endurance ---
const STAMINA_MAX := 100.0
const STAMINA_DRAIN := 25.0
const STAMINA_REGEN := 15.0
const STAMINA_MIN_TO_SPRINT := 10.0

# --- Lampe torche ---
const BATTERY_MAX := 100.0
const BATTERY_DRAIN := 3.0
const BATTERY_RECHARGE_SPEED := 35.0
const FLASH_ENERGY_MAX := 4.0
const FLASH_ENERGY_MIN := 0.15
const FLASH_RANGE_MAX := 35.0
const FLASH_RANGE_MIN := 6.0
const FLASH_ANGLE_MAX := 50.0
const FLASH_ANGLE_MIN := 15.0

# --- Portes ---
const DOOR_INTERACT_DISTANCE := 2.5
const DOOR_OPEN_SPEED := 1.5
const DOOR_SOUND_PATH := "res://door_open.ogg"

# --- Bruits de pas ---
const FOOTSTEP_SOUND_PATH := "res://footstep.ogg"

# --- Felipe ---
const FELIPE_SPEED_PATROL := 2.0
const FELIPE_SPEED_CHASE := 4.5
const FELIPE_CATCH_DISTANCE := 1.5
const FELIPE_HEAR_SPRINT := 25.0
const FELIPE_HEAR_WALK := 10.0
const FELIPE_HEAR_DOOR := 30.0
const FELIPE_LOSE_DISTANCE := 20.0
const FELIPE_PATROL_CHANGE := 4.0
const HEARTBEAT_PATH := "res://heartbeat.ogg"
const JUMPSCARE_PATH := "res://jumpscare.ogg"

var spawn_position := Vector3.ZERO
var player: CharacterBody3D
var camera: Camera3D
var flashlight: SpotLight3D
var flashlight_on := true
var gravity: float = 9.8

var stamina: float = STAMINA_MAX
var is_sprinting := false
var stamina_bar_fg: ColorRect
var stamina_bar_bg: ColorRect

var battery: float = BATTERY_MAX
var is_recharging := false
var battery_bar_fg: ColorRect
var battery_bar_bg: ColorRect

var player_spawned := false
var frames_before_spawn := 3

var doors: Array = []
var interact_label: Label
var grid_data: Array[Array] = []
var grid_rows: int = 0
var grid_cols: int = 0

var footstep_audio: AudioStreamPlayer

# Felipe
var felipe: CharacterBody3D
var felipe_state: String = "patrol"  # patrol, investigate, chase
var felipe_target := Vector3.ZERO
var felipe_patrol_timer := 0.0
var felipe_last_known_pos := Vector3.ZERO
var felipe_noise_level := 0.0
var heartbeat_audio: AudioStreamPlayer
var jumpscare_audio: AudioStreamPlayer
var is_game_over := false
var game_over_timer := 0.0
var jumpscare_overlay: ColorRect
var jumpscare_label: Label
var felipe_mesh_body: MeshInstance3D
var felipe_mesh_head: MeshInstance3D
var felipe_eyes_left: MeshInstance3D
var felipe_eyes_right: MeshInstance3D

# Navigation simplifiée
var nav_grid: Array[Array] = []  # 0=passable, 1=mur


class Door:
	var mesh: MeshInstance3D
	var body: StaticBody3D
	var pivot: Node3D
	var is_open := false
	var is_animating := false
	var current_angle := 0.0
	var target_angle := 0.0
	var audio: AudioStreamPlayer3D
	var center_pos := Vector3.ZERO
	var is_horizontal := true


func _ready() -> void:
	var image := Image.new()
	var err: int = image.load(MAP_PATH)
	
	if err != OK:
		print("ERREUR : impossible de charger ", MAP_PATH)
		return
	
	grid_cols = image.get_width()
	grid_rows = image.get_height()
	
	var red_grid: Array[Array] = []
	
	for row: int in range(grid_rows):
		var line: Array[int] = []
		var red_line: Array[bool] = []
		var nav_line: Array[int] = []
		for col: int in range(grid_cols):
			var pixel: Color = image.get_pixel(col, row)
			if pixel.r > 0.8 and pixel.g < 0.3 and pixel.b < 0.3:
				line.append(2)
				red_line.append(true)
				nav_line.append(0)  # porte = passable
			elif pixel.r < (THRESHOLD / 255.0):
				line.append(1)
				red_line.append(false)
				nav_line.append(1)  # mur
			else:
				line.append(0)
				red_line.append(false)
				nav_line.append(0)  # chemin
		grid_data.append(line)
		red_grid.append(red_line)
		nav_grid.append(nav_line)
	
	var door_blocks: Array = _find_door_blocks(red_grid, grid_rows, grid_cols)
	var rectangles: Array = _merge_walls(grid_data, grid_rows, grid_cols)
	var spawn_grid: Vector2 = _find_spawn(grid_data, grid_rows, grid_cols)
	spawn_position = Vector3(spawn_grid.x * SCALE, 2.0, spawn_grid.y * SCALE)
	
	_build_floor(grid_rows, grid_cols)
	_build_walls(rectangles, grid_rows)
	_build_doors_from_blocks(door_blocks)
	_create_felipe()
	_create_ui()
	
	print("Pret ! Murs: ", rectangles.size(), " | Portes: ", doors.size(), " | Spawn: ", spawn_position)


# ============================================
# FELIPE - ENNEMI
# ============================================

func _create_felipe() -> void:
	felipe = CharacterBody3D.new()
	
	# Spawn Felipe loin du joueur
	var felipe_spawn: Vector2 = _find_felipe_spawn()
	felipe.position = Vector3(felipe_spawn.x * SCALE, 1.0, felipe_spawn.y * SCALE)
	felipe_target = felipe.position
	
	# Felipe sur layer 2, collisionne avec layer 1 (murs/sol) mais PAS layer 3 (portes)
	felipe.collision_layer = 2
	felipe.collision_mask = 1
	
	# Collision
	var col_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.9
	col_shape.shape = capsule
	col_shape.position.y = 0.95
	felipe.add_child(col_shape)
	
	# Corps (capsule sombre)
	felipe_mesh_body = MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.35
	body_mesh.height = 1.6
	felipe_mesh_body.mesh = body_mesh
	felipe_mesh_body.position.y = 0.9
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.08, 0.08, 0.1)
	body_mat.emission_enabled = true
	body_mat.emission = Color(0.05, 0.0, 0.0)
	body_mat.emission_energy_multiplier = 0.3
	felipe_mesh_body.material_override = body_mat
	felipe.add_child(felipe_mesh_body)
	
	# Tête (sphère)
	felipe_mesh_head = MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.25
	head_mesh.height = 0.5
	felipe_mesh_head.mesh = head_mesh
	felipe_mesh_head.position.y = 1.9
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.1, 0.1, 0.12)
	head_mat.emission_enabled = true
	head_mat.emission = Color(0.05, 0.0, 0.0)
	head_mat.emission_energy_multiplier = 0.3
	felipe_mesh_head.material_override = head_mat
	felipe.add_child(felipe_mesh_head)
	
	# Yeux rouges
	felipe_eyes_left = MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.04
	eye_mesh.height = 0.08
	felipe_eyes_left.mesh = eye_mesh
	felipe_eyes_left.position = Vector3(-0.1, 1.95, -0.2)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.0, 0.0)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.0, 0.0)
	eye_mat.emission_energy_multiplier = 3.0
	felipe_eyes_left.material_override = eye_mat
	felipe.add_child(felipe_eyes_left)
	
	felipe_eyes_right = MeshInstance3D.new()
	felipe_eyes_right.mesh = eye_mesh
	felipe_eyes_right.position = Vector3(0.1, 1.95, -0.2)
	felipe_eyes_right.material_override = eye_mat
	felipe.add_child(felipe_eyes_right)
	
	add_child(felipe)
	
	# Audio battement de coeur
	heartbeat_audio = AudioStreamPlayer.new()
	if ResourceLoader.exists(HEARTBEAT_PATH):
		heartbeat_audio.stream = load(HEARTBEAT_PATH)
	heartbeat_audio.volume_db = -20.0
	add_child(heartbeat_audio)
	
	# Audio jumpscare
	jumpscare_audio = AudioStreamPlayer.new()
	if ResourceLoader.exists(JUMPSCARE_PATH):
		jumpscare_audio.stream = load(JUMPSCARE_PATH)
	jumpscare_audio.volume_db = 5.0
	add_child(jumpscare_audio)
	
	print("Felipe spawn a : ", felipe.position)


func _find_felipe_spawn() -> Vector2:
	# Spawn dans un coin opposé au joueur, dans un couloir large
	var spawn_grid_pos: Vector2 = Vector2(spawn_position.x / SCALE, spawn_position.z / SCALE)
	
	var best_pos := Vector2(-1, -1)
	var best_dist: float = 0.0
	
	# Chercher un bon spot loin du joueur
	for _attempt: int in range(50):
		var tx: int = randi_range(30, grid_cols - 30)
		var tz: int = randi_range(30, grid_rows - 30)
		
		if nav_grid[tz][tx] != 0:
			continue
		
		# Vérifier que c'est un espace ouvert (pas coincé)
		var open_count: int = 0
		for dx: int in range(-3, 4):
			for dz: int in range(-3, 4):
				if _is_walkable(tx + dx, tz + dz):
					open_count += 1
		
		if open_count < 30:  # pas assez d'espace
			continue
		
		var dist: float = Vector2(tx, tz).distance_to(spawn_grid_pos)
		if dist > best_dist:
			best_dist = dist
			best_pos = Vector2(tx, tz)
	
	if best_pos != Vector2(-1, -1):
		return best_pos
	
	# Fallback
	var walkable: Vector2 = _find_nearest_walkable(grid_cols - 50, grid_rows - 50)
	if walkable != Vector2(-1, -1):
		return walkable
	return Vector2(grid_cols / 2, grid_rows / 2)


func _find_nearest_walkable(cx: int, cy: int) -> Vector2:
	for radius: int in range(0, 100, 3):
		for angle: int in range(0, 360, 30):
			var rad: float = deg_to_rad(angle)
			var x: int = clampi(int(cx + radius * cos(rad)), 0, grid_cols - 1)
			var y: int = clampi(int(cy + radius * sin(rad)), 0, grid_rows - 1)
			if nav_grid[y][x] == 0:
				return Vector2(x, y)
	return Vector2(-1, -1)


func _update_felipe(delta: float) -> void:
	if is_game_over or not player:
		return
	
	var dist_to_player: float = felipe.global_position.distance_to(player.global_position)
	
	# Vérifier si Felipe attrape le joueur
	if dist_to_player < FELIPE_CATCH_DISTANCE:
		_trigger_jumpscare()
		return
	
	# Battement de coeur basé sur la distance
	_update_heartbeat(dist_to_player)
	
	# Machine à états
	match felipe_state:
		"patrol":
			_felipe_patrol(delta, dist_to_player)
		"investigate":
			_felipe_investigate(delta, dist_to_player)
		"chase":
			_felipe_chase(delta, dist_to_player)
	
	# Log toutes les 3 secondes
	if Engine.get_process_frames() % 180 == 0:
		print("Felipe [", felipe_state, "] pos=", snappedf(felipe.global_position.x, 0.1), ",", snappedf(felipe.global_position.z, 0.1), " | dist_joueur=", snappedf(dist_to_player, 0.1), " | waypoints=", felipe_waypoint_index, "/", felipe_waypoints.size())
	
	# Bouger Felipe
	_move_felipe(delta)
	
	# Faire tourner Felipe vers sa direction de mouvement
	_rotate_felipe_towards_target()
	
	# Yeux clignotent en chase
	if felipe_state == "chase":
		var blink: bool = fmod(Time.get_ticks_msec() / 150.0, 1.0) > 0.3
		var eye_energy: float = 5.0 if blink else 2.0
		var eye_mat: StandardMaterial3D = felipe_eyes_left.material_override as StandardMaterial3D
		eye_mat.emission_energy_multiplier = eye_energy


var felipe_waypoints: Array[Vector3] = []
var felipe_waypoint_index: int = 0
var felipe_stuck_timer: float = 0.0
var felipe_last_pos := Vector3.ZERO


func _felipe_patrol(delta: float, dist: float) -> void:
	if felipe_noise_level > 0 and dist < FELIPE_HEAR_SPRINT:
		felipe_last_known_pos = player.global_position
		felipe_waypoints.clear()
		if dist < FELIPE_HEAR_WALK:
			felipe_state = "chase"
			print("Felipe PATROL -> CHASE! bruit=", felipe_noise_level, " dist=", snappedf(dist, 0.1))
			return
		else:
			felipe_state = "investigate"
			print("Felipe PATROL -> INVESTIGATE bruit=", felipe_noise_level, " dist=", snappedf(dist, 0.1))
			return
	
	if felipe_waypoints.size() == 0 or felipe_waypoint_index >= felipe_waypoints.size():
		felipe_waypoints = _generate_patrol_path()
		felipe_waypoint_index = 0
		print("Felipe PATROL: nouveau chemin, ", felipe_waypoints.size(), " waypoints")
	
	if felipe_waypoint_index < felipe_waypoints.size():
		felipe_target = felipe_waypoints[felipe_waypoint_index]
		if felipe.global_position.distance_to(felipe_target) < 0.8:
			felipe_waypoint_index += 1
			print("Felipe PATROL: waypoint ", felipe_waypoint_index, "/", felipe_waypoints.size(), " pos=", felipe.global_position)


func _felipe_investigate(delta: float, dist: float) -> void:
	if felipe_noise_level > 0 and dist < FELIPE_HEAR_WALK:
		felipe_state = "chase"
		felipe_last_known_pos = player.global_position
		felipe_waypoints.clear()
		print("Felipe INVESTIGATE -> CHASE! dist=", dist)
		return
	
	if felipe_waypoints.size() == 0:
		felipe_waypoints = _find_path_to(felipe_last_known_pos)
		felipe_waypoint_index = 0
		print("Felipe INVESTIGATE: chemin vers bruit, ", felipe_waypoints.size(), " waypoints")
	
	if felipe_waypoint_index < felipe_waypoints.size():
		felipe_target = felipe_waypoints[felipe_waypoint_index]
		if felipe.global_position.distance_to(felipe_target) < 0.8:
			felipe_waypoint_index += 1
	
	if felipe.global_position.distance_to(felipe_last_known_pos) < 3.0:
		felipe_state = "patrol"
		felipe_waypoints.clear()
		print("Felipe INVESTIGATE -> PATROL: rien trouve")


func _felipe_chase(delta: float, dist: float) -> void:
	felipe_last_known_pos = player.global_position
	
	felipe_patrol_timer -= delta
	if felipe_patrol_timer <= 0 or felipe_waypoints.size() == 0:
		felipe_patrol_timer = 0.5
		felipe_waypoints = _find_path_to(player.global_position)
		felipe_waypoint_index = 0
		print("Felipe CHASE: recalcul chemin, ", felipe_waypoints.size(), " waypoints, dist=", snappedf(dist, 0.1))
	
	if felipe_waypoint_index < felipe_waypoints.size():
		felipe_target = felipe_waypoints[felipe_waypoint_index]
		if felipe.global_position.distance_to(felipe_target) < 0.8:
			felipe_waypoint_index += 1
	
	if dist > FELIPE_LOSE_DISTANCE and felipe_noise_level <= 0:
		felipe_state = "investigate"
		felipe_waypoints.clear()
		print("Felipe CHASE -> INVESTIGATE: joueur perdu, dist=", snappedf(dist, 0.1))


func _move_felipe(delta: float) -> void:
	var speed: float = FELIPE_SPEED_CHASE if felipe_state == "chase" else FELIPE_SPEED_PATROL
	
	var direction: Vector3 = (felipe_target - felipe.global_position)
	direction.y = 0
	
	if direction.length() < 0.3:
		return
	
	direction = direction.normalized()
	
	if not felipe.is_on_floor():
		felipe.velocity.y -= gravity * delta
	else:
		felipe.velocity.y = 0
	
	felipe.velocity.x = direction.x * speed
	felipe.velocity.z = direction.z * speed
	
	felipe.move_and_slide()
	
	felipe_stuck_timer += delta
	if felipe_stuck_timer > 2.0:
		if felipe.global_position.distance_to(felipe_last_pos) < 0.5:
			felipe_waypoints.clear()
			felipe_waypoint_index = 0
			print("Felipe BLOQUE! Recalcul... pos=", felipe.global_position)
		felipe_last_pos = felipe.global_position
		felipe_stuck_timer = 0.0


func _rotate_felipe_towards_target() -> void:
	var direction: Vector3 = felipe_target - felipe.global_position
	direction.y = 0
	if direction.length() > 0.1:
		var target_angle: float = atan2(-direction.x, -direction.z)
		felipe.rotation.y = lerpf(felipe.rotation.y, target_angle, 0.1)


func _world_to_grid(pos: Vector3) -> Vector2i:
	var gx: int = clampi(int(pos.x / SCALE), 0, grid_cols - 1)
	var gz: int = clampi(int(pos.z / SCALE), 0, grid_rows - 1)
	return Vector2i(gx, gz)


func _grid_to_world(g: Vector2i) -> Vector3:
	return Vector3(g.x * SCALE, felipe.global_position.y, g.y * SCALE)


func _is_walkable(gx: int, gy: int) -> bool:
	if gx < 0 or gx >= grid_cols or gy < 0 or gy >= grid_rows:
		return false
	return nav_grid[gy][gx] == 0


func _generate_patrol_path() -> Array[Vector3]:
	# Choisir une destination aléatoire marchable et utiliser BFS pour y aller
	var current: Vector2i = _world_to_grid(felipe.global_position)
	
	# Trouver un point aléatoire assez loin
	var target := Vector2i.ZERO
	var found_target := false
	
	for _attempt: int in range(30):
		var tx: int = randi_range(20, grid_cols - 20)
		var tz: int = randi_range(20, grid_rows - 20)
		
		if nav_grid[tz][tx] == 0:
			var dist: float = Vector2(current.x, current.y).distance_to(Vector2(tx, tz))
			if dist > 100:  # assez loin pour un bon parcours
				target = Vector2i(tx, tz)
				found_target = true
				break
	
	if not found_target:
		# Fallback : n'importe quel point marchable
		for _attempt: int in range(20):
			var tx: int = randi_range(10, grid_cols - 10)
			var tz: int = randi_range(10, grid_rows - 10)
			if nav_grid[tz][tx] == 0:
				target = Vector2i(tx, tz)
				found_target = true
				break
	
	if found_target:
		var target_pos := Vector3(target.x * SCALE, felipe.global_position.y, target.y * SCALE)
		return _find_path_to(target_pos)
	
	return []


func _find_path_to(target_pos: Vector3) -> Array[Vector3]:
	var start: Vector2i = _world_to_grid(felipe.global_position)
	var goal: Vector2i = _world_to_grid(target_pos)
	
	var cell_size: int = 6
	var start_cell := Vector2i(start.x / cell_size, start.y / cell_size)
	var goal_cell := Vector2i(goal.x / cell_size, goal.y / cell_size)
	
	var max_cells_x: int = grid_cols / cell_size
	var max_cells_y: int = grid_rows / cell_size
	
	start_cell.x = clampi(start_cell.x, 0, max_cells_x - 1)
	start_cell.y = clampi(start_cell.y, 0, max_cells_y - 1)
	goal_cell.x = clampi(goal_cell.x, 0, max_cells_x - 1)
	goal_cell.y = clampi(goal_cell.y, 0, max_cells_y - 1)
	
	var queue: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {}
	came_from[start_cell] = start_cell
	
	var found := false
	var iterations: int = 0
	var max_iterations: int = 2000
	
	while queue.size() > 0 and iterations < max_iterations:
		iterations += 1
		var current: Vector2i = queue.pop_front()
		
		if current == goal_cell:
			found = true
			break
		
		for dir: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var next: Vector2i = current + dir
			if next.x < 0 or next.x >= max_cells_x or next.y < 0 or next.y >= max_cells_y:
				continue
			if came_from.has(next):
				continue
			
			var cx: int = clampi(next.x * cell_size + cell_size / 2, 0, grid_cols - 1)
			var cy: int = clampi(next.y * cell_size + cell_size / 2, 0, grid_rows - 1)
			if nav_grid[cy][cx] != 0:
				continue
			
			came_from[next] = current
			queue.append(next)
	
	var path: Array[Vector3] = []
	if found:
		var current: Vector2i = goal_cell
		var cell_path: Array[Vector2i] = []
		while current != start_cell:
			cell_path.append(current)
			current = came_from[current]
		cell_path.reverse()
		
		for cell: Vector2i in cell_path:
			var world_pos := Vector3(
				(cell.x * cell_size + cell_size / 2) * SCALE,
				felipe.global_position.y,
				(cell.y * cell_size + cell_size / 2) * SCALE
			)
			path.append(world_pos)
	else:
		path.append(target_pos)
	
	return path


func _update_noise_level(is_moving: bool, door_opened: bool) -> void:
	# Calculer le niveau de bruit du joueur
	felipe_noise_level = 0.0
	
	if door_opened:
		felipe_noise_level = FELIPE_HEAR_DOOR
	elif is_moving:
		if is_sprinting:
			felipe_noise_level = FELIPE_HEAR_SPRINT
		else:
			felipe_noise_level = FELIPE_HEAR_WALK


func _update_heartbeat(dist: float) -> void:
	if dist < 30.0:
		if not heartbeat_audio.playing:
			heartbeat_audio.play()
		
		# Plus Felipe est proche, plus le son est fort et rapide
		var intensity: float = clampf(1.0 - (dist / 30.0), 0.0, 1.0)
		heartbeat_audio.volume_db = lerpf(-25.0, 2.0, intensity)
		heartbeat_audio.pitch_scale = lerpf(0.7, 1.8, intensity)
	else:
		if heartbeat_audio.playing:
			heartbeat_audio.stop()


func _trigger_jumpscare() -> void:
	if is_game_over:
		return
	
	is_game_over = true
	game_over_timer = 3.0
	
	# Stopper tous les sons
	if footstep_audio and footstep_audio.playing:
		footstep_audio.stop()
	if heartbeat_audio.playing:
		heartbeat_audio.stop()
	
	# Jouer le son de jumpscare
	if jumpscare_audio.stream:
		jumpscare_audio.play()
	
	# Overlay rouge
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	
	jumpscare_overlay = ColorRect.new()
	jumpscare_overlay.color = Color(0.6, 0.0, 0.0, 0.85)
	jumpscare_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(jumpscare_overlay)
	
	jumpscare_label = Label.new()
	jumpscare_label.text = "FELIPE T'A ATTRAPÉ"
	jumpscare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jumpscare_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	jumpscare_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	jumpscare_label.add_theme_font_size_override("font_size", 52)
	jumpscare_label.add_theme_color_override("font_color", Color.WHITE)
	canvas.add_child(jumpscare_label)
	
	add_child(canvas)
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("GAME OVER - Felipe t'a attrape!")


func _process_game_over(delta: float) -> void:
	game_over_timer -= delta
	
	# Flash de l'overlay
	if jumpscare_overlay:
		var flash: float = absf(sin(game_over_timer * 8.0))
		jumpscare_overlay.color = Color(0.6 + flash * 0.3, 0.0, 0.0, 0.85)
	
	if game_over_timer <= 0:
		get_tree().change_scene_to_file("res://menu.tscn")


# ============================================
# PLAYER & GAME LOOP
# ============================================

func _process(delta: float) -> void:
	if is_game_over:
		_process_game_over(delta)
		return
	
	if not player_spawned:
		frames_before_spawn -= 1
		if frames_before_spawn <= 0:
			_create_player()
			player_spawned = true
	
	for door: Door in doors:
		if door.is_animating:
			var diff: float = door.target_angle - door.current_angle
			if absf(diff) < 0.5:
				door.current_angle = door.target_angle
				door.is_animating = false
			else:
				door.current_angle += signf(diff) * DOOR_OPEN_SPEED * delta * 60.0
			door.pivot.rotation_degrees.y = door.current_angle
	
	_update_felipe(delta)


func _find_door_blocks(red_grid: Array, rows: int, cols: int) -> Array:
	var visited: Array[Array] = []
	for row: int in range(rows):
		var line: Array[bool] = []
		line.resize(cols)
		line.fill(false)
		visited.append(line)
	
	var blocks: Array = []
	
	for row: int in range(rows):
		for col: int in range(cols):
			if not red_grid[row][col] or visited[row][col]:
				continue
			
			var min_col: int = col
			var max_col: int = col
			var min_row: int = row
			var max_row: int = row
			
			var stack: Array[Vector2i] = [Vector2i(col, row)]
			visited[row][col] = true
			
			while stack.size() > 0:
				var p: Vector2i = stack.pop_back()
				min_col = mini(min_col, p.x)
				max_col = maxi(max_col, p.x)
				min_row = mini(min_row, p.y)
				max_row = maxi(max_row, p.y)
				
				for dir: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var nx: int = p.x + dir.x
					var ny: int = p.y + dir.y
					if nx >= 0 and nx < cols and ny >= 0 and ny < rows:
						if red_grid[ny][nx] and not visited[ny][nx]:
							visited[ny][nx] = true
							stack.append(Vector2i(nx, ny))
			
			var block_w: int = max_col - min_col + 1
			var block_h: int = max_row - min_row + 1
			blocks.append([min_col, min_row, block_w, block_h])
	
	return blocks


func _detect_orientation(col: int, row: int, w: int, h: int) -> bool:
	var center_row: int = row + h / 2
	var center_col: int = col + w / 2
	var check_dist: int = 5
	
	var left_wall := false
	var check_c: int = col - check_dist
	if check_c >= 0 and check_c < grid_cols:
		left_wall = grid_data[center_row][check_c] == 1
	
	var right_wall := false
	check_c = col + w + check_dist
	if check_c >= 0 and check_c < grid_cols:
		right_wall = grid_data[center_row][check_c] == 1
	
	var top_wall := false
	var check_r: int = row - check_dist
	if check_r >= 0 and check_r < grid_rows:
		top_wall = grid_data[check_r][center_col] == 1
	
	var bottom_wall := false
	check_r = row + h + check_dist
	if check_r >= 0 and check_r < grid_rows:
		bottom_wall = grid_data[check_r][center_col] == 1
	
	if left_wall and right_wall:
		return true
	elif top_wall and bottom_wall:
		return false
	elif left_wall or right_wall:
		return true
	else:
		return false


func _build_doors_from_blocks(blocks: Array) -> void:
	var sound: Resource = null
	if ResourceLoader.exists(DOOR_SOUND_PATH):
		sound = load(DOOR_SOUND_PATH)
	
	for block: Array in blocks:
		var col: int = block[0]
		var row: int = block[1]
		var w: int = block[2]
		var h: int = block[3]
		
		var is_horizontal: bool = _detect_orientation(col, row, w, h)
		
		var door := Door.new()
		door.pivot = Node3D.new()
		door.is_horizontal = is_horizontal
		
		var door_width: float
		var door_thickness: float = SCALE * 2.0
		var door_height: float = WALL_HEIGHT * 0.9
		
		if is_horizontal:
			door_width = w * SCALE
		else:
			door_width = h * SCALE
		
		var pivot_x: float
		var pivot_z: float
		
		if is_horizontal:
			pivot_x = col * SCALE
			pivot_z = (row + h / 2.0) * SCALE
		else:
			pivot_x = (col + w / 2.0) * SCALE
			pivot_z = row * SCALE
		
		door.pivot.position = Vector3(pivot_x, 0, pivot_z)
		
		door.center_pos = Vector3(
			(col + w / 2.0) * SCALE,
			1.0,
			(row + h / 2.0) * SCALE
		)
		
		door.mesh = MeshInstance3D.new()
		var box := BoxMesh.new()
		
		if is_horizontal:
			box.size = Vector3(door_width, door_height, door_thickness)
			door.mesh.position = Vector3(door_width / 2.0, door_height / 2.0, 0)
		else:
			box.size = Vector3(door_thickness, door_height, door_width)
			door.mesh.position = Vector3(0, door_height / 2.0, door_width / 2.0)
		
		door.mesh.mesh = box
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.2, 0.1)
		door.mesh.material_override = mat
		
		door.body = StaticBody3D.new()
		# Portes sur layer 3 (bit 4) — Felipe (mask=1) les ignore, joueur (mask=5) les touche
		door.body.collision_layer = 4
		door.body.collision_mask = 0
		var col_shape := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		col_shape.shape = shape
		col_shape.position = door.mesh.position
		door.body.add_child(col_shape)
		
		door.audio = AudioStreamPlayer3D.new()
		door.audio.max_distance = 20.0
		door.audio.unit_size = 4.0
		if sound:
			door.audio.stream = sound
		door.audio.position = door.mesh.position
		
		door.pivot.add_child(door.mesh)
		door.pivot.add_child(door.body)
		door.pivot.add_child(door.audio)
		add_child(door.pivot)
		
		doors.append(door)


func _get_nearest_door() -> Door:
	if not player:
		return null
	
	var nearest: Door = null
	var nearest_dist: float = DOOR_INTERACT_DISTANCE
	var player_pos_flat := Vector3(player.global_position.x, 1.0, player.global_position.z)
	
	for door: Door in doors:
		var dist: float = player_pos_flat.distance_to(door.center_pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = door
	
	return nearest


var door_just_opened := false

func _toggle_door(door: Door) -> void:
	if door.is_animating:
		return
	
	door.is_animating = true
	door_just_opened = true
	
	if door.is_open:
		door.target_angle = 0.0
		door.is_open = false
	else:
		door.target_angle = 90.0
		door.is_open = true
	
	if door.audio.stream:
		door.audio.play()


func _create_player() -> void:
	player = CharacterBody3D.new()
	player.position = spawn_position
	
	# Joueur sur layer 1, collisionne avec layer 1 (murs/sol) + layer 3 (portes, bit 4)
	player.collision_layer = 1
	player.collision_mask = 5  # bit 1 + bit 4 = 5
	
	var col_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	col_shape.shape = capsule
	col_shape.position.y = 0.9
	player.add_child(col_shape)
	
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.current = true
	player.add_child(camera)
	
	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(1.0, 0.9, 0.6)
	flashlight.light_energy = FLASH_ENERGY_MAX
	flashlight.spot_range = FLASH_RANGE_MAX
	flashlight.spot_angle = FLASH_ANGLE_MAX
	flashlight.shadow_enabled = true
	camera.add_child(flashlight)
	
	footstep_audio = AudioStreamPlayer.new()
	if ResourceLoader.exists(FOOTSTEP_SOUND_PATH):
		var step_sound: Resource = load(FOOTSTEP_SOUND_PATH)
		if step_sound:
			footstep_audio.stream = step_sound
	footstep_audio.volume_db = -5.0
	add_child(footstep_audio)
	
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	print("Joueur place a : ", player.position)


func _create_ui() -> void:
	var canvas := CanvasLayer.new()
	
	stamina_bar_bg = ColorRect.new()
	stamina_bar_bg.color = Color(0.15, 0.15, 0.15, 0.6)
	stamina_bar_bg.size = Vector2(200, 8)
	stamina_bar_bg.position = Vector2(20, -30)
	stamina_bar_bg.anchor_top = 1.0
	stamina_bar_bg.anchor_bottom = 1.0
	
	stamina_bar_fg = ColorRect.new()
	stamina_bar_fg.color = Color(0.9, 0.7, 0.1, 0.8)
	stamina_bar_fg.size = Vector2(200, 8)
	stamina_bar_fg.position = Vector2(20, -30)
	stamina_bar_fg.anchor_top = 1.0
	stamina_bar_fg.anchor_bottom = 1.0
	
	canvas.add_child(stamina_bar_bg)
	canvas.add_child(stamina_bar_fg)
	
	battery_bar_bg = ColorRect.new()
	battery_bar_bg.color = Color(0.15, 0.15, 0.15, 0.6)
	battery_bar_bg.size = Vector2(200, 8)
	battery_bar_bg.position = Vector2(20, -45)
	battery_bar_bg.anchor_top = 1.0
	battery_bar_bg.anchor_bottom = 1.0
	
	battery_bar_fg = ColorRect.new()
	battery_bar_fg.color = Color(0.3, 0.7, 0.9, 0.8)
	battery_bar_fg.size = Vector2(200, 8)
	battery_bar_fg.position = Vector2(20, -45)
	battery_bar_fg.anchor_top = 1.0
	battery_bar_fg.anchor_bottom = 1.0
	
	canvas.add_child(battery_bar_bg)
	canvas.add_child(battery_bar_fg)
	
	interact_label = Label.new()
	interact_label.text = "[E] Ouvrir"
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interact_label.position = Vector2(-60, -80)
	interact_label.add_theme_font_size_override("font_size", 20)
	interact_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.8))
	interact_label.visible = false
	canvas.add_child(interact_label)
	
	add_child(canvas)


func _update_ui() -> void:
	var stam_ratio: float = stamina / STAMINA_MAX
	stamina_bar_fg.size.x = 200.0 * stam_ratio
	
	if stam_ratio > 0.5:
		stamina_bar_fg.color = Color(0.9, 0.7, 0.1, 0.8)
	elif stam_ratio > 0.2:
		stamina_bar_fg.color = Color(0.9, 0.4, 0.1, 0.8)
	else:
		stamina_bar_fg.color = Color(0.9, 0.15, 0.1, 0.8)
	
	var show_stam: bool = stamina < STAMINA_MAX - 0.1
	stamina_bar_bg.visible = show_stam
	stamina_bar_fg.visible = show_stam
	
	var batt_ratio: float = battery / BATTERY_MAX
	battery_bar_fg.size.x = 200.0 * batt_ratio
	
	if is_recharging:
		var blink: bool = fmod(Time.get_ticks_msec() / 300.0, 1.0) > 0.5
		if blink:
			battery_bar_fg.color = Color(0.2, 0.9, 0.3, 0.8)
		else:
			battery_bar_fg.color = Color(0.1, 0.5, 0.2, 0.5)
	elif batt_ratio > 0.5:
		battery_bar_fg.color = Color(0.3, 0.7, 0.9, 0.8)
	elif batt_ratio > 0.2:
		battery_bar_fg.color = Color(0.9, 0.5, 0.1, 0.8)
	else:
		battery_bar_fg.color = Color(0.9, 0.15, 0.1, 0.8)
	
	battery_bar_bg.visible = true
	battery_bar_fg.visible = true
	
	var nearest: Door = _get_nearest_door()
	if nearest and not nearest.is_animating:
		if nearest.is_open:
			interact_label.text = "[E] Fermer"
		else:
			interact_label.text = "[E] Ouvrir"
		interact_label.visible = true
	else:
		interact_label.visible = false


func _update_flashlight(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		is_recharging = true
		flashlight.visible = false
		battery += BATTERY_RECHARGE_SPEED * delta
		battery = min(battery, BATTERY_MAX)
	else:
		is_recharging = false
		
		if flashlight_on and battery > 0:
			flashlight.visible = true
			battery -= BATTERY_DRAIN * delta
			battery = max(battery, 0.0)
		
		if battery <= 0:
			flashlight.visible = false
	
	var ratio: float = battery / BATTERY_MAX
	flashlight.light_energy = lerpf(FLASH_ENERGY_MIN, FLASH_ENERGY_MAX, ratio)
	flashlight.spot_range = lerpf(FLASH_RANGE_MIN, FLASH_RANGE_MAX, ratio)
	flashlight.spot_angle = lerpf(FLASH_ANGLE_MIN, FLASH_ANGLE_MAX, ratio)
	
	var warm: float = lerpf(0.4, 0.9, ratio)
	flashlight.light_color = Color(1.0, warm, warm * 0.6)
	
	if ratio < 0.15 and ratio > 0 and not is_recharging:
		var flicker: float = randf()
		if flicker < 0.08:
			flashlight.visible = false
		elif flashlight_on:
			flashlight.visible = true


func _update_footsteps(is_moving: bool) -> void:
	if not footstep_audio:
		return
	
	var on_ground: bool = player.is_on_floor()
	
	if is_moving and on_ground:
		var target_pitch: float = 1.4 if is_sprinting else 1.0
		footstep_audio.pitch_scale = target_pitch
		if not footstep_audio.playing:
			footstep_audio.play()
	else:
		if footstep_audio.playing:
			footstep_audio.stop()


func _unhandled_input(event: InputEvent) -> void:
	if not player or is_game_over:
		return
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -1.4, 1.4)
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		if not is_recharging:
			flashlight_on = not flashlight_on
			flashlight.visible = flashlight_on and battery > 0
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		var nearest: Door = _get_nearest_door()
		if nearest:
			_toggle_door(nearest)


func _physics_process(delta: float) -> void:
	if not player or is_game_over:
		return
	
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta
	
	if Input.is_key_pressed(KEY_SPACE) and player.is_on_floor():
		player.velocity.y = JUMP_VELOCITY
	
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	
	input_dir = input_dir.normalized()
	var is_moving: bool = input_dir.length() > 0.1
	
	var wants_sprint: bool = Input.is_key_pressed(KEY_SHIFT)
	if wants_sprint and is_moving and stamina > STAMINA_MIN_TO_SPRINT:
		is_sprinting = true
		stamina -= STAMINA_DRAIN * delta
		stamina = max(stamina, 0.0)
		if stamina <= 0.0:
			is_sprinting = false
	else:
		is_sprinting = false
		var regen_rate: float = STAMINA_REGEN if not is_moving else STAMINA_REGEN * 0.5
		stamina += regen_rate * delta
		stamina = min(stamina, STAMINA_MAX)
	
	var speed: float = SPRINT_SPEED if is_sprinting else WALK_SPEED
	var direction: Vector3 = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		player.velocity.x = direction.x * speed
		player.velocity.z = direction.z * speed
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, speed)
		player.velocity.z = move_toward(player.velocity.z, 0, speed)
	
	player.move_and_slide()
	
	# Bruit du joueur
	_update_noise_level(is_moving, door_just_opened)
	door_just_opened = false
	
	_update_footsteps(is_moving)
	_update_flashlight(delta)
	_update_ui()


# ============================================
# CONSTRUCTION DU MONDE
# ============================================

func _build_floor(rows: int, cols: int) -> void:
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(cols * SCALE, 1.0, rows * SCALE)
	floor_mesh.mesh = box
	floor_mesh.position = Vector3(cols * SCALE / 2.0, -0.5, rows * SCALE / 2.0)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.3)
	floor_mesh.material_override = mat
	
	var body := StaticBody3D.new()
	var col_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	col_shape.shape = shape
	body.add_child(col_shape)
	body.position = floor_mesh.position
	
	add_child(floor_mesh)
	add_child(body)


func _build_walls(rectangles: Array, rows: int) -> void:
	for rect: Array in rectangles:
		var col: int = rect[0]
		var row: int = rect[1]
		var w: int = rect[2]
		var h: int = rect[3]
		
		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(w * SCALE, WALL_HEIGHT, h * SCALE)
		wall.mesh = box
		wall.position = Vector3(
			(col + w / 2.0) * SCALE,
			WALL_HEIGHT / 2.0,
			(row + h / 2.0) * SCALE
		)
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.45, 0.5)
		wall.material_override = mat
		
		var body := StaticBody3D.new()
		var col_shape := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		col_shape.shape = shape
		body.add_child(col_shape)
		body.position = wall.position
		
		add_child(wall)
		add_child(body)


# ============================================
# PARSING DE LA MAP
# ============================================

func _find_spawn(grid: Array, rows: int, cols: int) -> Vector2:
	var cx: int = cols / 2
	var cy: int = rows / 2
	
	if grid[cy][cx] == 0:
		return Vector2(cx, cy)
	
	var max_radius: int = maxi(cols, rows) / 2
	for radius: int in range(1, max_radius, 5):
		for angle: int in range(0, 360, 15):
			var rad: float = deg_to_rad(angle)
			var x: int = int(cx + radius * cos(rad))
			var y: int = int(cy + radius * sin(rad))
			if x >= 0 and x < cols and y >= 0 and y < rows:
				if grid[y][x] == 0:
					return Vector2(x, y)
	
	for row: int in range(rows):
		for col: int in range(cols):
			if grid[row][col] == 0:
				return Vector2(col, row)
	
	return Vector2(cx, cy)


func _merge_walls(grid: Array, rows: int, cols: int) -> Array:
	var visited: Array[Array] = []
	for row: int in range(rows):
		var line: Array[bool] = []
		line.resize(cols)
		line.fill(false)
		visited.append(line)
	
	var rectangles: Array = []
	
	for row: int in range(rows):
		for col: int in range(cols):
			if grid[row][col] != 1 or visited[row][col]:
				continue
			
			var width: int = 0
			for c: int in range(col, cols):
				if grid[row][c] == 1 and not visited[row][c]:
					width += 1
				else:
					break
			
			var height: int = 0
			for r: int in range(row, rows):
				var full_row: bool = true
				for c: int in range(col, col + width):
					if c >= cols or grid[r][c] != 1 or visited[r][c]:
						full_row = false
						break
				if full_row:
					height += 1
				else:
					break
			
			for r: int in range(row, row + height):
				for c: int in range(col, col + width):
					visited[r][c] = true
			
			rectangles.append([col, row, width, height])
	
	return rectangles
