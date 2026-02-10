class_name PuzzleManager
extends Node3D
## Manages all puzzle systems with decoy objects: UV lamp parts, quiz PCs, stroboscope discs, exit door, and win condition.

# --- Shared puzzle state ---
var found_digits: Array = [-1, -1, -1, -1]
var current_quest: String = "find_exit"

# --- Decoy indices (randomized in setup) ---
var uv_real_index: int = 0
var pc_real_index: int = 0
var strobe_real_index: int = 0
var disc_real_index: int = 0

# --- UV Puzzle ---
var uv_parts_collected: int = 0
var uv_parts: Array = []
var has_uv_lamp := false
var uv_mode := false
var uv_tableaux: Array = []          # Array of Node3D (4 tableaux)
var uv_chiffre_meshes: Array = []    # Array of MeshInstance3D (4 digit meshes)

# --- Quiz ---
var pc_nodes: Array = []             # Array of Node3D (3 PCs)
var pc_screen_lights: Array = []     # Array of SpotLight3D
var quiz_active := false
var quiz_current_question: int = 0
var quiz_correct_count: int = 0
var pc_done := false
var active_pc_is_real := false       # Set when player interacts with a PC

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
var strobe_nodes: Array = []         # Array of Node3D (3 stroboscopes)
var strobe_active := false
var picked_strobe_is_real := false   # Was the picked strobe the real one?
var carried_strobe_node: Node3D = null  # Reference to the strobe the player is carrying

# --- Spinning Discs ---
var spinning_discs: Array = []       # Array of MeshInstance3D (4 discs)
var spinning_disc_positions: Array = []  # Array of Vector3
var disc_chiffre_meshes: Array = []  # Array of MeshInstance3D
var disc_rotation_speed: float = 720.0

# --- Exit ---
var exit_code: Array = [0, 0, 0, 0]
var code_panel_open: bool = false

var exit_door_pos := Vector3.ZERO
var exit_door_found := false
var game_won := false
var win_overlay: ColorRect = null

# --- References ---
var room_positions: Array = []
var spawn_position := Vector3.ZERO
var game_ui: GameUI

# --- Horror messages for decoys ---
var fake_uv_messages: Array = []
var fake_pc_messages: Array = []
var fake_strobe_messages: Array = []
var fake_disc_messages: Array = []

# --- Room position offsets ---
const UV_PART_START := 1       # positions 1-4
const TABLEAU_START := 5       # positions 5-8
const PC_START := 9            # positions 9-11
const STROBE_START := 12       # positions 12-14
const DISC_START := 15         # positions 15-18


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(positions: Array, spawn_pos: Vector3, ui: GameUI) -> void:
	room_positions = positions
	spawn_position = spawn_pos
	game_ui = ui

	# Generate random exit code + lure messages
	_generate_exit_code()

	# Randomize decoy indices
	uv_real_index = randi() % 4
	pc_real_index = randi() % 3
	strobe_real_index = randi() % 3
	disc_real_index = randi() % 4

	_place_exit_door()
	_place_uv_parts()
	_place_uv_tableaux()
	_place_pcs()
	_place_strobes_and_discs()

	print("Exit code: ", exit_code)
	print("Decoy indices - UV:", uv_real_index, " PC:", pc_real_index, " Strobe:", strobe_real_index, " Disc:", disc_real_index)


func _get_room_pos(index: int) -> Vector3:
	if index < room_positions.size():
		return room_positions[index]
	return spawn_position + Vector3(10, 0, 10)


func _show_message(text: String) -> void:
	if game_ui:
		var duration: float = 3.0 + text.length() * 0.04
		game_ui.show_message(text, duration)


func _generate_exit_code() -> void:
	exit_code[0] = randi_range(1, 9)
	exit_code[1] = randi_range(1, 9)
	exit_code[2] = randi_range(1, 9)
	exit_code[3] = randi_range(0, 9)
	_generate_lure_messages()


func _generate_lure_messages() -> void:
	var d4: int = exit_code[3]
	# Split d4 into 3 fragments: (frag_a + frag_b + frag_c) % 10 == d4
	var frag_a: int = randi_range(0, 9)
	var frag_b: int = randi_range(0, 9)
	var frag_c: int = (d4 - frag_a - frag_b) % 10
	if frag_c < 0:
		frag_c += 10

	# UV lures: embed frag_a as last digit of a year
	var year: int = 2010 + frag_a
	fake_uv_messages = [
		"Thomas... promo " + str(year) + "... il dit qu'il est dans les murs...",
		"La bete est furieuse. Tu n'aurais pas du utiliser cette lumiere.",
		"Les murs se souviennent. Ce n'est pas le bon tableau.",
	]

	# PC lures: embed frag_b as last digit of a day count
	var days: int = 800 + frag_b
	fake_pc_messages = [
		"[SYSTEME] Derniere connexion : Emma L. - il y a " + str(days) + " jours... session toujours active.",
		"[CONFIDENTIEL] rapport_incident_2021.pdf - Disparitions etage 2 - Acces refuse.",
	]

	# Strobe lures: hint to try another one
	fake_strobe_messages = [
		"Ce stroboscope appartenait a Lucas M... Il ne fonctionne plus. Cherchez-en un autre.",
		"Pas celui-la... La lumiere est trop faible. Il en existe d'autres.",
	]

	# Disc lures: embed frag_c as a group number
	fake_disc_messages = [
		"Le " + str(frag_c) + "eme groupe a tente de fuir... seules leurs chaussures ont ete retrouvees.",
		"Elle connait le code. Elle attend que tu l'entres.",
		"Ce disque ne montre rien d'utile... la bete a brouille le message.",
	]

	print("Hint fragments: UV=", frag_a, " PC=", frag_b, " Disc=", frag_c, " -> sum%10=", (frag_a + frag_b + frag_c) % 10)


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
# UV Parts & Tableaux (4 tableaux: 1 real + 3 decoys)
# ---------------------------------------------------------------------------

func _place_uv_parts() -> void:
	var part_names: Array = ["Ampoule UV", "Boitier", "Batterie", "Filtre"]
	for i: int in range(GameConfig.UV_PARTS_NEEDED):
		var pos: Vector3 = _get_room_pos(UV_PART_START + i)
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


func _place_uv_tableaux() -> void:
	for i: int in range(4):
		var pos: Vector3 = _get_room_pos(TABLEAU_START + i)
		var is_real: bool = (i == uv_real_index)

		var tableau := Node3D.new()
		tableau.position = pos
		tableau.set_meta("is_real", is_real)
		tableau.set_meta("tableau_index", i)

		# White board
		var board := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.0, 1.2, 0.05)
		board.mesh = box
		board.position = Vector3(0, 2.0, 0)
		var board_mat := StandardMaterial3D.new()
		board_mat.albedo_color = Color(0.9, 0.9, 0.9)
		board.material_override = board_mat
		tableau.add_child(board)

		# Hidden digit (invisible, revealed by UV)
		var chiffre_mesh := MeshInstance3D.new()
		var chiffre_box := BoxMesh.new()
		chiffre_box.size = Vector3(0.8, 0.8, 0.06)
		chiffre_mesh.mesh = chiffre_box
		chiffre_mesh.position = Vector3(0, 2.0, 0.02)
		chiffre_mesh.set_meta("is_real", is_real)
		chiffre_mesh.set_meta("fake_index", i if not is_real else -1)

		var chiffre_mat := StandardMaterial3D.new()
		chiffre_mat.albedo_color = Color(0.9, 0.9, 0.9, 0.0)
		chiffre_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		chiffre_mat.emission_enabled = true
		chiffre_mat.emission = Color(0.3, 0.0, 1.0) if is_real else Color(0.8, 0.0, 0.0)
		chiffre_mat.emission_energy_multiplier = 0.0
		chiffre_mesh.material_override = chiffre_mat
		tableau.add_child(chiffre_mesh)

		# "TABLEAU" label beneath
		var label_mesh := MeshInstance3D.new()
		var label_box := BoxMesh.new()
		label_box.size = Vector3(1.0, 0.15, 0.03)
		label_mesh.mesh = label_box
		label_mesh.position = Vector3(0, 1.3, 0)
		var label_mat := StandardMaterial3D.new()
		label_mat.albedo_color = Color(0.3, 0.2, 0.1)
		label_mesh.material_override = label_mat
		tableau.add_child(label_mesh)

		add_child(tableau)
		uv_tableaux.append(tableau)
		uv_chiffre_meshes.append(chiffre_mesh)
		print("UV Tableau ", i, " (real=", is_real, "): ", pos)


## Call each frame to reveal / hide the UV digit on all tableaux based on player distance & UV mode.
func update_uv_tableau(player_pos: Vector3) -> void:
	for i: int in range(uv_chiffre_meshes.size()):
		var chiffre_mesh: MeshInstance3D = uv_chiffre_meshes[i]
		if not chiffre_mesh or not is_instance_valid(chiffre_mesh):
			continue
		var tableau: Node3D = uv_tableaux[i]
		var dist: float = player_pos.distance_to(tableau.global_position)
		var mat: StandardMaterial3D = chiffre_mesh.material_override
		var is_real: bool = chiffre_mesh.get_meta("is_real", false)

		if uv_mode and has_uv_lamp and dist < 6.0:
			var reveal: float = clampf(1.0 - (dist - 2.0) / 4.0, 0.0, 1.0)
			if is_real:
				mat.albedo_color = Color(0.3, 0.0, 1.0, reveal * 0.9)
			else:
				mat.albedo_color = Color(0.8, 0.0, 0.0, reveal * 0.9)
			mat.emission_energy_multiplier = reveal * 4.0

			if reveal > 0.5:
				if is_real and found_digits[0] == -1:
					found_digits[0] = exit_code[0]
					_show_message("Chiffre 1 trouvé : " + str(exit_code[0]))
					_update_quest()
				elif not is_real:
					var fake_idx: int = chiffre_mesh.get_meta("fake_index", 0)
					# Show fake message only once per approach (use meta to track)
					if not chiffre_mesh.has_meta("message_shown"):
						chiffre_mesh.set_meta("message_shown", true)
						var msg_idx: int = fake_idx % fake_uv_messages.size()
						_show_message(fake_uv_messages[msg_idx])
		else:
			mat.albedo_color = Color(0.9, 0.9, 0.9, 0.0)
			mat.emission_energy_multiplier = 0.0
			# Reset message shown when player walks away
			if chiffre_mesh.has_meta("message_shown"):
				chiffre_mesh.remove_meta("message_shown")


# ---------------------------------------------------------------------------
# PC Quiz (3 PCs: 1 real + 2 decoys)
# ---------------------------------------------------------------------------

func _place_pcs() -> void:
	for i: int in range(3):
		var pos: Vector3 = _get_room_pos(PC_START + i)
		var is_real: bool = (i == pc_real_index)

		var pc := Node3D.new()
		pc.position = pos
		pc.set_meta("is_pc", true)
		pc.set_meta("is_real", is_real)
		pc.set_meta("pc_index", i)

		# Desk
		var desk := MeshInstance3D.new()
		var desk_box := BoxMesh.new()
		desk_box.size = Vector3(1.2, 0.8, 0.6)
		desk.mesh = desk_box
		desk.position.y = 0.4
		var desk_mat := StandardMaterial3D.new()
		desk_mat.albedo_color = Color(0.35, 0.25, 0.15)
		desk.material_override = desk_mat
		pc.add_child(desk)

		# Screen
		var screen := MeshInstance3D.new()
		var screen_box := BoxMesh.new()
		screen_box.size = Vector3(0.7, 0.5, 0.05)
		screen.mesh = screen_box
		screen.position = Vector3(0, 1.1, 0)
		screen.material_override = MaterialFactory.create_emissive_material(
			Color(0.1, 0.2, 0.4), Color(0.2, 0.4, 0.8), 2.0)
		pc.add_child(screen)

		# Screen light
		var pc_light := SpotLight3D.new()
		pc_light.light_color = Color(0.3, 0.5, 1.0)
		pc_light.light_energy = 5.0
		pc_light.spot_range = 8.0
		pc_light.spot_angle = 60.0
		pc_light.position = Vector3(0, 1.2, 0.5)
		pc.add_child(pc_light)
		pc_screen_lights.append(pc_light)

		add_child(pc)
		pc_nodes.append(pc)
		print("PC ", i, " (real=", is_real, "): ", pos)


func open_quiz(is_real: bool) -> void:
	if quiz_active or pc_done:
		return
	quiz_active = true
	active_pc_is_real = is_real
	quiz_current_question = 0
	quiz_correct_count = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_ui.quiz_panel.visible = true
	_show_quiz_question()


func _show_quiz_question() -> void:
	if quiz_current_question >= quiz_questions.size():
		if quiz_correct_count >= quiz_questions.size():
			# All answers correct
			if active_pc_is_real:
				game_ui.quiz_question_label.text = "Correct ! Le chiffre est : " + str(exit_code[1])
				found_digits[1] = exit_code[1]
				pc_done = true
				_update_quest()
			else:
				# Fake PC: show horror message
				var fake_msg: String = fake_pc_messages[randi() % fake_pc_messages.size()]
				game_ui.quiz_question_label.text = fake_msg
		else:
			game_ui.quiz_question_label.text = "Trop d'erreurs... Reessayez."
		for child: Node in game_ui.quiz_answers_container.get_children():
			child.queue_free()
		get_tree().create_timer(2.0).timeout.connect(close_quiz)
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
# Strobe + Spinning Discs (3 strobes: 1 real + 2 decoys, 4 discs: 1 real + 3 decoys)
# ---------------------------------------------------------------------------

func _place_strobes_and_discs() -> void:
	# Place 3 stroboscopes
	for i: int in range(3):
		var pos: Vector3 = _get_room_pos(STROBE_START + i)
		var is_real: bool = (i == strobe_real_index)

		var strobe := Node3D.new()
		strobe.position = pos
		strobe.set_meta("is_strobe", true)
		strobe.set_meta("is_real", is_real)
		strobe.set_meta("strobe_index", i)

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

		strobe.add_child(strobe_mesh)
		strobe.add_child(strobe_light)
		add_child(strobe)
		strobe_nodes.append(strobe)
		print("Stroboscope ", i, " (real=", is_real, "): ", pos)

	# Place 4 spinning discs
	for i: int in range(4):
		var disc_pos: Vector3 = _get_room_pos(DISC_START + i)
		var is_real: bool = (i == disc_real_index)

		spinning_disc_positions.append(disc_pos)

		var disc := MeshInstance3D.new()
		var disc_cyl := CylinderMesh.new()
		disc_cyl.top_radius = 0.6
		disc_cyl.bottom_radius = 0.6
		disc_cyl.height = 0.05
		disc.mesh = disc_cyl
		disc.position = Vector3(disc_pos.x, 2.0, disc_pos.z)
		disc.rotation_degrees = Vector3(90, 0, 0)
		disc.set_meta("is_real", is_real)
		disc.set_meta("disc_index", i)
		disc.set_meta("message_shown", false)

		var disc_mat := StandardMaterial3D.new()
		disc_mat.albedo_color = Color(0.2, 0.2, 0.2)
		disc.material_override = disc_mat
		add_child(disc)
		spinning_discs.append(disc)

		# Digit on the disc
		var chiffre := MeshInstance3D.new()
		var chiffre_box := BoxMesh.new()
		chiffre_box.size = Vector3(0.3, 0.06, 0.3)
		chiffre.mesh = chiffre_box
		chiffre.position = Vector3(0, 0.03, 0)
		chiffre.material_override = MaterialFactory.create_emissive_material(
			Color(1.0, 0.2, 0.2), Color(1.0, 0.0, 0.0), 2.0)
		disc.add_child(chiffre)
		disc_chiffre_meshes.append(chiffre)

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

		print("Disc ", i, " (real=", is_real, "): ", disc_pos)


## Call each frame to rotate all discs and check if the player can read the digit.
func update_spinning_disc(delta: float, player_pos: Vector3) -> void:
	for i: int in range(spinning_discs.size()):
		var disc: MeshInstance3D = spinning_discs[i]
		if not disc or not is_instance_valid(disc):
			continue

		# Rotate: slow if real strobe is active, fast otherwise
		if strobe_active and has_strobe and picked_strobe_is_real:
			disc.rotation_degrees.z += 5.0 * delta
		else:
			disc.rotation_degrees.z += disc_rotation_speed * delta

		# Check if player can read this disc (real strobe active + close enough)
		if strobe_active and has_strobe and picked_strobe_is_real:
			var disc_pos: Vector3 = spinning_disc_positions[i]
			var dist: float = player_pos.distance_to(disc_pos)
			if dist < 4.0:
				var is_real: bool = disc.get_meta("is_real", false)
				if is_real and found_digits[2] == -1:
					found_digits[2] = exit_code[2]
					_show_message("Chiffre 3 trouvé : " + str(exit_code[2]))
					_update_quest()
				elif not is_real and not disc.get_meta("message_shown", false):
					disc.set_meta("message_shown", true)
					var msg_idx: int = disc.get_meta("disc_index", 0) % fake_disc_messages.size()
					_show_message(fake_disc_messages[msg_idx])
		else:
			# Reset message shown when strobe is off
			for d: MeshInstance3D in spinning_discs:
				if is_instance_valid(d):
					d.set_meta("message_shown", false)


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
	# UV parts
	for part: Node3D in uv_parts:
		if not is_instance_valid(part) or not part.visible:
			continue
		if player_pos.distance_to(part.global_position) < GameConfig.INTERACT_DISTANCE:
			return "[E] Ramasser " + part.get_meta("part_name", "Piece")

	# PCs (any of the 3)
	if not pc_done:
		for pc: Node3D in pc_nodes:
			if player_pos.distance_to(pc.global_position) < GameConfig.INTERACT_DISTANCE:
				return "[E] Utiliser le PC"

	# Stroboscopes (pick up or swap)
	for strobe: Node3D in strobe_nodes:
		if is_instance_valid(strobe) and strobe.visible:
			if player_pos.distance_to(strobe.global_position) < GameConfig.INTERACT_DISTANCE:
				if has_strobe:
					return "[E] Echanger Stroboscope"
				else:
					return "[E] Ramasser Stroboscope"

	# Spinning discs (proximity hint, no E needed)
	if found_digits[2] == -1:
		for i: int in range(spinning_discs.size()):
			var disc_pos: Vector3 = spinning_disc_positions[i]
			if player_pos.distance_to(disc_pos) < 4.0:
				if strobe_active and has_strobe and picked_strobe_is_real:
					return "Le disque ralentit... approchez..."
				elif strobe_active and has_strobe and not picked_strobe_is_real:
					return "Le stroboscope ne fonctionne pas sur ce disque..."
				elif has_strobe:
					return "Activez le stroboscope [H] pres du disque"
				else:
					return "Il faut un stroboscope pour lire ce disque"

	# Exit door
	var exit_dist: float = player_pos.distance_to(exit_door_pos)
	if exit_dist < GameConfig.INTERACT_DISTANCE:
		if not exit_door_found:
			return "[E] Examiner la porte"
		elif not game_won:
			var digits_found: int = get_digits_found_count()
			if digits_found >= 3:
				return "[E] Entrer le code !"
			else:
				return "[E] Essayer le code (" + str(digits_found) + "/4 indices)"
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

	# PCs (find nearest)
	if not pc_done:
		for pc: Node3D in pc_nodes:
			if player_pos.distance_to(pc.global_position) < GameConfig.INTERACT_DISTANCE:
				var is_real: bool = pc.get_meta("is_real", false)
				open_quiz(is_real)
				return

	# Stroboscopes (pick up or swap)
	for strobe: Node3D in strobe_nodes:
		if not is_instance_valid(strobe) or not strobe.visible:
			continue
		if player_pos.distance_to(strobe.global_position) < GameConfig.INTERACT_DISTANCE:
			# If already carrying a strobe, drop the current one back
			if has_strobe and carried_strobe_node and is_instance_valid(carried_strobe_node):
				carried_strobe_node.visible = true
			# Pick up the new strobe
			has_strobe = true
			strobe_active = false
			picked_strobe_is_real = strobe.get_meta("is_real", false)
			carried_strobe_node = strobe
			strobe.visible = false
			if picked_strobe_is_real:
				_show_message("Stroboscope recupere ! [H] pour activer")
			else:
				var idx: int = strobe.get_meta("strobe_index", 0)
				var msg_idx: int = idx % fake_strobe_messages.size()
				_show_message(fake_strobe_messages[msg_idx])
			return

	# Exit door
	if _check_exit_interaction(player_pos):
		return

	# Normal doors (fallback)
	door_callback.call()


func _check_exit_interaction(player_pos: Vector3) -> bool:
	var dist: float = player_pos.distance_to(exit_door_pos)
	if dist < GameConfig.INTERACT_DISTANCE:
		if not exit_door_found:
			exit_door_found = true
			current_quest = "find_clues"
			_show_message("La porte est verrouillee... Il faut un code a 4 chiffres ! Additionnez les signes...")
			_update_quest()
			return true

		if not game_won and not code_panel_open:
			code_panel_open = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			game_ui.open_code_panel(found_digits)
			if not game_ui.code_confirm_btn.pressed.is_connected(_on_code_confirmed):
				game_ui.code_confirm_btn.pressed.connect(_on_code_confirmed)
			if not game_ui.code_cancel_btn.pressed.is_connected(_on_code_cancelled):
				game_ui.code_cancel_btn.pressed.connect(_on_code_cancelled)
		return true
	return false


func _on_code_confirmed() -> void:
	var entered: Array = game_ui.get_entered_code()
	# Check all 4 slots are filled
	for d: int in entered:
		if d == -1:
			_show_message("Completez les 4 chiffres !")
			return

	game_ui.close_code_panel()
	code_panel_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var correct := true
	for i: int in range(4):
		if entered[i] != exit_code[i]:
			correct = false
			break

	if correct:
		game_won = true
		_trigger_win()
	else:
		_show_message("Ce n'est pas le bon code... Quelque chose gronde dans les murs.")
		_reset_puzzles()


func _on_code_cancelled() -> void:
	game_ui.close_code_panel()
	code_panel_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _reset_puzzles() -> void:
	found_digits = [-1, -1, -1, -1]
	pc_done = false
	current_quest = "find_clues"

	# Generate new random code + lure messages
	_generate_exit_code()

	# Re-randomize decoy indices so player can't just memorize
	uv_real_index = randi() % 4
	pc_real_index = randi() % 3
	strobe_real_index = randi() % 3
	disc_real_index = randi() % 4

	# Update tableau real/fake status
	for i: int in range(uv_chiffre_meshes.size()):
		var is_real: bool = (i == uv_real_index)
		var chiffre_mesh: MeshInstance3D = uv_chiffre_meshes[i]
		if chiffre_mesh and is_instance_valid(chiffre_mesh):
			chiffre_mesh.set_meta("is_real", is_real)
			chiffre_mesh.set_meta("fake_index", i if not is_real else -1)
			var mat: StandardMaterial3D = chiffre_mesh.material_override
			mat.emission = Color(0.3, 0.0, 1.0) if is_real else Color(0.8, 0.0, 0.0)
		var tableau: Node3D = uv_tableaux[i]
		if tableau and is_instance_valid(tableau):
			tableau.set_meta("is_real", is_real)

	# Update PC real/fake status
	for i: int in range(pc_nodes.size()):
		var is_real: bool = (i == pc_real_index)
		pc_nodes[i].set_meta("is_real", is_real)

	# Update disc real/fake status
	for i: int in range(spinning_discs.size()):
		var is_real: bool = (i == disc_real_index)
		spinning_discs[i].set_meta("is_real", is_real)

	# Strobe: drop and reset all
	has_strobe = false
	picked_strobe_is_real = false
	strobe_active = false
	carried_strobe_node = null
	for i: int in range(strobe_nodes.size()):
		var strobe: Node3D = strobe_nodes[i]
		if is_instance_valid(strobe):
			strobe.visible = true
			var is_real: bool = (i == strobe_real_index)
			strobe.set_meta("is_real", is_real)

	print("RESET! New decoy indices - UV:", uv_real_index, " PC:", pc_real_index, " Strobe:", strobe_real_index, " Disc:", disc_real_index)


# ---------------------------------------------------------------------------
# Toggle modes
# ---------------------------------------------------------------------------

func toggle_uv() -> void:
	if has_uv_lamp:
		uv_mode = not uv_mode
		strobe_active = false
		_show_message("Lampe UV activée" if uv_mode else "Lampe normale")


func toggle_strobe() -> void:
	if has_strobe:
		strobe_active = not strobe_active
		uv_mode = false
		if picked_strobe_is_real:
			_show_message("Stroboscope activé !" if strobe_active else "Stroboscope désactivé")
		else:
			_show_message("Le stroboscope grésille faiblement..." if strobe_active else "Stroboscope désactivé")


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
