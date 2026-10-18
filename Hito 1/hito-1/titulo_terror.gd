class_name TituloTerror
extends Control

## Titulo con desfase de color (rojo/cian) y glitches esporadicos.

var texto := ""
var tamano := 64
var color := UIEstilo.HUESO
var frecuencia_glitch := 0.35

var _fuente: Font
var _glitch := 0.0
var _desfase := Vector2.ZERO
var _apagado := false


func _init(t: String = "", s: int = 64) -> void:
	texto = t
	tamano = s
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_fuente = UIEstilo.fuente()
	custom_minimum_size = _fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano) + Vector2(10, 8)


func glitch(duracion: float = 0.2) -> void:
	_glitch = duracion


func _process(delta: float) -> void:
	if _glitch > 0.0:
		_glitch -= delta
		_desfase = Vector2(randf_range(-5.0, 5.0), randf_range(-1.5, 1.5))
		_apagado = randf() < 0.2
		if _glitch <= 0.0:
			_desfase = Vector2.ZERO
			_apagado = false
		queue_redraw()
	elif randf() < delta * frecuencia_glitch:
		_glitch = randf_range(0.06, 0.22)


func _draw() -> void:
	var base := Vector2(5.0, _fuente.get_ascent(tamano) + 2.0)
	var activo := _glitch > 0.0
	var corrimiento := 4.0 if activo else 1.3
	draw_string(_fuente, base + Vector2(-corrimiento, 0.0) + _desfase, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, Color(0.7, 0.05, 0.05, 0.6))
	draw_string(_fuente, base + Vector2(corrimiento * 0.6, 0.0) - _desfase * 0.5, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, Color(0.2, 0.55, 0.6, 0.25 if activo else 0.1))
	draw_string(_fuente, base + _desfase * 0.3, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, Color(color, 0.45 if _apagado else 1.0))
