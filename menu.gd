extends Control

const MENU_MUSIC_PATH := "res://songs/menu_music.ogg"

var music_player: AudioStreamPlayer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_CENTER)
	vbox.position = Vector2(-150, -120)
	vbox.custom_minimum_size = Vector2(300, 0)
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)
	
	var title := Label.new()
	title.text = "ESCAPE EFREI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)
	
	var subtitle := Label.new()
	subtitle.text = "EFREI by Night"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(subtitle)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)
	
	var play_btn := Button.new()
	play_btn.text = "JOUER"
	play_btn.custom_minimum_size = Vector2(300, 55)
	play_btn.pressed.connect(_on_play)
	vbox.add_child(play_btn)
	
	var skip_btn := Button.new()
	skip_btn.text = "JOUER (SKIP INTRO)"
	skip_btn.custom_minimum_size = Vector2(300, 55)
	skip_btn.pressed.connect(_on_skip)
	vbox.add_child(skip_btn)
	
	var quit_btn := Button.new()
	quit_btn.text = "QUITTER"
	quit_btn.custom_minimum_size = Vector2(300, 55)
	quit_btn.pressed.connect(_on_quit)
	vbox.add_child(quit_btn)
	
	# Musique d'ambiance
	music_player = AudioStreamPlayer.new()
	if ResourceLoader.exists(MENU_MUSIC_PATH):
		music_player.stream = load(MENU_MUSIC_PATH)
	music_player.volume_db = -3.0
	music_player.autoplay = true
	add_child(music_player)
	
	music_player.finished.connect(_on_music_finished)


func _on_music_finished() -> void:
	music_player.play()


func _on_play() -> void:
	music_player.stop()
	get_tree().change_scene_to_file("res://cinematic/cinematic.tscn")


func _on_skip() -> void:
	music_player.stop()
	get_tree().change_scene_to_file("res://main.tscn")


func _on_quit() -> void:
	get_tree().quit()
