extends Node3D

# --- Configuration ---
const SCALE := 0.12
const WALL_HEIGHT := 5.0
const THRESHOLD := 128
const MAP_PATH := "res://map2.png"
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
const FLASH_ENERGY_MAX := 3.5
const FLASH_ENERGY_MIN := 0.15
const FLASH_RANGE_MAX := 35.0
const FLASH_RANGE_MIN := 6.0
const FLASH_ANGLE_MAX := 40.0
const FLASH_ANGLE_MIN := 15.0

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


func _ready() -> void:
	var image := Image.new()
	var err: int = image.load(MAP_PATH)
	
	if err != OK:
		print("ERREUR : impossible de charger ", MAP_PATH)
		return
	
	var cols: int = image.get_width()
	var rows: int = image.get_height()
	
	var grid: Array[Array] = []
	for row: int in range(rows):
		var line: Array[int] = []
		for col: int in range(cols):
			var pixel: Color = image.get_pixel(col, row)
			if pixel.r < (THRESHOLD / 255.0):
				line.append(1)
			else:
				line.append(0)
		grid.append(line)
	
	var rectangles: Array = _merge_walls(grid, rows, cols)
	var spawn_grid: Vector2 = _find_spawn(grid, rows, cols)
	spawn_position = Vector3(spawn_grid.x * SCALE, 2.0, spawn_grid.y * SCALE)
	
	_build_floor(rows, cols)
	_build_walls(rectangles, rows)
	_create_player()
	_create_ui()
	
	print("Pret ! Murs: ", rectangles.size(), " | Spawn: ", spawn_position)


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
	
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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


func _update_flashlight(delta: float) -> void:
	if Input.is_key_pressed(KEY_E):
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
