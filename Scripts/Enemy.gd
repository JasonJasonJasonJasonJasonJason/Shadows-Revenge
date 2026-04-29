extends CharacterBody3D

@export var move_speed := 1.2
@export var idle_time_min := 1.5
@export var idle_time_max := 3.0

# Assigned in the editor from the parent scene
@export var patrol_point_a: NodePath
@export var patrol_point_b: NodePath

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var player_ray: RayCast3D = $PlayerRay
@onready var warning_sprite: AnimatedSprite3D = $Warning

var point_a: Node3D
var point_b: Node3D
var target_point: Node3D
var is_idling := false
var player_seen := false
var warning_playing := false


func _ready():
	# Resolve patrol points
	point_a = get_node(patrol_point_a)
	point_b = get_node(patrol_point_b)

	target_point = point_b
	sprite.play("Walk")

	# Warning sprite starts hidden
	warning_sprite.visible = false

	# Ensure ray is pointing the correct direction at start
	_update_raycast_direction()


func _physics_process(_delta):
	_check_player_detection()

	# If player is seen, stop patrolling
	if player_seen:
		_handle_player_seen()
		return

	if is_idling:
		return

	var dir = (target_point.global_transform.origin - global_transform.origin)
	var distance = dir.length()

	# Reached patrol point → idle
	if distance < 0.2:
		_start_idle()
		return

	# Move toward target
	dir = dir.normalized()
	velocity = dir * move_speed
	move_and_slide()

	# Flip sprite based on Z movement (2.5D)
	if abs(dir.z) > 0.01:
		sprite.flip_h = dir.z < 0
		_update_raycast_direction()

	# Ensure walking animation
	if sprite.animation != "Walk":
		sprite.play("Walk")


func _start_idle():
	is_idling = true
	velocity = Vector3.ZERO
	sprite.play("Idle")

	var wait_time = randf_range(idle_time_min, idle_time_max)
	await get_tree().create_timer(wait_time).timeout

	# Switch patrol target
	if target_point == point_a:
		target_point = point_b
	else:
		target_point = point_a

	is_idling = false
	sprite.play("Walk")


# ---------------------------------------------------------
# PLAYER DETECTION
# ---------------------------------------------------------

func _check_player_detection():
	if player_ray.is_colliding():
		var col = player_ray.get_collider()
		if col and col.is_in_group("Player"):
			if not player_seen:
				_play_warning_once()
			player_seen = true
			return

	player_seen = false


func _handle_player_seen():
	velocity = Vector3.ZERO
	sprite.play("Idle")
	# Later: chase, attack, etc.


# ---------------------------------------------------------
# WARNING ANIMATION (plays once)
# ---------------------------------------------------------

func _play_warning_once():
	if warning_playing:
		return

	warning_playing = true
	warning_sprite.visible = true
	warning_sprite.play("Warning")

	# Calculate animation duration
	var frames = warning_sprite.sprite_frames.get_frame_count("Warning")
	var fps = warning_sprite.sprite_frames.get_animation_speed("Warning")
	var duration = frames / fps

	await get_tree().create_timer(duration).timeout

	warning_sprite.visible = false
	warning_playing = false


# ---------------------------------------------------------
# RAYCAST DIRECTION (flip with sprite)
# ---------------------------------------------------------

func _update_raycast_direction():
	if sprite.flip_h:
		# Facing left (negative Z)
		player_ray.target_position = Vector3(0, 1, 0)
	else:
		# Facing right (positive Z)
		player_ray.target_position = Vector3(0, -1, 0)
