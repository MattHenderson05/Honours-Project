@tool
extends Node3D

@onready var grid_map: GridMap = $GridMap

var dungeon: Array

@export var generate : bool = false : set = set_generate
func set_generate(_value: bool) -> void:
	generate_dungeon()

@export var border_size: Vector3i = Vector3i(10, 10, 10) : set = set_border_size
func set_border_size(value: Vector3i) -> void:
	border_size = value
	if border_size.x < 1:
		border_size.x = 1
	if border_size.y < 1:
		border_size.y = 1
	if border_size.z < 1:
		border_size.z = 1
	if Engine.is_editor_hint():
		create_border()

@export var start: Vector2i = Vector2i(0, 0) : set = set_start
func set_start(value: Vector2i) -> void:
	start = value
	if start.x < 0:
		start.x = 0
	if start.y < 0:
		start.y = 0
	if start.x > border_size.x:
		start.x = border_size.x - 1
	if start.y > border_size.y:
		start.y = border_size.y - 1

@export var path_length: int = 1 : set = set_length
func set_length(value: int) -> void:
	path_length = value
	if path_length < 1:
		path_length = 1
	if path_length > border_size.x * border_size.y - 2:
		path_length = border_size.x * border_size.y - 2

func create_border() -> void:
	grid_map.clear()
	
	# x border
	for i in range(-1, border_size.x + 1):
		grid_map.set_cell_item(Vector3i(i, 0, -1), 3)
		grid_map.set_cell_item(Vector3i(i, 0, border_size.y), 3)
		
		grid_map.set_cell_item(Vector3i(i, border_size.z, -1), 3)
		grid_map.set_cell_item(Vector3i(i, border_size.z, border_size.y), 3)
	
	# y border
	for i in range(-1, border_size.y + 1):
		grid_map.set_cell_item(Vector3i(-1, 0, i), 3)
		grid_map.set_cell_item(Vector3i(border_size.x, 0, i), 3)
		
		grid_map.set_cell_item(Vector3i(-1, border_size.z, i), 3)
		grid_map.set_cell_item(Vector3i(border_size.x, border_size.z, i), 3)
	
	#z border
	for i in range(0, border_size.z + 1):
		grid_map.set_cell_item(Vector3i(-1, i, -1), 3)
		grid_map.set_cell_item(Vector3i(border_size.x, i, 0), 3)
		
		grid_map.set_cell_item(Vector3i(-1, i, border_size.y), 3)
		grid_map.set_cell_item(Vector3i(border_size.x, i, border_size.y), 3)

func generate_dungeon() -> void:
	create_border()
	grid_map.set_cell_item(Vector3i(start.x, 0, start.y), 1)
	
	if generate_dungeon_path(path_length, start):
		print("Created Dungeon!")
	else:
		print("Failed to Create Dungeon!!!")


func generate_dungeon_path(length: int, start_pos: Vector2i) -> bool:
	if length == 0:
		return true
	
	var curr_pos: Vector2i = start_pos
	var dir: Vector2i
	
	match randi_range(0, 3):
		0:
			dir = Vector2i.LEFT
		1:
			dir = Vector2i.UP
		2:
			dir = Vector2i.DOWN
		3:
			dir = Vector2i.RIGHT
	
	for i in 4:
		if (curr_pos.x + dir.x >= 0 and curr_pos.x + dir.x < border_size.x and
			curr_pos.y + dir.y >= 0 and curr_pos.y + dir.y < border_size.y):
			if grid_map.get_cell_item(Vector3i(curr_pos.x + dir.x, 0, curr_pos.y + dir.y)) == -1:
				curr_pos += dir
				if length != 1:
					grid_map.set_cell_item(Vector3i(curr_pos.x, 0, curr_pos.y), 0)
				else:
					grid_map.set_cell_item(Vector3i(curr_pos.x, 0, curr_pos.y), 2)
				if generate_dungeon_path(length - 1, curr_pos):
					return true
				else:
					grid_map.set_cell_item(Vector3i(curr_pos.x, 0, curr_pos.y), -1)
					curr_pos -= dir
		dir = Vector2i(dir.y, -dir.x)
	
	return false
