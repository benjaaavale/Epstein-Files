extends CharacterBody3D

@export var mouse_sensitivity: float = 0.003 # Ajusta este valor si se mueve muy rápido o lento
@export var speed: float = 3.0
@export var run_speed: float = 5.0
@export var jump_velocity: float = 3.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head: Node3D = $Head
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var hand: Marker3D = $Head/Camera3D/Hand

var held_item: Item = null

func _ready() -> void:
	# Atrapa y oculta el mouse dentro de la ventana al iniciar el juego
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	# Solo rotamos si el mouse está capturado y detectamos movimiento
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		
		# 1. Rotar el cuerpo entero en el eje Y (Mirar a izquierda/derecha)
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# 2. Rotar SOLO la cabeza en el eje X (Mirar arriba/abajo)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		
		# 3. Limitar (Clamp) la rotación vertical para no romperte el cuello hacia atrás
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	if event.is_action_pressed("interactuar"):
		_try_pick_up()
	elif event.is_action_pressed("soltar"):
		_drop_item()

func _try_pick_up() -> void:
	if held_item != null:
		return
	var target := interact_ray.get_collider()
	if target is Item:
		held_item = target
		held_item.pick_up()
		held_item.reparent(hand, false)
		held_item.transform = Transform3D.IDENTITY

func _drop_item() -> void:
	if held_item == null:
		return
	var item := held_item
	held_item = null
	var world_transform := item.global_transform
	item.reparent(get_parent(), false)
	item.global_transform = world_transform
	item.drop()
	item.linear_velocity = -head.global_transform.basis.z * 2.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("saltar"):
		velocity.y = jump_velocity

	var current_speed := run_speed if Input.is_action_pressed("correr") else speed
	var input_dir := Input.get_vector("mover_izq", "mover_der", "mover_adelante", "mover_atras")
	var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = dir.x * current_speed
	velocity.z = dir.z * current_speed
	move_and_slide()
