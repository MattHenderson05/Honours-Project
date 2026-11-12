@tool
extends Node3D

@export var walls: Array [MeshInstance3D]

var directions: Array = [
	Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK,
]

func remove_walls(past_pos: Dictionary[Vector3i, Node3D]) -> void:
	for i in 4:
		if past_pos.has(Vector3i(position.x + directions[i].x, position.y + directions[i].y, position.z + directions[i].z)):
			walls[i].visible = false
