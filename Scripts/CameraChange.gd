extends Area3D

@export var new_camera_offset: Vector3 = Vector3(-0.827, 0.168, -0.005)
@export var transition_time: float = 0.3

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name != "Player":
		return

	var cam: Camera3D = body.find_child("PlayerCamera", true, false)
	if not cam:
		return

	# Tween the camera to the new offset (actual movement)
	var tween := create_tween()
	tween.tween_property(
		cam,
		"transform:origin",
		new_camera_offset,
		transition_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Update the player's default offset FOREVER
	body.set_camera_offset(new_camera_offset)
