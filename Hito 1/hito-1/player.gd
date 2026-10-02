extends CharacterBody3D

@export var mouse_sensitivity: float = 0.003 # Ajusta este valor si se mueve muy rápido o lento
@export var speed: float = 3.0
@export var run_speed: float = 5.0
@export var jump_velocity: float = 3.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head: Node3D = $Head
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var hand: Marker3D = $Head/Camera3D/Hand
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var linterna: Linterna = $Head/Camera3D/LeftHand/Linterna

var held_item: Item = null
var bloqueado: bool = false

func _ready() -> void:
	# Atrapa y oculta el mouse dentro de la ventana al iniciar el juego
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if bloqueado:
		return
	# Solo rotamos si el mouse está capturado y detectamos movimiento
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		
		# 1. Rotar el cuerpo entero en el eje Y (Mirar a izquierda/derecha)
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# 2. Rotar SOLO la cabeza en el eje X (Mirar arriba/abajo)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		
		# 3. Limitar (Clamp) la rotación vertical para no romperte el cuello hacia atrás
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	if event.is_action_pressed("interactuar"):
		_interact()
	elif event.is_action_pressed("soltar"):
		_drop_item()

func _process(_delta: float) -> void:
	var target := _get_target()
	prompt_label.visible = target != null and not (target is Item and held_item != null)
	if prompt_label.visible:
		if target is Door:
			prompt_label.text = "Abrir [E]" if held_item != null else "Necesitas la llave"
		else:
			prompt_label.text = "Tomar [E]"

func _get_target() -> Node:
	if not interact_ray.is_colliding():
		return null
	var hit := interact_ray.get_collider()
	var item: Item = null
	if hit is Item:
		item = hit
	elif hit.get_parent() is Item:
		item = hit.get_parent()
	if item != null:
		return item if item.is_revealed() else null
	if hit is Door and (hit as Door).esta_revelada(interact_ray.get_collision_point()):
		return hit
	return null

func _interact() -> void:
	var target := _get_target()
	if target is Door:
		if held_item == null:
			return
		var llave := held_item
		held_item = null
		bloqueado = true
		linterna.set_process_input(false)
		(target as Door).abrir(llave)
	elif target is Item and held_item == null:
		held_item = target as Item
		held_item.pick_up()
		held_item.reparent(hand, false)
		held_item.transform = Transform3D.IDENTITY

func _drop_item() -> void:
	if held_item == null:
		return
	var item := held_item
	held_item = null
	var forward := -head.global_transform.basis.z
	var spawn := hand.global_position + forward * 0.6
	var query := PhysicsRayQueryParameters3D.create(head.global_position, spawn, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		spawn = hit.position - forward * 0.1
	var basis_actual := item.global_transform.basis
	item.reparent(get_parent(), false)
	item.global_transform = Transform3D(basis_actual, spawn)
	item.add_collision_exception_with(self)
	item.drop()
	item.linear_velocity = forward * 2.5 + Vector3.UP * 2.0
	item.angular_velocity = Vector3(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))

func _physics_process(delta: float) -> void:
	if bloqueado:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return
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
