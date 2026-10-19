extends StaticBody3D
class_name Door

const FIN_NIVEL := preload("res://fin_nivel.tscn")
const MASK_W := 96
const MASK_H := 128
const MASK_MIN := Vector2(-0.52, 0.0)
const MASK_SIZE := Vector2(1.04, 1.7)
const FADE_DEGREES := 6.0
const PAINT_INTERVAL := 0.05

## Secreta: invisible hasta que se raspa con la luz morada. Si es false, es una puerta normal.
@export var secreta := true
## Si es false, la puerta solo se abre y el juego sigue.
@export var termina_nivel := true

@onready var pivote: Node3D = $Pivote
@onready var cerrojo: Marker3D = $Pivote/Cerrojo

var opened: bool = false
var linterna: Linterna = null
var _mask_bytes := PackedByteArray()
var _mask_texture: ImageTexture
var _texel_positions := PackedVector3Array()
var _paint_timer: float = 0.0

func _ready() -> void:
	if not secreta:
		for g in find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).set_instance_shader_parameter("force_visible", 1.0)
		return
	_mask_bytes.resize(MASK_W * MASK_H)
	_mask_texture = ImageTexture.create_from_image(Image.create_from_data(MASK_W, MASK_H, false, Image.FORMAT_R8, _mask_bytes))
	_texel_positions.resize(MASK_W * MASK_H)
	for y in MASK_H:
		for x in MASK_W:
			var local := Vector3(
				MASK_MIN.x + (x + 0.5) / MASK_W * MASK_SIZE.x,
				MASK_MIN.y + (1.0 - (y + 0.5) / MASK_H) * MASK_SIZE.y,
				0.045)
			_texel_positions[y * MASK_W + x] = to_global(local)
	var world_to_mask := Projection(global_transform.affine_inverse())
	for mat in _materiales():
		mat.set_shader_parameter("reveal_mask", _mask_texture)
		mat.set_shader_parameter("use_reveal_mask", true)
		mat.set_shader_parameter("world_to_mask", world_to_mask)
		mat.set_shader_parameter("mask_min", MASK_MIN)
		mat.set_shader_parameter("mask_size", MASK_SIZE)

func _materiales() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for g in find_children("*", "GeometryInstance3D", true, false):
		var mat := (g as GeometryInstance3D).material_override as ShaderMaterial
		if mat != null and not out.has(mat):
			out.append(mat)
	return out

func _process(delta: float) -> void:
	if opened or not secreta:
		return
	_paint_timer += delta
	if _paint_timer < PAINT_INTERVAL:
		return
	_paint_timer = 0.0
	if linterna == null:
		linterna = get_tree().current_scene.find_child("Linterna", true, false) as Linterna
		if linterna == null:
			return
	if linterna.current_channel == Linterna.Channel.VIOLET:
		_paint(linterna.spot_light_3d)

func _paint(spot: SpotLight3D) -> void:
	var origin := spot.global_position
	var dir := -spot.global_transform.basis.z
	var angle := spot.spot_angle - 2.0
	var cos_end := cos(deg_to_rad(angle))
	var cos_start := cos(deg_to_rad(angle - FADE_DEGREES))
	var changed := false
	for i in _texel_positions.size():
		var v := _texel_positions[i] - origin
		var c := v.normalized().dot(dir)
		if c <= cos_end:
			continue
		var value := int(clampf((c - cos_end) / (cos_start - cos_end), 0.0, 1.0) * 255.0)
		if value > _mask_bytes[i]:
			_mask_bytes[i] = value
			changed = true
	if changed:
		_mask_texture.update(Image.create_from_data(MASK_W, MASK_H, false, Image.FORMAT_R8, _mask_bytes))

func esta_revelada(point: Vector3) -> bool:
	if not secreta:
		return true
	var local := to_local(point)
	var x := int((local.x - MASK_MIN.x) / MASK_SIZE.x * MASK_W)
	var y := int((1.0 - (local.y - MASK_MIN.y) / MASK_SIZE.y) * MASK_H)
	if x < 0 or x >= MASK_W or y < 0 or y >= MASK_H:
		return false
	return _mask_bytes[y * MASK_W + x] > 127

func abrir(llave: Item) -> void:
	if opened:
		return
	opened = true
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).set_instance_shader_parameter("force_visible", 1.0)

	if secreta:
		_crear_hueco()

	var inicio := llave.global_transform
	# la llave no se cuelga de la puerta (puede estar escalada): la sigue a mano
	llave.reparent(get_tree().current_scene, true)
	llave.interact_zone.process_mode = Node.PROCESS_MODE_DISABLED
	var eje := cerrojo.global_transform.basis.z.normalized()
	var base_llave := cerrojo.global_transform.basis.orthonormalized()
	var fuera := cerrojo.global_position + eje * 0.27
	var dentro := cerrojo.global_position + eje * 0.13

	var t := create_tween()
	t.tween_method(func(w: float) -> void:
		llave.global_transform = Transform3D(
			inicio.basis.orthonormalized().slerp(base_llave, w),
			inicio.origin.lerp(fuera, w)),
		0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(llave, "global_position", dentro, 0.35)
	t.tween_method(func(a: float) -> void:
		llave.global_transform = Transform3D(Basis(eje, a) * base_llave, dentro),
		0.0, PI / 2.0, 0.45)
	t.tween_interval(0.2)
	t.tween_method(_girar_con_llave.bind(llave), 0.0, 1.75, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.tween_interval(0.4)
	await t.finished
	if termina_nivel:
		get_tree().current_scene.add_child(FIN_NIVEL.instantiate())
	else:
		($CollisionShape3D as CollisionShape3D).disabled = true


var _llave_relativa := Transform3D()
var _llave_relativa_lista := false


func _cerrojo_ortonormal() -> Transform3D:
	return Transform3D(cerrojo.global_transform.basis.orthonormalized(), cerrojo.global_position)


func _girar_con_llave(angulo: float, llave: Item) -> void:
	if not _llave_relativa_lista:
		_llave_relativa = _cerrojo_ortonormal().affine_inverse() * llave.global_transform
		_llave_relativa_lista = true
	pivote.rotation.y = angulo
	llave.global_transform = _cerrojo_ortonormal() * _llave_relativa


## Detras de una puerta secreta no hay paso real: se muestra un vacio negro al abrirla.
func _crear_hueco() -> void:
	var hueco := MeshInstance3D.new()
	hueco.name = "Hueco"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 1.6)
	hueco.mesh = quad
	var negro := StandardMaterial3D.new()
	negro.albedo_color = Color.BLACK
	negro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	negro.disable_fog = true
	hueco.material_override = negro
	hueco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hueco.position = Vector3(0, 0.8, -0.045)
	add_child(hueco)
