class_name GameUI
extends CanvasLayer
## All HUD elements: stamina/battery bars, interact label, quest, code display, messages, quiz panel.

var stamina_bar_fg: ColorRect
var stamina_bar_bg: ColorRect
var battery_bar_fg: ColorRect
var battery_bar_bg: ColorRect
var interact_label: Label
var quest_panel: PanelContainer
var quest_title_label: Label
var quest_main_label: Label
var quest_detail_label: Label
var _last_quest: String = ""
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

# PC Code Entry UI
var pc_code_panel: PanelContainer
var pc_code_digit_labels: Array = []
var pc_code_digit_values: Array = [-1, -1, -1, -1]
var pc_code_active_slot: int = -1
var pc_code_confirm_btn: Button
var pc_code_cancel_btn: Button
var pc_code_entry_active: bool = false

# Pause menu
var pause_panel: PanelContainer
var _music_slider: HSlider
var _monster_slider: HSlider
var _environment_slider: HSlider

# Loading screen
var loading_overlay: ColorRect
var loading_label: Label
var loading_dots_timer: float = 0.0


func _ready() -> void:
	_create_loading_screen()
	_create_bars()
	_create_labels()
	_create_quiz_panel()
	_create_code_panel()
	_create_pc_code_panel()
	_create_pause_menu()


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _create_loading_screen() -> void:
	loading_overlay = ColorRect.new()
	loading_overlay.color = Color(0.02, 0.02, 0.05, 1.0)
	loading_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_overlay.z_index = 200
	add_child(loading_overlay)

	loading_label = Label.new()
	loading_label.text = "Chargement..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading_label.set_anchors_preset(Control.PRESET_CENTER)
	loading_label.add_theme_font_size_override("font_size", 36)
	loading_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.9))
	loading_label.z_index = 201
	add_child(loading_label)


func hide_loading_screen() -> void:
	if loading_overlay:
		loading_overlay.visible = false
	if loading_label:
		loading_label.visible = false


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

	# Quest panel (prominent objective tracker)
	quest_panel = PanelContainer.new()
	quest_panel.position = Vector2(20, 20)
	quest_panel.custom_minimum_size = Vector2(500, 0)

	var quest_style := StyleBoxFlat.new()
	quest_style.bg_color = Color(0.02, 0.02, 0.06, 0.95)
	quest_style.border_color = Color(1.0, 0.75, 0.2, 0.8)
	quest_style.border_width_left = 8
	quest_style.border_width_top = 3
	quest_style.border_width_right = 3
	quest_style.border_width_bottom = 3
	quest_style.set_corner_radius_all(6)
	quest_style.content_margin_left = 16
	quest_style.content_margin_right = 16
	quest_style.content_margin_top = 12
	quest_style.content_margin_bottom = 12
	quest_panel.add_theme_stylebox_override("panel", quest_style)

	var quest_vbox := VBoxContainer.new()
	quest_vbox.add_theme_constant_override("separation", 6)

	quest_title_label = Label.new()
	quest_title_label.text = "◆ OBJECTIF"
	quest_title_label.add_theme_font_size_override("font_size", 14)
	quest_title_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2, 0.9))
	quest_vbox.add_child(quest_title_label)

	quest_main_label = Label.new()
	quest_main_label.text = "Trouver la sortie"
	quest_main_label.add_theme_font_size_override("font_size", 26)
	quest_main_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3, 1.0))
	quest_main_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	quest_vbox.add_child(quest_main_label)

	quest_detail_label = Label.new()
	quest_detail_label.text = "Explorez le batiment"
	quest_detail_label.add_theme_font_size_override("font_size", 17)
	quest_detail_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 0.85))
	quest_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	quest_detail_label.custom_minimum_size = Vector2(450, 0)
	quest_vbox.add_child(quest_detail_label)

	quest_panel.add_child(quest_vbox)
	add_child(quest_panel)

	code_label = Label.new()
	code_label.visible = false
	add_child(code_label)

	uv_parts_label = Label.new()
	uv_parts_label.text = ""
	uv_parts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	uv_parts_label.position = Vector2(20, 140)
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


func _create_pause_menu() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-200, -180)
	pause_panel.custom_minimum_size = Vector2(400, 340)
	pause_panel.visible = false
	pause_panel.z_index = 200

	# Dark background style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(0.4, 0.4, 0.5, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	pause_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)

	# Title
	var title := Label.new()
	title.text = "PAUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(title)

	# Music volume
	_music_slider = _create_volume_slider(vbox, "Musique", "Music")

	# Monster volume
	_monster_slider = _create_volume_slider(vbox, "Monstre", "Monster")

	# Environment volume
	_environment_slider = _create_volume_slider(vbox, "Environnement", "Environment")

	# Resume button
	var resume_btn := Button.new()
	resume_btn.text = "Reprendre"
	resume_btn.custom_minimum_size = Vector2(200, 40)
	resume_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume_btn.add_theme_font_size_override("font_size", 18)
	resume_btn.pressed.connect(func() -> void:
		hide_pause_menu()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false
	)
	vbox.add_child(resume_btn)

	# Quit button
	var quit_btn := Button.new()
	quit_btn.text = "Menu Principal"
	quit_btn.custom_minimum_size = Vector2(200, 40)
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit_btn.add_theme_font_size_override("font_size", 18)
	quit_btn.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://menu.tscn")
	)
	vbox.add_child(quit_btn)

	pause_panel.add_child(vbox)
	add_child(pause_panel)


func _create_volume_slider(parent: VBoxContainer, label_text: String, bus_name: String) -> HSlider:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(140, 0)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hbox.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = 1.0
	slider.custom_minimum_size = Vector2(180, 20)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(val: float) -> void:
		var bus_idx: int = AudioServer.get_bus_index(bus_name)
		if bus_idx >= 0:
			if val <= 0.01:
				AudioServer.set_bus_mute(bus_idx, true)
			else:
				AudioServer.set_bus_mute(bus_idx, false)
				AudioServer.set_bus_volume_db(bus_idx, linear_to_db(val))
	)
	hbox.add_child(slider)

	parent.add_child(hbox)
	return slider


func show_pause_menu() -> void:
	pause_panel.visible = true


func hide_pause_menu() -> void:
	pause_panel.visible = false


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
	if has_uv_lamp:
		uv_parts_label.text = "Lampe UV : ON [G]" if uv_mode else "Lampe UV : OFF [G]"
	else:
		uv_parts_label.text = ""
	if has_strobe:
		uv_parts_label.text += "  |  Strobo : ON [H]" if strobe_active else "  |  Strobo : OFF [H]"


func update_quest(current_quest: String, found_digits: Array, uv_collected: int = 0) -> void:
	var quest_changed: bool = (current_quest != _last_quest)
	_last_quest = current_quest

	match current_quest:
		"find_exit":
			quest_main_label.text = "Trouver la sortie"
			quest_detail_label.text = "Une porte... Explorez le batiment !"
		"collect_uv":
			quest_main_label.text = "Lampe UV"
			quest_detail_label.text = "Recuperez 4 elements violets pour construire une lampe UV\n\n" + str(uv_collected) + " / " + str(GameConfig.UV_PARTS_NEEDED) + " pieces collectees"
		"find_code":
			quest_main_label.text = "Trouver le code"
			var lines: PackedStringArray = []
			lines.append("Utilisez la lampe UV pour reveler les indices :")
			if found_digits[0] != -1:
				lines.append("  [✓] Code sur tableau (UV)")
			else:
				lines.append("  [ ] Code sur tableau (illumine par UV)")
			if found_digits[2] != -1:
				lines.append("  [✓] Code du PC")
			else:
				lines.append("  [ ] Code du PC (inscrit sur un mur)")
			quest_detail_label.text = "\n".join(lines)
		"enter_code":
			quest_main_label.text = "Dernier obstacle !"
			quest_detail_label.text = "La porte est pres... Entrez le code a 4 chiffres\n\nRetournez a la porte pour vous echapper !"

	quest_detail_label.visible = quest_detail_label.text != ""

	if quest_changed:
		_flash_quest_panel()


func _flash_quest_panel() -> void:
	if not quest_panel:
		return
	# Dramatic flash with scale animation
	quest_panel.scale = Vector2(0.95, 0.95)
	quest_panel.modulate = Color(2.0, 1.8, 0.6, 1.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(quest_panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.6)
	tween.tween_property(quest_panel, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


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


func open_code_panel(_found_digits: Array) -> void:
	code_entry_active = true
	code_panel.visible = true
	code_active_slot = -1

	# All slots are empty and editable (no pre-fill)
	for i: int in range(4):
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


# ---------------------------------------------------------------------------
# PC Code Entry Panel
# ---------------------------------------------------------------------------

func _create_pc_code_panel() -> void:
	pc_code_panel = PanelContainer.new()
	pc_code_panel.set_anchors_preset(Control.PRESET_CENTER)
	pc_code_panel.position = Vector2(-260, -210)
	pc_code_panel.custom_minimum_size = Vector2(520, 400)
	pc_code_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_color = Color(0.2, 0.4, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	pc_code_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)

	# Title
	var title := Label.new()
	title.text = "CODE D'ACCES PC"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.3, 0.5, 1.0))
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
		pc_code_digit_labels.append(digit_label)

	vbox.add_child(digits_hbox)

	# Instruction
	var instruction := Label.new()
	instruction.text = "Entrez le code d'acces"
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
		btn.pressed.connect(_on_pc_code_number_pressed.bind(n))
		num_hbox.add_child(btn)
	vbox.add_child(num_hbox)

	# Action buttons
	var action_hbox := HBoxContainer.new()
	action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_hbox.add_theme_constant_override("separation", 20)

	pc_code_confirm_btn = Button.new()
	pc_code_confirm_btn.text = "Confirmer"
	pc_code_confirm_btn.custom_minimum_size = Vector2(150, 45)
	action_hbox.add_child(pc_code_confirm_btn)

	pc_code_cancel_btn = Button.new()
	pc_code_cancel_btn.text = "Annuler"
	pc_code_cancel_btn.custom_minimum_size = Vector2(150, 45)
	action_hbox.add_child(pc_code_cancel_btn)

	vbox.add_child(action_hbox)

	pc_code_panel.add_child(vbox)
	add_child(pc_code_panel)


func open_pc_code_panel() -> void:
	pc_code_entry_active = true
	pc_code_panel.visible = true
	pc_code_active_slot = -1

	for i: int in range(4):
		pc_code_digit_values[i] = -1
		pc_code_digit_labels[i].text = "_"
		pc_code_digit_labels[i].add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

	_pc_select_next_empty_slot()


func close_pc_code_panel() -> void:
	pc_code_entry_active = false
	pc_code_panel.visible = false
	pc_code_active_slot = -1


func _pc_select_next_empty_slot() -> void:
	for i: int in range(4):
		if pc_code_digit_values[i] == -1:
			_pc_select_slot(i)
			return
	# All filled, select last
	_pc_select_slot(3)


func _pc_select_slot(index: int) -> void:
	# Deselect previous
	if pc_code_active_slot >= 0 and pc_code_active_slot < 4:
		var prev_parent: PanelContainer = pc_code_digit_labels[pc_code_active_slot].get_parent()
		var prev_style: StyleBoxFlat = prev_parent.get_theme_stylebox("panel")
		prev_style.border_color = Color(0.4, 0.4, 0.5)

	pc_code_active_slot = index

	# Highlight selected
	if index >= 0 and index < 4:
		var parent: PanelContainer = pc_code_digit_labels[index].get_parent()
		var cur_style: StyleBoxFlat = parent.get_theme_stylebox("panel")
		cur_style.border_color = Color(1.0, 0.8, 0.2)


func _on_pc_code_number_pressed(num: int) -> void:
	if pc_code_active_slot < 0 or pc_code_active_slot >= 4:
		return
	pc_code_digit_values[pc_code_active_slot] = num
	pc_code_digit_labels[pc_code_active_slot].text = str(num)
	_pc_select_next_empty_slot()


func get_entered_pc_code() -> Array:
	return pc_code_digit_values.duplicate()


func handle_pc_code_key_input(keycode: int) -> void:
	if not pc_code_entry_active:
		return
	if keycode >= KEY_0 and keycode <= KEY_9:
		var num: int = keycode - KEY_0
		_on_pc_code_number_pressed(num)
	elif keycode >= KEY_KP_0 and keycode <= KEY_KP_9:
		var num: int = keycode - KEY_KP_0
		_on_pc_code_number_pressed(num)
	elif keycode == KEY_BACKSPACE:
		if pc_code_active_slot >= 0:
			pc_code_digit_values[pc_code_active_slot] = -1
			pc_code_digit_labels[pc_code_active_slot].text = "_"


# Game Over
# ---------------------------------------------------------------------------

func show_game_over() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.3, 0.0, 0.0, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	add_child(overlay)

	var death_label := Label.new()
	death_label.text = "LE MONSTRE T'A ATTRAPE..."
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
