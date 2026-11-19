extends Node3D

@export var player_camera: Camera3D

func set_camera_state() -> void:
	player_camera.make_current()
