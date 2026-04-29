extends Node3D

@export var follow_target: Node3D
@export var y_offset := 2.0
@export var letter_delay := 0.03
@export var lag_strength := 0.15
@export var pop_scale := 1.15

@onready var label3d: Label3D = $Label3D
@onready var audio: AudioStreamPlayer3D = $AudioStreamPlayer3D

var full_text := ""
var typing := false
var smoothed_pos := Vector3.ZERO
var hide_tween: Tween = null
var shadow_voice: AudioStream = null


func _ready():
	label3d.text = ""
	label3d.visible = false

	# Load the ONE Shadow voice file
	shadow_voice = load("res://Assets/SFX/Voices/Shadow/SFX_SingleLowONoReverbv1.wav")

	if shadow_voice == null:
		print("ERROR: Shadow voice file missing!")
	else:
		print("Shadow voice loaded:", shadow_voice)


func _process(_delta):
	if not is_inside_tree():
		return
	if not follow_target:
		return

	var target = follow_target.global_transform.origin + Vector3.UP * y_offset
	smoothed_pos = smoothed_pos.lerp(target, lag_strength)
	global_transform.origin = smoothed_pos


func show_text(text: String):
	if not is_inside_tree():
		return

	if hide_tween and hide_tween.is_running():
		hide_tween.kill()

	full_text = text
	label3d.text = ""
	label3d.visible = true
	typing = true

	_start_typing()


func _start_typing():
	for i in full_text.length():
		if not typing:
			break
		if not is_inside_tree():
			return

		label3d.text = full_text.substr(0, i + 1)

		var letter = full_text[i]
		if letter != " " and shadow_voice:
			audio.stream = shadow_voice
			audio.pitch_scale = randf_range(0.95, 1.05)
			audio.stop()
			audio.play()

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
	hide_tween.tween_property(label3d, "modulate:a", 0.0, 0.15)

	hide_tween.finished.connect(func():
		if is_inside_tree():
			label3d.visible = false
			label3d.modulate.a = 1.0
	)


func is_typing() -> bool:
	return typing
