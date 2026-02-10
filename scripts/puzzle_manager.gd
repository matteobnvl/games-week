class_name PuzzleManager
extends Node3D
## Manages all puzzle systems with decoy objects: UV lamp parts, quiz PCs, stroboscope discs, exit door, and win condition.

# --- Custom fonts (loaded at runtime to avoid import issues) ---
var font_scary: FontFile
var font_code: FontFile

func _init() -> void:
	font_scary = FontFile.new()
	font_scary.data = FileAccess.get_file_as_bytes("res://fonts/help-me/HelpMe.ttf")
	font_code = FontFile.new()
	font_code.data = FileAccess.get_file_as_bytes("res://fonts/shlop/shlop rg.otf")

# --- Shared puzzle state ---
var found_digits: Array = [-1, -1, -1, -1]
var current_quest: String = "find_exit"

# --- Decoy indices (randomized in setup) ---
var pc_real_index: int = 0
var strobe_real_index: int = 0
var disc_real_index: int = 0

# --- UV Puzzle ---
var uv_parts_collected: int = 0
var uv_parts: Array = []
var has_uv_lamp := false
var uv_mode := false
var uv_chiffre_mesh: MeshInstance3D = null  # The UV-hidden digit on the chosen whiteboard
var uv_scary_texts: Array = []               # Array of {mesh: MeshInstance3D, parent: Node3D} for all UV-hidden scary writings

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

# --- Whiteboards (map-placed) ---
var whiteboard_nodes: Array = []     # Array of Node3D (all whiteboards from map)
var whiteboard_code_index: int = -1  # Index of the one showing the exit code
var whiteboard_code_read := false    # True once player has read the code board

# --- PC Access ---
const PC_ACCESS_CODE: Array = [1, 1, 1, 1]
var pc_code_panel_open: bool = false

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
var boards: Array = []
var wall_rects: Array = []
var pc_map_positions: Array = []  # Positions from map (navy blue pixels)

# --- Horror messages for decoys ---
var fake_pc_messages: Array = []
var fake_strobe_messages: Array = []
var fake_disc_messages: Array = []

# --- Room position offsets ---
const UV_PART_START := 1       # positions 1-4
const PC_START := 9            # positions 9-11
const STROBE_START := 12       # positions 12-14
const DISC_START := 15         # positions 15-18


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(positions: Array, spawn_pos: Vector3, ui: GameUI, boards: Array, wall_rects: Array, pc_rects: Array) -> void:
	room_positions = positions
	spawn_position = spawn_pos
	game_ui = ui
	self.boards = boards
	self.wall_rects = wall_rects

	# Convert PC rects (col, row, w, h) to world positions
	var s: float = GameConfig.SCALE
	for rect: Array in pc_rects:
		var cx: float = (rect[0] + rect[2] / 2.0) * s
		var cz: float = (rect[1] + rect[3] / 2.0) * s
		pc_map_positions.append(Vector3(cx, 0.0, cz))

	# Generate random exit code + lure messages
	_generate_exit_code()

	# Randomize decoy indices
	pc_real_index = randi() % 3
	strobe_real_index = randi() % 3
	disc_real_index = randi() % 4
	
	_place_exit_door()
	
	# disable strobes
	#_place_strobes_and_discs()

	# DEBUG: start with UV lamp ready
	has_uv_lamp = true
	uv_parts_collected = GameConfig.UV_PARTS_NEEDED

	print("Exit code: ", exit_code)
	print("Decoy indices - PC:", pc_real_index, " Strobe:", strobe_real_index, " Disc:", disc_real_index)


## Setup whiteboards from map-placed nodes. One random board has a UV-hidden digit (exit_code[0]).
func setup_whiteboards(boards: Array) -> void:
	whiteboard_nodes = boards
	if boards.is_empty():
		return

	# Choose one random whiteboard to hold the UV digit
	whiteboard_code_index = randi() % boards.size()

	for i: int in range(boards.size()):
		var wb: Node3D = boards[i]
		var is_code_board: bool = (i == whiteboard_code_index)
		wb.set_meta("is_code_board", is_code_board)
		wb.set_meta("wb_index", i)

		if is_code_board:
			# Add UV-hidden code text on this whiteboard (invisible until UV lamp)
			var wb_center_y: float = wb.get_meta("wb_y", GameConfig.WALL_HEIGHT / 2.0)
			var code_text: String = str(exit_code[0]) + " " + str(exit_code[1]) + " " + str(exit_code[2]) + " " + str(exit_code[3])
			var chiffre_mesh := MeshInstance3D.new()
			var tm := TextMesh.new()
			tm.text = code_text
			tm.font_size = 120
			tm.depth = 0.002
			if font_code:
				tm.font = font_code
			chiffre_mesh.mesh = tm
			chiffre_mesh.position = Vector3(0, wb_center_y, GameConfig.WHITEBOARD_THICKNESS / 2.0 + 0.005)
			var chiffre_mat := StandardMaterial3D.new()
			chiffre_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.0)  # fully transparent
			chiffre_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			chiffre_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			chiffre_mat.no_depth_test = true
			chiffre_mesh.material_override = chiffre_mat
			wb.add_child(chiffre_mesh)
			uv_chiffre_mesh = chiffre_mesh
		else:
			# Add a random scary UV message on other whiteboards
			var scary_msgs: Array = [
				"IL VOUS REGARDE",
				"SORTEZ",
				"NE REVENEZ PAS",
				"ELLE EST LA",
				"COUREZ",
				"JE SUIS DANS LES MURS",
				"AIDEZ MOI",
				"IL N'Y A PAS D'ISSUE",
				"DERRIERE TOI",
				"NE TE RETOURNE PAS",
				"LES MURS RESPIRENT",
				"ON NE PART JAMAIS",
			]
			var msg: String = scary_msgs[randi() % scary_msgs.size()]
			var wb_y: float = wb.get_meta("wb_y", GameConfig.WALL_HEIGHT / 2.0)
			var scary_node := _create_uv_text(msg, randi_range(50, 80))
			scary_node.position = Vector3(0, wb_y, GameConfig.WHITEBOARD_THICKNESS / 2.0 + 0.005)
			wb.add_child(scary_node)
			uv_scary_texts.append({"node": scary_node, "parent": wb})

			# DEBUG: tall light beam visible through walls
			var beam := MeshInstance3D.new()
			var beam_cyl := CylinderMesh.new()
			beam_cyl.top_radius = 0.05
			beam_cyl.bottom_radius = 0.05
			beam_cyl.height = 50.0
			beam.mesh = beam_cyl
			beam.position = Vector3(0, 25.0, 0)
			var beam_mat := StandardMaterial3D.new()
			beam_mat.albedo_color = Color(0.0, 1.0, 0.0, 0.6)
			beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			beam_mat.emission_enabled = true
			beam_mat.emission = Color(0.0, 1.0, 0.0)
			beam_mat.emission_energy_multiplier = 5.0
			beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			beam_mat.no_depth_test = true
			beam.material_override = beam_mat
			wb.add_child(beam)

			print("UV WHITEBOARD (digit hidden) at: ", wb.global_position)

	print("Whiteboards: ", boards.size(), " | UV board index: ", whiteboard_code_index)


## Create a UV-hidden TextMesh that looks like blood handwriting.
func _create_uv_text(text: String, font_size: int = 60, add_drips: bool = true) -> Node3D:
	var container := Node3D.new()

	# Main text
	var mesh := MeshInstance3D.new()
	var tm := TextMesh.new()
	tm.text = text
	tm.font_size = font_size
	tm.depth = 0.003
	if font_scary:
		tm.font = font_scary
	mesh.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mesh.material_override = mat
	mesh.set_meta("uv_scary_mat", true)

	# Hand-scrawled distortion: uneven scale and heavy tilt
	var sx: float = randf_range(0.85, 1.15)
	var sy: float = randf_range(0.9, 1.2)
	mesh.scale = Vector3(sx, sy, 1.0)
	mesh.rotation.z = randf_range(-0.15, 0.15)
	container.add_child(mesh)

	# Blood drip lines under the text
	if add_drips:
		var num_drips: int = randi_range(2, 5)
		var text_width_approx: float = text.length() * font_size * 0.006
		for d: int in range(num_drips):
			var drip := MeshInstance3D.new()
			var drip_box := BoxMesh.new()
			var drip_w: float = randf_range(0.02, 0.06)
			var drip_h: float = randf_range(0.1, 0.5)
			drip_box.size = Vector3(drip_w, drip_h, 0.003)
			drip.mesh = drip_box
			var drip_x: float = randf_range(-text_width_approx / 2.0, text_width_approx / 2.0)
			drip.position = Vector3(drip_x, -drip_h / 2.0 - 0.05, 0)
			var drip_mat := StandardMaterial3D.new()
			drip_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
			drip_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			drip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			drip_mat.no_depth_test = true
			drip.material_override = drip_mat
			drip.set_meta("uv_scary_mat", true)
			container.add_child(drip)

	return container


## Recursively set albedo_color on all MeshInstance3D children with uv_scary_mat meta.
func _set_uv_color_recursive(node: Node, color: Color) -> void:
	if node is MeshInstance3D and node.has_meta("uv_scary_mat"):
		var mat: StandardMaterial3D = node.material_override
		if mat:
			mat.albedo_color = color
	for child: Node in node.get_children():
		_set_uv_color_recursive(child, color)


## Place scary UV-hidden messages on random walls throughout the map.
func setup_uv_wall_texts(wall_rects: Array) -> void:
	var scary_wall_msgs: Array = [
		"TU N'ES PAS SEUL",
		"ILS SONT PARTOUT",
		"FUIS TANT QUE TU PEUX",
		"PERSONNE NE SORT",
		"ELLE TE SUIT",
		"LES OMBRES BOUGENT",
		"NE FAIS PAS DE BRUIT",
		"PROMO 2019... DISPARUS",
		"LE SANG SECHE VITE ICI",
		"REGARDE DERRIERE TOI",
		"JE T'ATTENDS",
		"ON MEURT TOUS ICI",
		"LE DERNIER A CRI\u00c9",
		"POURQUOI ES-TU VENU",
		"JE SUIS SOUS LE SOL",
		"AIDE",
	]

	# Pick ~10-15 random walls to put text on
	var num_texts: int = mini(15, wall_rects.size())
	var indices: Array = range(wall_rects.size())
	indices.shuffle()
	var s := GameConfig.SCALE

	for t: int in range(num_texts):
		var rect: Array = wall_rects[indices[t]]
		var col: int = rect[0]; var row: int = rect[1]
		var w: int = rect[2]; var h: int = rect[3]

		# Center of the wall rectangle
		var cx: float = (col + w / 2.0) * s
		var cz: float = (row + h / 2.0) * s

		var msg: String = scary_wall_msgs[randi() % scary_wall_msgs.size()]
		var text_node := _create_uv_text(msg, randi_range(40, 90))

		# Create an anchor node for the text
		var anchor := Node3D.new()
		anchor.position = Vector3(cx, 0, cz)

		# Place text at varying heights on the wall
		var text_y: float = randf_range(0.8, GameConfig.WALL_HEIGHT - 0.3)
		# Small offset from wall face so it doesn't z-fight
		var offset_z: float = 0.08

		# Orient based on wall shape
		if w > h:
			text_node.position = Vector3(0, text_y, offset_z)
			if randi() % 2 == 0:
				anchor.rotation.y = PI
		else:
			text_node.position = Vector3(0, text_y, offset_z)
			anchor.rotation.y = PI / 2.0
			if randi() % 2 == 0:
				anchor.rotation.y = -PI / 2.0

		anchor.add_child(text_node)
		add_child(anchor)
		uv_scary_texts.append({"node": text_node, "parent": anchor})

	print("UV scary wall texts placed: ", num_texts)


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
	# Force Y à 0 pour éviter le décalage d'étage
	var base_x: float = exit_door_pos.x
	var base_z: float = exit_door_pos.z

	# Door mesh
	var door_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, wh * 0.9, 0.15)
	door_mesh.mesh = box
	door_mesh.position = Vector3(base_x, wh * 0.45, base_z)
	door_mesh.material_override = MaterialFactory.create_emissive_material(
		Color(0.5, 0.1, 0.1), Color(0.3, 0.0, 0.0), 0.5)
	add_child(door_mesh)

	# Exit sign
	var exit_sign := MeshInstance3D.new()
	var sign_box := BoxMesh.new()
	sign_box.size = Vector3(1.2, 0.3, 0.05)
	exit_sign.mesh = sign_box
	exit_sign.position = Vector3(base_x, wh * 0.9 + 0.3, base_z)
	exit_sign.material_override = MaterialFactory.create_emissive_material(
		Color(0.0, 0.8, 0.0), Color(0.0, 1.0, 0.0), 2.0)
	add_child(exit_sign)

	# Green light
	var exit_light := OmniLight3D.new()
	exit_light.light_color = Color(0.0, 1.0, 0.2)
	exit_light.light_energy = 2.0
	exit_light.omni_range = 8.0
	exit_light.position = Vector3(base_x, wh * 0.9, base_z)
	add_child(exit_light)

	print("Exit door: ", exit_door_pos)

# ---------------------------------------------------------------------------
# UV Parts (collect 4 parts to build UV lamp)
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


## Call each frame to reveal / hide the UV digit on the chosen whiteboard + scary texts.
func update_uv_tableau(player_pos: Vector3) -> void:
	# --- Code whiteboard ---
	if uv_chiffre_mesh and is_instance_valid(uv_chiffre_mesh):
		if whiteboard_code_index >= 0 and whiteboard_code_index < whiteboard_nodes.size():
			var wb: Node3D = whiteboard_nodes[whiteboard_code_index]
			var wb_pos: Vector3 = wb.global_position
			var dist_xz: float = Vector2(player_pos.x - wb_pos.x, player_pos.z - wb_pos.z).length()
			var mat: StandardMaterial3D = uv_chiffre_mesh.material_override

			if uv_mode and has_uv_lamp and dist_xz < 6.0:
				var reveal: float = clampf(1.0 - (dist_xz - 2.0) / 4.0, 0.0, 1.0)
				mat.albedo_color = Color(0.1, 0.05, 0.4, reveal * 0.95)
				if reveal > 0.5 and found_digits[0] == -1:
					found_digits[0] = exit_code[0]
					_show_message("Code trouvé sur le tableau : " + str(exit_code[0]) + " " + str(exit_code[1]) + " " + str(exit_code[2]) + " " + str(exit_code[3]))
					_update_quest()
			else:
				mat.albedo_color = Color(0.0, 0.0, 0.0, 0.0)

	# --- Scary UV texts (whiteboards + walls) ---
	for entry: Dictionary in uv_scary_texts:
		var scary_node: Node3D = entry["node"]
		var parent: Node3D = entry["parent"]
		if not scary_node or not is_instance_valid(scary_node):
			continue
		if not parent or not is_instance_valid(parent):
			continue
		var p_pos: Vector3 = parent.global_position
		var d_xz: float = Vector2(player_pos.x - p_pos.x, player_pos.z - p_pos.z).length()

		if uv_mode and has_uv_lamp and d_xz < 5.0:
			var r: float = clampf(1.0 - (d_xz - 1.5) / 3.5, 0.0, 1.0)
			# Blood red - vary slightly per text for organic feel
			var red_val: float = randf_range(0.5, 0.8)
			var blood_color := Color(red_val, 0.02, 0.02, r * 0.92)
			_set_uv_color_recursive(scary_node, blood_color)
		else:
			_set_uv_color_recursive(scary_node, Color(0.0, 0.0, 0.0, 0.0))


# ---------------------------------------------------------------------------
# PC Quiz (3 PCs: 1 real + 2 decoys)
# ---------------------------------------------------------------------------

func _place_pcs() -> void:
	var count: int = pc_map_positions.size()
	if count == 0:
		print("WARNING: No PC positions found on map!")
		return
	pc_real_index = randi() % count
	for i: int in range(count):
		var pos: Vector3 = pc_map_positions[i]
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
# PC Code Entry
# ---------------------------------------------------------------------------

func _open_pc_code_panel() -> void:
	if pc_code_panel_open:
		return
	pc_code_panel_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_ui.open_pc_code_panel()
	if not game_ui.pc_code_confirm_btn.pressed.is_connected(_on_pc_code_confirmed):
		game_ui.pc_code_confirm_btn.pressed.connect(_on_pc_code_confirmed)
	if not game_ui.pc_code_cancel_btn.pressed.is_connected(_on_pc_code_cancelled):
		game_ui.pc_code_cancel_btn.pressed.connect(_on_pc_code_cancelled)


func _on_pc_code_confirmed() -> void:
	var entered: Array = game_ui.get_entered_pc_code()
	for d: int in entered:
		if d == -1:
			_show_message("Completez les 4 chiffres !")
			return

	var correct := true
	for i: int in range(4):
		if entered[i] != PC_ACCESS_CODE[i]:
			correct = false
			break

	game_ui.close_pc_code_panel()
	pc_code_panel_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if correct:
		open_quiz(true)
	else:
		_show_message("Mauvais code !")


func _on_pc_code_cancelled() -> void:
	game_ui.close_pc_code_panel()
	pc_code_panel_open = false
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

	# Whiteboards
	for wb: Node3D in whiteboard_nodes:
		if player_pos.distance_to(wb.global_position) < GameConfig.WHITEBOARD_INTERACT_DISTANCE:
			var is_code: bool = wb.get_meta("is_code_board", false)
			if is_code:
				return "[E] Lire le tableau (code)"
			else:
				return "Un tableau blanc... rien d'utile."

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
				if not is_real:
					_show_message("PC hors tension... Essayez un autre.")
				else:
					_open_pc_code_panel()
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

	# Whiteboards
	for wb: Node3D in whiteboard_nodes:
		if player_pos.distance_to(wb.global_position) < GameConfig.WHITEBOARD_INTERACT_DISTANCE:
			var is_code: bool = wb.get_meta("is_code_board", false)
			if is_code and not whiteboard_code_read:
				whiteboard_code_read = true
				_show_message("Le code est : " + str(exit_code[0]) + str(exit_code[1]) + str(exit_code[2]) + str(exit_code[3]) + " !")
			elif is_code:
				_show_message("Code : " + str(exit_code[0]) + str(exit_code[1]) + str(exit_code[2]) + str(exit_code[3]))
			else:
				_show_message("Rien d'interessant sur ce tableau...")
			return

	# Whiteboards
	for wb: Node3D in whiteboard_nodes:
		if player_pos.distance_to(wb.global_position) < GameConfig.WHITEBOARD_INTERACT_DISTANCE:
			var is_code: bool = wb.get_meta("is_code_board", false)
			if is_code and not whiteboard_code_read:
				whiteboard_code_read = true
				_show_message("Le code est : " + str(exit_code[0]) + str(exit_code[1]) + str(exit_code[2]) + str(exit_code[3]) + " !")
			elif is_code:
				_show_message("Code : " + str(exit_code[0]) + str(exit_code[1]) + str(exit_code[2]) + str(exit_code[3]))
			else:
				_show_message("Rien d'interessant sur ce tableau...")
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
			_setup_all_elements()
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
	pc_real_index = randi() % 3
	strobe_real_index = randi() % 3
	disc_real_index = randi() % 4

	# Reset UV whiteboard digit visibility
	if uv_chiffre_mesh and is_instance_valid(uv_chiffre_mesh):
		var mat: StandardMaterial3D = uv_chiffre_mesh.material_override
		mat.albedo_color = Color(0.9, 0.9, 0.9, 0.0)
		mat.emission_energy_multiplier = 0.0

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

	print("RESET! New decoy indices - PC:", pc_real_index, " Strobe:", strobe_real_index, " Disc:", disc_real_index)


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
	
	
func _setup_all_elements() -> void:
	_place_uv_parts()
	_place_pcs()
	setup_whiteboards(boards)
	setup_uv_wall_texts(wall_rects)
	
