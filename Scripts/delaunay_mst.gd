@tool
extends Node3D

@onready var grid_map: GridMap = $GridMap
@onready var container: Node3D = $Container
@onready var line_container: Node3D = $LineContainer

const norm_room = preload("res://Objects/Rooms/room.tscn")
const spawn_room = preload("res://Objects/Rooms/spawn.tscn")
const end_room = preload("res://Objects/Rooms/end.tscn")
const stair_room = preload("res://Objects/Rooms/stairs.tscn")

var past_pos: Dictionary [Vector3i, Node3D]
var room_pos: PackedVector3Array
var room_points: PackedInt32Array

var extra_connections: AStar3D
var mst_connections: AStar3D

const min_room_size : int = 2
const max_room_size : int = 5
const min_room_height_size : int = 1
const max_room_height_size : int = 3
const max_dist_between_rooms : int = 2
const max_room_loop : int = 50

@export var generate : bool = false : set = set_generate
func set_generate(_value: bool) -> void:
	generate_dungeon()

@export var border_size: Vector3i = Vector3i(20, 20, 20) : set = set_border_size
func set_border_size(value: Vector3i) -> void:
	border_size = value
	if border_size.x < 1:
		border_size.x = 1
	if border_size.y < 1:
		border_size.y = 1
	if border_size.z < 1:
		border_size.z = 1
	
	#start_pos_x.max_value = border_size.x - 1
	#start_pos_y.max_value = border_size.y - 1
	#start_pos_z.max_value = border_size.z - 1
	#@warning_ignore("integer_division")
	#path_length_slider.max_value = (border_size.x * border_size.y * border_size.z) / 2
	#
	#border_size_x.value = border_size.x
	#border_size_y.value = border_size.y
	#border_size_z.value = border_size.z
	#
	#@warning_ignore("integer_division")
	#main_camera.position.x = border_size.x / 2
	#main_camera.position.y = border_size.y
	#@warning_ignore("integer_division")
	#main_camera.position.z = -border_size.y / 2
	
	create_border()

@export var start: Vector3i = Vector3i(5, 5, 5) : set = set_start
func set_start(value: Vector3i) -> void:
	start = value
	if start.x < 0:
		start.x = 0
	if start.y < 0:
		start.y = 0
	if start.z < 0:
		start.z = 0
	if start.x > border_size.x - 1:
		start.x = border_size.x - 1
	if start.y > border_size.y - 1:
		start.y = border_size.y - 1
	if start.z > border_size.z - 1:
		start.z = border_size.z - 1

@export var num_of_rooms: int = 4 : set = set_num_of_rooms
func set_num_of_rooms(value: int) -> void:
	num_of_rooms = value
	
	if num_of_rooms < 2:
		num_of_rooms = 2
	
	if num_of_rooms * (max_room_size * max_room_height_size * max_room_size) >= border_size.x * border_size.y * border_size.z:
		@warning_ignore("integer_division")
		num_of_rooms = (border_size.x * border_size.y * border_size.z) / (max_room_size * max_room_height_size * max_room_size) - 1

func create_border() -> void:
	grid_map.clear()
	past_pos.clear()
	room_pos.clear()
	
	for child in container.get_children():
		child.queue_free()
	
	for child in line_container.get_children():
		child.queue_free()
	
	# x border
	for i in range(-1, border_size.x + 1):
		grid_map.set_cell_item(Vector3i(i, -1, -1), 3)
		grid_map.set_cell_item(Vector3i(i, -1, border_size.z), 3)
		
		grid_map.set_cell_item(Vector3i(i, border_size.y, -1), 3)
		grid_map.set_cell_item(Vector3i(i, border_size.y, border_size.z), 3)
	
	# y border
	for i in range(0, border_size.y + 1):
		grid_map.set_cell_item(Vector3i(-1, i, -1), 3)
		grid_map.set_cell_item(Vector3i(border_size.x, i, -1), 3)
		
		grid_map.set_cell_item(Vector3i(-1, i, border_size.z), 3)
		grid_map.set_cell_item(Vector3i(border_size.x, i, border_size.z), 3)
	
	#z border
	for i in range(0, border_size.z + 1):
		grid_map.set_cell_item(Vector3i(-1, -1, i), 3)
		grid_map.set_cell_item(Vector3i(border_size.x, -1, i), 3)
		
		grid_map.set_cell_item(Vector3i(-1, border_size.y, i), 3)
		grid_map.set_cell_item(Vector3i(border_size.x, border_size.y, i), 3)

func generate_dungeon() -> void:
	create_border()
	
	for i in num_of_rooms:
		spawn_rooms(i)
	
	create_delaunay_lines()
	
	calculate_mst()
	
	#for child in container.get_children():
		#child.remove_walls(past_pos)

func spawn_rooms(room_num: int) -> void:
	var height: int = randi_range(min_room_height_size, max_room_height_size)
	var width: int = randi_range(min_room_size, max_room_size)
	var breadth: int = randi_range(min_room_size, max_room_size)
	
	var start_pos: Vector3i
	if room_num == 0:
		start_pos = start
	else:
		for i in max_room_loop:
			if i == max_room_loop - 1:
				return
			
			var break_loop = true
			
			start_pos.x = randi_range(width, border_size.x) - width
			start_pos.y = randi_range(height, border_size.y) - height
			start_pos.z = randi_range(breadth, border_size.z) - breadth
			
			for h in range(-max_dist_between_rooms, height + max_dist_between_rooms):
				for w in range(-max_dist_between_rooms, width + max_dist_between_rooms):
					for b in range(-max_dist_between_rooms, breadth + max_dist_between_rooms):
						if past_pos.has(Vector3i(start_pos.x + w, start_pos.y + h, start_pos.z + b)):
							break_loop = false
			
			if break_loop:
				break
	
	for h in height:
		for w in width:
			for b in breadth:
				if room_num == 0:
					spawn_object(Vector3i(start_pos.x + w, start_pos.y + h, start_pos.z + b), 1)
				elif room_num == num_of_rooms - 1:
					spawn_object(Vector3i(start_pos.x + w, start_pos.y + h, start_pos.z + b), 2)
				else:
					spawn_object(Vector3i(start_pos.x + w, start_pos.y + h, start_pos.z + b), 0)
	
	@warning_ignore("integer_division")
	var avg_x : int = start_pos.x + (width / 2)
	@warning_ignore("integer_division")
	var avg_y: int = start_pos.y + (height / 2)
	@warning_ignore("integer_division")
	var avg_z: int = start_pos.z + (breadth / 2)
	
	room_pos.append(Vector3i(avg_x, avg_y, avg_z))

func spawn_object(pos: Vector3i, room: int) -> void:
	var new_obj: Node3D
	
	match room:
		0:
			new_obj = norm_room.instantiate()
		1:
			new_obj = spawn_room.instantiate()
		2:
			new_obj = end_room.instantiate()
	
	container.add_child(new_obj)
	
	new_obj.global_position = pos
	
	past_pos.set(pos, new_obj)

func create_delaunay_lines() -> void:
	room_points = Geometry3D.tetrahedralize_delaunay(room_pos)
	
	var mesh_inst = MeshInstance3D.new()
	var immed_mesh = ImmediateMesh.new()
	mesh_inst.mesh = immed_mesh
	
	extra_connections = AStar3D.new()
	mst_connections = AStar3D.new()
	
	for pos in room_pos:
		extra_connections.add_point(extra_connections.get_available_point_id(), pos)
		mst_connections.add_point(mst_connections.get_available_point_id(), pos)
	
	immed_mesh.surface_begin(Mesh.PRIMITIVE_LINES, StandardMaterial3D.new())
	
	for i in range(0, room_points.size(), 4):
		var a: Vector3 = room_pos[room_points[i]]
		var b: Vector3 = room_pos[room_points[i + 1]]
		var c: Vector3 = room_pos[room_points[i + 2]]
		var d: Vector3 = room_pos[room_points[i + 3]]
		
		immed_mesh.surface_add_vertex(a); immed_mesh.surface_add_vertex(b)
		immed_mesh.surface_add_vertex(a); immed_mesh.surface_add_vertex(c)
		immed_mesh.surface_add_vertex(a); immed_mesh.surface_add_vertex(d)
		immed_mesh.surface_add_vertex(b); immed_mesh.surface_add_vertex(c)
		immed_mesh.surface_add_vertex(b); immed_mesh.surface_add_vertex(d)
		immed_mesh.surface_add_vertex(c); immed_mesh.surface_add_vertex(d)
		
		extra_connections.connect_points(room_points[i], room_points[i + 1])
		extra_connections.connect_points(room_points[i], room_points[i + 2])
		extra_connections.connect_points(room_points[i], room_points[i + 3])
		extra_connections.connect_points(room_points[i + 1], room_points[i + 2])
		extra_connections.connect_points(room_points[i + 1], room_points[i + 3])
		extra_connections.connect_points(room_points[i + 2], room_points[i + 3])
		
	immed_mesh.surface_end()
	
	line_container.add_child(mesh_inst)

func calculate_mst() -> void:
	var visited_room_points: PackedInt32Array
	visited_room_points.append(0)
	
	var min_dist: float = INF
	var min_point: int
	var curr_point: int
	
	while visited_room_points.size() != mst_connections.get_point_count():
		for vis_point in visited_room_points:
			for extra_conn in extra_connections.get_point_connections(vis_point):
				if !visited_room_points.has(extra_conn):
					if room_pos[vis_point].distance_to(room_pos[extra_conn]) < min_dist:
						min_dist = room_pos[vis_point].distance_to(room_pos[extra_conn])
						min_point = extra_conn
						curr_point = vis_point
		
		visited_room_points.append(min_point)
		mst_connections.connect_points(curr_point, min_point)
		extra_connections.disconnect_points(curr_point, min_point)
	
	for child in line_container.get_children():
		child.queue_free()
	
	var mi = MeshInstance3D.new()
	var imesh = ImmediateMesh.new()
	mi.mesh = imesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.GREEN
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	imesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for i in range(0, visited_room_points.size() - 1):
		imesh.surface_add_vertex(room_pos[i])
		imesh.surface_add_vertex(room_pos[i + 1])
	imesh.surface_end()
	
	line_container.add_child(mi)
