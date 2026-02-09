class_name PuzzleManager
extends Node3D
## Manages all puzzle systems: UV lamp parts, quiz PC, stroboscope disc, exit door, and win condition.

# --- Shared puzzle state ---
var found_digits: Array = [-1, -1, -1, -1]
var current_quest: String = "find_exit"

# --- UV Puzzle ---
var uv_parts_collected: int = 0
var uv_parts: Array = []
var has_uv_lamp := false
var uv_mode := false
var uv_tableau: Node3D = null
var uv_chiffre_mesh: MeshInstance3D = null

# --- Quiz ---
var pc_node: Node3D = null
var pc_screen_light: SpotLight3D = null
var quiz_active := false
var quiz_current_question: int = 0
var quiz_correct_count: int = 0
var pc_done := false

var quiz_questions: Array = [
	{
		"question": "Quelle est la vitesse de la lumière dans le vide ?",
		"answers": ["300 000 km/s", "150 000 km/s", "1 000 000 km/s", "30 000 km/s"],
		"correct": 0,
	},
	{
		"question": "Quelle couleur a la plus grande longueur d'onde ?",
		"answers": ["Bleu", "Vert", "Rouge", "Violet"],
		"correct": 2,
	},
	{
		"question": "Que signifie UV dans 'lumière UV' ?",
		"answers": ["Ultra-Visible", "Ultra-Violet", "Uni-Variable", "Ultra-Vitesse"],
		"correct": 1,
	},
	{
		"question": "Quel phénomène décompose la lumière blanche en arc-en-ciel ?",
		"answers": ["La réflexion", "La diffraction", "La réfraction", "L'absorption"],
		"correct": 2,
	},
]

# --- Strobe ---
var has_strobe := false
var strobe_node: Node3D = null
var strobe_active := false
var spinning_disc: MeshInstance3D = null
var spinning_disc_pos := Vector3.ZERO
var disc_chiffre_mesh: MeshInstance3D = null
var disc_rotation_speed: float = 720.0

# --- Exit ---
var exit_door_pos := Vector3.ZERO
var exit_door_found := false
var game_won := false
var win_overlay: ColorRect = null

# --- References ---
var room_positions: Array = []
var spawn_position := Vector3.ZERO
var game_ui: GameUI


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(positions: Array, spawn_pos: Vector3, ui: GameUI) -> void:
	room_positions = positions
	spawn_position = spawn_pos
	game_ui = ui

	_place_exit_door()
	_place_uv_parts()
	_place_uv_tableau()
	_place_pc()
	_place_strobe_and_disc()


func _get_room_pos(index: int) -> Vector3:
	if index < room_positions.size():
		return room_positions[index]
	return spawn_position + Vector3(10, 0, 10)


func _show_message(text: String) -> void:
	if game_ui:
		game_ui.show_message(text)


# ---------------------------------------------------------------------------
# Exit Door
# ---------------------------------------------------------------------------

func _place_exit_door() -> void:
	var best_pos := Vector3.ZERO
	var best_dist: float = 0
	for i: int in range(mini(room_positions.size(), 20)):
		var d: float = room_positions[i].distance_to(spawn_position)
		if d > best_dist:
			best_dist = d
			best_pos = room_positions[i]
	exit_door_pos = best_pos

	var wh := GameConfig.WALL_HEIGHT

	# Door mesh
	var door_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, wh * 0.9, 0.15)
	door_mesh.mesh = box
	door_mesh.position = Vector3(exit_door_pos.x, wh * 0.45, exit_door_pos.z)
	door_mesh.material_override = MaterialFactory.create_emissive_material(
		Color(0.5, 0.1, 0.1), Color(0.3, 0.0, 0.0), 0.5)
	add_child(door_mesh)

	# Exit sign
	var exit_sign := MeshInstance3D.new()
	var sign_box := BoxMesh.new()
	sign_box.size = Vector3(1.2, 0.3, 0.05)
	exit_sign.mesh = sign_box
	exit_sign.position = Vector3(exit_door_pos.x, wh * 0.9 + 0.3, exit_door_pos.z)
	exit_sign.material_override = MaterialFactory.create_emissive_material(
		Color(0.0, 0.8, 0.0), Color(0.0, 1.0, 0.0), 2.0)
	add_child(exit_sign)

	# Green light
	var exit_light := OmniLight3D.new()
	exit_light.light_color = Color(0.0, 1.0, 0.2)
	exit_light.light_energy = 2.0
	exit_light.omni_range = 8.0
	exit_light.position = Vector3(exit_door_pos.x, wh * 0.9, exit_door_pos.z)
	add_child(exit_light)

	print("Exit door: ", exit_door_pos)


# ---------------------------------------------------------------------------
# UV Parts & Tableau
# ---------------------------------------------------------------------------

func _place_uv_parts() -> void:
	var part_names: Array = ["Ampoule UV", "Boitier", "Batterie", "Filtre"]
	for i: int in range(GameConfig.UV_PARTS_NEEDED):
		var pos: Vector3 = _get_room_pos(i + 1)
		var part := Node3D.new()
		part.position = pos
		part.set_meta("part_name", part_names[i])
		part.set_meta("is_uv_part", true)

		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.2
		sphere.height = 0.4
		mesh.mesh = sphere
		mesh.position.y = 0.3
		mesh.material_override = MaterialFactory.create_emissive_material(
			Color(0.5, 0.1, 0.9), Color(0.4, 0.0, 1.0), 2.0)

		var light := OmniLight3D.new()
		light.light_color = Color(0.5, 0.1, 1.0)
		light.light_energy = 1.5
		light.omni_range = 5.0
		light.position.y = 0.5

		part.add_child(mesh)
		part.add_child(light)
		add_child(part)
		uv_parts.append(part)
		print("UV piece [", part_names[i], "]: ", pos)


func _place_uv_tableau() -> void:
	var pos: Vector3 = _get_room_pos(GameConfig.UV_PARTS_NEEDED + 2)
	uv_tableau = Node3D.new()
	uv_tableau.position = pos

	# White board
	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 1.2, 0.05)
	board.mesh = box
	board.position = Vector3(0, 2.0, 0)
	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.9, 0.9, 0.9)
	board.material_override = board_mat
	uv_tableau.add_child(board)

	# Hidden digit (invisible, revealed by UV)
	uv_chiffre_mesh = MeshInstance3D.new()
	var chiffre_box := BoxMesh.new()
	chiffre_box.size = Vector3(0.8, 0.8, 0.06)
	uv_chiffre_mesh.mesh = chiffre_box
	uv_chiffre_mesh.position = Vector3(0, 2.0, 0.02)
	var chiffre_mat := StandardMaterial3D.new()
	chiffre_mat.albedo_color = Color(0.9, 0.9, 0.9, 0.0)
	chiffre_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	chiffre_mat.emission_enabled = true
	chiffre_mat.emission = Color(0.3, 0.0, 1.0)
	chiffre_mat.emission_energy_multiplier = 0.0
	uv_chiffre_mesh.material_override = chiffre_mat
	uv_tableau.add_child(uv_chiffre_mesh)

	# "TABLEAU" label beneath
	var label_mesh := MeshInstance3D.new()
	var label_box := BoxMesh.new()
	label_box.size = Vector3(1.0, 0.15, 0.03)
	label_mesh.mesh = label_box
	label_mesh.position = Vector3(0, 1.3, 0)
	var label_mat := StandardMaterial3D.new()
	label_mat.albedo_color = Color(0.3, 0.2, 0.1)
	label_mesh.material_override = label_mat
	uv_tableau.add_child(label_mesh)

	add_child(uv_tableau)
	print("UV Tableau: ", pos)


## Call each frame to reveal / hide the UV digit based on player distance & UV mode.
func update_uv_tableau(player_pos: Vector3) -> void:
	if not uv_chiffre_mesh:
		return
	var dist: float = player_pos.distance_to(uv_tableau.global_position)
	var mat: StandardMaterial3D = uv_chiffre_mesh.material_override

	if uv_mode and has_uv_lamp and dist < 6.0:
		var reveal: float = clampf(1.0 - (dist - 2.0) / 4.0, 0.0, 1.0)
		mat.albedo_color = Color(0.3, 0.0, 1.0, reveal * 0.9)
		mat.emission_energy_multiplier = reveal * 4.0
		if reveal > 0.5 and found_digits[0] == -1:
			found_digits[0] = GameConfig.EXIT_CODE[0]
			_show_message("Chiffre 1 trouve : " + str(GameConfig.EXIT_CODE[0]))
			_update_quest()
	else:
		mat.albedo_color = Color(0.9, 0.9, 0.9, 0.0)
		mat.emission_energy_multiplier = 0.0


# ---------------------------------------------------------------------------
# PC Quiz
# ---------------------------------------------------------------------------

func _place_pc() -> void:
	var pos: Vector3 = _get_room_pos(GameConfig.UV_PARTS_NEEDED + 3)
	pc_node = Node3D.new()
	pc_node.position = pos
	pc_node.set_meta("is_pc", true)

	# Desk
	var desk := MeshInstance3D.new()
	var desk_box := BoxMesh.new()
	desk_box.size = Vector3(1.2, 0.8, 0.6)
	desk.mesh = desk_box
	desk.position.y = 0.4
	var desk_mat := StandardMaterial3D.new()
	desk_mat.albedo_color = Color(0.35, 0.25, 0.15)
	desk.material_override = desk_mat
	pc_node.add_child(desk)

	# Screen
	var screen := MeshInstance3D.new()
	var screen_box := BoxMesh.new()
	screen_box.size = Vector3(0.7, 0.5, 0.05)
	screen.mesh = screen_box
	screen.position = Vector3(0, 1.1, 0)
	screen.material_override = MaterialFactory.create_emissive_material(
		Color(0.1, 0.2, 0.4), Color(0.2, 0.4, 0.8), 2.0)
	pc_node.add_child(screen)

	# Screen light
	pc_screen_light = SpotLight3D.new()
	pc_screen_light.light_color = Color(0.3, 0.5, 1.0)
	pc_screen_light.light_energy = 5.0
	pc_screen_light.spot_range = 8.0
	pc_screen_light.spot_angle = 60.0
	pc_screen_light.position = Vector3(0, 1.2, 0.5)
	pc_node.add_child(pc_screen_light)

	add_child(pc_node)
	print("PC Quiz: ", pos)


func open_quiz() -> void:
	if quiz_active or pc_done:
		return
	quiz_active = true
	quiz_current_question = 0
	quiz_correct_count = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_ui.quiz_panel.visible = true
	_show_quiz_question()


func _show_quiz_question() -> void:
	if quiz_current_question >= quiz_questions.size():
		if quiz_correct_count >= quiz_questions.size():
			game_ui.quiz_question_label.text = "Correct ! Le chiffre est : " + str(GameConfig.EXIT_CODE[1])
			found_digits[1] = GameConfig.EXIT_CODE[1]
			pc_done = true
			_update_quest()
			get_tree().create_timer(2.0).timeout.connect(close_quiz)
		else:
			game_ui.quiz_question_label.text = "Trop d'erreurs... Reessayez."
			get_tree().create_timer(1.5).timeout.connect(close_quiz)
		for child: Node in game_ui.quiz_answers_container.get_children():
			child.queue_free()
		return

	var q: Dictionary = quiz_questions[quiz_current_question]
	game_ui.quiz_question_label.text = "Q" + str(quiz_current_question + 1) + "/" + str(quiz_questions.size()) + " : " + q["question"]
	for child: Node in game_ui.quiz_answers_container.get_children():
		child.queue_free()
	for i: int in range(q["answers"].size()):
		var btn := Button.new()
		btn.text = q["answers"][i]
		btn.custom_minimum_size = Vector2(400, 40)
		var answer_index: int = i
		btn.pressed.connect(_on_quiz_answer.bind(answer_index))
		game_ui.quiz_answers_container.add_child(btn)


func _on_quiz_answer(index: int) -> void:
	var q: Dictionary = quiz_questions[quiz_current_question]
	if index == q["correct"]:
		quiz_correct_count += 1
	quiz_current_question += 1
	_show_quiz_question()


func close_quiz() -> void:
	quiz_active = false
	game_ui.quiz_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------------------
# Strobe + Spinning Disc
# ---------------------------------------------------------------------------

func _place_strobe_and_disc() -> void:
	# Stroboscope pickup
	var strobe_pos: Vector3 = _get_room_pos(GameConfig.UV_PARTS_NEEDED + 4)
	strobe_node = Node3D.new()
	strobe_node.position = strobe_pos
	strobe_node.set_meta("is_strobe", true)

	var strobe_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.1
	cyl.bottom_radius = 0.15
	cyl.height = 0.4
	strobe_mesh.mesh = cyl
	strobe_mesh.position.y = 0.3
	strobe_mesh.material_override = MaterialFactory.create_emissive_material(
		Color(0.9, 0.9, 0.2), Color(1.0, 1.0, 0.3), 1.5)

	var strobe_light := OmniLight3D.new()
	strobe_light.light_color = Color(1.0, 1.0, 0.4)
	strobe_light.light_energy = 1.0
	strobe_light.omni_range = 4.0
	strobe_light.position.y = 0.5

	strobe_node.add_child(strobe_mesh)
	strobe_node.add_child(strobe_light)
	add_child(strobe_node)

	# Spinning disc with hidden digit
	var disc_pos: Vector3 = _get_room_pos(GameConfig.UV_PARTS_NEEDED + 5)
	spinning_disc_pos = disc_pos

	spinning_disc = MeshInstance3D.new()
	var disc_cyl := CylinderMesh.new()
	disc_cyl.top_radius = 0.6
	disc_cyl.bottom_radius = 0.6
	disc_cyl.height = 0.05
	spinning_disc.mesh = disc_cyl
	spinning_disc.position = Vector3(disc_pos.x, 2.0, disc_pos.z)
	spinning_disc.rotation_degrees = Vector3(90, 0, 0)
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.2, 0.2, 0.2)
	spinning_disc.material_override = disc_mat
	add_child(spinning_disc)

	# Digit on the disc
	disc_chiffre_mesh = MeshInstance3D.new()
	var chiffre_box := BoxMesh.new()
	chiffre_box.size = Vector3(0.3, 0.06, 0.3)
	disc_chiffre_mesh.mesh = chiffre_box
	disc_chiffre_mesh.position = Vector3(0, 0.03, 0)
	disc_chiffre_mesh.material_override = MaterialFactory.create_emissive_material(
		Color(1.0, 0.2, 0.2), Color(1.0, 0.0, 0.0), 2.0)
	spinning_disc.add_child(disc_chiffre_mesh)

	# Support pole
	var support := MeshInstance3D.new()
	var support_box := BoxMesh.new()
	support_box.size = Vector3(0.1, 2.0, 0.1)
	support.mesh = support_box
	support.position = Vector3(disc_pos.x, 1.0, disc_pos.z)
	var support_mat := StandardMaterial3D.new()
	support_mat.albedo_color = Color(0.3, 0.3, 0.3)
	support.material_override = support_mat
	add_child(support)

	print("Stroboscope: ", strobe_pos, " | Disc: ", disc_pos)


## Call each frame to rotate the disc and check if the player can read the digit.
func update_spinning_disc(delta: float, player_pos: Vector3) -> void:
	if not spinning_disc:
		return
	if strobe_active and has_strobe:
		spinning_disc.rotation_degrees.z += 5.0 * delta
	else:
		spinning_disc.rotation_degrees.z += disc_rotation_speed * delta

	if strobe_active and has_strobe:
		var dist: float = player_pos.distance_to(spinning_disc_pos)
		if dist < 4.0 and found_digits[2] == -1:
			found_digits[2] = GameConfig.EXIT_CODE[2]
			_show_message("Chiffre 3 trouve : " + str(GameConfig.EXIT_CODE[2]))
			_update_quest()


# ---------------------------------------------------------------------------
# Quest & interaction helpers
# ---------------------------------------------------------------------------

func _update_quest() -> void:
	var digits_found: int = get_digits_found_count()
	if digits_found >= 3 and not game_won:
		current_quest = "enter_code"
	elif exit_door_found:
		current_quest = "find_clues"


func get_digits_found_count() -> int:
	var count: int = 0
	for d: int in found_digits:
		if d != -1:
			count += 1
	return count


## Return the interaction prompt text for puzzles, or "" if none.
func check_interactions(player_pos: Vector3) -> String:
	for part: Node3D in uv_parts:
		if not is_instance_valid(part) or not part.visible:
			continue
		if player_pos.distance_to(part.global_position) < GameConfig.INTERACT_DISTANCE:
			return "[E] Ramasser " + part.get_meta("part_name", "Piece")

	if pc_node and not pc_done:
		if player_pos.distance_to(pc_node.global_position) < GameConfig.INTERACT_DISTANCE:
			return "[E] Utiliser le PC"

	if strobe_node and is_instance_valid(strobe_node) and strobe_node.visible and not has_strobe:
		if player_pos.distance_to(strobe_node.global_position) < GameConfig.INTERACT_DISTANCE:
			return "[E] Ramasser Stroboscope"

	var exit_dist: float = player_pos.distance_to(exit_door_pos)
	if exit_dist < GameConfig.INTERACT_DISTANCE:
		var digits_found: int = get_digits_found_count()
		if digits_found >= 3:
			return "[E] Entrer le code !"
		elif exit_door_found:
			return "Porte verrouillee - Code : " + str(digits_found) + "/4"
		else:
			return "[E] Examiner la porte"
	return ""


## Try to interact with the nearest puzzle element. Falls back to the door callback.
func handle_interact(player_pos: Vector3, door_callback: Callable) -> void:
	if quiz_active:
		return

	# UV parts
	for part: Node3D in uv_parts:
		if not is_instance_valid(part) or not part.visible:
			continue
		if player_pos.distance_to(part.global_position) < GameConfig.INTERACT_DISTANCE:
			var pname: String = part.get_meta("part_name", "Piece")
			part.visible = false
			part.set_meta("collected", true)
			uv_parts_collected += 1
			_show_message(pname + " recupere ! (" + str(uv_parts_collected) + "/" + str(GameConfig.UV_PARTS_NEEDED) + ")")
			if uv_parts_collected >= GameConfig.UV_PARTS_NEEDED:
				has_uv_lamp = true
				_show_message("Lampe UV craftee ! [G] pour activer")
			return

	# PC
	if pc_node and not pc_done:
		if player_pos.distance_to(pc_node.global_position) < GameConfig.INTERACT_DISTANCE:
			open_quiz()
			return

	# Stroboscope
	if strobe_node and is_instance_valid(strobe_node) and strobe_node.visible and not has_strobe:
		if player_pos.distance_to(strobe_node.global_position) < GameConfig.INTERACT_DISTANCE:
			has_strobe = true
			strobe_node.visible = false
			_show_message("Stroboscope recupere ! [H] pour activer")
			return

	# Exit door
	_check_exit_interaction(player_pos)

	# Normal doors (fallback)
	door_callback.call()


func _check_exit_interaction(player_pos: Vector3) -> void:
	var dist: float = player_pos.distance_to(exit_door_pos)
	if dist < GameConfig.INTERACT_DISTANCE:
		if not exit_door_found:
			exit_door_found = true
			current_quest = "find_clues"
			_show_message("La porte est verrouillee... Il faut un code a 4 chiffres !")
			_update_quest()
		if get_digits_found_count() >= 3 and not game_won:
			game_won = true
			_trigger_win()


# ---------------------------------------------------------------------------
# Toggle modes
# ---------------------------------------------------------------------------

func toggle_uv() -> void:
	if has_uv_lamp:
		uv_mode = not uv_mode
		strobe_active = false
		_show_message("Lampe UV activee" if uv_mode else "Lampe normale")


func toggle_strobe() -> void:
	if has_strobe:
		strobe_active = not strobe_active
		uv_mode = false
		_show_message("Stroboscope active !" if strobe_active else "Stroboscope desactive")


# ---------------------------------------------------------------------------
# Win
# ---------------------------------------------------------------------------

func _trigger_win() -> void:
	win_overlay = ColorRect.new()
	win_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	win_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var canvas := CanvasLayer.new()
	canvas.layer = 10
	canvas.add_child(win_overlay)

	var win_label := Label.new()
	win_label.text = "VOUS VOUS ETES ECHAPPE !"
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	win_label.set_anchors_preset(Control.PRESET_CENTER)
	win_label.add_theme_font_size_override("font_size", 48)
	win_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.3))
	win_label.modulate.a = 0.0
	canvas.add_child(win_label)
	add_child(canvas)

	var tween := create_tween()
	tween.tween_property(win_overlay, "color:a", 0.85, 2.0)
	tween.parallel().tween_property(win_label, "modulate:a", 1.0, 2.0)
	tween.tween_interval(3.0)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file("res://menu.tscn"))
