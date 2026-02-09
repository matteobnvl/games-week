class_name GameUI
extends CanvasLayer
## All HUD elements: stamina/battery bars, interact label, quest, code display, messages, quiz panel.

var stamina_bar_fg: ColorRect
var stamina_bar_bg: ColorRect
var battery_bar_fg: ColorRect
var battery_bar_bg: ColorRect
var interact_label: Label
var quest_label: Label
var code_label: Label
var uv_parts_label: Label
var message_label: Label
var message_timer: float = 0.0

# Quiz UI
var quiz_panel: PanelContainer
var quiz_question_label: Label
var quiz_answers_container: VBoxContainer


func _ready() -> void:
	_create_bars()
	_create_labels()
	_create_quiz_panel()


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _create_bars() -> void:
	# Stamina
	stamina_bar_bg = ColorRect.new()
	stamina_bar_bg.color = Color(0.15, 0.15, 0.15, 0.6)
	stamina_bar_bg.size = Vector2(200, 8)
	stamina_bar_bg.position = Vector2(20, -30)
	stamina_bar_bg.anchor_top = 1.0
	stamina_bar_bg.anchor_bottom = 1.0
	add_child(stamina_bar_bg)

	stamina_bar_fg = ColorRect.new()
	stamina_bar_fg.color = Color(0.9, 0.7, 0.1, 0.8)
	stamina_bar_fg.size = Vector2(200, 8)
	stamina_bar_fg.position = Vector2(20, -30)
	stamina_bar_fg.anchor_top = 1.0
	stamina_bar_fg.anchor_bottom = 1.0
	add_child(stamina_bar_fg)

	# Battery
	battery_bar_bg = ColorRect.new()
	battery_bar_bg.color = Color(0.15, 0.15, 0.15, 0.6)
	battery_bar_bg.size = Vector2(200, 8)
	battery_bar_bg.position = Vector2(20, -45)
	battery_bar_bg.anchor_top = 1.0
	battery_bar_bg.anchor_bottom = 1.0
	add_child(battery_bar_bg)

	battery_bar_fg = ColorRect.new()
	battery_bar_fg.color = Color(0.3, 0.7, 0.9, 0.8)
	battery_bar_fg.size = Vector2(200, 8)
	battery_bar_fg.position = Vector2(20, -45)
	battery_bar_fg.anchor_top = 1.0
	battery_bar_fg.anchor_bottom = 1.0
	add_child(battery_bar_fg)


func _create_labels() -> void:
	interact_label = Label.new()
	interact_label.text = "[E] Ouvrir"
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interact_label.position = Vector2(-60, -80)
	interact_label.add_theme_font_size_override("font_size", 20)
	interact_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.8))
	interact_label.visible = false
	add_child(interact_label)

	quest_label = Label.new()
	quest_label.text = ">> Trouver la sortie"
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	quest_label.position = Vector2(20, 20)
	quest_label.add_theme_font_size_override("font_size", 22)
	quest_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.9))
	add_child(quest_label)

	code_label = Label.new()
	code_label.text = "Code : _ _ _ _"
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	code_label.anchor_left = 1.0
	code_label.anchor_right = 1.0
	code_label.position = Vector2(-220, 20)
	code_label.add_theme_font_size_override("font_size", 22)
	code_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.9))
	add_child(code_label)

	uv_parts_label = Label.new()
	uv_parts_label.text = ""
	uv_parts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	uv_parts_label.position = Vector2(20, 50)
	uv_parts_label.add_theme_font_size_override("font_size", 16)
	uv_parts_label.add_theme_color_override("font_color", Color(0.6, 0.4, 1.0, 0.8))
	add_child(uv_parts_label)

	message_label = Label.new()
	message_label.text = ""
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.set_anchors_preset(Control.PRESET_CENTER)
	message_label.position = Vector2(-300, -200)
	message_label.add_theme_font_size_override("font_size", 26)
	message_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	message_label.visible = false
	add_child(message_label)


func _create_quiz_panel() -> void:
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
	add_child(quiz_panel)


# ---------------------------------------------------------------------------
# Update helpers
# ---------------------------------------------------------------------------

func show_message(text: String, duration: float = 3.0) -> void:
	message_label.text = text
	message_label.visible = true
	message_timer = duration


func update_stamina_bar(current_stamina: float) -> void:
	var ratio: float = current_stamina / GameConfig.STAMINA_MAX
	stamina_bar_fg.size.x = 200.0 * ratio
	if ratio > 0.5:
		stamina_bar_fg.color = Color(0.9, 0.7, 0.1, 0.8)
	elif ratio > 0.2:
		stamina_bar_fg.color = Color(0.9, 0.4, 0.1, 0.8)
	else:
		stamina_bar_fg.color = Color(0.9, 0.15, 0.1, 0.8)
	var show: bool = current_stamina < GameConfig.STAMINA_MAX - 0.1
	stamina_bar_bg.visible = show
	stamina_bar_fg.visible = show


func update_battery_bar(current_battery: float, recharging: bool) -> void:
	var ratio: float = current_battery / GameConfig.BATTERY_MAX
	battery_bar_fg.size.x = 200.0 * ratio
	if recharging:
		var blink: bool = fmod(Time.get_ticks_msec() / 300.0, 1.0) > 0.5
		battery_bar_fg.color = Color(0.2, 0.9, 0.3, 0.8) if blink else Color(0.1, 0.5, 0.2, 0.5)
	elif ratio > 0.5:
		battery_bar_fg.color = Color(0.3, 0.7, 0.9, 0.8)
	elif ratio > 0.2:
		battery_bar_fg.color = Color(0.9, 0.5, 0.1, 0.8)
	else:
		battery_bar_fg.color = Color(0.9, 0.15, 0.1, 0.8)
	battery_bar_bg.visible = true
	battery_bar_fg.visible = true


func update_uv_label(uv_collected: int, has_uv_lamp: bool, uv_mode: bool, has_strobe: bool, strobe_active: bool) -> void:
	if uv_collected > 0 and not has_uv_lamp:
		uv_parts_label.text = "Pieces UV : " + str(uv_collected) + "/" + str(GameConfig.UV_PARTS_NEEDED)
	elif has_uv_lamp:
		uv_parts_label.text = "Lampe UV : ON [G]" if uv_mode else "Lampe UV : OFF [G]"
	else:
		uv_parts_label.text = ""
	if has_strobe:
		uv_parts_label.text += "  |  Strobo : ON [H]" if strobe_active else "  |  Strobo : OFF [H]"


func update_quest(current_quest: String, found_digits: Array) -> void:
	match current_quest:
		"find_exit":
			quest_label.text = ">> Trouver la sortie"
		"find_clues":
			quest_label.text = ">> Explorer et trouver le code"
		"enter_code":
			quest_label.text = ">> Retourner a la porte de sortie !"
	var code_text: String = "Code : "
	for i: int in range(4):
		if found_digits[i] != -1:
			code_text += str(found_digits[i]) + " "
		else:
			code_text += "_ "
	code_label.text = code_text


func update_message_timer(delta: float) -> void:
	if message_timer > 0:
		message_timer -= delta
		if message_timer <= 0:
			message_label.visible = false


func show_interact(text: String) -> void:
	interact_label.text = text
	interact_label.visible = true


func hide_interact() -> void:
	interact_label.visible = false


# ---------------------------------------------------------------------------
# Game Over
# ---------------------------------------------------------------------------

func show_game_over() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.3, 0.0, 0.0, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	add_child(overlay)

	var death_label := Label.new()
	death_label.text = "FELIPE T'A ATTRAPE..."
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.set_anchors_preset(Control.PRESET_CENTER)
	death_label.add_theme_font_size_override("font_size", 52)
	death_label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
	death_label.modulate.a = 0.0
	death_label.z_index = 101
	add_child(death_label)

	var subtitle := Label.new()
	subtitle.text = "Tu n'aurais pas du faire de bruit..."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_CENTER)
	subtitle.position.y = 50
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	subtitle.modulate.a = 0.0
	subtitle.z_index = 101
	add_child(subtitle)

	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 0.9, 1.5)
	tween.parallel().tween_property(death_label, "modulate:a", 1.0, 1.5)
	tween.tween_property(subtitle, "modulate:a", 1.0, 1.0)
	tween.tween_interval(3.0)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file("res://menu.tscn"))
