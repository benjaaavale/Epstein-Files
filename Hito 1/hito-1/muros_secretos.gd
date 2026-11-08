extends CSGBox3D
class_name MuroSecreto

## Pared falsa: la luz morada la va borrando donde apunta (como raspar pintura).
## Cuando se borra lo suficiente, se desvanece entera y deja pasar.
## La mascara se dibuja sobre la cara grande de la caja, sea cual sea su eje delgado.

signal revelado

const FADE_DEGREES := 6.0
const PAINT_INTERVAL := 0.05
const MASK_W := 64
const MASK_H := 64
## Fraccion borrada a partir de la cual el muro desaparece del todo.
const UMBRAL := 0.45

@export var secreta := true
## Evento que recibe el guion al abrirse (vacio = ninguno).
@export var evento := "muro_revelado"

var linterna: Linterna = null
var abierto := false
var _mask_bytes := PackedByteArray()
var _mask_texture: ImageTexture
var _texel_positions := PackedVector3Array()
var _paint_timer: float = 0.0
var _mask_min := Vector2.ZERO
var _mask_size := Vector2.ONE


func _ready() -> void:
	if not secreta:
		_forzar_visible(1.0)
		return
	_forzar_visible(0.0)

	# ejes de la cara: los dos lados mas grandes de la caja
	var delgado := 0
	if size.y < size[delgado]:
		delgado = 1
	if size.z < size[delgado]:
		delgado = 2
	var eje_u := 2 if delgado == 0 else 0
	var eje_v := 1 if delgado != 1 else 2
	_mask_min = Vector2(-size[eje_u], -size[eje_v]) * 0.5
	_mask_size = Vector2(size[eje_u], size[eje_v])

	_mask_bytes.resize(MASK_W * MASK_H)
	_mask_bytes.fill(255)
	_mask_texture = ImageTexture.create_from_image(Image.create_from_data(MASK_W, MASK_H, false, Image.FORMAT_R8, _mask_bytes))
	_texel_positions.resize(MASK_W * MASK_H)
	for y in MASK_H:
		for x in MASK_W:
			var local := Vector3.ZERO
			local[eje_u] = _mask_min.x + (x + 0.5) / MASK_W * _mask_size.x
			local[eje_v] = _mask_min.y + (1.0 - (y + 0.5) / MASK_H) * _mask_size.y
			_texel_positions[y * MASK_W + x] = to_global(local)

	# el shader lee local.xy: se reordenan los ejes para que xy sean los de la cara
	var cols := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	cols[eje_u] = Vector3(1, 0, 0)
	cols[eje_v] = Vector3(0, 1, 0)
	cols[delgado] = Vector3(0, 0, 1)
	var permuta := Transform3D(Basis(cols[0], cols[1], cols[2]), Vector3.ZERO)
	var world_to_mask := Projection(permuta * global_transform.affine_inverse())
	for mat in _materiales():
		mat.set_shader_parameter("reveal_mask", _mask_texture)
		mat.set_shader_parameter("use_reveal_mask", true)
		mat.set_shader_parameter("world_to_mask", world_to_mask)
		mat.set_shader_parameter("mask_min", _mask_min)
		mat.set_shader_parameter("mask_size", _mask_size)


func _forzar_visible(v: float) -> void:
	set_instance_shader_parameter("force_visible", v)
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).set_instance_shader_parameter("force_visible", v)


func _materiales() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	if material is ShaderMaterial:
		out.append(material)
	for g in find_children("*", "GeometryInstance3D", true, false):
		var geom := g as GeometryInstance3D
		if geom.material_override is ShaderMaterial and not out.has(geom.material_override):
			out.append(geom.material_override as ShaderMaterial)
		if geom is MeshInstance3D:
			var surf := (geom as MeshInstance3D).get_surface_override_material(0)
			if surf is ShaderMaterial and not out.has(surf):
				out.append(surf as ShaderMaterial)
	return out


func _process(delta: float) -> void:
	if not secreta or abierto:
		return
	_paint_timer += delta
	if _paint_timer < PAINT_INTERVAL:
		return
	_paint_timer = 0.0
	if linterna == null:
		linterna = get_tree().current_scene.find_child("Linterna", true, false) as Linterna
		if linterna == null:
			return
	if linterna.current_channel == Linterna.Channel.VIOLET and linterna.spot_light_3d.visible:
		_paint(linterna.spot_light_3d)


func _paint(spot: SpotLight3D) -> void:
	var origin := spot.global_position
	var dir := -spot.global_transform.basis.z
	var angle := spot.spot_angle - 2.0
	var cos_end := cos(deg_to_rad(angle))
	var cos_start := cos(deg_to_rad(angle - FADE_DEGREES))
	var changed := false
	var borrados := 0
	for i in _texel_positions.size():
		var v := _texel_positions[i] - origin
		if v.length() < 7.0:
			var c := v.normalized().dot(dir)
			if c > cos_end:
				var luz := int(clampf((c - cos_end) / (cos_start - cos_end), 0.0, 1.0) * 255.0)
				var valor := 255 - luz
				if valor < _mask_bytes[i]:
					_mask_bytes[i] = valor
					changed = true
		if _mask_bytes[i] < 128:
			borrados += 1
	if changed:
		_mask_texture.update(Image.create_from_data(MASK_W, MASK_H, false, Image.FORMAT_R8, _mask_bytes))
	if borrados > _mask_bytes.size() * UMBRAL:
		_abrir()


## Termina de borrar el muro, apaga su colision y avisa.
func _abrir() -> void:
	abierto = true
	use_collision = false
	var t := create_tween()
	t.tween_method(_desvanecer, 0.0, 1.0, 0.8)
	if evento != "":
		var player := get_tree().current_scene.find_child("Player", true, false)
		if player != null and player.has_signal("evento"):
			player.evento.emit(evento)
	revelado.emit()


func _desvanecer(k: float) -> void:
	var limite := int(255.0 * (1.0 - k))
	for i in _mask_bytes.size():
		_mask_bytes[i] = mini(_mask_bytes[i], limite)
	_mask_texture.update(Image.create_from_data(MASK_W, MASK_H, false, Image.FORMAT_R8, _mask_bytes))
	if k >= 1.0:
		visible = false
