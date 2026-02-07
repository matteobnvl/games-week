extends CharacterBody3D

# --- Mouvement ---
const SPEED := 5.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.002

# --- Références ---
@onready var camera: Camera3D = $Camera3D
@onready var flashlight: SpotLight3D = $Camera3D/SpotLight3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var flashlight_on := true


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	print("🎮 Player ready, souris capturée")


func _unhandled_input(event: InputEvent):
	# Rotation caméra avec la souris
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -1.4, 1.4)
	
	# Échap : libérer/capturer la souris
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# F : toggle lampe torche
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		flashlight_on = !flashlight_on
		flashlight.visible = flashlight_on
		print("🔦 Lampe : ", "ON" if flashlight_on else "OFF")


func _physics_process(delta: float):
	# Gravité
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Saut
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Direction de mouvement (ZQSD + WASD)
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
	
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	move_and_slide()
	
	# Debug position (toutes les 60 frames)
	if Engine.get_physics_frames() % 60 == 0 and (velocity.x != 0 or velocity.z != 0):
		print("📍 Position : ", global_position)
