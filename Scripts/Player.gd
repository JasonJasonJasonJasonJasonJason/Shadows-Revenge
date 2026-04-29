extends CharacterBody3D

@export var walk_speed := 3
@export var jump_force := 5
@export var gravity := -24.0

@export var dash_speed := 12
@export var dash_duration := 0.15
@export var dash_cooldown := 0.35

var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := 0.0

var is_falling_through := false
var disable_shadow_camera := false

# Raycast-based detection
var shadow_hit : StaticBody3D = null
var rise_hit : StaticBody3D = null

# NEW: extra hits for reverse-style behavior
var shadow_rise_hit : StaticBody3D = null
var rise_fall_hit : StaticBody3D = null

# Camera shift + zoom-out
@onready var cam: Camera3D = $PlayerCamera
var cam_default_offset := Vector3.ZERO
var cam_down_offset := Vector3(-0.6, 0.4, 0.0)
var cam_shadow_offset := Vector3(-2.5, 1.2, 0.0)

# Foot light + pulsing
@onready var foot_light: SpotLight3D = $Ability
var light_on_energy := 5
var light_off_energy := 0.0
var light_tween : Tween = null
var pulse_tween : Tween = null

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var shadow_check: RayCast3D = $ShadowCheck
@onready var ground_ray: RayCast3D = $ShadowCheck
@onready var footstep_player: AudioStreamPlayer3D = $Footsteps
var current_surface := "None"
var footstep_sounds: Array[String] = []
var step_distance := 1
var distance_accum := 0.0
var last_position := Vector3.ZERO

func _ready():
	cam_default_offset = cam.transform.origin
	foot_light.light_energy = 0.0
	last_position = global_position


func _physics_process(delta):
	if CutsceneManager.input_locked:
		velocity = Vector3.ZERO
		move_and_slide()
		if shadow_hit and CutsceneManager.powers_enabled:
			_set_light_energy(light_on_energy)
			_start_light_pulse()
		return

	# --- RAYCAST DETECTION ---
	_update_shadow_from_raycast()
	_update_rise_from_raycast()
	_update_shadow_rise_from_raycast()
	_update_rise_fall_from_raycast()
	_update_surface_from_raycast()
	
	var moved := global_position.distance_to(last_position)
	distance_accum += moved

	if distance_accum >= step_distance and is_on_floor():
		play_footstep()
		distance_accum = 0.0

	last_position = global_position

	if CutsceneManager.powers_enabled:
		light_on_energy = 5

	# --- LIGHT POWER FEEDBACK ---
	if CutsceneManager.powers_enabled:
		if shadow_hit or rise_hit:
			_set_light_energy(light_on_energy)
			_start_light_pulse()
		else:
			_set_light_energy(light_off_energy)
			_stop_light_pulse()

	# FALLTHROUGH (Shadow)
	if CutsceneManager.powers_enabled:
		if Input.is_action_just_pressed("down") and is_on_floor() and shadow_hit:
			if not disable_shadow_camera:
				_camera_shift_down()
				_camera_zoom_shadow()
			_start_fallthrough(shadow_hit)

	# RISE (Rise)
	if CutsceneManager.powers_enabled:
		if Input.is_action_just_pressed("up") and is_on_floor() and rise_hit:
			_camera_shift_down()
			_start_rise(rise_hit)
			_camera_zoom_reset()

	# Dash cooldown
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	# DASH ACTIVE
	if is_dashing:
		dash_timer -= delta
		velocity.z = dash_direction * dash_speed
		velocity.y = 0

		if dash_timer <= 0:
			is_dashing = false
			dash_cooldown_timer = dash_cooldown

		move_and_slide()
		return

	# NORMAL MOVEMENT
	var input_dir := Input.get_axis("move_left", "move_right")
	velocity.z = input_dir * walk_speed

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_force

	# DASH INPUT
	if Input.is_action_just_pressed("dash") and input_dir != 0 and dash_cooldown_timer <= 0:
		_start_dash(input_dir)

	move_and_slide()

	# Sprite flipping
	if input_dir != 0:
		sprite.flip_h = input_dir < 0

	# Animation logic
	_update_animation(input_dir)


# ---------------------------------------------------------
# CAMERA SHIFT + ZOOM
# ---------------------------------------------------------

func _camera_shift_down():
	var tween = create_tween()
	tween.tween_property(
		cam,
		"transform:origin",
		cam_default_offset + cam_down_offset,
		0.15
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _camera_zoom_shadow():
	var tween = create_tween()
	tween.tween_property(
		cam,
		"transform:origin",
		cam_shadow_offset,
		0.35
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _camera_zoom_reset():
	var tween = create_tween()
	tween.tween_property(
		cam,
		"transform:origin",
		cam_default_offset,
		0.35
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------
# FOOT LIGHT ENERGY + PULSE
# ---------------------------------------------------------

func _set_light_energy(target: float, duration := 0.25):
	if light_tween:
		light_tween.kill()

	light_tween = create_tween()
	light_tween.tween_property(
		foot_light,
		"light_energy",
		target,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _start_light_pulse():
	if pulse_tween:
		return  

	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(
		foot_light,
		"light_energy",
		light_on_energy + 1.0,
		0.6
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(
		foot_light,
		"light_energy",
		light_on_energy - 0.5,
		0.6
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_light_pulse():
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null


# ---------------------------------------------------------
# RAYCAST SHADOW DETECTION
# ---------------------------------------------------------

func _update_shadow_from_raycast():
	shadow_hit = null

	if shadow_check.is_colliding():
		var col = shadow_check.get_collider()
		if col and col.is_in_group("Shadow"):
			shadow_hit = col

# ---------------------------------------------------------
# RAYCAST RISE DETECTION
# ---------------------------------------------------------

func _update_rise_from_raycast():
	rise_hit = null

	if shadow_check.is_colliding():
		var col = shadow_check.get_collider()
		if col and col.is_in_group("Rise"):
			rise_hit = col


# ---------------------------------------------------------
# RAYCAST SHADOW RISE DETECTION (NEW)
# ---------------------------------------------------------

func _update_shadow_rise_from_raycast():
	shadow_rise_hit = null

	if shadow_check.is_colliding():
		var col = shadow_check.get_collider()
		if col and col.is_in_group("ShadowRise"):
			shadow_rise_hit = col


# ---------------------------------------------------------
# RAYCAST RISE FALL DETECTION (NEW)
# ---------------------------------------------------------

func _update_rise_fall_from_raycast():
	rise_fall_hit = null

	if shadow_check.is_colliding():
		var col = shadow_check.get_collider()
		if col and col.is_in_group("RiseFall"):
			rise_fall_hit = col


# ---------------------------------------------------------
# SHADOW FALLTHROUGH (DOWN)
# ---------------------------------------------------------

func _start_fallthrough(shadow_obj):
	if is_falling_through:
		return

	is_falling_through = true
	print("FALLTHROUGH on:", shadow_obj.name)

	if shadow_obj is CollisionObject3D:
		shadow_obj.set_collision_layer_value(1, false)
		shadow_obj.set_collision_mask_value(1, false)

	var tween = create_tween()
	var target_pos = global_transform.origin + Vector3(0, -1.2, 0)

	tween.tween_property(self, "global_transform:origin", target_pos, 0.18)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await tween.finished

	if shadow_obj is CollisionObject3D:
		shadow_obj.set_collision_layer_value(1, true)
		shadow_obj.set_collision_mask_value(1, true)

	is_falling_through = false
	print("FALLTHROUGH COMPLETE")


# ---------------------------------------------------------
# RISE (UP)
# ---------------------------------------------------------

func _start_rise(rise_obj):
	if is_falling_through:
		return

	is_falling_through = true
	print("RISE on:", rise_obj.name)

	if rise_obj is CollisionObject3D:
		rise_obj.set_collision_layer_value(1, false)
		rise_obj.set_collision_mask_value(1, false)

	var tween = create_tween()
	var target_pos = global_transform.origin + Vector3(0, 1.2, 0)

	tween.tween_property(self, "global_transform:origin", target_pos, 0.18)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await tween.finished

	if rise_obj is CollisionObject3D:
		rise_obj.set_collision_layer_value(1, true)
		rise_obj.set_collision_mask_value(1, true)

	is_falling_through = false
	print("RISE COMPLETE")


# ---------------------------------------------------------
# SHADOW RISE (COPY OF FALL, NEW GROUP)
# ---------------------------------------------------------

func _start_shadow_rise(shadow_obj):
	if is_falling_through:
		return

	is_falling_through = true
	print("SHADOW RISE on:", shadow_obj.name)

	if shadow_obj is CollisionObject3D:
		shadow_obj.set_collision_layer_value(1, false)
		shadow_obj.set_collision_mask_value(1, false)

	var tween = create_tween()
	var target_pos = global_transform.origin + Vector3(0, -1.2, 0)

	tween.tween_property(self, "global_transform:origin", target_pos, 0.18)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await tween.finished

	if shadow_obj is CollisionObject3D:
		shadow_obj.set_collision_layer_value(1, true)
		shadow_obj.set_collision_mask_value(1, true)

	is_falling_through = false
	print("SHADOW RISE COMPLETE")


# ---------------------------------------------------------
# RISE FALL (COPY OF RISE, NEW GROUP)
# ---------------------------------------------------------

func _start_rise_fall(rise_obj):
	if is_falling_through:
		return

	is_falling_through = true
	print("RISE FALL on:", rise_obj.name)

	if rise_obj is CollisionObject3D:
		rise_obj.set_collision_layer_value(1, false)
		rise_obj.set_collision_mask_value(1, false)

	var tween = create_tween()
	var target_pos = global_transform.origin + Vector3(0, 1.2, 0)

	tween.tween_property(self, "global_transform:origin", target_pos, 0.18)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await tween.finished

	if rise_obj is CollisionObject3D:
		rise_obj.set_collision_layer_value(1, true)
		rise_obj.set_collision_mask_value(1, true)

	is_falling_through = false
	print("RISE FALL COMPLETE")


# ---------------------------------------------------------
# DASH
# ---------------------------------------------------------

func _start_dash(dir):
	is_dashing = true
	dash_timer = dash_duration
	dash_direction = dir
	sprite.play("Dash")


# ---------------------------------------------------------
# ANIMATION
# ---------------------------------------------------------

func _update_animation(input_dir):
	if is_dashing:
		return

	if not is_on_floor():
		if velocity.y > 2.0:
			sprite.play("Jump")
			sprite.frame = 0
		elif velocity.y > -2.0:
			sprite.play("Jump")
			sprite.frame = 1
		else:
			sprite.play("Jump")
			sprite.frame = 2
		return

	if input_dir == 0:
		sprite.play("Idle")
	else:
		sprite.play("Run")

func set_camera_offset(new_offset: Vector3):
	cam_default_offset = new_offset

func _load_footstep_set(surface: String):
	footstep_sounds.clear()

	var base_path := ""
	if surface == "Grass":
		base_path = "res://Assets/SFX/Footsteps/Dirt/Steps_dirt-"
	elif surface == "Wood":
		base_path = "res://Assets/SFX/Footsteps/Wood/Steps_wood-"
	else:
		return

	for i in range(1, 22):
		var num := "%03d" % i
		var file := "%s%s.ogg" % [base_path, num]
		footstep_sounds.append(file)

	current_surface = surface

func _update_surface_from_raycast():
	if not ground_ray.is_colliding():
		return

	var col = ground_ray.get_collider()
	if not col:
		return

	# Only change if Grass or Wood
	if col.is_in_group("Grass") and current_surface != "Grass":
		_load_footstep_set("Grass")

	elif col.is_in_group("Wood") and current_surface != "Wood":
		_load_footstep_set("Wood")

	# Ignore Shadow, Rise, ShadowRise, RiseFall, etc.
	
func play_footstep():
	if footstep_sounds.is_empty():
		return

	var index := randi() % footstep_sounds.size()
	var stream := load(footstep_sounds[index])

	if stream:
		footstep_player.stream = stream
		footstep_player.play()
