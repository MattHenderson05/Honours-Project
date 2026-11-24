@tool
extends Node3D

@onready var grid_map: GridMap = $GridMap

@export_subgroup("UI")

@export var generate_button: Button
@export var border_size_x: SpinBox
@export var border_size_y: SpinBox
@export var border_size_z: SpinBox
@export var start_pos_x: SpinBox
@export var start_pos_y: SpinBox
@export var start_pos_z: SpinBox
@export var path_length_label: Label
@export var path_length_slider: HSlider

@export_subgroup("Camera")

@export var main_camera: Camera3D

var past_pos: Dictionary [Vector3i, Node3D]

const norm_room = preload("res://Objects/Rooms/room.tscn")
const spawn_room = preload("res://Objects/Rooms/spawn.tscn")
const end_room = preload("res://Objects/Rooms/end.tscn")
const stair_room = preload("res://Objects/Rooms/stairs.tscn")

@onready var container: Node3D = $Container

@export_subgroup("Data")

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
	
	start_pos_x.max_value = border_size.x - 1
	start_pos_y.max_value = border_size.y - 1
	start_pos_z.max_value = border_size.z - 1
	@warning_ignore("integer_division")
	path_length_slider.max_value = (border_size.x * border_size.y * border_size.z) / 2
	
	border_size_x.value = border_size.x
	border_size_y.value = border_size.y
	border_size_z.value = border_size.z
	
	@warning_ignore("integer_division")
	main_camera.position.x = border_size.x / 2
	main_camera.position.y = border_size.y
	@warning_ignore("integer_division")
	main_camera.position.z = -border_size.y / 2
	
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
	
	start_pos_x.value = start.x
	start_pos_y.value = start.y
	start_pos_z.value = start.z
	
	create_border()

@export var path_length: int = 90 : set = set_length
func set_length(value: int) -> void:
	path_length = value
	if path_length < 1:
		path_length = 1
	@warning_ignore("integer_division")
	if path_length > (border_size.x * border_size.y * border_size.z) / 2:
		@warning_ignore("integer_division")
		path_length = (border_size.x * border_size.y * border_size.z) / 2
	
	path_length_label.text = "Path Length: " + str(path_length)
	path_length_slider.value = path_length

var directions: Array = [
	Vector3i.BACK, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP
]

func _ready() -> void:
	generate_dungeon()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Space") and !generate_button.disabled and past_pos.get(start):
		if main_camera.current:
			past_pos.get(start).set_player_camera_state()
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			main_camera.make_current()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

#Creates a visible border using a grid map
func create_border() -> void:
	grid_map.clear()
	past_pos.clear()
	
	for child in container.get_children():
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

#Starting function that is called to generate dungeon. Will spawn the starting room then call generate_dungeon_path
func generate_dungeon() -> void:
	change_ui_editability(false)
	
	create_border()
	spawn_object(start, 1, Vector3i.ZERO)
	
	var f = await generate_dungeon_path(path_length, start, Vector3i.ZERO)
	if f:
		print("Created Dungeon!")
		for child in container.get_children():
			child.remove_walls(past_pos)
		past_pos.get(start).spawn_player()
		change_ui_editability(true)
	else:
		print("Failed to Create Dungeon!!!")
		change_ui_editability(true)

#Main recursive function that creates the dungeon path
func generate_dungeon_path(length: int, start_pos: Vector3i, prev_dir: Vector3i) -> bool:
	if length == 0:
		return true
	var curr_pos: Vector3i = start_pos
	
	await get_tree().create_timer(0.0).timeout
	
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
						if past_pos.has(curr_pos + prev_dir) or !check_inside_boundary(curr_pos + prev_dir) or length == path_length or length == 2:
							#print("Skipped up because no room")
							curr_pos -= dir
							continue
						curr_pos += prev_dir
						spawn_object(curr_pos, 3, prev_dir)
					elif dir == Vector3i.DOWN:
						if past_pos.has(curr_pos + prev_dir) or !check_inside_boundary(curr_pos + prev_dir) or length == path_length or length == 2:
							#print("Skipped down because no room")
							curr_pos -= dir
							continue
						curr_pos += prev_dir
						spawn_object(curr_pos, 4, prev_dir)
					else:
						spawn_object(curr_pos, 0, prev_dir)
				else:
					#if dir != Vector3i.UP and dir != Vector3i.DOWN:
					#grid_map.set_cell_item(curr_pos, 2)
					if dir ==  Vector3i.UP or dir ==  Vector3i.DOWN:
						curr_pos -= dir
						continue
					spawn_object(curr_pos, 2, prev_dir)
				var f = await generate_dungeon_path(length - 1, curr_pos, dir)
				if f:
					return true
				else:
					#grid_map.set_cell_item(curr_pos, -1)
					var node_removal: Node3D 
					
					if dir == Vector3i.UP or dir == Vector3i.DOWN:
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
					else:
						node_removal = past_pos[curr_pos]
						past_pos.erase(curr_pos)
						curr_pos -= dir
						node_removal.queue_free()
	
	return false

#Spawns the rooms and stairs
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
		4:
			node_removal = past_pos[pos - prev_dir - Vector3i.DOWN]
			node_removal.queue_free()
			
			stair_obj = stair_room.instantiate()
			past_pos.set((pos - prev_dir - Vector3i.DOWN), stair_obj)
			past_pos.set((pos - prev_dir), stair_obj)
			container.add_child(stair_obj)
			
			match prev_dir:
				Vector3i.RIGHT:
					stair_obj.global_position = pos - Vector3i.FORWARD
					stair_obj.rotation.y += deg_to_rad(180)
				Vector3i.FORWARD:
					stair_obj.global_position = pos - prev_dir - Vector3i.LEFT
					stair_obj.rotation.y += deg_to_rad(270)
				Vector3i.LEFT:
					stair_obj.global_position = pos - prev_dir
				Vector3i.BACK:
					stair_obj.global_position = pos
					stair_obj.rotation.y += deg_to_rad(90)
			
			new_obj = norm_room.instantiate()
	
	container.add_child(new_obj)
	
	new_obj.global_position = pos
	
	past_pos.set(pos, new_obj)

#Checks if the passed in value is inside the boundarys
func check_inside_boundary(pos: Vector3i) -> bool:
	if (pos.x >= 0 and pos.x < border_size.x and
			pos.y >= 0 and pos.y < border_size.y and 
			pos.z >= 0 and pos.z < border_size.z):
				return true
	
	return false

#Enables and disables the UI
func change_ui_editability(value: bool) -> void:
	if value == true:
		generate_button.disabled = false
		border_size_x.editable = true
		border_size_y.editable = true
		border_size_z.editable = true
		start_pos_x.editable = true
		start_pos_y.editable = true
		start_pos_z.editable = true
		path_length_slider.editable = true
	elif value == false:
		generate_button.disabled = true
		border_size_x.editable = false
		border_size_y.editable = false
		border_size_z.editable = false
		start_pos_x.editable = false
		start_pos_y.editable = false
		start_pos_z.editable = false
		path_length_slider.editable = false

#Button to generate fungeon
func _on_generate_button_pressed() -> void:
	generate_dungeon()

#Box values that change the border size
func _on_x_spin_box_value_changed(value: float) -> void:
	set_border_size(Vector3i(int(value), int(border_size_y.value), int(border_size_z.value)))

func _on_y_spin_box_value_changed(value: float) -> void:
	set_border_size(Vector3i(int(border_size_x.value), int(value), int(border_size_z.value)))

func _on_z_spin_box_value_changed(value: float) -> void:
	set_border_size(Vector3i(int(border_size_x.value), int(border_size_y.value), int(value)))

#Box values that change the start position
func _on_x_box_value_changed(value: float) -> void:
	set_start(Vector3i(int(value), int(start_pos_y.value), int(start_pos_z.value)))

func _on_y_box_value_changed(value: float) -> void:
	set_start(Vector3i(int(start_pos_x.value), int(value), int(start_pos_z.value)))

func _on_z_box_value_changed(value: float) -> void:
	set_start(Vector3i(int(start_pos_x.value), int(start_pos_y.value), int(value)))

#Slider that changes the path length
func _on_path_length_slider_value_changed(value: float) -> void:
	set_length(int(value))
