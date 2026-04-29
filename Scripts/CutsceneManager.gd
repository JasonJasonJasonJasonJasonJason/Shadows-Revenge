extends Node

@export var dialogue_file: String = "res://Assets/Dialogue/Script.txt"

var player: Node = null
var player_cam: Camera3D = null
var cutscene_cam: Camera3D = null
var letterbox_top: ColorRect = null
var letterbox_bottom: ColorRect = null
var input_locked: bool = false
var follow_target: Node3D = null
var follow_enabled: bool = false
var last_camera_position: Vector3
var shadow_node: Node3D = null
var powers_enabled: bool = false
var player_flipped: bool = false
var fade_rect: ColorRect = null

var cutscene_active: bool = false

func _ready():
	set_process(true)
	_resolve_nodes()

# ---------------------------------------------------------
#  FIND NODES IN THE CURRENT SCENE
# ---------------------------------------------------------
func _resolve_nodes():
	var scene = get_tree().current_scene
	if scene == null:
		return

	player = scene.find_child("Player", true, false)
	if player:
		player_cam = player.find_child("PlayerCamera", true, false)
		fade_rect = player.find_child("Fade", true, false)

	cutscene_cam = scene.find_child("CutsceneCamera", true, false)

	letterbox_top = scene.find_child("LetterboxTop", true, false)
	letterbox_bottom = scene.find_child("LetterboxBottom", true, false)
	shadow_node = scene.find_child("ShadowText", true, false)
	print("Shadow Node:", shadow_node)


# ---------------------------------------------------------
#  PUBLIC API — CALL THIS FROM TRIGGERS
# ---------------------------------------------------------
func load_scene(scene_name: String):
	if cutscene_active:
		return

	_resolve_nodes()
	cutscene_active = true

	_disable_all_input_except_dialogue()
	_fade_letterbox_in()
	_switch_to_cutscene_camera()
	force_player_idle()
	hide_all_tutorials()

	DialogueManager.load_scene(dialogue_file, scene_name)
	DialogueManager.next()

	DialogueManager.connect("dialogue_finished", Callable(self, "_on_cutscene_end"), CONNECT_ONE_SHOT)


# ---------------------------------------------------------
#  CUTSCENE END
# ---------------------------------------------------------
func _on_cutscene_end():
	_switch_to_player_camera()
	_fade_letterbox_out()
	_enable_all_input()
	
	follow_enabled = false
	follow_target = null
	cutscene_active = false


# ---------------------------------------------------------
#  CAMERA CONTROL
# ---------------------------------------------------------
func _switch_to_cutscene_camera():
	if cutscene_cam:
		cutscene_cam.current = true

	if player_cam:
		player_cam.current = false


func _switch_to_player_camera():
	if player_cam:
		player_cam.current = true

	if cutscene_cam:
		cutscene_cam.current = false


# ---------------------------------------------------------
#  LETTERBOX FADE (ALPHA)
# ---------------------------------------------------------
func _fade_letterbox_in():
	if not letterbox_top or not letterbox_bottom:
		return

	var tween = get_tree().create_tween()

	# Run both tweens in parallel
	tween.parallel().tween_property(letterbox_top, "self_modulate:a", 1.0, 0.4)
	tween.parallel().tween_property(letterbox_bottom, "self_modulate:a", 1.0, 0.4)



func _fade_letterbox_out():
	if not letterbox_top or not letterbox_bottom:
		return

	var tween = get_tree().create_tween()

	tween.parallel().tween_property(letterbox_top, "self_modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(letterbox_bottom, "self_modulate:a", 0.0, 0.4)


# ---------------------------------------------------------
#  INPUT LOCKING
# ---------------------------------------------------------
func _disable_all_input_except_dialogue():
	input_locked = true

func _enable_all_input():
	input_locked = false

func force_player_idle():
	if not player:
		return

	var anim: AnimatedSprite3D = player.find_child("AnimatedSprite3D", true, false)
	print(anim)
	if anim:
		anim.play("Idle")

# ---------------------------------------------------------
#  COMMAND: MOVE CAMERA TO POSITION
# ---------------------------------------------------------
func command_move(target_pos: Vector3):
	if not cutscene_cam:
		return

	var t := cutscene_cam.global_transform
	t.origin = target_pos
	cutscene_cam.global_transform = t


func command_move_smooth(target: Vector3, duration: float):
	var tween = create_tween()
	tween.tween_property(cutscene_cam, "global_transform:origin", target, duration)
	return tween.finished

# ---------------------------------------------------------
#  COMMAND: FOLLOW NODE
# ---------------------------------------------------------
func command_follow(node_name: String):
	var scene = get_tree().current_scene
	if not scene:
		return

	var target = scene.find_child(node_name, true, false)
	if not target:
		print("CutsceneManager: FOLLOW target not found:", node_name)
		return

	follow_target = target
	follow_enabled = true
	
func _process(_delta):
	if follow_enabled and follow_target and cutscene_cam:
		var cam_pos = cutscene_cam.global_transform.origin
		var target_pos = follow_target.global_transform.origin

		# Keep the camera's current X position
		target_pos.x = cam_pos.x

		# Smooth follow on Y and Z only
		var new_pos = cam_pos.lerp(target_pos, 0.1)

		var t = cutscene_cam.global_transform
		t.origin = new_pos
		cutscene_cam.global_transform = t

func get_camera_position() -> Vector3:
	return cutscene_cam.global_transform.origin

func save_camera_position():
	if cutscene_cam:
		last_camera_position = cutscene_cam.global_transform.origin

func command_reset_camera():
	if not cutscene_cam:
		return

	var t := cutscene_cam.global_transform
	t.origin = last_camera_position
	cutscene_cam.global_transform = t

func command_stop_follow():
	follow_target = null
	follow_enabled = false
	
func command_shadow_move_z(z_value: float):
	if not shadow_node:
		return get_tree().create_timer(0).timeout

	var pos = shadow_node.global_transform.origin
	pos.z = z_value

	var t := shadow_node.global_transform
	t.origin = pos
	shadow_node.global_transform = t

	return get_tree().create_timer(0).timeout
	
func command_cut_to_player():
	if not player_cam or not cutscene_cam:
		return get_tree().create_timer(0).timeout

	# Copy full transform (position + rotation)
	cutscene_cam.global_transform = player_cam.global_transform

	return get_tree().create_timer(0).timeout

func command_cut_to_node(node_name: String):
	if not cutscene_cam:
		return get_tree().create_timer(0).timeout

	var scene = get_tree().current_scene
	var target: Node3D = scene.find_child(node_name, true, false)

	if not target:
		print("CutToNode: Target not found:", node_name)
		return get_tree().create_timer(0).timeout

	var cam_pos = cutscene_cam.global_transform.origin
	var target_pos = target.global_transform.origin

	# Keep X the same initially
	# Copy Y and Z
	cam_pos.y = target_pos.y
	cam_pos.z = target_pos.z

	# If Y is exactly 0, apply +0.5 offset
	if cam_pos.y == 0:
		cam_pos.y += 0.5

	# If X is too close to the target, push back by -0.5
	if abs(cam_pos.x - target_pos.x) < 0.7:
		cam_pos.x -= 0.7

	var t := cutscene_cam.global_transform
	t.origin = cam_pos
	cutscene_cam.global_transform = t

	return get_tree().create_timer(0).timeout

func command_give_powers():
	powers_enabled = true
	print("Powers Enabled!")
	return get_tree().create_timer(0).timeout

func command_flip_player():
	if not player:
		return get_tree().create_timer(0).timeout

	var sprite: AnimatedSprite3D = player.find_child("AnimatedSprite3D", true, false)
	if not sprite:
		return get_tree().create_timer(0).timeout

	if player_flipped:
		sprite.scale.x = abs(sprite.scale.x)
		player_flipped = false
	else:
		sprite.scale.x = -abs(sprite.scale.x)
		player_flipped = true

	return get_tree().create_timer(0).timeout

func command_show_tutorial(label_name: String):
	var scene = get_tree().current_scene
	var label: Label3D = scene.find_child(label_name, true, false)

	if label:
		label.visible = true

	return get_tree().create_timer(0).timeout

func command_hide_tutorial(label_name: String):
	var scene = get_tree().current_scene
	var label: Label3D = scene.find_child(label_name, true, false)

	if label:
		label.visible = false

	return get_tree().create_timer(0).timeout

func hide_all_tutorials():
	var scene = get_tree().current_scene
	var tutorials = scene.find_child("Tutorials", true, false)

	if tutorials:
		for child in tutorials.get_children():
			if child is Label3D:
				child.visible = false

func command_shadow_move_y(y_value: float):
	if not shadow_node:
		return get_tree().create_timer(0).timeout

	var pos := shadow_node.global_transform.origin
	pos.y = y_value

	var t := shadow_node.global_transform
	t.origin = pos
	shadow_node.global_transform = t

	return get_tree().create_timer(0).timeout

func command_camera_pan(z_start: float, z_end: float, duration: float):
	if not cutscene_cam:
		return get_tree().create_timer(0).timeout

	var tween := create_tween()
	tween.tween_property(
		cutscene_cam,
		"global_transform:origin:z",
		z_end,
		duration
	).from(z_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	return tween.finished

func command_camera_shake(intensity: float):
	if not cutscene_cam:
		return get_tree().create_timer(0).timeout

	var tween := create_tween()
	var original_pos := cutscene_cam.global_transform.origin

	for i in range(6):
		var offset := Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(
			cutscene_cam,
			"global_transform:origin",
			original_pos + offset,
			0.05
		)

	tween.tween_property(
		cutscene_cam,
		"global_transform:origin",
		original_pos,
		0.05
	)

	return tween.finished
	
func FadeToBlack(duration := 0.5):
	if not fade_rect:
		return get_tree().create_timer(0).timeout

	var tween := create_tween()
	tween.tween_property(
		fade_rect,
		"self_modulate:a",
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	return tween.finished

func FadeOut(duration := 0.5):
	if not fade_rect:
		return get_tree().create_timer(0).timeout

	var tween := create_tween()
	tween.tween_property(
		fade_rect,
		"self_modulate:a",
		0.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	return tween.finished
