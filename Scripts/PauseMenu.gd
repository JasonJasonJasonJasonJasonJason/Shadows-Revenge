extends Control

# ---------------------------------------------------------
# NODE REFERENCES (MATCH YOUR NEW TREE EXACTLY)
# ---------------------------------------------------------
@onready var panel := $Panel
@onready var options_panel := $OptionsPanel

@onready var resume_button := $Panel/VBoxContainer/Resume
@onready var options_button := $Panel/VBoxContainer/Options
@onready var mainmenu_button := $Panel/VBoxContainer/MainMenu
@onready var quit_button := $Panel/VBoxContainer/Quit

@onready var options_close := $OptionsPanel/Panel/Close
@onready var resolution_button: OptionButton = $OptionsPanel/Panel/HBoxContainer/VBoxContainer3/VBoxContainer/Resolution
@onready var fullscreen_check: CheckBox = $OptionsPanel/Panel/HBoxContainer/VBoxContainer3/VBoxContainer2/Fullscreen

# ---------------------------------------------------------
# RESOLUTION LIST
# ---------------------------------------------------------
var resolutions := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

# ---------------------------------------------------------
# READY
# ---------------------------------------------------------
func _ready():
	visible = false
	options_panel.visible = false

	_populate_resolutions()
	_load_settings()

	resume_button.pressed.connect(_on_resume)
	options_button.pressed.connect(_on_options)
	mainmenu_button.pressed.connect(_on_mainmenu)
	quit_button.pressed.connect(_on_quit)

	options_close.pressed.connect(_on_options_close)
	resolution_button.item_selected.connect(_on_resolution_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)


# ---------------------------------------------------------
# ESC HANDLING
# ---------------------------------------------------------
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if options_panel.visible:
			_on_options_close()
			return

		if visible:
			_on_resume()
		else:
			_show_pause_menu()


func _show_pause_menu():
	visible = true
	get_tree().paused = true


func _on_resume():
	visible = false
	get_tree().paused = false


# ---------------------------------------------------------
# BUTTON HANDLERS
# ---------------------------------------------------------
func _on_options():
	options_panel.visible = true
	panel.visible = false


func _on_options_close():
	options_panel.visible = false
	panel.visible = true


func _on_mainmenu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")


func _on_quit():
	get_tree().quit()


# ---------------------------------------------------------
# RESOLUTION HANDLING
# ---------------------------------------------------------
func _populate_resolutions():
	resolution_button.clear()

	for r in resolutions:
		resolution_button.add_item("%dx%d" % [r.x, r.y])

	var current = DisplayServer.window_get_size()
	for i in range(resolutions.size()):
		if resolutions[i] == current:
			resolution_button.select(i)
			break


func _on_resolution_selected(index):
	var res = resolutions[index]
	DisplayServer.window_set_size(res)
	_save_settings()


# ---------------------------------------------------------
# FULLSCREEN HANDLING
# ---------------------------------------------------------
func _on_fullscreen_toggled(pressed):
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	_save_settings()


# ---------------------------------------------------------
# SAVE / LOAD SETTINGS
# ---------------------------------------------------------
func _save_settings():
	var cfg = ConfigFile.new()
	cfg.set_value("video", "fullscreen", fullscreen_check.button_pressed)
	cfg.set_value("video", "resolution", resolution_button.get_selected_id())
	cfg.save("user://settings.cfg")


func _load_settings():
	var cfg = ConfigFile.new()
	var err = cfg.load("user://settings.cfg")

	if err != OK:
		return

	var fs = cfg.get_value("video", "fullscreen", false)
	fullscreen_check.button_pressed = fs

	if fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	var index = cfg.get_value("video", "resolution", 0)
	if index < resolutions.size():
		var res = resolutions[index]
		DisplayServer.window_set_size(res)
