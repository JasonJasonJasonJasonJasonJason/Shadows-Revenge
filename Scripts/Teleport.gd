extends Area3D

@export var teleport_position: Vector3 = Vector3(0.0, 0.265, 33.348)

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name != "Player":
		return

	# Teleport the player
	body.global_transform.origin = teleport_position
