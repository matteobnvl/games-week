extends Control

const MENU_MUSIC_PATH := "res://songs/menu_music.ogg"
const MONSTER_MODEL_PATH := "res://characters/funny_fear_p2_rig.glb"
const MONSTER_IDLE_ANIM := "funny_fear_p2_ref_skeleton|idle"

var music_player: AudioStreamPlayer
var _monster_anim: AnimationPlayer = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# --- 3D background with monster and light ---
	_setup_3d_background()
	
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


func _setup_3d_background() -> void:
	# SubViewportContainer fills the whole screen behind UI
	var svc := SubViewportContainer.new()
	svc.set_anchors_preset(PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	
	var sv := SubViewport.new()
	sv.size = Vector2i(1920, 1080)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	svc.add_child(sv)
	
	# Dark environment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = 2
	env.ambient_light_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_energy = 0.05
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	sv.add_child(world_env)
	
	# Camera looking at the scene
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 5)
	cam.look_at(Vector3(0, 1.2, 0))
	cam.current = true
	sv.add_child(cam)
	
	# Eerie light on the LEFT side
	var light_left := OmniLight3D.new()
	light_left.position = Vector3(-4, 3, 3)
	light_left.light_color = Color(0.6, 0.15, 0.1)  # Deep red
	light_left.light_energy = 4.0
	light_left.omni_range = 12.0
	light_left.shadow_enabled = true
	sv.add_child(light_left)
	
	# Subtle fill light
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(2, 2, 4)
	fill_light.light_color = Color(0.1, 0.05, 0.15)  # Faint purple
	fill_light.light_energy = 1.5
	fill_light.omni_range = 10.0
	sv.add_child(fill_light)
	
	# Floor
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.05, 0.05, 0.05)
	floor_mesh.material_override = floor_mat
	sv.add_child(floor_mesh)
	
	# Monster on the RIGHT side
	if ResourceLoader.exists(MONSTER_MODEL_PATH):
		var monster_scene: PackedScene = load(MONSTER_MODEL_PATH)
		var monster := monster_scene.instantiate()
		var monster_anchor := Node3D.new()
		monster_anchor.position = Vector3(2.5, 0, 1.5)
		monster_anchor.rotation.y = -0.4  # Slightly angled toward camera
		monster_anchor.add_child(monster)
		sv.add_child(monster_anchor)
		
		# Disable AnimationTree if present
		for child in monster.get_children():
			if child is AnimationTree:
				child.active = false
		
		# Find AnimationPlayer and play idle (looping)
		_monster_anim = _find_anim_player(monster)
		if _monster_anim:
			if _monster_anim.has_animation(MONSTER_IDLE_ANIM):
				_monster_anim.play(MONSTER_IDLE_ANIM)
			else:
				# Try first available animation as fallback
				var anims := _monster_anim.get_animation_list()
				if anims.size() > 0:
					_monster_anim.play(anims[0])
			_monster_anim.animation_finished.connect(_on_monster_anim_finished)


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_anim_player(child)
		if result:
			return result
	return null


func _on_monster_anim_finished(_anim_name: StringName) -> void:
	if _monster_anim:
		if _monster_anim.has_animation(MONSTER_IDLE_ANIM):
			_monster_anim.play(MONSTER_IDLE_ANIM)
		else:
			var anims := _monster_anim.get_animation_list()
			if anims.size() > 0:
				_monster_anim.play(anims[0])
