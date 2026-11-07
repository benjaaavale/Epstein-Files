@tool
extends MeshInstance3D
class_name Escrito

## Algo pintado en una superficie (pared, piso) que solo se ve con un color de luz.
## Sirve para pistas (codigos, frases, rastros) y para ambientar.

enum Canal { AZUL, ROJA, MORADA, SIEMPRE }

const SHADER := preload("res://luz_revela.gdshader")

@export var textura: Texture2D:
	set(v):
		textura = v
		_armar()
@export var canal: Canal = Canal.ROJA:
	set(v):
		canal = v
		_armar()
@export var tamano := Vector2(1.6, 0.8):
	set(v):
		tamano = v
		_armar()
## Color con que brilla al revelarse (puede pasar de 1 para que resalte).
@export var color := Color(1.6, 0.22, 0.18):
	set(v):
		color = v
		_armar()
## En el piso: el quad mira hacia arriba.
@export var en_el_piso := false:
	set(v):
		en_el_piso = v
		_armar()


func _ready() -> void:
	_armar()


func _armar() -> void:
	if not is_inside_tree() and not Engine.is_editor_hint():
		return
	var q := QuadMesh.new()
	q.size = tamano
	if en_el_piso:
		q.orientation = PlaneMesh.FACE_Y
	mesh = q
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo_texture", textura)
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("unshaded_look", true)
	m.set_shader_parameter("light_channel", 2 if canal == Canal.SIEMPRE else int(canal))
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_instance_shader_parameter("force_visible", 1.0 if canal == Canal.SIEMPRE else 0.0)
