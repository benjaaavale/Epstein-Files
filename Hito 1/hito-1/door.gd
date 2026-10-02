extends StaticBody3D
class_name Door

const FIN_NIVEL := preload("res://fin_nivel.tscn")
const MASK_W := 96
const MASK_H := 128
const MASK_MIN := Vector2(-0.52, 0.0)
const MASK_SIZE := Vector2(1.04, 1.7)
const FADE_DEGREES := 6.0
const PAINT_INTERVAL := 0.05

@onready var pivote: Node3D = $Pivote
@onready var cerrojo: Marker3D = $Pivote/Cerrojo

var opened: bool = false
var linterna: Linterna = null
var _mask_bytes := PackedByteArray()
var _mask_texture: ImageTexture
var _texel_positions := PackedVector3Array()
var _paint_timer: float = 0.0

func _ready() -> void:
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
	if opened:
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
		var c := v.dot(dir) / v.length()
		if c <= cos_end:
			continue
		var value := int(clampf((c - cos_end) / (cos_start - cos_end), 0.0, 1.0) * 255.0)
		if value > _mask_bytes[i]:
			_mask_bytes[i] = value
			changed = true
	if changed:
		_mask_texture.update(Image.create_from_data(MASK_W, MASK_H, false, Image.FORMAT_R8, _mask_bytes))

func esta_revelada(point: Vector3) -> bool:
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

	var inicio := llave.global_transform
	llave.reparent(cerrojo, true)
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
	t.tween_property(pivote, "rotation:y", 1.75, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.tween_interval(0.4)
	await t.finished
	get_tree().current_scene.add_child(FIN_NIVEL.instantiate())
