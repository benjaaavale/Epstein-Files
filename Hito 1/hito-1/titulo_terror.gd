class_name TituloTerror
extends Control

## Titulo con desfase de color (rojo/cian), glitches esporadicos y, opcionalmente,
## sangre que gotea lento desde las letras.

var texto := ""
var tamano := 64
var color := UIEstilo.HUESO
var frecuencia_glitch := 0.35
## Gotas de sangre que bajan desde la base del texto.
var goteo := false

var _fuente: Font
var _glitch := 0.0
var _desfase := Vector2.ZERO
var _apagado := false
var _gotas: Array[Dictionary] = []


func _init(t: String = "", s: int = 64) -> void:
	texto = t
	tamano = s
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_fuente = UIEstilo.fuente_titulo()
	# alto justo de las mayusculas (la fuente de titulos trae mucho interlineado)
	var ancho_texto := _fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
	custom_minimum_size = Vector2(ancho_texto + 10.0, _fuente.get_ascent(tamano) * 0.92 + (tamano * 0.3 if goteo else 6.0))
	if goteo:
		var ancho := custom_minimum_size.x - 10.0
		for i in int(ancho / 38.0):
			_gotas.append({
				"x": 5.0 + randf() * ancho,
				"largo": 0.0,
				"max": randf_range(8.0, tamano * 0.55),
				"vel": randf_range(1.5, 6.0),
				"ancho": randf_range(1.5, 3.5),
				"espera": randf() * 6.0,
			})


func glitch(duracion: float = 0.2) -> void:
	_glitch = duracion


func _process(delta: float) -> void:
	var redibujar := false
	if _glitch > 0.0:
		_glitch -= delta
		_desfase = Vector2(randf_range(-5.0, 5.0), randf_range(-1.5, 1.5))
		_apagado = randf() < 0.2
		if _glitch <= 0.0:
			_desfase = Vector2.ZERO
			_apagado = false
		redibujar = true
	elif randf() < delta * frecuencia_glitch:
		_glitch = randf_range(0.06, 0.22)
	for g in _gotas:
		if g.espera > 0.0:
			g.espera -= delta
			continue
		if g.largo < g.max:
			g.largo = minf(g.largo + g.vel * delta, g.max)
			redibujar = true
		elif randf() < delta * 0.05:
			# la gota cae y vuelve a empezar
			g.largo = 0.0
			g.max = randf_range(8.0, tamano * 0.55)
			g.espera = randf_range(1.0, 5.0)
			redibujar = true
	if redibujar:
		queue_redraw()


func _draw() -> void:
	var base := Vector2(5.0, _fuente.get_ascent(tamano) * 0.92)
	var activo := _glitch > 0.0
	var corrimiento := 4.0 if activo else 1.3
	for g in _gotas:
		if g.largo <= 0.5:
			continue
		var x: float = g.x
		var y0 := base.y - 2.0
		var sangre := Color(0.45, 0.02, 0.02, 0.9)
		draw_line(Vector2(x, y0), Vector2(x, y0 + g.largo), sangre, g.ancho, true)
		draw_circle(Vector2(x, y0 + g.largo), g.ancho * 0.9, sangre, true, -1.0, true)
	draw_string(_fuente, base + Vector2(-corrimiento, 0.0) + _desfase, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, Color(0.7, 0.05, 0.05, 0.6))
	draw_string(_fuente, base + Vector2(corrimiento * 0.6, 0.0) - _desfase * 0.5, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, Color(0.2, 0.55, 0.6, 0.25 if activo else 0.1))
	draw_string(_fuente, base + _desfase * 0.3, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, Color(color, 0.45 if _apagado else 1.0))
