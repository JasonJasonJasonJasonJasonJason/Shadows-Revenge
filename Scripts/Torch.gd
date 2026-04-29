extends Node3D

@onready var light: OmniLight3D = $OmniLight3D

func _ready():
	TorchManager.register_torch(light)
