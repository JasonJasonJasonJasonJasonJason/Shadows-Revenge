extends Control

@export var follow_target: Node3D
@export var y_offset := 2.0
@export var letter_delay := 0.03
@export var lag_strength := 0.15
@export var pop_scale := 1.15

@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/Label

var type_sound: AudioStreamPlayer3D = null
var narrator_sounds: Array[AudioStream] = []

var full_text := ""
var typing := false
var smoothed_pos := Vector2.ZERO
var hide_tween: Tween = null


# ---------------------------------------------------------
#  UNIVERSAL FINDER — FINDS "TypeSoundNarrator" ANYWHERE
# ---------------------------------------------------------
func _find_type_sound():
	var root = get_tree().current_scene
	return root.find_child("TypeSoundNarrator", true, false)


func _ready():
	panel.visible = false
	panel.scale = Vector2.ZERO
	label.autowrap_mode = TextServer.AUTOWRAP_WORD

	# Load narrator voice clips (7–18)
	for i in range(7, 19):
		var path = "res://Assets/SFX/Voices/Narrator/SFX_Penv%d.wav" % i
		var stream = load(path)
		if stream:
			narrator_sounds.append(stream)

	# Auto‑find TypeSound anywhere in the scene
	type_sound = _find_type_sound()

	if type_sound == null:
		print("ERROR: Narrator could not find TypeSound node!")
	else:
		print("Narrator: TypeSound found at:", type_sound.get_path())


func _process(_delta):
	if not is_inside_tree():
		return

	if not follow_target:
		return

	var cam := get_viewport().get_camera_3d()
	if not cam:
		return

	var target_pos = cam.unproject_position(
		follow_target.global_transform.origin + Vector3.UP * y_offset
	)

	smoothed_pos = smoothed_pos.lerp(target_pos, lag_strength)
	panel.position = smoothed_pos
	panel.reset_size()


func show_text(text: String):
	if not is_inside_tree():
		return

	# Kill old hide tween
	if hide_tween and hide_tween.is_running():
		hide_tween.kill()

	full_text = text
	label.text = ""
	panel.visible = true
	panel.scale = Vector2.ZERO

	typing = true

	var tween = get_tree().create_tween()
	tween.tween_property(panel, "scale", Vector2(pop_scale, pop_scale), 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.08)

	_start_typing()


func _start_typing():
	for i in full_text.length():
		if not typing:
			break

		if not is_inside_tree():
			return

		label.text = full_text.substr(0, i + 1)
		panel.reset_size()

		# Play narrator voice sound (skip spaces)
		var letter = full_text[i]
		if letter != " " and narrator_sounds.size() > 0 and type_sound:
			var sfx = narrator_sounds[randi() % narrator_sounds.size()]
			type_sound.stream = sfx
			type_sound.pitch_scale = randf_range(0.95, 1.05)
			type_sound.stop()
			type_sound.play()

		await get_tree().create_timer(letter_delay).timeout

	typing = false

	if is_inside_tree():
		DialogueManager.notify_typing_finished()


func hide_now():
	if not is_inside_tree():
		return

	if hide_tween and hide_tween.is_running():
		hide_tween.kill()

	hide_tween = get_tree().create_tween()
	hide_tween.tween_property(panel, "scale", Vector2(0.0, 0.0), 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	hide_tween.finished.connect(func():
		if is_inside_tree():
			panel.visible = false
	)

func is_typing() -> bool:
	return typing
