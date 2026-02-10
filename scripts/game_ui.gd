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

# Code Entry UI
var code_panel: PanelContainer
var code_digit_labels: Array = []
var code_digit_values: Array = [-1, -1, -1, -1]
var code_locked_slots: Array = [false, false, false, false]
var code_active_slot: int = -1
var code_confirm_btn: Button
var code_cancel_btn: Button
var code_entry_active: bool = false


func _ready() -> void:
	_create_bars()
	_create_labels()
	_create_quiz_panel()
	_create_code_panel()


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
		elif i == 3:
			code_text += "? "
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
# Code Entry Panel
# ---------------------------------------------------------------------------

func _create_code_panel() -> void:
	code_panel = PanelContainer.new()
	code_panel.set_anchors_preset(Control.PRESET_CENTER)
	code_panel.position = Vector2(-260, -210)
	code_panel.custom_minimum_size = Vector2(520, 400)
	code_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(0.5, 0.1, 0.1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	code_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)

	# Title
	var title := Label.new()
	title.text = "ENTREZ LE CODE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	vbox.add_child(title)

	# Digit slots
	var digits_hbox := HBoxContainer.new()
	digits_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	digits_hbox.add_theme_constant_override("separation", 20)

	for i: int in range(4):
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(70, 80)
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.15, 0.15, 0.2)
		slot_style.border_color = Color(0.4, 0.4, 0.5)
		slot_style.set_border_width_all(2)
		slot_style.set_corner_radius_all(4)
		slot_panel.add_theme_stylebox_override("panel", slot_style)

		var digit_label := Label.new()
		digit_label.text = "_"
		digit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		digit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		digit_label.add_theme_font_size_override("font_size", 40)
		digit_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		slot_panel.add_child(digit_label)

		digits_hbox.add_child(slot_panel)
		code_digit_labels.append(digit_label)

	vbox.add_child(digits_hbox)

	# Instruction
	var instruction := Label.new()
	instruction.text = "Cliquez sur un chiffre ou tapez 0-9"
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.add_theme_font_size_override("font_size", 14)
	instruction.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(instruction)

	# Number buttons (0-9)
	var num_hbox := HBoxContainer.new()
	num_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	num_hbox.add_theme_constant_override("separation", 5)
	for n: int in range(10):
		var btn := Button.new()
		btn.text = str(n)
		btn.custom_minimum_size = Vector2(42, 42)
		btn.pressed.connect(_on_code_number_pressed.bind(n))
		num_hbox.add_child(btn)
	vbox.add_child(num_hbox)

	# Action buttons
	var action_hbox := HBoxContainer.new()
	action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_hbox.add_theme_constant_override("separation", 20)

	code_confirm_btn = Button.new()
	code_confirm_btn.text = "Confirmer"
	code_confirm_btn.custom_minimum_size = Vector2(150, 45)
	action_hbox.add_child(code_confirm_btn)

	code_cancel_btn = Button.new()
	code_cancel_btn.text = "Annuler"
	code_cancel_btn.custom_minimum_size = Vector2(150, 45)
	action_hbox.add_child(code_cancel_btn)

	vbox.add_child(action_hbox)

	code_panel.add_child(vbox)
	add_child(code_panel)


func open_code_panel(found_digits: Array) -> void:
	code_entry_active = true
	code_panel.visible = true
	code_active_slot = -1

	for i: int in range(4):
		if found_digits[i] != -1:
			code_digit_values[i] = found_digits[i]
			code_digit_labels[i].text = str(found_digits[i])
			code_digit_labels[i].add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
			code_locked_slots[i] = true
		else:
			code_digit_values[i] = -1
			code_digit_labels[i].text = "_"
			code_digit_labels[i].add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			code_locked_slots[i] = false

	_select_next_empty_slot()


func close_code_panel() -> void:
	code_entry_active = false
	code_panel.visible = false
	code_active_slot = -1


func _select_next_empty_slot() -> void:
	for i: int in range(4):
		if not code_locked_slots[i] and code_digit_values[i] == -1:
			_select_slot(i)
			return
	# All filled or locked, select last unlocked
	for i: int in range(3, -1, -1):
		if not code_locked_slots[i]:
			_select_slot(i)
			return


func _select_slot(index: int) -> void:
	# Deselect previous
	if code_active_slot >= 0 and code_active_slot < 4:
		var prev_parent: PanelContainer = code_digit_labels[code_active_slot].get_parent()
		var prev_style: StyleBoxFlat = prev_parent.get_theme_stylebox("panel")
		prev_style.border_color = Color(0.4, 0.4, 0.5)

	code_active_slot = index

	# Highlight selected
	if index >= 0 and index < 4:
		var parent: PanelContainer = code_digit_labels[index].get_parent()
		var cur_style: StyleBoxFlat = parent.get_theme_stylebox("panel")
		cur_style.border_color = Color(1.0, 0.8, 0.2)


func _on_code_number_pressed(num: int) -> void:
	if code_active_slot < 0 or code_active_slot >= 4:
		return
	if code_locked_slots[code_active_slot]:
		return
	code_digit_values[code_active_slot] = num
	code_digit_labels[code_active_slot].text = str(num)
	_select_next_empty_slot()


func get_entered_code() -> Array:
	return code_digit_values.duplicate()


func handle_code_key_input(keycode: int) -> void:
	if not code_entry_active:
		return
	if keycode >= KEY_0 and keycode <= KEY_9:
		var num: int = keycode - KEY_0
		_on_code_number_pressed(num)
	elif keycode >= KEY_KP_0 and keycode <= KEY_KP_9:
		var num: int = keycode - KEY_KP_0
		_on_code_number_pressed(num)
	elif keycode == KEY_BACKSPACE:
		if code_active_slot >= 0 and not code_locked_slots[code_active_slot]:
			code_digit_values[code_active_slot] = -1
			code_digit_labels[code_active_slot].text = "_"
