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
	if path_length > border_size.x * border_size.y * border_size.z - 2:
		path_length = border_size.x * border_size.y * border_size.z - 2

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
	spawn_object(start, 1, Vector3i.ZERO)
	
	if generate_dungeon_path(path_length, start, Vector3i.ZERO):
		print("Created Dungeon!")
		for child in container.get_children():
			child.remove_walls(past_pos)
	else:
		print("Failed to Create Dungeon!!!")
	
	#spawn_object(Vector3(-6, -5, -5), 0, Vector3i.ZERO)
	#spawn_object(Vector3(-6, -5, -4), 0, Vector3i.ZERO)
	#spawn_object(Vector3(-4, -4, -5), 3, Vector3i.RIGHT) #0 right
	#spawn_object(Vector3(-6, -4, -7), 3, Vector3i.FORWARD) #90 forward
	#spawn_object(Vector3(-8, -4, -5), 3, Vector3i.LEFT) #180 left
	#spawn_object(Vector3(-6, -4, -3), 3, Vector3i.BACK) #270 back
	
	#for child in container.get_children():
			#child.remove_walls(past_pos)
	
	#for past in past_pos:
		#print(past)


func generate_dungeon_path(length: int, start_pos: Vector3i, prev_dir: Vector3i) -> bool:
	if length == 0:
		return true
	var curr_pos: Vector3i = start_pos
	
	directions.shuffle()
	
	for dir in directions:
		if check_inside_boundary(curr_pos + dir):
			#if grid_map.get_cell_item(Vector3i(curr_pos.x + dir.x, curr_pos.z + dir.z, curr_pos.y + dir.y)) == -1:
			if !past_pos.has(curr_pos + dir):
				if dir == Vector3i.UP and dir == prev_dir or dir == Vector3i.DOWN and dir == prev_dir:
					#print("Skipped because already made stairs")
					continue
				curr_pos += dir
				if length != 1:
					#grid_map.set_cell_item(curr_pos, 0)
					if dir == Vector3i.UP:
						#print("up")
						if past_pos.has(curr_pos + prev_dir) and !check_inside_boundary(curr_pos + prev_dir):
							#print("Skipped because no room")
							continue
						curr_pos += prev_dir
						spawn_object(curr_pos, 3, prev_dir)
					else:
						spawn_object(curr_pos, 0, prev_dir)
				else:
					#if dir != Vector3i.UP and dir != Vector3i.DOWN:
					#grid_map.set_cell_item(curr_pos, 2)
					spawn_object(curr_pos, 2, prev_dir)
				if generate_dungeon_path(length - 1, curr_pos, dir):
					return true
				else:
					#grid_map.set_cell_item(curr_pos, -1)
					var node_removal: Node3D 
					
					if dir == Vector3i.UP:
						#print("destroyed")
						node_removal = past_pos[curr_pos]
						past_pos.erase(curr_pos)
						node_removal.queue_free()
						curr_pos -= prev_dir
						node_removal = past_pos[curr_pos]
						past_pos.erase(curr_pos)
						node_removal.queue_free()
						curr_pos -= dir
						past_pos.erase(curr_pos)
						spawn_object(curr_pos, 0, prev_dir)
					elif dir == Vector3i.DOWN:
						node_removal = past_pos[curr_pos]
						past_pos.erase(curr_pos)
						curr_pos -= dir
						node_removal.queue_free()
					else:
						node_removal = past_pos[curr_pos]
						past_pos.erase(curr_pos)
						curr_pos -= dir
						node_removal.queue_free()
	
	return false


func spawn_object(pos: Vector3i, room: int, prev_dir: Vector3i):
	var new_obj: Node3D
	var stair_obj: Node3D
	var node_removal: Node3D
	
	match room:
		0:
			new_obj = norm_room.instantiate()
		1:
			new_obj = spawn_room.instantiate()
		2:
			new_obj = end_room.instantiate()
		3: 
			node_removal = past_pos[pos - prev_dir - Vector3i.UP]
			node_removal.queue_free()
			
			stair_obj = stair_room.instantiate()
			past_pos.set((pos - prev_dir - Vector3i.UP), stair_obj)
			past_pos.set((pos - prev_dir), stair_obj)
			container.add_child(stair_obj)
			
			match prev_dir:
				Vector3i.RIGHT:
					stair_obj.global_position = pos - prev_dir - Vector3i.UP
				Vector3i.FORWARD:
					stair_obj.global_position = pos - prev_dir - prev_dir - Vector3i.UP
					stair_obj.rotation.y += deg_to_rad(90)
				Vector3i.LEFT:
					stair_obj.global_position = pos - prev_dir - prev_dir - Vector3i.UP - Vector3i.FORWARD
					stair_obj.rotation.y += deg_to_rad(180)
				Vector3i.BACK:
					stair_obj.global_position = pos - prev_dir - Vector3i.UP - Vector3i.LEFT
					stair_obj.rotation.y += deg_to_rad(270)
			
			new_obj = norm_room.instantiate()
	
	container.add_child(new_obj)
	
	new_obj.global_position = pos
	
	past_pos.set(pos, new_obj)

func check_inside_boundary(pos: Vector3i) -> bool:
	if (pos.x >= 0 and pos.x < border_size.x and
			pos.y >= 0 and pos.y < border_size.z and 
			pos.z >= 0 and pos.z < border_size.y):
				return true
	
	return false
