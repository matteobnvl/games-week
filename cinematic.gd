extends Control

const LINES: Array[String] = [
	"Cours de Monsieur Geoffroy.",
	"14h35.",
	"",
	"Comme d'habitude, sa voix monotone fait effet...",
	"Tes paupières deviennent lourdes.",
	"",
	"Tu résistes...",
	"",
	"...",
	"",
	"Tu t'endors.",
	"",
	"",
	"",
	"...",
	"",
	"",
	"Un bruit te réveille.",
	"",
	"Il fait noir.",
	"",
	"Complètement noir.",
	"",
	"Tu regardes ton téléphone.",
	"",
	"3h47.",
	"",
	"La salle est vide.",
	"Le campus est fermé.",
	"",
	"",
	"Tu dois sortir d'ici.",
	"",
	"",
	"Mais tu n'es pas seul...",
	"",
	"",
	"",
	"On raconte que Felipe rôde dans les couloirs la nuit.",
	"",
	"Personne ne sait pourquoi il est là.",
	"Personne ne veut le savoir.",
	"",
	"",
	"Une seule règle :",
	"",
	"",
	"Ne te fais pas attraper.",
	"",
	"",
	"",
	"",
	"",
]

const CHAR_DELAY := 0.04         # délai entre chaque caractère
const LINE_PAUSE := 0.8          # pause entre chaque ligne
const DOTS_PAUSE := 1.5          # pause plus longue pour les "..."
const EMPTY_PAUSE := 0.3         # pause pour les lignes vides
const END_PAUSE := 2.0           # pause à la fin avant de lancer le jeu

var current_line: int = 0
var current_char: int = 0
var timer: float = 0.0
var state: String = "typing"     # typing, pausing, finished
var pause_duration: float = 0.0
var displayed_text: String = ""

var label: Label
var skip_label: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Fond noir
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	
	# Texte principal
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = ""
	add_child(label)
	
	# Petit texte en bas (pas de skip mais indication)
	skip_label = Label.new()
	skip_label.text = ""
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_label.set_anchors_preset(PRESET_BOTTOM_WIDE)
	skip_label.position.y = -40
	skip_label.add_theme_font_size_override("font_size", 14)
	skip_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	add_child(skip_label)


func _process(delta: float) -> void:
	if state == "typing":
		_process_typing(delta)
	elif state == "pausing":
		_process_pause(delta)
	elif state == "finished":
		_process_finished(delta)


func _process_typing(delta: float) -> void:
	if current_line >= LINES.size():
		state = "finished"
		pause_duration = END_PAUSE
		return
	
	var line: String = LINES[current_line]
	
	# Ligne vide = juste une pause
	if line == "":
		displayed_text += "\n"
		label.text = displayed_text
		current_line += 1
		state = "pausing"
		pause_duration = EMPTY_PAUSE
		return
	
	# Taper caractère par caractère
	timer += delta
	if timer >= CHAR_DELAY:
		timer = 0.0
		if current_char < line.length():
			displayed_text += line[current_char]
			label.text = displayed_text
			current_char += 1
		else:
			# Ligne terminée
			displayed_text += "\n"
			label.text = displayed_text
			current_char = 0
			current_line += 1
			state = "pausing"
			
			# Pause plus longue pour les "..."
			if line == "...":
				pause_duration = DOTS_PAUSE
			elif line.ends_with("..."):
				pause_duration = DOTS_PAUSE
			else:
				pause_duration = LINE_PAUSE
	
	# Garder seulement les dernières lignes visibles (effet défilement)
	_trim_display()


func _process_pause(delta: float) -> void:
	pause_duration -= delta
	if pause_duration <= 0:
		state = "typing"


func _process_finished(delta: float) -> void:
	pause_duration -= delta
	if pause_duration <= 0:
		# Fondu au noir puis lancer le jeu
		_start_fade()


func _trim_display() -> void:
	# Garder max 12 lignes affichées
	var lines: PackedStringArray = displayed_text.split("\n")
	if lines.size() > 12:
		var trimmed: PackedStringArray = lines.slice(lines.size() - 12)
		displayed_text = "\n".join(trimmed)
		label.text = displayed_text


var fading := false
var fade_rect: ColorRect
var fade_alpha: float = 0.0

func _start_fade() -> void:
	if fading:
		return
	fading = true
	
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(PRESET_FULL_RECT)
	fade_rect.z_index = 100
	add_child(fade_rect)
	
	# Utiliser un tween pour le fondu
	var tween: Tween = create_tween()
	tween.tween_method(_set_fade, 0.0, 1.0, 2.0)
	tween.tween_callback(_go_to_game)


func _set_fade(value: float) -> void:
	fade_alpha = value
	if fade_rect:
		fade_rect.color = Color(0, 0, 0, value)
	# Faire disparaître le texte aussi
	label.add_theme_color_override("font_color", Color(0.75 * (1.0 - value), 0.75 * (1.0 - value), 0.75 * (1.0 - value)))


func _go_to_game() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
