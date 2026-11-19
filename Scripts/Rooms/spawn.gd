@tool
extends room_class

const player = preload("res://Objects/player.tscn")

var player_obj: Node3D

func spawn_player() -> void:
	player_obj = player.instantiate()
	
	add_child(player_obj)
	
	player_obj.global_position = position + Vector3(0.5, 0.5, 0.5)

func set_player_camera_state() -> void:
	player_obj.set_camera_state()
