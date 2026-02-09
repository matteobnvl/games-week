class_name Door
## Data class representing a single door with its scene nodes and state.

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


## Toggle the door between open and closed states.
func toggle() -> void:
	if is_animating:
		return
	is_animating = true
	if is_open:
		target_angle = 0.0
		is_open = false
	else:
		target_angle = 90.0
		is_open = true
	if audio and audio.stream:
		audio.play()


## Animate the door rotation each frame.
func animate(delta: float) -> void:
	if not is_animating:
		return
	var diff: float = target_angle - current_angle
	if absf(diff) < 0.5:
		current_angle = target_angle
		is_animating = false
	else:
		current_angle += signf(diff) * GameConfig.DOOR_OPEN_SPEED * delta * 60.0
	pivot.rotation_degrees.y = current_angle
