extends Area3D

func _on_body_entered(body):
	if body.is_in_group("Player"):
		body.disable_shadow_camera = true
		print("DEBUG: Camera disabled")
