extends Node3D

## Cable pintado sobre la pared: solo se ve con la luz morada.
## "puntos" son coordenadas locales de este nodo; se une cada par con un tramo recto.

const SHADER := preload("res://luz_revela.gdshader")

@export var puntos := PackedVector3Array()
@export var grosor := 0.018
@export var color := Color(0.8, 0.45, 1.0)

static var _material: ShaderMaterial


func _ready() -> void:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter("light_channel", 2)
		_material.set_shader_parameter("unshaded_look", true)
		_material.set_shader_parameter("albedo", color)
	for i in puntos.size() - 1:
		_tramo(puntos[i], puntos[i + 1])
		_grapa(puntos[i])
	if puntos.size() > 0:
		_grapa(puntos[puntos.size() - 1])


func _tramo(a: Vector3, b: Vector3) -> void:
	var largo := a.distance_to(b)
	if largo < 0.001:
		return
	var m := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(grosor, grosor, largo)
	m.mesh = caja
	m.material_override = _material
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	var arriba := Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT
	m.transform = Transform3D(Basis.looking_at(b - a, arriba), (a + b) * 0.5)


func _grapa(p: Vector3) -> void:
	var m := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = grosor * 0.9
	esfera.height = grosor * 1.8
	esfera.radial_segments = 8
	esfera.rings = 4
	m.mesh = esfera
	m.material_override = _material
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = p
	add_child(m)
