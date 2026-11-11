@tool
extends Node3D


func _ready() -> void:
	add_to_group("Stairs")

func remove_walls(past_pos: Dictionary[Vector3i, Node3D]) -> void:
	pass
