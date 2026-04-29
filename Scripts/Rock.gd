extends Node3D

@export var fade_speed := 0.25
@export var fade_amount := 0.6   # 0 = opaque, 1 = invisible

@onready var mesh: MeshInstance3D = $Rock_Moss_3
@onready var ray: RayCast3D = $RayCast3D

var fade_tween: Tween = null


func _ready():
	# Duplicate material so we don't modify the original resource
	var mat := mesh.get_active_material(0)
	if mat:
		mesh.set_surface_override_material(0, mat.duplicate())
	else:
		print("WARNING: Mesh has no material")


func _physics_process(_delta):
	if ray.is_colliding():
		var col = ray.get_collider()
		if col and col.is_in_group("Player"):
			_fade_to(fade_amount)
			return

	# No player behind → fade back in
	_fade_to(0.0)


func _fade_to(target: float):
	if fade_tween:
		fade_tween.kill()

	fade_tween = get_tree().create_tween()
	fade_tween.tween_method(
		_set_alpha,
		_get_alpha(),
		target,
		fade_speed
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_alpha(value: float):
	var mat := mesh.get_active_material(0)
	if mat and mat is BaseMaterial3D:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		var c: Color = mat.albedo_color   # <-- FIXED
		c.a = 1.0 - value
		mat.albedo_color = c



func _get_alpha() -> float:
	var mat := mesh.get_active_material(0)
	if mat and mat is BaseMaterial3D:
		return 1.0 - mat.albedo_color.a
	return 0.0
