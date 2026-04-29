extends Node

var bubble_player_ref: Control = null
var narrator_ref: Control = null
var shadow_ref: Node = null        # ⭐ NEW
var proceed_label: Label = null
var proceed_tween: Tween = null

var scene_lines: Array[String] = []
var index := 0
var has_active_bubble := false
signal dialogue_finished
@warning_ignore("unused_signal")
signal command_done
var can_advance: bool = false


func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	_resolve_ui()


# ---------------------------------------------------------
#  FIND UI NODES UNDER PLAYER
# ---------------------------------------------------------
func _resolve_ui():
	var root_scene = get_tree().current_scene
	if root_scene == null:
		return

	var player = root_scene.get_node_or_null("Player")
	if player == null:
		return

	var ui = player.get_node_or_null("UI")
	if ui == null:
		return

	bubble_player_ref = ui.get_node_or_null("PlayerBubble")
	narrator_ref = ui.get_node_or_null("NarratorBox")
	proceed_label = ui.get_node_or_null("Proceed")
	shadow_ref = root_scene.find_child("ShadowText", true, false)

	if proceed_label:
		proceed_label.visible = false


# ---------------------------------------------------------
#  PROCEED LABEL CONTROL
# ---------------------------------------------------------
func _show_proceed():
	if not proceed_label:
		return

	proceed_label.visible = true
	proceed_label.modulate.a = 0.0

	if proceed_tween and proceed_tween.is_running():
		proceed_tween.kill()

	proceed_tween = get_tree().create_tween()
	proceed_tween.tween_property(
		proceed_label,
		"modulate:a",
		1.0,
		0.25
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	proceed_tween.finished.connect(func():
		_start_proceed_flash())
	can_advance = true


func _start_proceed_flash():
	if not proceed_label:
		return

	if proceed_tween and proceed_tween.is_running():
		proceed_tween.kill()

	proceed_tween = get_tree().create_tween().set_loops()
	proceed_tween.tween_property(proceed_label, "modulate:a", 0.3, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	proceed_tween.tween_property(proceed_label, "modulate:a", 1.0, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _hide_proceed():
	if not proceed_label:
		return

	proceed_label.visible = false

	if proceed_tween and proceed_tween.is_running():
		proceed_tween.kill()

	proceed_label.modulate.a = 1.0
	can_advance = false


# ---------------------------------------------------------
#  LOAD DIALOGUE SCENE BLOCK
# ---------------------------------------------------------
func load_scene(path: String, scene_name: String):
	scene_lines.clear()
	index = 0
	has_active_bubble = false
	_hide_proceed()

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Could not open dialogue file: " + path)
		return

	var inside_scene := false

	while not file.eof_reached():
		var line := file.get_line().strip_edges()

		if line == "{" + scene_name + "}":
			inside_scene = true
			continue

		if line == "{/" + scene_name + "}":
			inside_scene = false
			break

		if inside_scene and line != "":
			scene_lines.append(line)

	file.close()


# ---------------------------------------------------------
#  ADVANCE DIALOGUE
# ---------------------------------------------------------
func next():
	_resolve_ui()
	_hide_proceed()

	# ---------------------------------------------------------
	#  COMMAND PARSING
	# ---------------------------------------------------------

	# Only hide if bubble exists AND typing is finished
	if has_active_bubble:
		if narrator_ref and not narrator_ref.is_typing():
			narrator_ref.hide_now()

		if bubble_player_ref and not bubble_player_ref.is_typing():
			bubble_player_ref.hide_now()

		if shadow_ref and not shadow_ref.is_typing():   # ⭐ NEW
			shadow_ref.hide_now()

	if index >= scene_lines.size():
		emit_signal("dialogue_finished")
		return

	var line := scene_lines[index]
	index += 1
	
	if line.begins_with("[") and line.ends_with("]"):
		var awaitable = _process_command_internal(line)
		await awaitable
		next()
		return



	var parts := line.split(":", false, 1)
	if parts.size() < 2:
		return

	var speaker := parts[0].strip_edges()
	var text := parts[1].strip_edges()

	if speaker == "Narrator":
		if narrator_ref:
			narrator_ref.show_text(text)
			has_active_bubble = true

	elif speaker == "Character" or speaker == "Player":
		if bubble_player_ref:
			bubble_player_ref.show_text(text)
			has_active_bubble = true

	elif speaker == "Shadow":   # ⭐ NEW
		if shadow_ref:
			shadow_ref.show_text(text)
			has_active_bubble = true


# ---------------------------------------------------------
#  INPUT HANDLING
# ---------------------------------------------------------
func _input(event):
	if event.is_action_pressed("dialogue_next"):
		if can_advance:
			next()

# ---------------------------------------------------------
#  CALLED BY BUBBLES WHEN TYPING FINISHES
# ---------------------------------------------------------
func notify_typing_finished():
	_show_proceed()

func _process_command(cmd: String) -> void:
	await _process_command_internal(cmd)

func _process_command_internal(cmd: String):
	var inner := cmd.substr(1, cmd.length() - 2).strip_edges()

	var comma_index := inner.find(",")
	var command := ""
	var data := ""

	if comma_index == -1:
		command = inner
	else:
		command = inner.substr(0, comma_index).strip_edges()
		data = inner.substr(comma_index + 1).strip_edges()
	
	print(command)
	print(data)
	
	# WAIT ------------------------------------
	if command == "Wait":
		var seconds := float(data)
		return get_tree().create_timer(seconds).timeout

	# MOVE ------------------------------------
	if command == "Move":
		data = data.trim_prefix("(").trim_suffix(")")
		var xyz := data.split(",", false)

		if xyz.size() == 3:
			var current_pos = CutsceneManager.get_camera_position()

			var x_str = xyz[0].strip_edges()
			var y_str = xyz[1].strip_edges()
			var z_str = xyz[2].strip_edges()

			var x = current_pos.x if x_str == "x" else float(x_str)
			var y = current_pos.y if y_str == "y" else float(y_str)
			var z = current_pos.z if z_str == "z" else float(z_str)

			CutsceneManager.save_camera_position()
			CutsceneManager.command_move(Vector3(x, y, z))

		return get_tree().create_timer(0).timeout

	if command == "MoveSmooth":
		var parts = data.split(")", false)
		var xyz_str = parts[0].trim_prefix("(")
		var duration_str = parts[1].trim_prefix(",").strip_edges()

		var duration = float(duration_str)
		var xyz = xyz_str.split(",", false)

		if xyz.size() == 3:
			var current_pos = CutsceneManager.get_camera_position()

			var x_str = xyz[0].strip_edges()
			var y_str = xyz[1].strip_edges()
			var z_str = xyz[2].strip_edges()

			var x = current_pos.x if x_str == "x" else float(x_str)
			var y = current_pos.y if y_str == "y" else float(y_str)
			var z = current_pos.z if z_str == "z" else float(z_str)

			CutsceneManager.save_camera_position()
			return CutsceneManager.command_move_smooth(Vector3(x, y, z), duration)

		return get_tree().create_timer(0).timeout

	# FOLLOW ----------------------------------
	if command == "Follow":
		CutsceneManager.command_follow(data)
		return get_tree().create_timer(0).timeout

	if command == "Reset":
		CutsceneManager.command_reset_camera()
		return get_tree().create_timer(0).timeout

	if command == "SaveCamera":
		CutsceneManager.save_camera_position()
		return get_tree().create_timer(0).timeout
	
	if command == "StopFollow":
		CutsceneManager.command_stop_follow()
		return get_tree().create_timer(0).timeout
	
	if command == "ShadowMoveZ":
		print(command)
		print(data)
		var amount = float(data)
		return CutsceneManager.command_shadow_move_z(amount)
		
	if command == "CutToPlayer":
		return CutsceneManager.command_cut_to_player()
		
	if command == "CutToNode":
		return CutsceneManager.command_cut_to_node(data)
	
	if command == "GivePowers":
		return CutsceneManager.command_give_powers()

	if command == "FlipPlayer":
		return CutsceneManager.command_flip_player()

	if command == "ShowTutorial":
		return CutsceneManager.command_show_tutorial(data)

	if command == "HideTutorial":
		return CutsceneManager.command_hide_tutorial(data)

	if command == "ShadowMoveY":
		return CutsceneManager.command_shadow_move_y(float(data))
	
	if command == "CameraPan":
		var cleaned := data.replace("(", "").replace(")", "")
		var parts := cleaned.split(",")
		return CutsceneManager.command_camera_pan(
			float(parts[0]),
			float(parts[1]),
			float(parts[2])
		)
	
	if command == "CameraShake":
		return CutsceneManager.command_camera_shake(float(data))

	if command == "RunWhileText":
		return _run_while_text(data)
		
	if command == "FadeToBlack":
		return CutsceneManager.FadeToBlack(float(data))

	if command == "FadeOut":
		return CutsceneManager.FadeOut(float(data))
	
	if command == "MainMenu":
		MainMenu()
		return true

	# DEFAULT ---------------------------------
	return get_tree().create_timer(0).timeout


func _run_while_text(inner_cmd: String):
	# Start the inner command WITHOUT awaiting it
	print(inner_cmd)
	_process_command_internal(inner_cmd)

	# Return an instant awaitable so the text system controls the wait
	return get_tree().create_timer(0).timeout

func MainMenu():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
