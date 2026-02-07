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
var was_sprinting := false

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
		for col: int in range(grid_cols):
			var pixel: Color = image.get_pixel(col, row)
			if pixel.r > 0.8 and pixel.g < 0.3 and pixel.b < 0.3:
				line.append(2)
				red_line.append(true)
			elif pixel.r < (THRESHOLD / 255.0):
				line.append(1)
				red_line.append(false)
			else:
				line.append(0)
				red_line.append(false)
		grid_data.append(line)
		red_grid.append(red_line)
	
	var door_blocks: Array = _find_door_blocks(red_grid, grid_rows, grid_cols)
	var rectangles: Array = _merge_walls(grid_data, grid_rows, grid_cols)
	var spawn_grid: Vector2 = _find_spawn(grid_data, grid_rows, grid_cols)
	spawn_position = Vector3(spawn_grid.x * SCALE, 2.0, spawn_grid.y * SCALE)
	
	_build_floor(grid_rows, grid_cols)
	_build_walls(rectangles, grid_rows)
	_build_doors_from_blocks(door_blocks)
	_create_ui()
	
	print("Pret ! Murs: ", rectangles.size(), " | Portes: ", doors.size(), " | Spawn: ", spawn_position)


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


func _process(delta: float) -> void:
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


func _toggle_door(door: Door) -> void:
	if door.is_animating:
		return
	
	door.is_animating = true
	
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
	
	# Son de pas
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
		# Ajuster le pitch selon marche/sprint
		var target_pitch: float = 1.4 if is_sprinting else 1.0
		footstep_audio.pitch_scale = target_pitch
		
		if not footstep_audio.playing:
			footstep_audio.play()
	else:
		if footstep_audio.playing:
			footstep_audio.stop()


func _unhandled_input(event: InputEvent) -> void:
	if not player:
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
	if not player:
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
