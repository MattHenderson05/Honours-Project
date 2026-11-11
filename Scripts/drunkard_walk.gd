@tool
extends Node3D

@onready var grid_map: GridMap = $GridMap

var dungeon: Array
var past_pos: Dictionary [Vector3i, Node3D]

const norm_room = preload("res://Objects/room.tscn")
const spawn_room = preload("res://Objects/spawn.tscn")
const end_room = preload("res://Objects/end.tscn")
const stair_room = preload("res://Objects/stairs.tscn")

@onready var container: Node3D = $Container

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

@export var start: Vector3i = Vector3i(5, 5, 5) : set = set_start
func set_start(value: Vector3i) -> void:
	start = value
	if start.x < 0:
		start.x = 0
	if start.y < 0:
		start.y = 0
	if start.x > border_size.x:
		start.x = border_size.x - 1
	if start.y > border_size.y:
		start.y = border_size.y - 1

@export var path_length: int = 90 : set = set_length
func set_length(value: int) -> void:
	path_length = value
	if path_length < 1:
		path_length = 1
	if path_length > border_size.x * border_size.y - 2:
		path_length = border_size.x * border_size.y - 2

var directions: Array = [
	Vector3i.BACK, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP
]

func create_border() -> void:
	grid_map.clear()
	past_pos.clear()
	
	for child in container.get_children():
		child.queue_free()
	
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
		grid_map.set_cell_item(Vector3i(border_size.x, i, -1), 3)
		
		grid_map.set_cell_item(Vector3i(-1, i, border_size.y), 3)
		grid_map.set_cell_item(Vector3i(border_size.x, i, border_size.y), 3)

func generate_dungeon() -> void:
	create_border()
	spawn_object(start, 1)
	
	if generate_dungeon_path(path_length, start):
		print("Created Dungeon!")
		for child in container.get_children():
			child.remove_walls(past_pos)
	else:
		print("Failed to Create Dungeon!!!")
	
	spawn_object(Vector3(-6, -5, -5), 0)
	#spawn_object(Vector3(-5, -5, -5), 3) #0 right
	#spawn_object(Vector3(-6, -5, -5), 3) #90 forward
	spawn_object(Vector3(-6, -5, -4), 3) #180 left
	#spawn_object(Vector3(-5, -5, -4), 3) #270 back


func generate_dungeon_path(length: int, start_pos: Vector3i) -> bool:
	if length == 0:
		return true
	
	var curr_pos: Vector3i = start_pos
	
	directions.shuffle()
	
	for dir in directions:
		if (curr_pos.x + dir.x >= 0 and curr_pos.x + dir.x < border_size.x and
			curr_pos.y + dir.y >= 0 and curr_pos.y + dir.y < border_size.z and 
			curr_pos.z + dir.z >= 0 and curr_pos.z + dir.z < border_size.y):
			#if grid_map.get_cell_item(Vector3i(curr_pos.x + dir.x, curr_pos.z + dir.z, curr_pos.y + dir.y)) == -1:
			if !past_pos.has(curr_pos + dir):
				curr_pos += dir
				if length != 1:
					#grid_map.set_cell_item(curr_pos, 0)
					spawn_object(curr_pos, 0)
				else:
					#grid_map.set_cell_item(curr_pos, 2)
					spawn_object(curr_pos, 2)
				if generate_dungeon_path(length - 1, curr_pos):
					return true
				else:
					#grid_map.set_cell_item(curr_pos, -1)
					past_pos.erase(curr_pos)
					curr_pos -= dir
	
	return false


func spawn_object(pos: Vector3, room: int):
	var new_obj
	
	match room:
		0:
			new_obj = norm_room.instantiate()
		1:
			new_obj = spawn_room.instantiate()
		2:
			new_obj = end_room.instantiate()
		3: 
			new_obj = stair_room.instantiate()
			new_obj.rotation.y += deg_to_rad(180)
	
	container.add_child(new_obj)
	
	new_obj.global_position = pos
	
	past_pos.set(pos, new_obj)
