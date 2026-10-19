extends CharacterBody3D

## Avisa al guion del nivel: "puerta_bloqueada", "documento_leido", "objeto_tomado", "puerta_abierta".
signal evento(nombre: String)

@export var mouse_sensitivity: float = 0.003 # Ajusta este valor si se mueve muy rápido o lento
@export var speed: float = 3.0
@export var run_speed: float = 5.0
@export var crouch_speed: float = 1.2
@export var jump_velocity: float = 3.0
@export var ground_accel: float = 14.0
@export var air_accel: float = 4.0
@export var crouch_height: float = 1.2

@export_group("Camara")
@export var bob_amount: float = 0.035
@export var bob_frequency: float = 2.2
@export var sprint_fov_boost: float = 6.0
@export var sway_amount: float = 0.0008

const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.12

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var hand: Marker3D = $Head/Camera3D/Hand
@onready var left_hand: Marker3D = $Head/Camera3D/LeftHand
@onready var linterna: Linterna = $Head/Camera3D/LeftHand/Linterna
@onready var hud: Hud = $HUD
@onready var collision: CollisionShape3D = $CollisionShape3D

var held_item: Item = null
var bloqueado: bool = false

var _capsule: CapsuleShape3D
var _stand_height: float
var _head_base_y: float
var _base_fov: float
var _left_hand_base: Transform3D
var _hand_base: Transform3D
var _crouching := false
var _bob_time := 0.0
var _step_index := 0
var _sway := Vector2.ZERO
var _land_dip := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _step_player: AudioStreamPlayer
var _land_player: AudioStreamPlayer
var _step_streams: Array[AudioStream] = []
var _creak_player: AudioStreamPlayer
var _creak_streams: Array[AudioStream] = []

func _ready() -> void:
	# Atrapa y oculta el mouse dentro de la ventana al iniciar el juego
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_capsule = collision.shape.duplicate() as CapsuleShape3D
	collision.shape = _capsule
	_stand_height = _capsule.height
	_head_base_y = head.position.y
	_base_fov = camera.fov
	_left_hand_base = left_hand.transform
	_hand_base = hand.transform
	hud.linterna = linterna
	hud.documento_cerrado.connect(_on_documento_cerrado)
	Ajustes.inicio_nivel_ms = Time.get_ticks_msec()

	_step_player = AudioStreamPlayer.new()
	add_child(_step_player)
	_land_player = AudioStreamPlayer.new()
	_land_player.stream = load("res://sonidos/aterrizaje.wav")
	add_child(_land_player)
	for i in 6:
		_step_streams.append(load("res://sonidos/paso_%d.wav" % (i + 1)))
	_creak_player = AudioStreamPlayer.new()
	_creak_player.volume_db = -20.0
	add_child(_creak_player)
	for i in 3:
		_creak_streams.append(load("res://sonidos/crujido_%d.wav" % (i + 1)))

func _unhandled_input(event: InputEvent) -> void:
	if bloqueado:
		return
	# Solo rotamos si el mouse está capturado y detectamos movimiento
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# 1. Rotar el cuerpo entero en el eje Y (Mirar a izquierda/derecha)
		rotate_y(-event.relative.x * mouse_sensitivity * Ajustes.sensibilidad)
		# 2. Rotar SOLO la cabeza en el eje X (Mirar arriba/abajo)
		head.rotate_x(-event.relative.y * mouse_sensitivity * Ajustes.sensibilidad)
		# 3. Limitar (Clamp) la rotación vertical para no romperte el cuello hacia atrás
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		# Las manos se quedan un poco atrás del movimiento del mouse
		_sway = (_sway + Vector2(event.relative.x, event.relative.y) * sway_amount).limit_length(0.06)

	if event.is_action_pressed("interactuar"):
		_interact()
	elif event.is_action_pressed("soltar"):
		_drop_item()

func _process(delta: float) -> void:
	_update_prompt()
	_update_camera(delta)

# ---------- interaccion ----------

func _update_prompt() -> void:
	var target := _get_target()
	if bloqueado or target == null or (target is Item and held_item != null):
		hud.hide_prompt()
	elif target is Door:
		if held_item != null:
			hud.show_prompt("E", "Abrir puerta")
		else:
			hud.show_prompt("", "Cerrada con llave", false)
	elif target is Leible:
		hud.show_prompt("E", (target as Leible).accion)
	else:
		hud.show_prompt("E", "Tomar " + (target as Item).item_name.to_lower())

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
	if hit is Leible:
		return hit
	return null

func _interact() -> void:
	var target := _get_target()
	if target is Door:
		var puerta := target as Door
		if held_item == null:
			hud.toast("Está cerrada con llave")
			evento.emit("puerta_bloqueada")
			return
		var llave := held_item
		held_item = null
		bloqueado = true
		linterna.set_process_input(false)
		hud.set_held_item("")
		hud.set_cinematic(true)
		await puerta.abrir(llave)
		if not puerta.termina_nivel:
			bloqueado = false
			linterna.set_process_input(true)
			hud.set_cinematic(false)
			evento.emit("puerta_abierta")
	elif target is Leible:
		var doc := target as Leible
		bloqueado = true
		doc.leido = true
		hud.mostrar_documento(doc.encabezado, doc.titulo, doc.cuerpo)
	elif target is Item and held_item == null:
		held_item = target as Item
		held_item.pick_up()
		held_item.reparent(hand, false)
		held_item.transform = Transform3D.IDENTITY
		hud.set_held_item(held_item.item_name)
		hud.toast(held_item.item_name, "OBJETO OBTENIDO")
		evento.emit("objeto_tomado")

func _on_documento_cerrado() -> void:
	bloqueado = false
	evento.emit("documento_leido")

func _drop_item() -> void:
	if held_item == null:
		return
	var item := held_item
	held_item = null
	hud.set_held_item("")
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

# ---------- movimiento ----------

func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= gravity * delta
	_update_crouch(delta)

	if bloqueado:
		velocity.x = move_toward(velocity.x, 0.0, ground_accel * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_accel * delta)
		move_and_slide()
		return

	# Coyote time y buffer: el salto responde aunque se apriete un poco antes o tarde
	_coyote = COYOTE_TIME if on_floor else maxf(_coyote - delta, 0.0)
	_jump_buffer = JUMP_BUFFER if Input.is_action_just_pressed("saltar") else maxf(_jump_buffer - delta, 0.0)
	if _jump_buffer > 0.0 and _coyote > 0.0 and not _crouching:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0

	var input_dir := Input.get_vector("mover_izq", "mover_der", "mover_adelante", "mover_atras")
	var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var target_speed := speed
	if _crouching:
		target_speed = crouch_speed
	elif _is_sprinting():
		target_speed = run_speed
	var accel := ground_accel if on_floor else air_accel
	velocity.x = move_toward(velocity.x, dir.x * target_speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * target_speed, accel * delta)

	if not on_floor:
		_fall_speed = maxf(_fall_speed, -velocity.y)
	move_and_slide()
	_check_landing()

func _is_sprinting() -> bool:
	return Input.is_action_pressed("correr") and not _crouching

func _update_crouch(delta: float) -> void:
	var want := Input.is_action_pressed("agacharse") and not bloqueado
	if not want and _crouching and not _can_stand():
		want = true
	_crouching = want
	var target_h := crouch_height if _crouching else _stand_height
	var new_h := move_toward(_capsule.height, target_h, delta * 5.0)
	if new_h > _capsule.height and not _can_stand():
		new_h = _capsule.height
	_capsule.height = new_h
	# Los pies quedan fijos: la capsula se achica desde arriba
	collision.position.y = (_capsule.height - _stand_height) * 0.5
	head.position.y = _head_base_y - (_stand_height - _capsule.height) * 0.5

func _can_stand() -> bool:
	return not test_move(global_transform, Vector3.UP * (_stand_height - _capsule.height + 0.02))

func _check_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and _fall_speed > 1.5:
		_land_dip = clampf(_fall_speed * 0.025, 0.02, 0.12)
		_land_player.volume_db = clampf(-14.0 + _fall_speed * 2.0, -14.0, -2.0)
		_land_player.pitch_scale = randf_range(0.9, 1.05)
		_land_player.play()
	if on_floor:
		_fall_speed = 0.0
	_was_on_floor = on_floor

# ---------- camara ----------

func _update_camera(delta: float) -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var bob := Vector3.ZERO
	if is_on_floor() and hspeed > 0.3:
		_bob_time += delta * hspeed * bob_frequency
		var amp := bob_amount * clampf(hspeed / speed, 0.5, 1.6) * (0.5 if _crouching else 1.0)
		bob = Vector3(cos(_bob_time) * amp * 0.6, -absf(sin(_bob_time)) * amp, 0.0)
		# Un paso cada vez que la camara llega al punto mas bajo
		var step := int((_bob_time + PI * 0.5) / PI)
		if step != _step_index:
			_step_index = step
			_play_step(hspeed)

	_land_dip = lerpf(_land_dip, 0.0, clampf(delta * 6.0, 0.0, 1.0))
	camera.position = camera.position.lerp(bob + Vector3(0.0, -_land_dip, 0.0), clampf(delta * 12.0, 0.0, 1.0))

	var sprinting := _is_sprinting() and hspeed > speed + 0.2
	var target_fov := _base_fov + (sprint_fov_boost if sprinting else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 6.0, 0.0, 1.0))

	_sway = _sway.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	var sway_basis := Basis.from_euler(Vector3(_sway.y, _sway.x, 0.0))
	left_hand.transform = Transform3D(_left_hand_base.basis * sway_basis, _left_hand_base.origin)
	hand.transform = Transform3D(_hand_base.basis * sway_basis, _hand_base.origin)

func _play_step(hspeed: float) -> void:
	if _step_streams.is_empty():
		return
	_step_player.stream = _step_streams[randi() % _step_streams.size()]
	_step_player.pitch_scale = randf_range(0.92, 1.08)
	if _crouching:
		_step_player.volume_db = -24.0
	elif hspeed > speed + 0.2:
		_step_player.volume_db = -12.0
	else:
		_step_player.volume_db = -16.0
	_step_player.play()
	# Las tablas viejas crujen de vez en cuando
	if not _creak_player.playing and randf() < 0.12:
		_creak_player.stream = _creak_streams[randi() % _creak_streams.size()]
		_creak_player.pitch_scale = randf_range(0.85, 1.15)
		_creak_player.play()
