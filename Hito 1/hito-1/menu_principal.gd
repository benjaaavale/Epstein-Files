extends Control

## Menu principal: oscuridad total y un foco que deambula revelando mensajes escritos en la pared.

const MENSAJES := [
	["SIGUE LA LUZ", Vector2(0.62, 0.22), -6.0, 46],
	["NO ESTÁS SOLO", Vector2(0.7, 0.62), 4.0, 38],
	["8350", Vector2(0.5, 0.8), -3.0, 64],
	["ELLA TE VE", Vector2(0.84, 0.4), 8.0, 30],
	["NO MIRES ATRÁS", Vector2(0.38, 0.12), 2.0, 26],
]

var _contenido: VBoxContainer
var _titulo_a: TituloTerror
var _titulo_b: TituloTerror
var _botones: Array[MenuBoton] = []
var _negro: ColorRect
var _opciones: PanelOpciones
var _ambiente: AudioStreamPlayer
var _saliendo := false


func _ready() -> void:
	UIEstilo.llenar(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_construir()
	_animar_entrada()


func _construir() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.035, 0.03, 0.03)
	UIEstilo.llenar(fondo)
	add_child(fondo)

	# Mensajes ocultos: solo se leen cuando el foco pasa encima
	for m in MENSAJES:
		var l := UIEstilo.label(m[0], m[3], Color(UIEstilo.SANGRE, 0.85))
		l.anchor_left = m[1].x
		l.anchor_right = m[1].x
		l.anchor_top = m[1].y
		l.anchor_bottom = m[1].y
		l.rotation_degrees = m[2]
		add_child(l)

	add_child(UIEstilo.capa_ruido({
		"darkness": 0.96, "light_amount": 1.0, "light_radius": 0.32,
		"vignette_amount": 0.6, "grain_amount": 0.0, "flicker_amount": 0.08,
	}))

	var caja := Control.new()
	UIEstilo.llenar(caja)
	add_child(caja)
	_contenido = UIEstilo.columna_izquierda(560.0, 520.0)
	_contenido.offset_top -= 20.0
	caja.add_child(_contenido)

	_contenido.add_child(UIEstilo.label("— EXPEDIENTE N° 0417", 11, UIEstilo.SANGRE, true))
	_titulo_a = TituloTerror.new("SHADE", 104)
	_titulo_b = TituloTerror.new("MANSION", 104)
	_titulo_b.frecuencia_glitch = 0.2
	_contenido.add_child(_titulo_a)
	_contenido.add_child(_titulo_b)
	_contenido.add_child(UIEstilo.label("La luz revela lo que la casa esconde.", 17, Color(UIEstilo.HUESO, 0.6)))
	_contenido.add_child(Rasgo.new(380.0))
	_contenido.add_child(UIEstilo.espacio(26))

	_boton("ENTRAR", _on_jugar)
	_boton("OPCIONES", func() -> void: _opciones.abrir())
	_boton("SALIR", func() -> void: get_tree().quit())

	var estudio := UIEstilo.label("DIDDY GAMES", 10, Color(UIEstilo.HUESO, 0.4), true)
	estudio.anchor_left = 0.09
	estudio.anchor_top = 1.0
	estudio.anchor_bottom = 1.0
	estudio.offset_top = -56.0
	add_child(estudio)

	var curso := UIEstilo.label("CC5408", 10, Color(UIEstilo.HUESO, 0.4), true)
	curso.anchor_left = 1.0
	curso.anchor_right = 1.0
	curso.anchor_top = 1.0
	curso.anchor_bottom = 1.0
	curso.offset_left = -300.0
	curso.offset_right = -48.0
	curso.offset_top = -56.0
	curso.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(curso)

	add_child(UIEstilo.capa_ruido({"vignette_amount": 0.0, "grain_amount": 0.08, "flicker_amount": 0.0}))

	_opciones = PanelOpciones.new()
	add_child(_opciones)

	_negro = ColorRect.new()
	_negro.color = Color.BLACK
	UIEstilo.llenar(_negro)
	add_child(_negro)

	_ambiente = AudioStreamPlayer.new()
	_ambiente.stream = load("res://assets varios/ambiente_loop.wav")
	_ambiente.volume_db = -12.0
	_ambiente.autoplay = true
	add_child(_ambiente)


func _boton(texto: String, accion: Callable) -> void:
	var b := MenuBoton.new(texto, 28)
	b.pressed.connect(accion)
	b.modulate.a = 0.0
	_botones.append(b)
	_contenido.add_child(b)


func _animar_entrada() -> void:
	var t := create_tween()
	t.tween_property(_negro, "modulate:a", 0.0, 2.0).set_trans(Tween.TRANS_SINE)
	t.tween_callback(_titulo_a.glitch.bind(0.35))
	for b in _botones:
		t.tween_property(b, "modulate:a", 1.0, 0.25)


func _on_jugar() -> void:
	if _saliendo:
		return
	_saliendo = true
	_titulo_b.glitch(0.6)
	var t := create_tween().set_parallel(true)
	t.tween_property(_negro, "modulate:a", 1.0, 1.1)
	t.tween_property(_ambiente, "volume_db", -60.0, 1.1)
	t.chain().tween_callback(func() -> void: Ajustes.ir_a(Ajustes.NIVEL_1))
