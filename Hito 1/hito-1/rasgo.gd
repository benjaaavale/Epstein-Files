class_name Rasgo
extends Control

## Linea irregular, como trazada a mano con algo rojo.

var progreso := 1.0
var color := UIEstilo.SANGRE
var semilla := 7

var _puntos := PackedVector2Array()


func _init(ancho: float = 240.0) -> void:
	custom_minimum_size = Vector2(ancho, 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(_generar)
	_generar()


func set_progreso(v: float) -> void:
	progreso = v
	queue_redraw()


func _generar() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	_puntos.clear()
	var tramos := 26
	for i in tramos + 1:
		var x := size.x * float(i) / tramos
		_puntos.append(Vector2(x, size.y * 0.5 + rng.randf_range(-1.7, 1.7)))
	queue_redraw()


func _draw() -> void:
	if progreso <= 0.0 or _puntos.size() < 2:
		return
	var cantidad := clampi(int(ceil(progreso * (_puntos.size() - 1))) + 1, 2, _puntos.size())
	var trazo := _puntos.slice(0, cantidad)
	draw_polyline(trazo, color, 2.0, true)
	var sombra := PackedVector2Array()
	for p in trazo:
		sombra.append(p + Vector2(1.0, 1.6))
	draw_polyline(sombra, Color(color, 0.35), 1.0, true)
