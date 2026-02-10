class_name MapParser
## Static utility class for parsing map images into grid data and finding features.


## Parse a floor-1 map image and return a dictionary with grid, red_grid, terrace_grid, rows, cols.
static func parse_image(path: String) -> Dictionary:
	var image := Image.new()
	var err: int = image.load(path)
	if err != OK:
		push_error("Cannot load map: " + path)
		return {}

	var cols: int = image.get_width()
	var rows: int = image.get_height()
	var grid: Array[Array] = []
	var red_grid: Array[Array] = []
	var terrace_grid: Array[Array] = []
	var threshold_ratio: float = GameConfig.THRESHOLD / 255.0

	for row: int in range(rows):
		var line: Array[int] = []
		var red_line: Array[bool] = []
		var terrace_line: Array[bool] = []
		for col: int in range(cols):
			var px: Color = image.get_pixel(col, row)
			if px.r > 0.8 and px.g < 0.3 and px.b < 0.3:
				line.append(2)            # Red = door
				red_line.append(true)
				terrace_line.append(false)
			elif px.b > 0.8 and px.r < 0.3 and px.g < 0.3:
				line.append(3)            # Blue = window
				red_line.append(false)
				terrace_line.append(false)
			elif px.g > 0.8 and px.r < 0.3 and px.b < 0.3:
				line.append(4)            # Green = terrace
				red_line.append(false)
				terrace_line.append(true)
			elif px.r > 0.8 and px.g < 0.3 and px.b > 0.8:
				line.append(5)            # Magenta = fence
				red_line.append(false)
				terrace_line.append(false)
			elif px.r < 0.3 and px.g > 0.8 and px.b > 0.8:
				line.append(6)            # Cyan = coffee machine
				red_line.append(false)
				terrace_line.append(false)
			elif px.r > 0.8 and px.g > 0.8 and px.b < 0.3:
				line.append(7)            # Yellow = staircase
				red_line.append(false)
				terrace_line.append(false)
			elif px.r < threshold_ratio:
				line.append(1)            # Dark = wall
				red_line.append(false)
				terrace_line.append(false)
			else:
				line.append(0)            # White = open space
				red_line.append(false)
				terrace_line.append(false)
		grid.append(line)
		red_grid.append(red_line)
		terrace_grid.append(terrace_line)

	return {
		"grid": grid,
		"red_grid": red_grid,
		"terrace_grid": terrace_grid,
		"rows": rows,
		"cols": cols,
	}


## Parse a floor-2 map image and return grid, red_grid, void_grid, rows, cols.
static func parse_floor2_image(path: String) -> Dictionary:
	var image := Image.new()
	var err: int = image.load(path)
	if err != OK:
		push_error("Cannot load floor-2 map: " + path)
		return {}

	var cols: int = image.get_width()
	var rows: int = image.get_height()
	var grid: Array[Array] = []
	var red_grid: Array[Array] = []
	var void_grid: Array[Array] = []
	var threshold_ratio: float = GameConfig.THRESHOLD / 255.0

	for row: int in range(rows):
		var line: Array[int] = []
		var red_line: Array[bool] = []
		var void_line: Array[bool] = []
		for col: int in range(cols):
			var px: Color = image.get_pixel(col, row)
			if px.r > 0.8 and px.g > 0.8 and px.b < 0.4:
				line.append(0)            # Yellow = void
				red_line.append(false)
				void_line.append(true)
			elif px.r > 0.8 and px.g < 0.3 and px.b < 0.3:
				line.append(2)            # Red = door
				red_line.append(true)
				void_line.append(false)
			elif px.b > 0.6 and px.r < 0.3 and px.g < 0.3:
				line.append(3)            # Blue = window
				red_line.append(false)
				void_line.append(false)
			elif px.r < threshold_ratio:
				line.append(1)            # Dark = wall
				red_line.append(false)
				void_line.append(false)
			else:
				line.append(0)            # Open
				red_line.append(false)
				void_line.append(false)
		grid.append(line)
		red_grid.append(red_line)
		void_grid.append(void_line)

	return {
		"grid": grid,
		"red_grid": red_grid,
		"void_grid": void_grid,
		"rows": rows,
		"cols": cols,
	}


## Find a good spawn point in open space near the center of the map.
static func find_spawn(grid: Array, rows: int, cols: int) -> Vector2:
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


## Flood-fill to find connected red (door) pixel blocks. Returns Array of [col, row, w, h].
static func find_door_blocks(red_grid: Array, rows: int, cols: int) -> Array:
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
				for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = p.x + dir.x
					var ny: int = p.y + dir.y
					if nx >= 0 and nx < cols and ny >= 0 and ny < rows:
						if red_grid[ny][nx] and not visited[ny][nx]:
							visited[ny][nx] = true
							stack.append(Vector2i(nx, ny))

			blocks.append([min_col, min_row, max_col - min_col + 1, max_row - min_row + 1])
	return blocks


## Merge adjacent cells of a given type into larger rectangles. Returns Array of [col, row, w, h].
static func merge_type(grid: Array, rows: int, cols: int, type_id: int) -> Array:
	var visited: Array[Array] = []
	for row: int in range(rows):
		var line: Array[bool] = []
		line.resize(cols)
		line.fill(false)
		visited.append(line)

	var rectangles: Array = []
	for row: int in range(rows):
		for col: int in range(cols):
			if grid[row][col] != type_id or visited[row][col]:
				continue
			var width: int = 0
			for c: int in range(col, cols):
				if grid[row][c] == type_id and not visited[row][c]:
					width += 1
				else:
					break
			var height: int = 0
			for r: int in range(row, rows):
				var full_row: bool = true
				for c: int in range(col, col + width):
					if c >= cols or grid[r][c] != type_id or visited[r][c]:
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


## Merge non-excluded areas into rectangles (used for ceiling/floor generation).
static func merge_non_excluded_areas(rows: int, cols: int, exclude_grid: Array) -> Array:
	var visited: Array[Array] = []
	for row: int in range(rows):
		var line: Array[bool] = []
		line.resize(cols)
		line.fill(false)
		visited.append(line)

	var rectangles: Array = []
	for row: int in range(rows):
		for col: int in range(cols):
			if exclude_grid[row][col] or visited[row][col]:
				continue
			var width: int = 0
			for c: int in range(col, cols):
				if not exclude_grid[row][c] and not visited[row][c]:
					width += 1
				else:
					break
			var height: int = 0
			for r: int in range(row, rows):
				var full_row: bool = true
				for c: int in range(col, col + width):
					if c >= cols or exclude_grid[r][c] or visited[r][c]:
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


## Detect whether a door block is oriented horizontally based on surrounding walls.
static func detect_orientation(grid_data: Array, grid_rows: int, grid_cols: int, col: int, row: int, w: int, h: int) -> bool:
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
	return false


## Scan the grid for open areas suitable for placing objects.
static func find_room_positions(grid_data: Array, grid_rows: int, grid_cols: int, spawn_position: Vector3, height: float = 0.5) -> Array:
	var positions: Array = []
	var step: int = 25
	var s: float = GameConfig.SCALE
	var spawn_gx: int = int(spawn_position.x / s)
	var spawn_gz: int = int(spawn_position.z / s)

	for gz: int in range(step, grid_rows - step, step):
		for gx: int in range(step, grid_cols - step, step):
			var open := true
			for dz: int in range(-2, 3):
				for dx: int in range(-2, 3):
					var cx: int = gx + dx
					var cz: int = gz + dz
					if cx < 0 or cx >= grid_cols or cz < 0 or cz >= grid_rows:
						open = false
						break
					if grid_data[cz][cx] != 0:
						open = false
						break
				if not open:
					break
			if not open:
				continue
			if Vector2(gx, gz).distance_to(Vector2(spawn_gx, spawn_gz)) < 40:
				continue
			positions.append(Vector3(gx * s, height, gz * s))

	positions.shuffle()
	return positions
