class_name PlayerController
extends CharacterBody3D
## Manages the first-person player: movement, camera, flashlight, stamina, footsteps.

var camera: Camera3D
var flashlight: SpotLight3D
var footstep_audio: AudioStreamPlayer

var flashlight_on := true
var stamina: float = GameConfig.STAMINA_MAX
var is_sprinting := false
var battery: float = GameConfig.BATTERY_MAX
var is_recharging := false

## Set to false to freeze the player (quiz, win screen, etc.).
var movement_enabled := true

var gravity: float = 9.8


func _ready() -> void:
	floor_max_angle = deg_to_rad(60.0)

	# Collision capsule
	var col_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	col_shape.shape = capsule
	col_shape.position.y = 0.9
	add_child(col_shape)

	# Camera
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.current = true
	add_child(camera)

	# Flashlight (child of camera so it follows look direction)
	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(1.0, 0.9, 0.6)
	flashlight.light_energy = GameConfig.FLASH_ENERGY_MAX
	flashlight.spot_range = GameConfig.FLASH_RANGE_MAX
	flashlight.spot_angle = GameConfig.FLASH_ANGLE_MAX
	flashlight.shadow_enabled = true
	camera.add_child(flashlight)

	# Footstep audio
	footstep_audio = AudioStreamPlayer.new()
	if ResourceLoader.exists(GameConfig.FOOTSTEP_SOUND_PATH):
		var step_sound: Resource = load(GameConfig.FOOTSTEP_SOUND_PATH)
		if step_sound:
			footstep_audio.stream = step_sound
	footstep_audio.volume_db = -5.0
	add_child(footstep_audio)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

## Apply mouse motion to rotate the player and tilt the camera.
func handle_mouse_motion(relative: Vector2) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	rotate_y(-relative.x * GameConfig.MOUSE_SENSITIVITY)
	camera.rotate_x(-relative.y * GameConfig.MOUSE_SENSITIVITY)
	camera.rotation.x = clamp(camera.rotation.x, -1.4, 1.4)


# ---------------------------------------------------------------------------
# Movement (call from main._physics_process)
# ---------------------------------------------------------------------------

func update_movement(delta: float) -> void:
	if not movement_enabled:
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = GameConfig.JUMP_VELOCITY

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
	_update_stamina(delta, is_moving)

	var speed: float = GameConfig.SPRINT_SPEED if is_sprinting else GameConfig.WALK_SPEED
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	_update_footsteps(is_moving)


func _update_stamina(delta: float, is_moving: bool) -> void:
	var wants_sprint: bool = Input.is_key_pressed(KEY_SHIFT)
	if wants_sprint and is_moving and stamina > GameConfig.STAMINA_MIN_TO_SPRINT:
		is_sprinting = true
		stamina -= GameConfig.STAMINA_DRAIN * delta
		stamina = max(stamina, 0.0)
		if stamina <= 0.0:
			is_sprinting = false
	else:
		is_sprinting = false
		var regen_rate: float = GameConfig.STAMINA_REGEN if not is_moving else GameConfig.STAMINA_REGEN * 0.5
		stamina += regen_rate * delta
		stamina = min(stamina, GameConfig.STAMINA_MAX)


# ---------------------------------------------------------------------------
# Flashlight (call from main._physics_process)
# ---------------------------------------------------------------------------

func update_flashlight(delta: float, uv_mode: bool, has_uv_lamp: bool, strobe_active: bool, has_strobe: bool, strobe_is_real: bool = true) -> void:
	if Input.is_key_pressed(KEY_R):
		is_recharging = true
		flashlight.visible = false
		battery += GameConfig.BATTERY_RECHARGE_SPEED * delta
		battery = min(battery, GameConfig.BATTERY_MAX)
	else:
		is_recharging = false
		if flashlight_on and battery > 0:
			flashlight.visible = true
			# Don't drain battery during UV/strobe (they use their own power)
			var special_mode: bool = (uv_mode and has_uv_lamp) or (strobe_active and has_strobe)
			if not special_mode:
				battery -= GameConfig.BATTERY_DRAIN * delta
				battery = max(battery, 0.0)
		else:
			flashlight.visible = false

	var ratio: float = battery / GameConfig.BATTERY_MAX
	flashlight.light_energy = lerpf(GameConfig.FLASH_ENERGY_MIN, GameConfig.FLASH_ENERGY_MAX, ratio)
	flashlight.spot_range = lerpf(GameConfig.FLASH_RANGE_MIN, GameConfig.FLASH_RANGE_MAX, ratio)
	flashlight.spot_angle = lerpf(GameConfig.FLASH_ANGLE_MIN, GameConfig.FLASH_ANGLE_MAX, ratio)

	# UV mode overrides (force flashlight visible)
	if uv_mode and has_uv_lamp:
		flashlight.visible = true
		flashlight.light_color = Color(0.4, 0.1, 1.0)
		flashlight.spot_range = 12.0
		flashlight.light_energy = 3.0
	else:
		var warm: float = lerpf(0.4, 0.9, ratio)
		flashlight.light_color = Color(1.0, warm, warm * 0.6)

	# Low-battery flicker
	if ratio < 0.15 and ratio > 0 and not is_recharging:
		if randf() < 0.08:
			flashlight.visible = false
		elif flashlight_on:
			flashlight.visible = true

	# Strobe effect overrides everything (force flashlight visible)
	if strobe_active and has_strobe:
		flashlight.visible = true
		if strobe_is_real:
			# Real strobe: clean white blink at 50ms interval, high energy
			var strobe_blink: bool = fmod(Time.get_ticks_msec() / 50.0, 1.0) > 0.5
			flashlight.light_energy = 8.0 if strobe_blink else 0.5
			flashlight.light_color = Color(1.0, 1.0, 1.0)
		else:
			# Fake strobe: erratic sinusoidal yellow-pale buzz, low energy
			var t: float = Time.get_ticks_msec() / 1000.0
			var buzz: float = (sin(t * 12.0) * 0.5 + 0.5) * (sin(t * 37.0) * 0.3 + 0.7)
			flashlight.light_energy = 0.4 + buzz * 0.8
			flashlight.light_color = Color(1.0, 0.95, 0.5)


# ---------------------------------------------------------------------------
# Footsteps
# ---------------------------------------------------------------------------

func _update_footsteps(is_moving: bool) -> void:
	if not footstep_audio:
		return
	var on_ground: bool = is_on_floor()
	if is_moving and on_ground:
		footstep_audio.pitch_scale = 1.4 if is_sprinting else 1.0
		if not footstep_audio.playing:
			footstep_audio.play()
	else:
		if footstep_audio.playing:
			footstep_audio.stop()
