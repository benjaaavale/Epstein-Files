@tool
extends MeshInstance3D

## Foto de una de las personas desaparecidas, clavada en la pared.

@export_range(1, 6) var numero := 1:
	set(v):
		numero = v
		_armar()


func _ready() -> void:
	_armar()


func _armar() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(0.24, 0.3)
	mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://mapa/texturas/foto_desaparecido_%d.png" % numero)
	m.roughness = 0.7
	material_override = m
