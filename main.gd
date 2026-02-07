extends Node3D

# --- Configuration ---
const SCALE := 0.12
const WALL_HEIGHT := 5.0
const THRESHOLD := 128
const MAP_PATH := "res://map2.png"
const SPEED := 5.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.002

var spawn_position := Vector3.ZERO
var player: CharacterBody3D
var camera: Camera3D
var flashlight: SpotLight3D
var flashlight_on := true
var gravity: float = 9.8


func _ready():
	var image := Image.new()
	var err := image.load(MAP_PATH)
	
	if err != OK:
		print("❌ ERREUR : impossible de charger ", MAP_PATH)
		return
	
	print("✅ Image chargée : ", image.get_width(), "x", image.get_height())
	
	var cols := image.get_width()
	var rows := image.get_height()
	
	var grid: Array[Array] = []
	for row in range(rows):
		var line: Array[int] = []
		for col in range(cols):
			var pixel := image.get_pixel(col, row)
			if pixel.r < (THRESHOLD / 255.0):
				line.append(1)
			else:
				line.append(0)
		grid.append(line)
	
	var rectangles := _merge_walls(grid, rows, cols)
	print("✅ Murs générés : ", rectangles.size())
	
	var spawn_grid := _find_spawn(grid, rows, cols)
	spawn_position = Vector3(spawn_grid.x * SCALE, 2.0, spawn_grid.y * SCALE)
	print("✅ Spawn : ", spawn_position)
	
	# Construire le monde
	_build_floor(rows, cols)
	_build_walls(rectangles, rows)
	# _add_debug_light()
	
	# Créer le joueur par code (pas de scène séparée)
	_create_player()
	
	print("✅ Tout est prêt !")


func _create_player():
	# CharacterBody3D
	player = CharacterBody3D.new()
	player.position = spawn_position
	
	# Collision capsule
	var col_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	col_shape.shape = capsule
	col_shape.position.y = 0.9
	player.add_child(col_shape)
	
	# Caméra
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.current = true
	player.add_child(camera)
	
	# Lampe torche
	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(1.0, 0.9, 0.6)
	flashlight.light_energy = 1.5
	flashlight.spot_range = 20.0
	flashlight.spot_angle = 45.0
	flashlight.shadow_enabled = true
	camera.add_child(flashlight)
	
	add_child(player)
	
	# Capturer la souris
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	print("✅ Joueur créé à : ", player.position)


func _add_debug_light():
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1, 0.95, 0.85)
	sun.light_energy = 0.3
	sun.rotation_degrees = Vector3(-45, 45, 0)
	add_child(sun)


func _unhandled_input(event: InputEvent):
	if not player:
		return
	
	# Souris
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -1.4, 1.4)
	
	# Échap
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# F : lampe torche
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		flashlight_on = !flashlight_on
		flashlight.visible = flashlight_on


func _physics_process(delta: float):
	if not player:
		return
	
	# Gravité
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta
	
	# Saut
	if Input.is_key_pressed(KEY_SPACE) and player.is_on_floor():
		player.velocity.y = JUMP_VELOCITY
	
	# Mouvement ZQSD / WASD
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
	var direction := (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		player.velocity.x = direction.x * SPEED
		player.velocity.z = direction.z * SPEED
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, SPEED)
		player.velocity.z = move_toward(player.velocity.z, 0, SPEED)
	
	player.move_and_slide()
	
	# Debug
	if Engine.get_physics_frames() % 120 == 0:
		print("📍 Pos: ", player.global_position, " | Au sol: ", player.is_on_floor())


# ============================================
# CONSTRUCTION DU MONDE
# ============================================

func _build_floor(rows: int, cols: int):
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


func _build_walls(rectangles: Array, rows: int):
	for rect in rectangles:
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
	var cx := cols / 2
	var cy := rows / 2
	
	if grid[cy][cx] == 0:
		return Vector2(cx, cy)
	
	var max_radius := maxi(cols, rows) / 2
	for radius in range(1, max_radius, 5):
		for angle in range(0, 360, 15):
			var rad := deg_to_rad(angle)
			var x := int(cx + radius * cos(rad))
			var y := int(cy + radius * sin(rad))
			if x >= 0 and x < cols and y >= 0 and y < rows:
				if grid[y][x] == 0:
					return Vector2(x, y)
	
	for row in range(rows):
		for col in range(cols):
			if grid[row][col] == 0:
				return Vector2(col, row)
	
	return Vector2(cx, cy)


func _merge_walls(grid: Array, rows: int, cols: int) -> Array:
	var visited: Array[Array] = []
	for row in range(rows):
		var line: Array[bool] = []
		line.resize(cols)
		line.fill(false)
		visited.append(line)
	
	var rectangles: Array = []
	
	for row in range(rows):
		for col in range(cols):
			if grid[row][col] != 1 or visited[row][col]:
				continue
			
			var width := 0
			for c in range(col, cols):
				if grid[row][c] == 1 and not visited[row][c]:
					width += 1
				else:
					break
			
			var height := 0
			for r in range(row, rows):
				var full_row := true
				for c in range(col, col + width):
					if c >= cols or grid[r][c] != 1 or visited[r][c]:
						full_row = false
						break
				if full_row:
					height += 1
				else:
					break
			
			for r in range(row, row + height):
				for c in range(col, col + width):
					visited[r][c] = true
			
			rectangles.append([col, row, width, height])
	
	return rectangles
