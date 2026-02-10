extends Control


const MENU_MUSIC_PATH := "res://songs/menu_music.ogg"
const MONSTER_MODEL_PATH := "res://characters/funny_fear_p2_rig.glb"
const MONSTER_IDLE_ANIM := "funny_fear_p2_ref_skeleton|idle"
const MONSTER_WALK_ANIM := "funny_fear_p2_ref_skeleton|walk"
const MONSTER_SCREAM_ANIM := "funny_fear_p2_ref_skeleton|scream"
const MONSTER_FOOTSTEPS_SOUND_PATH := "res://songs/walk_1.wav"
const MONSTER_SCREAM_SOUND_PATH := "res://songs/monster-growl-fx_96bpm.wav"


var music_player: AudioStreamPlayer
var _monster_anim: AnimationPlayer = null
var _monster_anchor: Node3D = null
var _monster_audio: AudioStreamPlayer = null
var _monster_footsteps_audio: AudioStreamPlayer = null
var _camera: Camera3D = null
var _ui_container: VBoxContainer = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# --- 3D background with monster and light ---
	_setup_3d_background()
	
	_ui_container = VBoxContainer.new()
	_ui_container.set_anchors_preset(PRESET_CENTER)
	_ui_container.position = Vector2(-150, -120)
	_ui_container.custom_minimum_size = Vector2(300, 0)
	_ui_container.add_theme_constant_override("separation", 20)
	add_child(_ui_container)
	
	var title := Label.new()
	title.text = "ESCAPE EFREI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color.WHITE)
	_ui_container.add_child(title)
	
	var subtitle := Label.new()
	subtitle.text = "EFREI by Night"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_ui_container.add_child(subtitle)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	_ui_container.add_child(spacer)
	
	var play_btn := Button.new()
	play_btn.text = "JOUER"
	play_btn.custom_minimum_size = Vector2(300, 55)
	play_btn.pressed.connect(_on_play)
	_ui_container.add_child(play_btn)
	
	var skip_btn := Button.new()
	skip_btn.text = "JOUER (SKIP INTRO)"
	skip_btn.custom_minimum_size = Vector2(300, 55)
	skip_btn.pressed.connect(_on_skip)
	_ui_container.add_child(skip_btn)
	
	var quit_btn := Button.new()
	quit_btn.text = "QUITTER"
	quit_btn.custom_minimum_size = Vector2(300, 55)
	quit_btn.pressed.connect(_on_quit)
	_ui_container.add_child(quit_btn)
	
	# Musique d'ambiance
	music_player = AudioStreamPlayer.new()
	if ResourceLoader.exists(MENU_MUSIC_PATH):
		music_player.stream = load(MENU_MUSIC_PATH)
	music_player.volume_db = -3.0
	music_player.autoplay = true
	add_child(music_player)
	
	music_player.finished.connect(_on_music_finished)
	
	# Setup monster audio pour le CRI (walk_1.wav)
	_monster_audio = AudioStreamPlayer.new()
	if ResourceLoader.exists(MONSTER_SCREAM_SOUND_PATH):
		_monster_audio.stream = load(MONSTER_SCREAM_SOUND_PATH)
		print("Son de cri chargé: ", MONSTER_SCREAM_SOUND_PATH)
	else:
		print("ERREUR: Son de cri non trouvé: ", MONSTER_SCREAM_SOUND_PATH)
	_monster_audio.volume_db = 0.0  # Volume normal
	_monster_audio.pitch_scale = 1.7 
	add_child(_monster_audio)
	
	# Setup audio pour les PAS (monster-growl-fx_96bpm.wav)
	_monster_footsteps_audio = AudioStreamPlayer.new()
	if ResourceLoader.exists(MONSTER_FOOTSTEPS_SOUND_PATH):
		_monster_footsteps_audio.stream = load(MONSTER_FOOTSTEPS_SOUND_PATH)
		print("Son de pas chargé: ", MONSTER_FOOTSTEPS_SOUND_PATH)
	else:
		print("ERREUR: Son de pas non trouvé: ", MONSTER_FOOTSTEPS_SOUND_PATH)
	_monster_footsteps_audio.volume_db = -3.0
	add_child(_monster_footsteps_audio)


func _on_music_finished() -> void:
	music_player.play()


func _on_play() -> void:
	# Arrêter la musique
	if music_player:
		music_player.stop()
	
	# Masquer l'interface utilisateur
	if _ui_container:
		_ui_container.visible = false
	
	# Monster approach and scream sequence
	if _monster_anchor and _monster_anim and _camera:
		var tween := create_tween()
		tween.set_parallel(false)
		
		# Étape 1: Démarrer l'animation de marche et les sons de pas
		tween.tween_callback(func():
			print("Démarrage de l'animation de marche")
			# Jouer l'animation de marche
			if _monster_anim.has_animation(MONSTER_WALK_ANIM):
				_monster_anim.play(MONSTER_WALK_ANIM)
				print("Animation de marche lancée")
			else:
				print("ATTENTION: Animation de marche non trouvée, animations disponibles:")
				for anim_name in _monster_anim.get_animation_list():
					print("  - ", anim_name)
			
			# Démarrer les sons de pas
			if _monster_footsteps_audio and _monster_footsteps_audio.stream:
				_monster_footsteps_audio.play()
				print("Son de pas lancé")
			else:
				print("ERREUR: Pas de son de pas disponible")
		)
		
		# Étape 2: Le monstre s'approche (position optimale pour voir la tête)
		tween.tween_property(_monster_anchor, "position", Vector3(0.3, 0, 3.2), 2.0)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_IN)
		
		# Étape 3: Arrêter les pas et l'animation de marche
		tween.tween_callback(func():
			print("Arrêt de la marche")
			if _monster_footsteps_audio:
				_monster_footsteps_audio.stop()
		)
		
		# Petite pause dramatique
		tween.tween_interval(0.2)
		
		# Étape 4: Le monstre crie - SYNCHRONISATION PARFAITE
		tween.tween_callback(func():
			print("CRI DU MONSTRE!")
			
			# JOUER LE SON EN PREMIER (immédiatement)
			if _monster_audio and _monster_audio.stream:
				if not _monster_audio.playing:
					_monster_audio.play()
					print("Son de cri lancé immédiatement")
			
			# PUIS jouer l'animation
			if _monster_anim and _monster_anim.has_animation(MONSTER_SCREAM_ANIM):
				_monster_anim.play(MONSTER_SCREAM_ANIM)
				print("Animation de cri lancée")
			else:
				print("ATTENTION: Animation de cri non trouvée")
			
			# Déclencher l'effet de tremblement légèrement après le début du cri
			var shake_timer := get_tree().create_timer(0.2)
			shake_timer.timeout.connect(func():
				_start_camera_shake(1.5, 0.2, 28.0)
			)
		)
		
		# Étape 5: Transition vers la cinématique après le cri
		tween.tween_callback(func():
			print("Transition vers la cinématique")
			get_tree().change_scene_to_file("res://cinematic/cinematic.tscn")
		).set_delay(2.5)  # Augmenté pour laisser le temps au cri de se terminer
	else:
		# Fallback si pas de monstre
		print("ATTENTION: Éléments manquants pour la séquence")
		get_tree().change_scene_to_file("res://cinematic/cinematic.tscn")


func _start_camera_shake(duration: float, amplitude: float, frequency: float) -> void:
	"""
	Crée un effet de tremblement de caméra
	duration: durée totale du shake en secondes
	amplitude: intensité du tremblement (distance max de décalage)
	frequency: fréquence du tremblement (vitesse)
	"""
	if not _camera:
		return
	
	var original_pos := _camera.position
	var shake_tween := create_tween()
	
	# Nombre de secousses basé sur la durée et la fréquence
	var shake_count := int(duration * frequency)
	
	for i in shake_count:
		# Calculer une position aléatoire dans un rayon
		var offset := Vector3(
			randf_range(-amplitude, amplitude),
			randf_range(-amplitude, amplitude),
			randf_range(-amplitude * 0.3, amplitude * 0.3)  # Moins de mouvement en Z
		)
		
		# Diminuer progressivement l'amplitude (effet d'amortissement)
		var decay := 1.0 - (float(i) / float(shake_count))
		offset *= decay
		
		shake_tween.tween_property(
			_camera, 
			"position", 
			original_pos + offset, 
			1.0 / frequency
		).set_trans(Tween.TRANS_SINE)
	
	# Retour à la position originale
	shake_tween.tween_property(_camera, "position", original_pos, 0.2)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)


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
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 1.5, 5)
	_camera.look_at(Vector3(0, 1.2, 0))
	_camera.current = true
	sv.add_child(_camera)
	
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
		_monster_anchor = Node3D.new()
		_monster_anchor.position = Vector3(2.5, 0, 1.5)
		_monster_anchor.rotation.y = -0.4  # Slightly angled toward camera
		_monster_anchor.add_child(monster)
		sv.add_child(_monster_anchor)
		
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
		else:
			print("ATTENTION: AnimationPlayer du monstre non trouvé")
	else:
		print("ERREUR: Modèle du monstre non trouvé: ", MONSTER_MODEL_PATH)


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
