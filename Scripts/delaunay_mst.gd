@tool
extends Node3D

@onready var grid_map: GridMap = $GridMap
@onready var container: Node3D = $Container
@onready var line_container: Node3D = $LineContainer

const norm_room = preload("res://Objects/Rooms/room.tscn")
const spawn_room = preload("res://Objects/Rooms/spawn.tscn")
const end_room = preload("res://Objects/Rooms/end.tscn")
const stair_room = preload("res://Objects/Rooms/stairs.tscn")
const door_room = preload("res://Objects/Rooms/door.tscn")
const hallway_room = preload("res://Objects/Rooms/hall_way.tscn")

var past_pos: Dictionary [Vector3i, Node3D]
var room_object_pos: Array[PackedVector3Array]
var room_pos: PackedVector3Array
var room_points: PackedInt32Array
var stairway_points: Dictionary [Vector3i, int] # o up - 1 down

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
	room_object_pos.clear()
	room_points.clear()
	stairway_points.clear()
	
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
	
	for i in range(start.y - 5, start.y + 5):
		spawn_stairs(i)
	
	create_delaunay_lines()
	
	calculate_mst()
	
	spawn_hallways()
	
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
			start_pos.y = randi_range(start.y - 5, start.y + 5)
			start_pos.z = randi_range(breadth, border_size.z) - breadth
			
			if start_pos.y < 0:
				start_pos.y = 0
			
			for h in range(-max_dist_between_rooms, height + max_dist_between_rooms):
				for w in range(-max_dist_between_rooms, width + max_dist_between_rooms):
					for b in range(-max_dist_between_rooms, breadth + max_dist_between_rooms):
						if past_pos.has(Vector3i(start_pos.x + w, start_pos.y + h, start_pos.z + b)):
							break_loop = false
			
			if break_loop:
				break
	
	var pos: PackedVector3Array
	var first_level: bool = false
	
	for h in height:
		for w in width:
			for b in breadth:
				if room_num == 0:
					spawn_object(Vector3i(start_pos.x + w, start_pos.y + h, start_pos.z + b), 1)
				elif room_num == num_of_rooms - 1:
					spawn_object(Vector3i(start_pos.x + w, start_pos.y + h, start_pos.z + b), 2)
				else:
					spawn_object(Vector3i(start_pos.x + w, start_pos.y + h, start_pos.z + b), 0)
				
				if !first_level:
					pos.append(Vector3i(start_pos.x + w, start_pos.y + h, start_pos.z + b))
		first_level = true
	
	room_object_pos.append(pos)
	first_level = false
	
	@warning_ignore("integer_division")
	var avg_x : int = start_pos.x + (width / 2)
	@warning_ignore("integer_division")
	var avg_y: int = start_pos.y + (height / 2)
	@warning_ignore("integer_division")
	var avg_z: int = start_pos.z + (breadth / 2)
	
	room_pos.append(Vector3i(avg_x, avg_y, avg_z))

func spawn_stairs(height: int) -> void:
	var start_pos: Vector3i
	for i in max_room_loop:
		if i == max_room_loop - 1:
			return
		
		var break_loop = true
		
		start_pos.x = randi_range(2, border_size.x - 3)
		start_pos.y = height
		start_pos.z = randi_range(2, border_size.z - 3)
		
		for h in range(-max_dist_between_rooms, height + max_dist_between_rooms):
			for w in range(-max_dist_between_rooms, start_pos.x + max_dist_between_rooms):
					for b in range(-max_dist_between_rooms, start_pos.z + max_dist_between_rooms):
						if past_pos.has(Vector3i(start_pos.x + w, start_pos.y + h, start_pos.z + b)):
							break_loop = false
		
		if break_loop:
			break
	
	
	var dir = randi_range(0, 3)
	spawn_stair(start_pos, dir, height)

func spawn_object(pos: Vector3i, room: int) -> void:
	var new_obj: Node3D
	
	match room:
		0:
			new_obj = norm_room.instantiate()
		1:
			new_obj = spawn_room.instantiate()
		2:
			new_obj = end_room.instantiate()
		3:
			var old_obj = past_pos.get(pos)
			old_obj.queue_free()
			
			new_obj = door_room.instantiate()
		4:
			new_obj = hallway_room.instantiate()
	
	container.add_child(new_obj)
	
	new_obj.global_position = pos
	
	past_pos.set(pos, new_obj)

func spawn_stair(pos: Vector3i, dir: int, height: int) -> void:
	var new_obj_infront: Node3D
	var new_obj_behind: Node3D
	var stair_obj: Node3D
	
	stair_obj = stair_room.instantiate()
	new_obj_infront = door_room.instantiate()
	new_obj_behind = door_room.instantiate()
	
	container.add_child(stair_obj)
	container.add_child(new_obj_infront)
	container.add_child(new_obj_behind)
	
	match dir:
		0:
			stair_obj.global_position = pos - Vector3i.LEFT
			new_obj_infront.global_position = pos
			new_obj_behind.global_position = pos + Vector3i.UP - Vector3i.LEFT - Vector3i.LEFT
			
			past_pos.set(pos - Vector3i.LEFT, stair_obj)
			past_pos.set(pos - Vector3i.LEFT + Vector3i.UP, stair_obj)
			
			stairway_points.set(pos, 0)
			stairway_points.set(pos + Vector3i.UP - Vector3i.LEFT - Vector3i.LEFT, 1)
		1:
			stair_obj.global_position = pos
			stair_obj.rotation.y += deg_to_rad(90)
			new_obj_infront.global_position = pos
			new_obj_behind.global_position = pos + Vector3i.UP - Vector3i.BACK - Vector3i.BACK
			
			past_pos.set(pos - Vector3i.BACK, stair_obj)
			past_pos.set(pos - Vector3i.BACK + Vector3i.UP, stair_obj)
			
			stairway_points.set(pos, 0)
			stairway_points.set(pos + Vector3i.UP - Vector3i.BACK - Vector3i.BACK, 1)
		2:
			stair_obj.global_position = pos - Vector3i.FORWARD
			stair_obj.rotation.y += deg_to_rad(180)
			new_obj_infront.global_position = pos
			new_obj_behind.global_position = pos + Vector3i.UP - Vector3i.RIGHT - Vector3i.RIGHT
			
			past_pos.set(pos - Vector3i.RIGHT, stair_obj)
			past_pos.set(pos - Vector3i.RIGHT + Vector3i.UP, stair_obj)
			
			stairway_points.set(pos, 0)
			stairway_points.set(pos + Vector3i.UP - Vector3i.RIGHT - Vector3i.RIGHT, 1)
		3:
			stair_obj.global_position = pos - Vector3i.FORWARD - Vector3i.LEFT
			stair_obj.rotation.y += deg_to_rad(270)
			new_obj_infront.global_position = pos
			new_obj_behind.global_position = pos + Vector3i.UP - Vector3i.FORWARD - Vector3i.FORWARD
			
			past_pos.set(pos - Vector3i.FORWARD, stair_obj)
			past_pos.set(pos - Vector3i.FORWARD + Vector3i.UP, stair_obj)
			
			stairway_points.set(pos, 0)
			stairway_points.set(pos + Vector3i.UP - Vector3i.FORWARD - Vector3i.FORWARD, 1)

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
		min_dist = INF
	
	for extra_points in extra_connections.get_point_ids():
		for extra_conn in extra_connections.get_point_connections(extra_points):
			if extra_conn > extra_points:
				var conn_chance: float = randf_range(0, 1)
				if conn_chance < 0.1:
					mst_connections.connect_points(extra_points, extra_conn)
	
	# Removes the old grey connections and replaces them with green ones
	for child in line_container.get_children():
		child.queue_free()
	
	var mi = MeshInstance3D.new()
	var imesh = ImmediateMesh.new()
	mi.mesh = imesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.GREEN
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	imesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	
	for mst_id in mst_connections.get_point_ids():
		for mst_conn in mst_connections.get_point_connections(mst_id):
			if mst_conn > mst_id:
				imesh.surface_add_vertex(room_pos[mst_id])
				imesh.surface_add_vertex(room_pos[mst_conn])
	imesh.surface_end()
	
	line_container.add_child(mi)

func spawn_hallways() -> void:
	var hallways : Array[PackedVector3Array] = []
	
	for mst_id in mst_connections.get_point_ids():
		for mst_conn in mst_connections.get_point_connections(mst_id):
			if mst_conn > mst_id:
				var room_from : PackedVector3Array = room_object_pos[mst_id]
				var room_to : PackedVector3Array = room_object_pos[mst_conn]
				var closest_object_from : Vector3 = room_from[0]
				var closest_object_to : Vector3 = room_to[0]
				
				for from in room_from:
					if from.distance_squared_to(room_pos[mst_conn]) < closest_object_from.distance_squared_to(room_pos[mst_conn]):
						closest_object_from = from
					
				for to in room_to:
					if to.distance_squared_to(room_pos[mst_id]) < closest_object_to.distance_squared_to(room_pos[mst_id]):
						closest_object_to = to
					
				var hallway : PackedVector3Array = [closest_object_from, closest_object_to]
				hallways.append(hallway)
				past_pos.get(closest_object_from).add_to_group("Door")
				past_pos.get(closest_object_to).add_to_group("Door")
				spawn_object(closest_object_from, 3)
				spawn_object(closest_object_to, 3)
	
	var a_star: AStar3D = AStar3D.new()
	var room_ids: Dictionary [Vector3i, int]
	var break_loop: bool = false
	
	for i in range(0, hallways.size()):
		var id_1: int = a_star.get_available_point_id()
		a_star.add_point(id_1, hallways[i][0])
		room_ids.set(Vector3i(hallways[i][0]), id_1)
		
		var id_2: int = a_star.get_available_point_id()
		a_star.add_point(id_2, hallways[i][1])
		room_ids.set(Vector3i(hallways[i][1]), id_2)
	
	for height in border_size.y:
		for width in border_size.x:
			for breadth in border_size.z:
				for halls in hallways:
					if halls.has(Vector3(width, height, breadth)):
						break_loop = true
						continue
				if break_loop:
					break_loop = false
					continue
				var id: int = a_star.get_available_point_id()
				a_star.add_point(id, Vector3(width, height, breadth))
				room_ids.set(Vector3(width, height, breadth), id)
				if past_pos.has(Vector3(width, height, breadth)):
					a_star.set_point_disabled(id, true)
	
	var dir_offset: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.BACK, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.UP, Vector3i.DOWN]
	
	for height in border_size.y:
		for width in border_size.x:
			for breadth in border_size.z:
				for offset in dir_offset:
					var next_room: Vector3i = Vector3i(width, height, breadth) + offset
					if room_ids.has(next_room) and room_ids.has(Vector3i(width, height, breadth)):
						if !a_star.is_point_disabled(room_ids[Vector3i(width, height, breadth)]) and !a_star.is_point_disabled(room_ids[next_room]):
							a_star.connect_points(room_ids[Vector3i(width, height, breadth)], room_ids[next_room])
	
	for i in range(0, hallways.size() * 2, 2):
		var hall_pos : PackedVector3Array = a_star.get_point_path(i, i + 1, true)
		if hall_pos[0].y == hall_pos[hall_pos.size() - 1].y:
			for f in range(1, hall_pos.size() - 1):
				spawn_object(hall_pos[f], 4)
		else:
			var min_height: int = hall_pos[0].y
			var max_height: int = hall_pos[hall_pos.size() - 1].y
			var going_up: bool
			
			if min_height - max_height < 0:
				going_up = true
			else:
				going_up = false
			
			for height in range(min_height, max_height):
				pass
			
