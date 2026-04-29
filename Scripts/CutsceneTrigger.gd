extends Area3D

@export var scene_name := ""
var triggered := false


func _ready():
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):
	if triggered:
		return

	if body.is_in_group("Player"):
		triggered = true
		CutsceneManager.load_scene(scene_name)
