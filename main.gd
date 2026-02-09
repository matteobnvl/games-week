extends Node3D
## Main scene orchestrator – wires together WorldBuilder, PlayerController, PuzzleManager, and GameUI.

var player: PlayerController
var game_ui: GameUI
var world_builder: WorldBuilder
var puzzle_manager: PuzzleManager

var doors: Array = []
var grid_data: Array[Array] = []
var grid_rows: int = 0
var grid_cols: int = 0
var staircase_rects: Array = []
var spawn_position := Vector3.ZERO
var room_positions: Array = []

var player_spawned := false
var frames_before_spawn := 3


func _ready() -> void:
	# --- Parse map ---
	var map_data := MapParser.parse_image(GameConfig.MAP_PATH)
	if map_data.is_empty():
		return

	grid_data = map_data["grid"]
	grid_rows = map_data["rows"]
	grid_cols = map_data["cols"]
	var red_grid: Array = map_data["red_grid"]
	var terrace_grid: Array = map_data["terrace_grid"]

	# --- Extract features ---
	var door_blocks: Array = MapParser.find_door_blocks(red_grid, grid_rows, grid_cols)
	var wall_rects: Array = MapParser.merge_type(grid_data, grid_rows, grid_cols, 1)
	var window_rects: Array = MapParser.merge_type(grid_data, grid_rows, grid_cols, 3)
	var terrace_rects: Array = MapParser.merge_type(grid_data, grid_rows, grid_cols, 4)
	var fence_rects: Array = MapParser.merge_type(grid_data, grid_rows, grid_cols, 5)
	var coffee_rects: Array = MapParser.merge_type(grid_data, grid_rows, grid_cols, 6)
	staircase_rects = MapParser.merge_type(grid_data, grid_rows, grid_cols, 7)

	var spawn_grid: Vector2 = MapParser.find_spawn(grid_data, grid_rows, grid_cols)
	spawn_position = Vector3(spawn_grid.x * GameConfig.SCALE, 2.0, spawn_grid.y * GameConfig.SCALE)

	# --- Room positions for puzzle objects ---
	room_positions = MapParser.find_room_positions(grid_data, grid_rows, grid_cols, spawn_position)

	# --- Build world geometry ---
	world_builder = WorldBuilder.new()
	add_child(world_builder)

	world_builder.build_floor(grid_rows, grid_cols)
	world_builder.build_terrace_floors(terrace_rects)
	world_builder.build_ceiling_with_holes(grid_rows, grid_cols, terrace_grid, staircase_rects)
	world_builder.build_walls(wall_rects)
	world_builder.build_windows(window_rects)
	world_builder.build_glass_fences(fence_rects)
	world_builder.build_coffee_machines(coffee_rects)

	# Floor 1 doors
	var f1_doors: Array = world_builder.build_doors_from_blocks(door_blocks, grid_data, grid_rows, grid_cols)
	doors.append_array(f1_doors)

	# Floor 2
	var f2_doors: Array = world_builder.build_floor_2()
	doors.append_array(f2_doors)

	# Staircases
	world_builder.build_staircases(staircase_rects, grid_cols)

	# Environment (sky, fog, sun)
	world_builder.setup_environment()

	# --- UI ---
	game_ui = GameUI.new()
	add_child(game_ui)

	# --- Puzzles ---
	puzzle_manager = PuzzleManager.new()
	add_child(puzzle_manager)
	puzzle_manager.setup(room_positions, spawn_position, game_ui)

	print("Ready! Walls: ", wall_rects.size(), " | Doors: ", doors.size(), " | Rooms: ", room_positions.size())


# ---------------------------------------------------------------------------
# Per-frame updates
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Delayed player spawn (wait a few frames for physics to settle)
	if not player_spawned:
		frames_before_spawn -= 1
		if frames_before_spawn <= 0:
			_spawn_player()
			player_spawned = true

	# Animate doors
	for door: Door in doors:
		door.animate(delta)

	# Puzzle per-frame updates
	if player:
		puzzle_manager.update_spinning_disc(delta, player.global_position)
		puzzle_manager.update_uv_tableau(player.global_position)


func _physics_process(delta: float) -> void:
	if not player:
		return

	# Freeze player during quiz or win
	player.movement_enabled = not puzzle_manager.quiz_active and not puzzle_manager.game_won
	player.update_movement(delta)
	player.update_flashlight(
		delta,
		puzzle_manager.uv_mode,
		puzzle_manager.has_uv_lamp,
		puzzle_manager.strobe_active,
		puzzle_manager.has_strobe,
	)
	_update_ui()


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not player:
		return

	# While quiz is open, only allow Escape to close it
	if puzzle_manager.quiz_active:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			puzzle_manager.close_quiz()
		return

	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.handle_mouse_motion(event.relative)

	# Key presses
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				else:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			KEY_F:
				if not player.is_recharging:
					player.flashlight_on = not player.flashlight_on
					player.flashlight.visible = player.flashlight_on and player.battery > 0
			KEY_G:
				puzzle_manager.toggle_uv()
			KEY_H:
				puzzle_manager.toggle_strobe()
			KEY_E:
				_handle_interact()


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func _handle_interact() -> void:
	puzzle_manager.handle_interact(
		player.global_position,
		func() -> void:
			var nearest: Door = _get_nearest_door()
			if nearest:
				nearest.toggle()
	)


func _get_nearest_door() -> Door:
	if not player:
		return null
	var nearest: Door = null
	var nearest_dist: float = GameConfig.DOOR_INTERACT_DISTANCE
	for door: Door in doors:
		var dist: float = player.global_position.distance_to(door.center_pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = door
	return nearest


# ---------------------------------------------------------------------------
# UI sync
# ---------------------------------------------------------------------------

func _update_ui() -> void:
	game_ui.update_stamina_bar(player.stamina)
	game_ui.update_battery_bar(player.battery, player.is_recharging)
	game_ui.update_uv_label(
		puzzle_manager.uv_parts_collected,
		puzzle_manager.has_uv_lamp,
		puzzle_manager.uv_mode,
		puzzle_manager.has_strobe,
		puzzle_manager.strobe_active,
	)
	game_ui.update_message_timer(get_process_delta_time())

	# Interact label
	game_ui.hide_interact()
	var puzzle_text: String = puzzle_manager.check_interactions(player.global_position)
	if puzzle_text != "":
		game_ui.show_interact(puzzle_text)
	else:
		var nearest: Door = _get_nearest_door()
		if nearest and not nearest.is_animating:
			game_ui.show_interact("[E] Fermer" if nearest.is_open else "[E] Ouvrir")

	game_ui.update_quest(puzzle_manager.current_quest, puzzle_manager.found_digits)


# ---------------------------------------------------------------------------
# Player spawn
# ---------------------------------------------------------------------------

func _spawn_player() -> void:
	player = PlayerController.new()
	player.position = spawn_position
	add_child(player)
	print("Player spawned at: ", player.position)
