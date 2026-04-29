extends Camera3D

var start_z := -8.75
var end_z := 9.75
var scroll_time := 30   # how long one full scroll takes

func _ready():
	global_position.z = start_z
	_start_scroll()


func _start_scroll():
	var tween := create_tween().set_loops()  # infinite loop

	# Move from start → end
	tween.tween_property(self, "global_position:z", end_z, scroll_time)

	# Instantly teleport back to start
	tween.tween_callback(func():
		global_position.z = start_z
	)
