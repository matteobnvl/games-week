extends Node3D

# --- Configuration ---
const SCALE := 0.12
const WALL_HEIGHT := 5.0
const THRESHOLD := 128
const MAP_PATH := "res://map_100.png"
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

# --- Puzzle ---
const UV_PARTS_NEEDED := 4
const INTERACT_DISTANCE := 2.5
const EXIT_CODE := [7, 3, 5, 0]  # Code de sortie (4eme chiffre = placeholder)

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

# --- Puzzle state ---
var quest_label: Label
var code_label: Label
var current_quest: String = "find_exit"
var found_digits: Array = [-1, -1, -1, -1]  # -1 = pas trouvé

# Chiffre 1 : UV
var uv_parts_collected: int = 0
var uv_parts: Array = []  # Les objets pièces UV dans le monde
var has_uv_lamp := false
var uv_mode := false
var uv_parts_label: Label
var uv_tableau: Node3D = null
var uv_chiffre_mesh: MeshInstance3D = null

# Chiffre 2 : Quiz PC
var pc_node: Node3D = null
var pc_screen_light: SpotLight3D = null
var quiz_active := false
var quiz_panel: PanelContainer = null
var quiz_question_label: Label = null
var quiz_answers_container: VBoxContainer = null
var quiz_current_question: int = 0
var quiz_correct_count: int = 0
var pc_done := false

var quiz_questions: Array = [
	{
		"question": "Quelle est la vitesse de la lumière dans le vide ?",
		"answers": ["300 000 km/s", "150 000 km/s", "1 000 000 km/s", "30 000 km/s"],
		"correct": 0
	},
	{
		"question": "Quelle couleur a la plus grande longueur d'onde ?",
		"answers": ["Bleu", "Vert", "Rouge", "Violet"],
		"correct": 2
	},
	{
		"question": "Que signifie UV dans 'lumière UV' ?",
		"answers": ["Ultra-Visible", "Ultra-Violet", "Uni-Variable", "Ultra-Vitesse"],
		"correct": 1
	},
	{
		"question": "Quel phénomène décompose la lumière blanche en arc-en-ciel ?",
		"answers": ["La réflexion", "La diffraction", "La réfraction", "L'absorption"],
		"correct": 2
	}
]

# Chiffre 3 : Stroboscope
var has_strobe := false
var strobe_node: Node3D = null
var strobe_active := false
var spinning_disc: MeshInstance3D = null
var spinning_disc_pos := Vector3.ZERO
var disc_chiffre_mesh: MeshInstance3D = null
var disc_rotation_speed: float = 720.0  # degrés par seconde

# Porte de sortie
var exit_door_pos := Vector3.ZERO
var exit_door_found := false
var game_won := false
var win_overlay: ColorRect = null

# Positions de spawn des objets (calculées aléatoirement)
var room_positions: Array = []


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
	var terrace_grid: Array[Array] = []
	
	for row: int in range(grid_rows):
		var line: Array[int] = []
		var red_line: Array[bool] = []
		var terrace_line: Array[bool] = []
		for col: int in range(grid_cols):
			var pixel: Color = image.get_pixel(col, row)
			if pixel.r > 0.8 and pixel.g < 0.3 and pixel.b < 0.3:
				line.append(2)
				red_line.append(true)
				terrace_line.append(false)
			elif pixel.b > 0.8 and pixel.r < 0.3 and pixel.g < 0.3:
				line.append(3)
				red_line.append(false)
				terrace_line.append(false)
			elif pixel.g > 0.8 and pixel.r < 0.3 and pixel.b < 0.3:
				line.append(4)
				red_line.append(false)
				terrace_line.append(true)
			elif pixel.r > 0.8 and pixel.g < 0.3 and pixel.b > 0.8:
				line.append(5)
				red_line.append(false)
				terrace_line.append(false)
			elif pixel.r < 0.3 and pixel.g > 0.8 and pixel.b > 0.8:
				line.append(6)
				red_line.append(false)
				terrace_line.append(false)
			elif pixel.r < (THRESHOLD / 255.0):
				line.append(1)
				red_line.append(false)
				terrace_line.append(false)
			else:
				line.append(0)
				red_line.append(false)
				terrace_line.append(false)
		grid_data.append(line)
		red_grid.append(red_line)
		terrace_grid.append(terrace_line)
	
	var door_blocks: Array = _find_door_blocks(red_grid, grid_rows, grid_cols)
	var rectangles: Array = _merge_type(grid_data, grid_rows, grid_cols, 1)
	var window_rects: Array = _merge_type(grid_data, grid_rows, grid_cols, 3)
	var terrace_rects: Array = _merge_type(grid_data, grid_rows, grid_cols, 4)
	var fence_rects: Array = _merge_type(grid_data, grid_rows, grid_cols, 5)
	var coffee_machines: Array = _merge_type(grid_data, grid_rows, grid_cols, 6)
	var spawn_grid: Vector2 = _find_spawn(grid_data, grid_rows, grid_cols)
	spawn_position = Vector3(spawn_grid.x * SCALE, 2.0, spawn_grid.y * SCALE)
	
	# Trouver des positions de salles pour placer les objets
	_find_room_positions()
	
	_build_floor(grid_rows, grid_cols)
	_build_terrace_floors(terrace_rects)
	_build_ceiling(grid_rows, grid_cols, terrace_grid)
	_build_walls(rectangles, grid_rows)
	_build_windows(window_rects)
	_build_glass_fences(fence_rects)
	_build_coffee_machines(coffee_machines)
	_build_doors_from_blocks(door_blocks)
	_setup_environment()
	
	# Placer les éléments de puzzle
	_place_exit_door()
	_place_uv_parts()
	_place_uv_tableau()
	_place_pc()
	_place_strobe_and_disc()
	
	_create_ui()
	
	print("Pret ! Murs: ", rectangles.size(), " | Portes: ", doors.size(), " | Salles: ", room_positions.size())


# ============================================
# POSITIONS DE SALLES (pour spawns aléatoires)
# ============================================

func _find_room_positions() -> void:
	# Trouver des zones ouvertes (loin du spawn) pour y placer des objets
	var step: int = 40  # scanner tous les 40 pixels
	var spawn_gx: int = int(spawn_position.x / SCALE)
	var spawn_gz: int = int(spawn_position.z / SCALE)
	
	for gz: int in range(step, grid_rows - step, step):
		for gx: int in range(step, grid_cols - step, step):
			# Vérifier que c'est un espace ouvert (5x5 autour)
			var open := true
			for dz: int in range(-3, 4):
				for dx: int in range(-3, 4):
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
			
			# Au moins 60 pixels du spawn
			var dist: float = Vector2(gx, gz).distance_to(Vector2(spawn_gx, spawn_gz))
			if dist < 60:
				continue
			
			room_positions.append(Vector3(gx * SCALE, 0.5, gz * SCALE))
	
	# Mélanger
	room_positions.shuffle()


func _get_room_pos(index: int) -> Vector3:
	if index < room_positions.size():
		return room_positions[index]
	return spawn_position + Vector3(10, 0, 10)


# ============================================
# PORTE DE SORTIE
# ============================================

func _place_exit_door() -> void:
	# Placer la porte de sortie loin du spawn
	var best_pos := Vector3.ZERO
	var best_dist: float = 0
	for i: int in range(mini(room_positions.size(), 20)):
		var d: float = room_positions[i].distance_to(spawn_position)
		if d > best_dist:
			best_dist = d
			best_pos = room_positions[i]
	
	exit_door_pos = best_pos
	
	# Mesh porte spéciale (rouge foncé avec panneau EXIT)
	var door_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, WALL_HEIGHT * 0.9, 0.15)
	door_mesh.mesh = box
	door_mesh.position = Vector3(exit_door_pos.x, WALL_HEIGHT * 0.45, exit_door_pos.z)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.1, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.0, 0.0)
	mat.emission_energy_multiplier = 0.5
	door_mesh.material_override = mat
	add_child(door_mesh)
	
	# Panneau "SORTIE" au-dessus
	var exit_sign := MeshInstance3D.new()
	var sign_box := BoxMesh.new()
	sign_box.size = Vector3(1.2, 0.3, 0.05)
	exit_sign.mesh = sign_box
	exit_sign.position = Vector3(exit_door_pos.x, WALL_HEIGHT * 0.9 + 0.3, exit_door_pos.z)
	
	var sign_mat := StandardMaterial3D.new()
	sign_mat.albedo_color = Color(0.0, 0.8, 0.0)
	sign_mat.emission_enabled = true
	sign_mat.emission = Color(0.0, 1.0, 0.0)
	sign_mat.emission_energy_multiplier = 2.0
	exit_sign.material_override = sign_mat
	add_child(exit_sign)
	
	# Lumière verte au-dessus
	var exit_light := OmniLight3D.new()
	exit_light.light_color = Color(0.0, 1.0, 0.2)
	exit_light.light_energy = 2.0
	exit_light.omni_range = 8.0
	exit_light.position = Vector3(exit_door_pos.x, WALL_HEIGHT * 0.9, exit_door_pos.z)
	add_child(exit_light)
	
	print("Porte de sortie : ", exit_door_pos)


# ============================================
# CHIFFRE 1 : PIÈCES UV + LAMPE + TABLEAU
# ============================================

func _place_uv_parts() -> void:
	var part_names: Array = ["Ampoule UV", "Boitier", "Batterie", "Filtre"]
	
	for i: int in range(UV_PARTS_NEEDED):
		var pos: Vector3 = _get_room_pos(i + 1)  # +1 pour éviter la pos de la porte
		
		var part := Node3D.new()
		part.position = pos
		part.set_meta("part_name", part_names[i])
		part.set_meta("is_uv_part", true)
		
		# Sphère violette luminescente
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.2
		sphere.height = 0.4
		mesh.mesh = sphere
		mesh.position.y = 0.3
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.1, 0.9)
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.0, 1.0)
		mat.emission_energy_multiplier = 2.0
		mesh.material_override = mat
		
		# Lumière violette faible pour attirer l'attention
		var light := OmniLight3D.new()
		light.light_color = Color(0.5, 0.1, 1.0)
		light.light_energy = 1.5
		light.omni_range = 5.0
		light.position.y = 0.5
		
		part.add_child(mesh)
		part.add_child(light)
		add_child(part)
		uv_parts.append(part)
		
		print("UV piece [", part_names[i], "] : ", pos)


func _place_uv_tableau() -> void:
	var pos: Vector3 = _get_room_pos(UV_PARTS_NEEDED + 2)
	
	uv_tableau = Node3D.new()
	uv_tableau.position = pos
	
	# Tableau (rectangle blanc sur le mur)
	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 1.2, 0.05)
	board.mesh = box
	board.position = Vector3(0, 2.0, 0)
	
	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.9, 0.9, 0.9)
	board.material_override = board_mat
	
	uv_tableau.add_child(board)
	
	# Chiffre caché (invisible par défaut, visible en UV)
	uv_chiffre_mesh = MeshInstance3D.new()
	var chiffre_box := BoxMesh.new()
	chiffre_box.size = Vector3(0.8, 0.8, 0.06)
	uv_chiffre_mesh.mesh = chiffre_box
	uv_chiffre_mesh.position = Vector3(0, 2.0, 0.02)
	
	var chiffre_mat := StandardMaterial3D.new()
	chiffre_mat.albedo_color = Color(0.9, 0.9, 0.9, 0.0)  # Invisible
	chiffre_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	chiffre_mat.emission_enabled = true
	chiffre_mat.emission = Color(0.3, 0.0, 1.0)
	chiffre_mat.emission_energy_multiplier = 0.0  # Pas d'émission par défaut
	uv_chiffre_mesh.material_override = chiffre_mat
	
	uv_tableau.add_child(uv_chiffre_mesh)
	
	# Texte "TABLEAU" petit sous le tableau pour aider
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
	print("Tableau UV : ", pos)


func _update_uv_tableau() -> void:
	if not uv_chiffre_mesh or not player:
		return
	
	var dist: float = player.global_position.distance_to(uv_tableau.global_position)
	var mat: StandardMaterial3D = uv_chiffre_mesh.material_override
	
	if uv_mode and has_uv_lamp and dist < 6.0:
		# Révéler le chiffre en UV !
		var reveal: float = clampf(1.0 - (dist - 2.0) / 4.0, 0.0, 1.0)
		mat.albedo_color = Color(0.3, 0.0, 1.0, reveal * 0.9)
		mat.emission_energy_multiplier = reveal * 4.0
		
		if reveal > 0.5 and found_digits[0] == -1:
			found_digits[0] = EXIT_CODE[0]
			_show_message("Chiffre 1 trouve : " + str(EXIT_CODE[0]))
			_update_quest()
	else:
		mat.albedo_color = Color(0.9, 0.9, 0.9, 0.0)
		mat.emission_energy_multiplier = 0.0


# ============================================
# CHIFFRE 2 : PC QUIZ
# ============================================

func _place_pc() -> void:
	var pos: Vector3 = _get_room_pos(UV_PARTS_NEEDED + 3)
	
	pc_node = Node3D.new()
	pc_node.position = pos
	pc_node.set_meta("is_pc", true)
	
	# Bureau
	var desk := MeshInstance3D.new()
	var desk_box := BoxMesh.new()
	desk_box.size = Vector3(1.2, 0.8, 0.6)
	desk.mesh = desk_box
	desk.position.y = 0.4
	var desk_mat := StandardMaterial3D.new()
	desk_mat.albedo_color = Color(0.35, 0.25, 0.15)
	desk.material_override = desk_mat
	pc_node.add_child(desk)
	
	# Écran
	var screen := MeshInstance3D.new()
	var screen_box := BoxMesh.new()
	screen_box.size = Vector3(0.7, 0.5, 0.05)
	screen.mesh = screen_box
	screen.position = Vector3(0, 1.1, 0)
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.1, 0.2, 0.4)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.2, 0.4, 0.8)
	screen_mat.emission_energy_multiplier = 2.0
	screen.material_override = screen_mat
	pc_node.add_child(screen)
	
	# Lumière de l'écran
	pc_screen_light = SpotLight3D.new()
	pc_screen_light.light_color = Color(0.3, 0.5, 1.0)
	pc_screen_light.light_energy = 5.0
	pc_screen_light.spot_range = 8.0
	pc_screen_light.spot_angle = 60.0
	pc_screen_light.position = Vector3(0, 1.2, 0.5)
	pc_screen_light.rotation_degrees = Vector3(0, 0, 0)
	pc_node.add_child(pc_screen_light)
	
	add_child(pc_node)
	print("PC Quiz : ", pos)


func _open_quiz() -> void:
	if quiz_active or pc_done:
		return
	
	quiz_active = true
	quiz_current_question = 0
	quiz_correct_count = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	quiz_panel.visible = true
	_show_quiz_question()


func _show_quiz_question() -> void:
	if quiz_current_question >= quiz_questions.size():
		# Toutes les questions répondues
		if quiz_correct_count >= quiz_questions.size():
			quiz_question_label.text = "Correct ! Le chiffre est : " + str(EXIT_CODE[1])
			found_digits[1] = EXIT_CODE[1]
			pc_done = true
			_update_quest()
			# Fermer après 2 secondes
			get_tree().create_timer(2.0).timeout.connect(_close_quiz)
		else:
			quiz_question_label.text = "Trop d'erreurs... Reessayez."
			get_tree().create_timer(1.5).timeout.connect(_close_quiz)
		
		# Vider les boutons
		for child: Node in quiz_answers_container.get_children():
			child.queue_free()
		return
	
	var q: Dictionary = quiz_questions[quiz_current_question]
	quiz_question_label.text = "Q" + str(quiz_current_question + 1) + "/" + str(quiz_questions.size()) + " : " + q["question"]
	
	# Vider les anciens boutons
	for child: Node in quiz_answers_container.get_children():
		child.queue_free()
	
	# Créer les boutons de réponse
	for i: int in range(q["answers"].size()):
		var btn := Button.new()
		btn.text = q["answers"][i]
		btn.custom_minimum_size = Vector2(400, 40)
		var answer_index: int = i
		btn.pressed.connect(_on_quiz_answer.bind(answer_index))
		quiz_answers_container.add_child(btn)


func _on_quiz_answer(index: int) -> void:
	var q: Dictionary = quiz_questions[quiz_current_question]
	if index == q["correct"]:
		quiz_correct_count += 1
	
	quiz_current_question += 1
	_show_quiz_question()


func _close_quiz() -> void:
	quiz_active = false
	quiz_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ============================================
# CHIFFRE 3 : STROBOSCOPE + DISQUE
# ============================================

func _place_strobe_and_disc() -> void:
	# Stroboscope à ramasser
	var strobe_pos: Vector3 = _get_room_pos(UV_PARTS_NEEDED + 4)
	
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
	
	var strobe_mat := StandardMaterial3D.new()
	strobe_mat.albedo_color = Color(0.9, 0.9, 0.2)
	strobe_mat.emission_enabled = true
	strobe_mat.emission = Color(1.0, 1.0, 0.3)
	strobe_mat.emission_energy_multiplier = 1.5
	strobe_mesh.material_override = strobe_mat
	
	var strobe_light := OmniLight3D.new()
	strobe_light.light_color = Color(1.0, 1.0, 0.4)
	strobe_light.light_energy = 1.0
	strobe_light.omni_range = 4.0
	strobe_light.position.y = 0.5
	
	strobe_node.add_child(strobe_mesh)
	strobe_node.add_child(strobe_light)
	add_child(strobe_node)
	
	# Disque qui tourne avec le chiffre
	var disc_pos: Vector3 = _get_room_pos(UV_PARTS_NEEDED + 5)
	spinning_disc_pos = disc_pos
	
	spinning_disc = MeshInstance3D.new()
	var disc_cyl := CylinderMesh.new()
	disc_cyl.top_radius = 0.6
	disc_cyl.bottom_radius = 0.6
	disc_cyl.height = 0.05
	spinning_disc.mesh = disc_cyl
	spinning_disc.position = Vector3(disc_pos.x, 2.0, disc_pos.z)
	spinning_disc.rotation_degrees = Vector3(90, 0, 0)  # Face au joueur
	
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.2, 0.2, 0.2)
	spinning_disc.material_override = disc_mat
	add_child(spinning_disc)
	
	# Chiffre sur le disque (enfant du disque, tourne avec)
	disc_chiffre_mesh = MeshInstance3D.new()
	var chiffre_box := BoxMesh.new()
	chiffre_box.size = Vector3(0.3, 0.06, 0.3)
	disc_chiffre_mesh.mesh = chiffre_box
	disc_chiffre_mesh.position = Vector3(0, 0.03, 0)
	
	var chiffre_mat := StandardMaterial3D.new()
	chiffre_mat.albedo_color = Color(1.0, 0.2, 0.2)
	chiffre_mat.emission_enabled = true
	chiffre_mat.emission = Color(1.0, 0.0, 0.0)
	chiffre_mat.emission_energy_multiplier = 2.0
	disc_chiffre_mesh.material_override = chiffre_mat
	spinning_disc.add_child(disc_chiffre_mesh)
	
	# Support du disque
	var support := MeshInstance3D.new()
	var support_box := BoxMesh.new()
	support_box.size = Vector3(0.1, 2.0, 0.1)
	support.mesh = support_box
	support.position = Vector3(disc_pos.x, 1.0, disc_pos.z)
	var support_mat := StandardMaterial3D.new()
	support_mat.albedo_color = Color(0.3, 0.3, 0.3)
	support.material_override = support_mat
	add_child(support)
	
	print("Stroboscope : ", strobe_pos)
	print("Disque : ", disc_pos)


func _update_spinning_disc(delta: float) -> void:
	if not spinning_disc:
		return
	
	if strobe_active and has_strobe:
		# Strobo actif : le disque semble figé (rotation très lente, flicker)
		spinning_disc.rotation_degrees.z += 5.0 * delta
	else:
		# Rotation rapide normale
		spinning_disc.rotation_degrees.z += disc_rotation_speed * delta
	
	# Vérifier si le joueur peut lire le chiffre
	if strobe_active and has_strobe and player:
		var dist: float = player.global_position.distance_to(spinning_disc_pos)
		if dist < 4.0 and found_digits[2] == -1:
			found_digits[2] = EXIT_CODE[2]
			_show_message("Chiffre 3 trouve : " + str(EXIT_CODE[2]))
			_update_quest()


# ============================================
# SYSTÈME DE QUÊTES
# ============================================

func _update_quest() -> void:
	var digits_found: int = 0
	for d: int in found_digits:
		if d != -1:
			digits_found += 1
	
	if digits_found >= 3 and not game_won:
		current_quest = "enter_code"
	elif exit_door_found:
		current_quest = "find_clues"
	
	_update_quest_ui()


func _update_quest_ui() -> void:
	if not quest_label:
		return
	
	match current_quest:
		"find_exit":
			quest_label.text = ">> Trouver la sortie"
		"find_clues":
			quest_label.text = ">> Explorer et trouver le code"
		"enter_code":
			quest_label.text = ">> Retourner a la porte de sortie !"
	
	# Code display
	var code_text: String = "Code : "
	for i: int in range(4):
		if found_digits[i] != -1:
			code_text += str(found_digits[i]) + " "
		else:
			code_text += "_ "
	code_label.text = code_text


func _check_exit_interaction() -> void:
	if not player:
		return
	
	var dist: float = player.global_position.distance_to(exit_door_pos)
	
	if dist < INTERACT_DISTANCE:
		if not exit_door_found:
			exit_door_found = true
			current_quest = "find_clues"
			_show_message("La porte est verrouillee... Il faut un code a 4 chiffres !")
			_update_quest()
		
		# Vérifier si on a assez de chiffres
		var digits_found: int = 0
		for d: int in found_digits:
			if d != -1:
				digits_found += 1
		
		if digits_found >= 3 and not game_won:
			# Gagné ! (on considère 3/4 suffisant pour l'instant)
			game_won = true
			_trigger_win()


func _check_puzzle_interactions() -> void:
	if not player or quiz_active:
		return
	
	# Pièces UV
	for part: Node3D in uv_parts:
		if not is_instance_valid(part) or not part.visible:
			continue
		var dist: float = player.global_position.distance_to(part.global_position)
		if dist < INTERACT_DISTANCE:
			var pname: String = part.get_meta("part_name", "Piece")
			interact_label.text = "[E] Ramasser " + pname
			interact_label.visible = true
			return
	
	# PC
	if pc_node and not pc_done:
		var dist: float = player.global_position.distance_to(pc_node.global_position)
		if dist < INTERACT_DISTANCE:
			interact_label.text = "[E] Utiliser le PC"
			interact_label.visible = true
			return
	
	# Stroboscope
	if strobe_node and is_instance_valid(strobe_node) and strobe_node.visible and not has_strobe:
		var dist: float = player.global_position.distance_to(strobe_node.global_position)
		if dist < INTERACT_DISTANCE:
			interact_label.text = "[E] Ramasser Stroboscope"
			interact_label.visible = true
			return
	
	# Porte de sortie
	var exit_dist: float = player.global_position.distance_to(exit_door_pos)
	if exit_dist < INTERACT_DISTANCE:
		var digits_found: int = 0
		for d: int in found_digits:
			if d != -1:
				digits_found += 1
		if digits_found >= 3:
			interact_label.text = "[E] Entrer le code !"
			interact_label.visible = true
		elif exit_door_found:
			interact_label.text = "Porte verrouillee - Code : " + str(digits_found) + "/4"
			interact_label.visible = true
		else:
			interact_label.text = "[E] Examiner la porte"
			interact_label.visible = true
		return


func _handle_interact() -> void:
	if quiz_active:
		return
	if not player:
		return
	
	# Pièces UV
	for part: Node3D in uv_parts:
		if not is_instance_valid(part) or not part.visible:
			continue
		var dist: float = player.global_position.distance_to(part.global_position)
		if dist < INTERACT_DISTANCE:
			var pname: String = part.get_meta("part_name", "Piece")
			part.visible = false
			part.set_meta("collected", true)
			uv_parts_collected += 1
			_show_message(pname + " recupere ! (" + str(uv_parts_collected) + "/" + str(UV_PARTS_NEEDED) + ")")
			
			if uv_parts_collected >= UV_PARTS_NEEDED:
				has_uv_lamp = true
				_show_message("Lampe UV craftee ! [G] pour activer")
			return
	
	# PC
	if pc_node and not pc_done:
		var dist: float = player.global_position.distance_to(pc_node.global_position)
		if dist < INTERACT_DISTANCE:
			_open_quiz()
			return
	
	# Stroboscope
	if strobe_node and is_instance_valid(strobe_node) and strobe_node.visible and not has_strobe:
		var dist: float = player.global_position.distance_to(strobe_node.global_position)
		if dist < INTERACT_DISTANCE:
			has_strobe = true
			strobe_node.visible = false
			_show_message("Stroboscope recupere ! [H] pour activer")
			return
	
	# Porte de sortie
	_check_exit_interaction()
	
	# Portes normales
	var nearest: Door = _get_nearest_door()
	if nearest:
		_toggle_door(nearest)


# ============================================
# VICTOIRE
# ============================================

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
	
	# Animation fade in
	var tween := create_tween()
	tween.tween_property(win_overlay, "color:a", 0.85, 2.0)
	tween.parallel().tween_property(win_label, "modulate:a", 1.0, 2.0)
	tween.tween_interval(3.0)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file("res://menu.tscn"))


# ============================================
# MESSAGE TEMPORAIRE
# ============================================

var message_label: Label
var message_timer: float = 0.0

func _show_message(text: String) -> void:
	if message_label:
		message_label.text = text
		message_label.visible = true
		message_timer = 3.0


# ============================================
# UI
# ============================================

func _create_ui() -> void:
	var canvas := CanvasLayer.new()
	
	# Barres stamina / batterie
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
	
	# Interact label
	interact_label = Label.new()
	interact_label.text = "[E] Ouvrir"
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interact_label.position = Vector2(-60, -80)
	interact_label.add_theme_font_size_override("font_size", 20)
	interact_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.8))
	interact_label.visible = false
	canvas.add_child(interact_label)
	
	# Quête en haut
	quest_label = Label.new()
	quest_label.text = ">> Trouver la sortie"
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	quest_label.position = Vector2(20, 20)
	quest_label.add_theme_font_size_override("font_size", 22)
	quest_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.9))
	canvas.add_child(quest_label)
	
	# Code en haut droite
	code_label = Label.new()
	code_label.text = "Code : _ _ _ _"
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	code_label.anchor_left = 1.0
	code_label.anchor_right = 1.0
	code_label.position = Vector2(-220, 20)
	code_label.add_theme_font_size_override("font_size", 22)
	code_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.9))
	canvas.add_child(code_label)
	
	# Pièces UV compteur
	uv_parts_label = Label.new()
	uv_parts_label.text = ""
	uv_parts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	uv_parts_label.position = Vector2(20, 50)
	uv_parts_label.add_theme_font_size_override("font_size", 16)
	uv_parts_label.add_theme_color_override("font_color", Color(0.6, 0.4, 1.0, 0.8))
	canvas.add_child(uv_parts_label)
	
	# Message temporaire
	message_label = Label.new()
	message_label.text = ""
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.set_anchors_preset(Control.PRESET_CENTER)
	message_label.position = Vector2(-300, -200)
	message_label.add_theme_font_size_override("font_size", 26)
	message_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	message_label.visible = false
	canvas.add_child(message_label)
	
	# Quiz panel (caché par défaut)
	quiz_panel = PanelContainer.new()
	quiz_panel.set_anchors_preset(Control.PRESET_CENTER)
	quiz_panel.position = Vector2(-250, -180)
	quiz_panel.custom_minimum_size = Vector2(500, 350)
	quiz_panel.visible = false
	
	var quiz_vbox := VBoxContainer.new()
	quiz_vbox.add_theme_constant_override("separation", 15)
	
	quiz_question_label = Label.new()
	quiz_question_label.text = ""
	quiz_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	quiz_question_label.custom_minimum_size = Vector2(480, 60)
	quiz_question_label.add_theme_font_size_override("font_size", 20)
	quiz_question_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	quiz_vbox.add_child(quiz_question_label)
	
	quiz_answers_container = VBoxContainer.new()
	quiz_answers_container.add_theme_constant_override("separation", 8)
	quiz_vbox.add_child(quiz_answers_container)
	
	quiz_panel.add_child(quiz_vbox)
	canvas.add_child(quiz_panel)
	
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
	
	# UV parts counter
	if uv_parts_collected > 0 and not has_uv_lamp:
		uv_parts_label.text = "Pieces UV : " + str(uv_parts_collected) + "/" + str(UV_PARTS_NEEDED)
	elif has_uv_lamp:
		if uv_mode:
			uv_parts_label.text = "Lampe UV : ON [G]"
		else:
			uv_parts_label.text = "Lampe UV : OFF [G]"
	else:
		uv_parts_label.text = ""
	
	if has_strobe:
		if strobe_active:
			uv_parts_label.text += "  |  Strobo : ON [H]"
		else:
			uv_parts_label.text += "  |  Strobo : OFF [H]"
	
	# Message timer
	if message_timer > 0:
		message_timer -= get_process_delta_time()
		if message_timer <= 0:
			message_label.visible = false
	
	# Interact label - reset then check puzzles
	interact_label.visible = false
	_check_puzzle_interactions()
	
	# Si pas d'interaction puzzle, vérifier les portes
	if not interact_label.visible:
		var nearest: Door = _get_nearest_door()
		if nearest and not nearest.is_animating:
			if nearest.is_open:
				interact_label.text = "[E] Fermer"
			else:
				interact_label.text = "[E] Ouvrir"
			interact_label.visible = true
	
	_update_quest_ui()


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
	
	# Couleur selon le mode
	if uv_mode and has_uv_lamp:
		flashlight.light_color = Color(0.4, 0.1, 1.0)  # Violet UV
		flashlight.spot_range = 12.0  # Portée réduite
		flashlight.light_energy = 3.0
	else:
		var warm: float = lerpf(0.4, 0.9, ratio)
		flashlight.light_color = Color(1.0, warm, warm * 0.6)
	
	if ratio < 0.15 and ratio > 0 and not is_recharging:
		var flicker: float = randf()
		if flicker < 0.08:
			flashlight.visible = false
		elif flashlight_on:
			flashlight.visible = true
	
	# Effet strobo
	if strobe_active and has_strobe:
		var strobe_blink: bool = fmod(Time.get_ticks_msec() / 50.0, 1.0) > 0.5
		flashlight.light_energy = 8.0 if strobe_blink else 0.5
		flashlight.light_color = Color(1.0, 1.0, 1.0)


func _update_footsteps(is_moving: bool) -> void:
	if not footstep_audio:
		return
	
	var on_ground: bool = player.is_on_floor()
	
	if is_moving and on_ground:
		var target_pitch: float = 1.4 if is_sprinting else 1.0
		footstep_audio.pitch_scale = target_pitch
		
		if not footstep_audio.playing:
			footstep_audio.play()
	else:
		if footstep_audio.playing:
			footstep_audio.stop()


# ============================================
# INPUT
# ============================================

func _unhandled_input(event: InputEvent) -> void:
	if not player:
		return
	
	if quiz_active:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_quiz()
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
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_G:
		if has_uv_lamp:
			uv_mode = not uv_mode
			strobe_active = false  # Désactiver strobo quand on passe en UV
			if uv_mode:
				_show_message("Lampe UV activee")
			else:
				_show_message("Lampe normale")
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		if has_strobe:
			strobe_active = not strobe_active
			uv_mode = false  # Désactiver UV quand on passe en strobo
			if strobe_active:
				_show_message("Stroboscope active !")
			else:
				_show_message("Stroboscope desactive")
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_handle_interact()


# ============================================
# PLAYER + PROCESS
# ============================================

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
	
	_update_spinning_disc(delta)
	_update_uv_tableau()


func _physics_process(delta: float) -> void:
	if not player:
		return
	
	if quiz_active:
		player.velocity = Vector3.ZERO
		return
	
	if game_won:
		player.velocity = Vector3.ZERO
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


func _build_ceiling(rows: int, cols: int, terrace_grid: Array) -> void:
	var ceiling_rects: Array = _merge_ceiling_areas(rows, cols, terrace_grid)
	
	for rect: Array in ceiling_rects:
		var col: int = rect[0]
		var row: int = rect[1]
		var w: int = rect[2]
		var h: int = rect[3]
		
		var ceiling_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(w * SCALE, 1.0, h * SCALE)
		ceiling_mesh.mesh = box
		ceiling_mesh.position = Vector3(
			(col + w / 2.0) * SCALE,
			WALL_HEIGHT + 0.5,
			(row + h / 2.0) * SCALE
		)
		
		var ceiling_texture := StandardMaterial3D.new()
		if ResourceLoader.exists("res://textures/ceiling_cut.jpg"):
			ceiling_texture.albedo_texture = load("res://textures/ceiling_cut.jpg")
			ceiling_texture.uv1_scale = Vector3(w / 8.0, h / 14.0, 1)
		else:
			ceiling_texture.albedo_color = Color(0.4, 0.4, 0.42)
		ceiling_mesh.material_override = ceiling_texture
		
		var body := StaticBody3D.new()
		var col_shape := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		col_shape.shape = shape
		body.add_child(col_shape)
		body.position = ceiling_mesh.position
		
		add_child(ceiling_mesh)
		add_child(body)


func _build_terrace_floors(rectangles: Array) -> void:
	for rect: Array in rectangles:
		var col: int = rect[0]
		var row: int = rect[1]
		var w: int = rect[2]
		var h: int = rect[3]
		
		var terrace := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(w * SCALE, 1.0, h * SCALE)
		terrace.mesh = box
		terrace.position = Vector3(
			(col + w / 2.0) * SCALE, -0.5, (row + h / 2.0) * SCALE
		)
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.45, 0.35)
		mat.roughness = 0.9
		terrace.material_override = mat
		
		var body := StaticBody3D.new()
		var col_shape := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		col_shape.shape = shape
		body.add_child(col_shape)
		body.position = terrace.position
		
		add_child(terrace)
		add_child(body)


func _build_glass_fences(rectangles: Array) -> void:
	for rect: Array in rectangles:
		var col: int = rect[0]
		var row: int = rect[1]
		var w: int = rect[2]
		var h: int = rect[3]
		
		var fence := MeshInstance3D.new()
		var box := BoxMesh.new()
		var fence_height: float = WALL_HEIGHT * 0.3
		box.size = Vector3(w * SCALE, fence_height, h * SCALE)
		fence.mesh = box
		fence.position = Vector3(
			(col + w / 2.0) * SCALE, fence_height / 2.0, (row + h / 2.0) * SCALE
		)
		
		var glass_mat := StandardMaterial3D.new()
		glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass_mat.albedo_color = Color(1.0, 0.5, 0.75, 0.4)
		glass_mat.metallic = 0.1
		glass_mat.roughness = 0.05
		glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		fence.material_override = glass_mat
		
		var body := StaticBody3D.new()
		var col_shape := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		col_shape.shape = shape
		body.add_child(col_shape)
		body.position = fence.position
		
		add_child(fence)
		add_child(body)


func _build_coffee_machines(rectangles: Array) -> void:
	for rect: Array in rectangles:
		var col: int = rect[0]
		var row: int = rect[1]
		var w: int = rect[2]
		var h: int = rect[3]
		
		var machine := MeshInstance3D.new()
		var box := BoxMesh.new()
		var machine_height: float = WALL_HEIGHT * 0.7
		box.size = Vector3(w * SCALE, machine_height, h * SCALE)
		machine.mesh = box
		machine.position = Vector3(
			(col + w / 2.0) * SCALE, machine_height / 2.0, (row + h / 2.0) * SCALE
		)
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.0, 0.8, 0.9)
		mat.metallic = 0.6
		mat.roughness = 0.3
		machine.material_override = mat
		add_child(machine)
		
		var light := SpotLight3D.new()
		light.light_color = Color(0.3, 0.7, 1.0)
		light.light_energy = 20.0
		light.spot_range = 15.0
		light.spot_angle = 45.0
		light.shadow_enabled = true
		light.position = Vector3(
			col * SCALE + w * SCALE * 0.5,
			machine_height / 2.0,
			row * SCALE - h * SCALE / 2.0
		)
		light.rotation_degrees = Vector3(0, 0, 0)
		add_child(light)


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
			(col + w / 2.0) * SCALE, WALL_HEIGHT / 2.0, (row + h / 2.0) * SCALE
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


func _build_windows(rectangles: Array) -> void:
	for rect: Array in rectangles:
		var col: int = rect[0]
		var row: int = rect[1]
		var w: int = rect[2]
		var h: int = rect[3]
		
		var window := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(w * SCALE, WALL_HEIGHT, h * SCALE)
		window.mesh = box
		window.position = Vector3(
			(col + w / 2.0) * SCALE, WALL_HEIGHT / 2.0, (row + h / 2.0) * SCALE
		)
		
		var glass_mat := StandardMaterial3D.new()
		glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass_mat.albedo_color = Color(0.7, 0.85, 1.0, 0.3)
		glass_mat.metallic = 0.0
		glass_mat.roughness = 0.1
		glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		window.material_override = glass_mat
		
		var body := StaticBody3D.new()
		var col_shape := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		col_shape.shape = shape
		body.add_child(col_shape)
		body.position = window.position
		
		add_child(window)
		add_child(body)


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
			(col + w / 2.0) * SCALE, 1.0, (row + h / 2.0) * SCALE
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


func _setup_environment() -> void:
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
	
	var sun_light := DirectionalLight3D.new()
	sun_light.light_color = Color(1.0, 0.7, 0.5)
	sun_light.light_energy = 0.6
	sun_light.shadow_enabled = true
	sun_light.shadow_blur = 1.5
	sun_light.rotation_degrees = Vector3(-15, -45, 0)
	add_child(sun_light)
	
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


func _merge_type(grid: Array, rows: int, cols: int, type_id: int) -> Array:
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


func _merge_ceiling_areas(rows: int, cols: int, terrace_grid: Array) -> Array:
	var visited: Array[Array] = []
	for row: int in range(rows):
		var line: Array[bool] = []
		line.resize(cols)
		line.fill(false)
		visited.append(line)
	
	var rectangles: Array = []
	
	for row: int in range(rows):
		for col: int in range(cols):
			if terrace_grid[row][col] or visited[row][col]:
				continue
			
			var width: int = 0
			for c: int in range(col, cols):
				if not terrace_grid[row][c] and not visited[row][c]:
					width += 1
				else:
					break
			
			var height: int = 0
			for r: int in range(row, rows):
				var full_row: bool = true
				for c: int in range(col, col + width):
					if c >= cols or terrace_grid[r][c] or visited[r][c]:
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
