extends Node

var torches: Array[OmniLight3D] = []

# Settings you can tweak globally
var base_energy: float = 1
var flicker_amount: float = 0.4
var flicker_speed: float = 0.08

func _ready():
	# Start the flicker loop
	_start_flicker_loop()

func register_torch(light: OmniLight3D):
	if light and not torches.has(light):
		torches.append(light)

func _start_flicker_loop() -> void:
	while true:
		for light in torches:
			if light:
				var random_energy := base_energy + randf_range(-flicker_amount, flicker_amount)
				light.light_energy = max(random_energy, 0.0)

		await get_tree().create_timer(flicker_speed).timeout
