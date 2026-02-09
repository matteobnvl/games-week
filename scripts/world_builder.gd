class_name WorldBuilder
extends Node3D
## Responsible for constructing all 3D level geometry (floors, walls, ceilings, stairs, doors, environment).


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Create a box mesh + matching StaticBody3D collision at the given position.
static func build_mesh_with_collision(parent: Node3D, box_size: Vector3, pos: Vector3, material: StandardMaterial3D) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = material

	var body := StaticBody3D.new()
	var col_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	col_shape.shape = shape
	body.add_child(col_shape)
	body.position = pos

	parent.add_child(mesh)
	parent.add_child(body)


# ---------------------------------------------------------------------------
# Floor 1 geometry
# ---------------------------------------------------------------------------

func build_floor(rows: int, cols: int) -> void:
	var s := GameConfig.SCALE
	var size := Vector3(cols * s, 1.0, rows * s)
	var pos := Vector3(cols * s / 2.0, -0.5, rows * s / 2.0)
	WorldBuilder.build_mesh_with_collision(self, size, pos, MaterialFactory.create_floor_material())


func build_walls(rectangles: Array) -> void:
	var mat := MaterialFactory.create_wall_material()
	var s := GameConfig.SCALE
	var wh := GameConfig.WALL_HEIGHT
	for rect: Array in rectangles:
		var col: int = rect[0]; var row: int = rect[1]
		var w: int = rect[2]; var h: int = rect[3]
		WorldBuilder.build_mesh_with_collision(
			self,
			Vector3(w * s, wh, h * s),
			Vector3((col + w / 2.0) * s, wh / 2.0, (row + h / 2.0) * s),
			mat
		)


func build_windows(rectangles: Array) -> void:
	var mat := MaterialFactory.create_glass_material()
	var s := GameConfig.SCALE
	var wh := GameConfig.WALL_HEIGHT
	for rect: Array in rectangles:
		var col: int = rect[0]; var row: int = rect[1]
		var w: int = rect[2]; var h: int = rect[3]
		WorldBuilder.build_mesh_with_collision(
			self,
			Vector3(w * s, wh, h * s),
			Vector3((col + w / 2.0) * s, wh / 2.0, (row + h / 2.0) * s),
			mat
		)


func build_terrace_floors(rectangles: Array) -> void:
	var s := GameConfig.SCALE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.45, 0.35)
	mat.roughness = 0.9
	for rect: Array in rectangles:
		var col: int = rect[0]; var row: int = rect[1]
		var w: int = rect[2]; var h: int = rect[3]
		WorldBuilder.build_mesh_with_collision(
			self,
			Vector3(w * s, 1.0, h * s),
			Vector3((col + w / 2.0) * s, -0.5, (row + h / 2.0) * s),
			mat
		)


func build_glass_fences(rectangles: Array) -> void:
	var s := GameConfig.SCALE
	var fence_h: float = GameConfig.WALL_HEIGHT * 0.3
	var mat := MaterialFactory.create_glass_material(Color(1.0, 0.5, 0.75, 0.4))
	mat.metallic = 0.1
	mat.roughness = 0.05
	for rect: Array in rectangles:
		var col: int = rect[0]; var row: int = rect[1]
		var w: int = rect[2]; var h: int = rect[3]
		WorldBuilder.build_mesh_with_collision(
			self,
			Vector3(w * s, fence_h, h * s),
			Vector3((col + w / 2.0) * s, fence_h / 2.0, (row + h / 2.0) * s),
			mat
		)


func build_coffee_machines(rectangles: Array) -> void:
	var s := GameConfig.SCALE
	var machine_h: float = GameConfig.WALL_HEIGHT * 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.8, 0.9)
	mat.metallic = 0.6
	mat.roughness = 0.3

	for rect: Array in rectangles:
		var col: int = rect[0]; var row: int = rect[1]
		var w: int = rect[2]; var h: int = rect[3]

		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(w * s, machine_h, h * s)
		mesh.mesh = box
		mesh.position = Vector3((col + w / 2.0) * s, machine_h / 2.0, (row + h / 2.0) * s)
		mesh.material_override = mat
		add_child(mesh)

		var light := SpotLight3D.new()
		light.light_color = Color(0.3, 0.7, 1.0)
		light.light_energy = 20.0
		light.spot_range = 15.0
		light.spot_angle = 45.0
		light.shadow_enabled = true
		light.position = Vector3(col * s + w * s * 0.5, machine_h / 2.0, row * s - h * s / 2.0)
		add_child(light)


# ---------------------------------------------------------------------------
# Ceiling with holes (terraces, staircases, floor-2 areas)
# ---------------------------------------------------------------------------

func build_ceiling_with_holes(rows: int, cols: int, terrace_grid: Array, staircase_rects: Array) -> void:
	var s := GameConfig.SCALE
	var wh := GameConfig.WALL_HEIGHT

	# Determine where floor 2 has solid floor (= no ceiling needed for floor 1)
	var f2_has_floor: Array[Array] = []
	var f2_image := Image.new()
	var f2_loaded: bool = f2_image.load(GameConfig.MAP_PATH_F2) == OK
	for row: int in range(rows):
		var line: Array[bool] = []
		line.resize(cols)
		line.fill(false)
		f2_has_floor.append(line)

	if f2_loaded:
		var f2_cols: int = f2_image.get_width()
		var f2_rows: int = f2_image.get_height()
		var threshold_ratio: float = GameConfig.THRESHOLD / 255.0
		for row: int in range(mini(rows, f2_rows)):
			for col: int in range(mini(cols, f2_cols)):
				var px: Color = f2_image.get_pixel(col, row)
				var is_yellow: bool = px.r > 0.8 and px.g > 0.8 and px.b < 0.4
				var is_wall: bool = px.r < threshold_ratio
				if not is_yellow and not is_wall:
					f2_has_floor[row][col] = true

	# Build exclude grid
	var exclude_grid: Array[Array] = []
	for row: int in range(rows):
		var line: Array[bool] = []
		line.resize(cols)
		line.fill(false)
		exclude_grid.append(line)

	for row: int in range(rows):
		for col: int in range(cols):
			if terrace_grid[row][col] or f2_has_floor[row][col]:
				exclude_grid[row][col] = true

	for rect: Array in staircase_rects:
		var sc: int = rect[0]; var sr: int = rect[1]
		var sw: int = rect[2]; var sh: int = rect[3]
		for r: int in range(sr, mini(sr + sh, rows)):
			for c: int in range(sc, mini(sc + sw, cols)):
				exclude_grid[r][c] = true

	var ceiling_rects: Array = MapParser.merge_non_excluded_areas(rows, cols, exclude_grid)
	var ceil_mat := MaterialFactory.create_ceiling_material()
	for rect: Array in ceiling_rects:
		var col: int = rect[0]; var row: int = rect[1]
		var w: int = rect[2]; var h: int = rect[3]
		WorldBuilder.build_mesh_with_collision(
			self,
			Vector3(w * s, 1.0, h * s),
			Vector3((col + w / 2.0) * s, wh + 0.5, (row + h / 2.0) * s),
			ceil_mat
		)


# ---------------------------------------------------------------------------
# Floor 2
# ---------------------------------------------------------------------------

func build_floor_2() -> Array:
	var f2_data := MapParser.parse_floor2_image(GameConfig.MAP_PATH_F2)
	if f2_data.is_empty():
		return []

	var f2_grid: Array = f2_data["grid"]
	var f2_red_grid: Array = f2_data["red_grid"]
	var f2_void_grid: Array = f2_data["void_grid"]
	var f2_rows: int = f2_data["rows"]
	var f2_cols: int = f2_data["cols"]

	var s := GameConfig.SCALE
	var wh := GameConfig.WALL_HEIGHT
	var f2h := GameConfig.FLOOR_2_HEIGHT

	# Stats
	var void_count: int = 0; var wall_count: int = 0; var open_count: int = 0
	for row: int in range(f2_rows):
		for col: int in range(f2_cols):
			if f2_void_grid[row][col]:
				void_count += 1
			elif f2_grid[row][col] == 1:
				wall_count += 1
			elif f2_grid[row][col] == 0:
				open_count += 1
	print("Floor 2: void=", void_count, " walls=", wall_count, " open=", open_count)

	var f2_walls: Array = MapParser.merge_type(f2_grid, f2_rows, f2_cols, 1)
	var f2_windows: Array = MapParser.merge_type(f2_grid, f2_rows, f2_cols, 3)
	var f2_door_blocks: Array = MapParser.find_door_blocks(f2_red_grid, f2_rows, f2_cols)

	# Floor-exclude grid (walls + void)
	var sol_exclude: Array[Array] = []
	for row: int in range(f2_rows):
		var line: Array[bool] = []
		for col: int in range(f2_cols):
			line.append(f2_void_grid[row][col] or f2_grid[row][col] == 1)
		sol_exclude.append(line)
	var sol_rects: Array = MapParser.merge_non_excluded_areas(f2_rows, f2_cols, sol_exclude)

	var floor_mat := MaterialFactory.create_floor_material()
	var ceil_under_mat := MaterialFactory.create_ceiling_material()
	var wall_mat := MaterialFactory.create_wall_material()
	var glass_mat := MaterialFactory.create_glass_material()
	var ceil_mat := MaterialFactory.create_ceiling_material()

	# Floor tiles + ceiling-underside (visible from floor 1)
	for rect: Array in sol_rects:
		var col: int = rect[0]; var row: int = rect[1]
		var w: int = rect[2]; var h: int = rect[3]
		WorldBuilder.build_mesh_with_collision(
			self,
			Vector3(w * s, 1.0, h * s),
			Vector3((col + w / 2.0) * s, f2h - 0.5, (row + h / 2.0) * s),
			floor_mat
		)
		# Thin ceiling underside slab
		var c_mesh := MeshInstance3D.new()
		var c_box := BoxMesh.new()
		c_box.size = Vector3(w * s, 0.05, h * s)
		c_mesh.mesh = c_box
		c_mesh.position = Vector3((col + w / 2.0) * s, f2h - 1.0, (row + h / 2.0) * s)
		c_mesh.material_override = ceil_under_mat
		add_child(c_mesh)

	# Floor 2 ceiling
	for rect: Array in sol_rects:
		var col: int = rect[0]; var row: int = rect[1]
		var w: int = rect[2]; var h: int = rect[3]
		WorldBuilder.build_mesh_with_collision(
			self,
			Vector3(w * s, 1.0, h * s),
			Vector3((col + w / 2.0) * s, f2h + wh + 0.5, (row + h / 2.0) * s),
			ceil_mat
		)

	# Walls
	for rect: Array in f2_walls:
		var col: int = rect[0]; var row: int = rect[1]
		var w: int = rect[2]; var h: int = rect[3]
		WorldBuilder.build_mesh_with_collision(
			self,
			Vector3(w * s, wh, h * s),
			Vector3((col + w / 2.0) * s, f2h + wh / 2.0, (row + h / 2.0) * s),
			wall_mat
		)

	# Windows
	for rect: Array in f2_windows:
		var col: int = rect[0]; var row: int = rect[1]
		var w: int = rect[2]; var h: int = rect[3]
		WorldBuilder.build_mesh_with_collision(
			self,
			Vector3(w * s, wh, h * s),
			Vector3((col + w / 2.0) * s, f2h + wh / 2.0, (row + h / 2.0) * s),
			glass_mat
		)

	# Doors
	var f2_doors: Array = []
	var sound: Resource = null
	if ResourceLoader.exists(GameConfig.DOOR_SOUND_PATH):
		sound = load(GameConfig.DOOR_SOUND_PATH)
	for block: Array in f2_door_blocks:
		var door := _create_door(block, f2_grid, f2_rows, f2_cols, sound, f2h)
		f2_doors.append(door)

	print("Floor 2: Walls=", f2_walls.size(), " Doors=", f2_door_blocks.size(),
		" Windows=", f2_windows.size(), " Floor=", sol_rects.size())
	return f2_doors


# ---------------------------------------------------------------------------
# Staircases
# ---------------------------------------------------------------------------

func build_staircases(staircase_rects: Array, grid_cols: int) -> void:
	var s := GameConfig.SCALE
	var wh := GameConfig.WALL_HEIGHT
	var f2h := GameConfig.FLOOR_2_HEIGHT

	print("=== BUILDING STAIRCASES ===")
	print("Staircase zones: ", staircase_rects.size())

	for rect: Array in staircase_rects:
		var col: int = rect[0]; var row: int = rect[1]
		var w: int = rect[2]; var h: int = rect[3]

		var stair_x: float = col * s
		var stair_z: float = row * s
		var stair_width_x: float = w * s
		var stair_depth_z: float = h * s

		var center_x: float = grid_cols * s / 2.0
		var mid_x: float = stair_x + stair_width_x / 2.0
		var goes_towards_center: bool = mid_x < center_x

		print("  Staircase: grid=(", col, ",", row, ") towards_center=", goes_towards_center)

		var num_slabs: int = 80
		var slab_length: float = stair_width_x / num_slabs * 1.5
		var slab_rise: float = f2h / num_slabs
		var slab_mat := StandardMaterial3D.new()
		slab_mat.albedo_color = Color(0.5, 0.45, 0.4)

		for i: int in range(num_slabs):
			var slab_y: float = slab_rise * i
			var t: float = float(i) / float(num_slabs)
			var slab_x: float
			if goes_towards_center:
				slab_x = stair_x + stair_width_x * t
			else:
				slab_x = stair_x + stair_width_x * (1.0 - t)

			WorldBuilder.build_mesh_with_collision(
				self,
				Vector3(slab_length, 0.05, stair_depth_z),
				Vector3(slab_x, slab_y, stair_z + stair_depth_z / 2.0),
				slab_mat
			)

		# Side walls
		var total_h: float = f2h + wh
		var rail_mat := StandardMaterial3D.new()
		rail_mat.albedo_color = Color(0.4, 0.4, 0.45)
		for side: int in [0, 1]:
			var rail_z: float
			if side == 0:
				rail_z = stair_z - s * 1.5
			else:
				rail_z = stair_z + stair_depth_z + s * 1.5
			WorldBuilder.build_mesh_with_collision(
				self,
				Vector3(stair_width_x, total_h, s * 3),
				Vector3(stair_x + stair_width_x / 2.0, total_h / 2.0, rail_z),
				rail_mat
			)
		print("  -> Ramp: ", num_slabs, " slabs")


# ---------------------------------------------------------------------------
# Doors
# ---------------------------------------------------------------------------

func build_doors_from_blocks(blocks: Array, grid_data: Array, grid_rows: int, grid_cols: int) -> Array:
	var created_doors: Array = []
	var sound: Resource = null
	if ResourceLoader.exists(GameConfig.DOOR_SOUND_PATH):
		sound = load(GameConfig.DOOR_SOUND_PATH)
	for block: Array in blocks:
		created_doors.append(_create_door(block, grid_data, grid_rows, grid_cols, sound, 0.0))
	return created_doors


func _create_door(block: Array, grid_data: Array, grid_rows: int, grid_cols: int, sound: Resource, y_offset: float) -> Door:
	var s := GameConfig.SCALE
	var wh := GameConfig.WALL_HEIGHT
	var col: int = block[0]; var row: int = block[1]
	var w: int = block[2]; var h: int = block[3]

	var is_horizontal: bool = MapParser.detect_orientation(grid_data, grid_rows, grid_cols, col, row, w, h)
	var door := Door.new()
	door.pivot = Node3D.new()
	door.is_horizontal = is_horizontal

	var door_width: float
	var door_thickness: float = s * 2.0
	var door_height: float = wh * 0.9

	if is_horizontal:
		door_width = w * s
	else:
		door_width = h * s

	var pivot_x: float; var pivot_z: float
	if is_horizontal:
		pivot_x = col * s
		pivot_z = (row + h / 2.0) * s
	else:
		pivot_x = (col + w / 2.0) * s
		pivot_z = row * s

	door.pivot.position = Vector3(pivot_x, y_offset, pivot_z)
	door.center_pos = Vector3((col + w / 2.0) * s, y_offset + 1.0, (row + h / 2.0) * s)

	door.mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	if is_horizontal:
		box.size = Vector3(door_width, door_height, door_thickness)
		door.mesh.position = Vector3(door_width / 2.0, door_height / 2.0, 0)
	else:
		box.size = Vector3(door_thickness, door_height, door_width)
		door.mesh.position = Vector3(0, door_height / 2.0, door_width / 2.0)
	door.mesh.mesh = box
	door.mesh.material_override = MaterialFactory.create_door_material()

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

	return door


# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

func setup_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()

	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.15, 0.18, 0.35)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.45, 0.6)
	env.ambient_light_energy = 0.5
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.015
	env.volumetric_fog_albedo = Color(0.6, 0.65, 0.8)
	env.volumetric_fog_emission_energy = 0.0
	env.volumetric_fog_length = 50.0
	env.volumetric_fog_detail_spread = 2.0
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.05
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 0.85

	world_env.environment = env
	add_child(world_env)

	# Directional sun light
	var sun_light := DirectionalLight3D.new()
	sun_light.light_color = Color(1.0, 0.7, 0.5)
	sun_light.light_energy = 0.6
	sun_light.shadow_enabled = true
	sun_light.shadow_blur = 1.5
	sun_light.rotation_degrees = Vector3(-15, -45, 0)
	add_child(sun_light)

	# Sun sphere mesh
	var sun_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 15.0
	sphere.height = 30.0
	sun_mesh.mesh = sphere

	var distance: float = 300.0
	var angle_h: float = deg_to_rad(-45 + 180)
	var angle_v: float = deg_to_rad(15)
	sun_mesh.position = Vector3(
		cos(angle_h) * cos(angle_v) * distance,
		sin(angle_v) * distance,
		sin(angle_h) * cos(angle_v) * distance
	)

	var sun_mat := StandardMaterial3D.new()
	sun_mat.emission_enabled = true
	sun_mat.emission = Color(1.0, 0.6, 0.3)
	sun_mat.emission_energy_multiplier = 3.0
	sun_mat.albedo_color = Color(1.0, 0.7, 0.4)
	sun_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sun_mesh.material_override = sun_mat
	add_child(sun_mesh)
