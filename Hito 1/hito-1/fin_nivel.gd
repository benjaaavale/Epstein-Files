extends CanvasLayer

var _fondo: ColorRect
var _contenido: VBoxContainer
var _titulo: TituloTerror
var _subtitulo: Label
var _rasgo: Rasgo


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var pausa := get_tree().current_scene.find_child("PauseMenu", true, false)
	if pausa:
		pausa.set_process_input(false)
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_construir()
	_animar_entrada()


func _construir() -> void:
	var raiz := Control.new()
	UIEstilo.llenar(raiz)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(raiz)

	_fondo = ColorRect.new()
	_fondo.color = Color(0.0, 0.0, 0.0, 0.94)
	UIEstilo.llenar(_fondo)
	raiz.add_child(_fondo)
	raiz.add_child(UIEstilo.capa_ruido({"vignette_amount": 0.9, "grain_amount": 0.09, "flicker_amount": 0.12}))

	var caja := Control.new()
	UIEstilo.llenar(caja)
	raiz.add_child(caja)
	_contenido = UIEstilo.columna_izquierda(620.0, 470.0)
	caja.add_child(_contenido)

	_contenido.add_child(UIEstilo.label("— CASO 01 · LA MANSIÓN", 11, UIEstilo.SANGRE, true))
	_titulo = TituloTerror.new("ESCAPASTE", 84)
	_titulo.frecuencia_glitch = 0.6
	_contenido.add_child(_titulo)
	_subtitulo = UIEstilo.label("...por ahora.", 22, Color(UIEstilo.HUESO, 0.7))
	_contenido.add_child(_subtitulo)
	_rasgo = Rasgo.new(340.0)
	_rasgo.progreso = 0.0
	_contenido.add_child(_rasgo)
	_contenido.add_child(UIEstilo.espacio(8))

	var segundos := (Time.get_ticks_msec() - Ajustes.inicio_nivel_ms) / 1000
	var tiempo := "TIEMPO EN LA CASA   %02d:%02d" % [segundos / 60, segundos % 60]
	_contenido.add_child(UIEstilo.label(tiempo, 12, Color(UIEstilo.HUESO, 0.55), true))
	_contenido.add_child(UIEstilo.espacio(22))

	_boton("VOLVER A ENTRAR", func() -> void: Ajustes.reiniciar_nivel())
	_boton("MENÚ PRINCIPAL", func() -> void: Ajustes.ir_a(Ajustes.MENU_PRINCIPAL))
	_boton("SALIR DEL JUEGO", func() -> void: get_tree().quit())


func _boton(texto: String, accion: Callable) -> void:
	var b := MenuBoton.new(texto, 24)
	b.pressed.connect(accion)
	_contenido.add_child(b)


func _animar_entrada() -> void:
	_fondo.modulate.a = 0.0
	_contenido.modulate.a = 0.0
	_subtitulo.visible_ratio = 0.0
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(_fondo, "modulate:a", 1.0, 1.2)
	t.tween_callback(_titulo.glitch.bind(0.4))
	t.tween_property(_contenido, "modulate:a", 1.0, 0.6)
	t.tween_property(_subtitulo, "visible_ratio", 1.0, 0.9)
	t.tween_method(_rasgo.set_progreso, 0.0, 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
