extends Node3D
## Main scene orchestrator – wires together WorldBuilder, PlayerController, PuzzleManager, and GameUI.

var player: PlayerController
var game_ui: GameUI
var world_builder: WorldBuilder
var puzzle_manager: PuzzleManager
var enemy: EnemyController

var doors: Array = []
var grid_data: Array[Array] = []
var grid_rows: int = 0
var grid_cols: int = 0
var staircase_rects: Array = []
var spawn_position := Vector3.ZERO
var room_positions: Array = []

var player_spawned := false
var frames_before_spawn := 3
var game_over := false
var ambient_music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# --- Setup audio buses ---
	_setup_audio_buses()

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
	world_builder.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	game_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(game_ui)

	# --- Puzzles ---
	puzzle_manager = PuzzleManager.new()
	puzzle_manager.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(puzzle_manager)
	puzzle_manager.setup(room_positions, spawn_position, game_ui)

	print("Ready! Walls: ", wall_rects.size(), " | Doors: ", doors.size(), " | Rooms: ", room_positions.size())


# ---------------------------------------------------------------------------
# Per-frame updates
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Don't run game logic while paused
	if get_tree().paused:
		return

	# Delayed player spawn (wait a few frames for physics to settle)
	if not player_spawned:
		frames_before_spawn -= 1
		if frames_before_spawn <= 0:
			_spawn_player()
			_spawn_enemy()
			_start_ambient_music()
			player_spawned = true

	# Animate doors
	for door: Door in doors:
		door.animate(delta)

	# Puzzle per-frame updates
	if player:
		puzzle_manager.update_spinning_disc(delta, player.global_position)
		puzzle_manager.update_uv_tableau(player.global_position)


func _physics_process(delta: float) -> void:
	if not player or game_over or get_tree().paused:
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
	# Allow pause toggle even while paused
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not puzzle_manager.quiz_active:
			_toggle_pause_menu()
			return
	
	# Block all other input while paused
	if get_tree().paused:
		return

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
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	print("Player spawned at: ", player.position)


func _spawn_enemy() -> void:
	# Find a spawn point far from the player
	var best_pos := Vector3.ZERO
	var best_dist: float = 0
	for pos: Vector3 in room_positions:
		var d: float = pos.distance_to(spawn_position)
		if d > GameConfig.ENEMY_SPAWN_MIN_DIST and d > best_dist:
			best_dist = d
			best_pos = pos
	if best_pos == Vector3.ZERO and room_positions.size() > 0:
		best_pos = room_positions[room_positions.size() - 1]

	enemy = EnemyController.new()
	enemy.model_path = GameConfig.ENEMY2_MODEL_PATH
	enemy.model_scale = GameConfig.ENEMY2_MODEL_SCALE
	enemy.model_y_offset = GameConfig.ENEMY2_MODEL_Y_OFFSET
	enemy.anim_walk = GameConfig.ENEMY2_MODEL_WALK_ANIMATION
	enemy.anim_run = GameConfig.ENEMY2_MODEL_RUN_ANIMATION
	enemy.anim_attack = GameConfig.ENEMY2_MODEL_ATTACK_ANIMATION
	enemy.anim_idle = GameConfig.ENEMY2_MODEL_IDLE_ANIMATION
	enemy.anim_scream = GameConfig.ENEMY2_MODEL_SCREAM_ANIMATION
	enemy.position = Vector3(best_pos.x, 2.0, best_pos.z)
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(enemy)

	var waypoints: Array = []
	for i: int in range(mini(room_positions.size(), 15)):
		waypoints.append(room_positions[i])
	enemy.setup(grid_data, grid_rows, grid_cols, waypoints, player, doors)
	enemy.caught_player.connect(_on_player_caught)
	print("Enemy (funny_fear) spawned at: ", enemy.position)


func _on_player_caught() -> void:
	if game_over:
		return
	game_over = true
	player.movement_enabled = false
	if ambient_music and ambient_music.playing:
		ambient_music.stop()
	game_ui.show_game_over()
	print("GAME OVER - Felipe caught you!")


func _start_ambient_music() -> void:
	var paths: Array = GameConfig.AMBIENT_MUSIC_PATHS
	if paths.is_empty():
		return
	var chosen_path: String = paths[randi() % paths.size()]
	if not ResourceLoader.exists(chosen_path):
		print("Ambient music not found: ", chosen_path)
		return
	ambient_music = AudioStreamPlayer.new()
	ambient_music.process_mode = Node.PROCESS_MODE_PAUSABLE
	var music: Resource = load(chosen_path)
	if music:
		ambient_music.stream = music
		ambient_music.volume_db = -10.0
		ambient_music.bus = "Music"
		add_child(ambient_music)
		ambient_music.finished.connect(_on_ambient_music_finished)
		ambient_music.play()
		print("Ambient music: ", chosen_path)


func _on_ambient_music_finished() -> void:
	if game_over or not ambient_music:
		return
	# Pick a new random track and play it
	var paths: Array = GameConfig.AMBIENT_MUSIC_PATHS
	var chosen_path: String = paths[randi() % paths.size()]
	if ResourceLoader.exists(chosen_path):
		var music: Resource = load(chosen_path)
		if music:
			ambient_music.stream = music
			ambient_music.play()


# ---------------------------------------------------------------------------
# Audio buses
# ---------------------------------------------------------------------------

var _pause_open := false

func _setup_audio_buses() -> void:
	# Create buses: Music, Monster, Environment (all routed to Master)
	for bus_name: String in ["Music", "Monster", "Environment"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _toggle_pause_menu() -> void:
	if game_over:
		return
	_pause_open = not _pause_open
	if _pause_open:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		game_ui.show_pause_menu()
	else:
		game_ui.hide_pause_menu()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false
