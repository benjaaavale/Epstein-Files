extends Node3D

## Rastro de pisadas ensangrentadas sobre el piso: solo se ve con la luz roja.
## "puntos" marca el recorrido (coordenadas locales, la altura se ajusta al piso).

const SHADER := preload("res://luz_revela.gdshader")
const HUELLA := preload("res://mapa/texturas/huella.png")
const GOTAS := preload("res://mapa/texturas/gotas.png")

@export var puntos := PackedVector3Array()
@export var paso := 0.62
@export var cada_gotas := 4

var _mat_huella: ShaderMaterial
var _mat_gotas: ShaderMaterial


func _ready() -> void:
	_mat_huella = _material(HUELLA)
	_mat_gotas = _material(GOTAS)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var recorrido := 0.0
	var n := 0
	for i in puntos.size() - 1:
		var a := puntos[i]
		var b := puntos[i + 1]
		var largo := a.distance_to(b)
		var dir := (b - a).normalized()
		var lado := Vector3(dir.z, 0.0, -dir.x)
		while recorrido < largo:
			var p := a + dir * recorrido + lado * (0.1 if n % 2 == 0 else -0.1)
			_poner(p, dir, Vector2(0.17, 0.34), _mat_huella, n % 2 == 1)
			if cada_gotas > 0 and n % cada_gotas == 2:
				_poner(p - lado * 0.25 + dir * 0.2, dir.rotated(Vector3.UP, randf() * TAU), Vector2(0.35, 0.35), _mat_gotas, false)
			recorrido += paso
			n += 1
		recorrido -= largo


func _material(tex: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo_texture", tex)
	m.set_shader_parameter("light_channel", 1)
	m.set_shader_parameter("unshaded_look", true)
	m.set_shader_parameter("albedo", Color(2.2, 1.4, 1.4))
	return m


func _poner(p: Vector3, dir: Vector3, tam: Vector2, mat: ShaderMaterial, espejo: bool) -> void:
	var g := to_global(p)
	var q := PhysicsRayQueryParameters3D.create(g + Vector3.UP * 0.8, g + Vector3.DOWN * 0.8, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var y := g.y
	if not hit.is_empty():
		y = (hit.position as Vector3).y
	var m := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = tam
	quad.orientation = PlaneMesh.FACE_Y
	m.mesh = quad
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	var adelante := Vector3(dir.x, 0.0, dir.z).normalized()
	var base := Basis.looking_at(-adelante, Vector3.UP)
	if espejo:
		base = base * Basis.from_scale(Vector3(-1, 1, 1))
	m.global_transform = Transform3D(base.rotated(Vector3.UP, randf_range(-0.12, 0.12)), Vector3(g.x, y + 0.006, g.z))
