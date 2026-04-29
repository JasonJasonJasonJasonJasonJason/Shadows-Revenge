extends Node3D

# ---------------------------------------------------------
# NODE REFERENCES (MATCH YOUR SCENE EXACTLY)
# ---------------------------------------------------------
@onready var ui := $UI

@onready var margin_container := $UI/MarginContainer
@onready var title1 := $UI/Title1
@onready var title2 := $UI/Title2

@onready var options_panel := $UI/OptionsPanel
@onready var credits_panel := $UI/Credits

@onready var resolution_button: OptionButton = $UI/OptionsPanel/HBoxContainer/VBoxContainer3/VBoxContainer/Resolution
@onready var fullscreen_check: CheckBox = $UI/OptionsPanel/HBoxContainer/VBoxContainer3/VBoxContainer2/Fullscreen

# Buttons
@onready var start_button = $UI/MarginContainer/VBoxContainer/Start
@onready var options_button = $UI/MarginContainer/VBoxContainer/Options
@onready var credits_button = $UI/MarginContainer/VBoxContainer/Credits
@onready var quit_button = $UI/MarginContainer/VBoxContainer/Quit

@onready var credits_label1 = $UI/Credits/Label
@onready var credits_label2 = $UI/Credits/Label2
@onready var credits_next = $UI/Credits/Next
@onready var credits_prev = $UI/Credits/Previous
@onready var credits_close = $UI/Credits/Close
@onready var options_close = $UI/OptionsPanel/Close

@onready var sfx_player: AudioStreamPlayer3D = $WorldRoot/Camera3D/AudioStreamPlayer3D

var hover_sfx: AudioStream = preload("res://Assets/SFX/UI/Minimalist4.wav")
var click_sfx: AudioStream = preload("res://Assets/SFX/UI/Minimalist10.wav")

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
	options_panel.visible = false
	credits_panel.visible = false

	_load_settings()
	_populate_resolutions()
	_connect_buttons()


# ---------------------------------------------------------
# CONNECT BUTTONS
# ---------------------------------------------------------
func _connect_buttons():
	# Main menu buttons
	add_sfx_to_button(start_button)
	add_sfx_to_button(options_button)
	add_sfx_to_button(credits_button)
	add_sfx_to_button(quit_button)

	# Credits buttons
	add_sfx_to_button(credits_next)
	add_sfx_to_button(credits_prev)
	add_sfx_to_button(credits_close)

	# OptionsPanel buttons
	add_sfx_to_button(options_close)
	add_sfx_to_button(resolution_button)
	add_sfx_to_button(fullscreen_check)


	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_on_options_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	credits_close.pressed.connect(_on_credits_close)
	credits_next.pressed.connect(_on_credits_next_pressed)
	credits_prev.pressed.connect(_on_credits_prev_pressed)
	options_close.pressed.connect(_on_options_close)

	resolution_button.item_selected.connect(_on_resolution_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)


# ---------------------------------------------------------
# BUTTON HANDLERS
# ---------------------------------------------------------
func _on_start_pressed():
	get_tree().change_scene_to_file("res://Scenes/Debug.tscn")


func _on_options_pressed():
	options_panel.visible = true

	# Hide main menu UI
	margin_container.visible = false
	title1.visible = false
	title2.visible = false


func _on_credits_pressed():
	credits_panel.visible = true

	# Show page 1
	credits_label1.visible = true
	credits_label2.visible = false
	credits_next.visible = true
	credits_prev.visible = false

	# Hide main menu UI
	margin_container.visible = false
	title1.visible = false
	title2.visible = false

func _on_credits_next_pressed():
	credits_label1.visible = false
	credits_label2.visible = true

	credits_next.visible = false
	credits_prev.visible = true

func _on_credits_prev_pressed():
	credits_label1.visible = true
	credits_label2.visible = false

	credits_next.visible = true
	credits_prev.visible = false

func _on_quit_pressed():
	get_tree().quit()


func _on_credits_close():
	credits_panel.visible = false

	# Restore main menu UI
	margin_container.visible = true
	title1.visible = true
	title2.visible = true

func _on_options_close():
	options_panel.visible = false

	# Restore main menu UI
	margin_container.visible = true
	title1.visible = true
	title2.visible = true


# ---------------------------------------------------------
# RESOLUTION HANDLING
# ---------------------------------------------------------
func _populate_resolutions():
	resolution_button.clear()

	for r in resolutions:
		resolution_button.add_item("%dx%d" % [r.x, r.y])

	# Select current resolution
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

	# Fullscreen
	var fs = cfg.get_value("video", "fullscreen", false)
	fullscreen_check.button_pressed = fs

	if fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# Resolution
	var index = cfg.get_value("video", "resolution", 0)
	if index < resolutions.size():
		var res = resolutions[index]
		DisplayServer.window_set_size(res)

func play_hover():
	sfx_player.stream = hover_sfx
	sfx_player.play()

func play_click():
	sfx_player.stream = click_sfx
	sfx_player.play()

func add_sfx_to_button(btn: BaseButton):
	btn.mouse_entered.connect(play_hover)
	btn.pressed.connect(play_click)
