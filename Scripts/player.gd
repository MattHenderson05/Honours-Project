extends Node3D

@export var player_camera: Camera3D
@export var character_body: CharacterBody3D

const speed: float = 2.0
const sensitivity: float = 0.01

var dir: Vector3 = Vector3(0, 0, 0)

func _input(event: InputEvent) -> void:
	if player_camera.current:
		var input_dir := Input.get_vector("Left", "Right", "Forward", "Back",)
		
		dir = (character_body.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			character_body.rotate_y(-event.relative.x * sensitivity)
			
			player_camera.rotate_x(-event.relative.y * sensitivity)
			player_camera.rotation.x = clamp(player_camera.rotation.x, deg_to_rad(-70), deg_to_rad(70))

func _process(_delta: float) -> void:
	if player_camera.current:
		if not character_body.is_on_floor():
			dir.y = -1
		else:
			dir.y = 0
		
		if dir:
			character_body.velocity.x = dir.x * speed
			character_body.velocity.y = dir.y * speed
			character_body.velocity.z = dir.z * speed
		else:
			character_body.velocity.x = move_toward(character_body.velocity.x, 0, speed)
			character_body.velocity.y = move_toward(character_body.velocity.y, 0, speed)
			character_body.velocity.z = move_toward(character_body.velocity.z, 0, speed)
		character_body.move_and_slide()

func set_camera_state() -> void:
	player_camera.make_current()
