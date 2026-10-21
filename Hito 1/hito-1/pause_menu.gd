extends CanvasLayer

var _raiz: Control
var _contenido: VBoxContainer
var _caja: Control
var _titulo: TituloTerror
var _opciones: PanelOpciones


func _ready() -> void:
	layer = 50
	_construir()
	hide()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("PauseMenu"):
		return
	get_viewport().set_input_as_handled()
	if visible and _opciones.visible:
		_opciones.cerrar()
		return
	if get_tree().paused and not visible:
		return
	_set_pausa(not visible)


func _set_pausa(activa: bool) -> void:
	get_tree().paused = activa
	visible = activa
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if activa else Input.MOUSE_MODE_CAPTURED)
	if activa:
		_raiz.modulate.a = 0.0
		_caja.position.x = -18.0
		var t := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(_raiz, "modulate:a", 1.0, 0.2)
		t.tween_property(_caja, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_titulo.glitch(0.3)


func _construir() -> void:
	_raiz = Control.new()
	UIEstilo.llenar(_raiz)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)

	var fondo := ColorRect.new()
	fondo.color = Color(0.02, 0.0, 0.0, 0.62)
	UIEstilo.llenar(fondo)
	_raiz.add_child(fondo)
	_raiz.add_child(UIEstilo.capa_ruido({"vignette_amount": 0.95, "grain_amount": 0.09, "flicker_amount": 0.1}))

	_caja = Control.new()
	UIEstilo.llenar(_caja)
	_raiz.add_child(_caja)
	_contenido = UIEstilo.columna_izquierda(460.0, 420.0)
	_contenido.anchor_left = 0.13
	_contenido.anchor_right = 0.13
	_caja.add_child(_contenido)

	_contenido.add_child(UIEstilo.label("— EXPEDIENTE EN PAUSA", 11, UIEstilo.SANGRE, true))
	_titulo = TituloTerror.new("PAUSA", 72)
	_contenido.add_child(_titulo)
	_contenido.add_child(Rasgo.new(260.0))
	_contenido.add_child(UIEstilo.espacio(18))

	_boton("CONTINUAR", func() -> void: _set_pausa(false))
	_boton("OPCIONES", func() -> void: _opciones.abrir())
	_boton("REINICIAR NIVEL", func() -> void: Ajustes.reiniciar_nivel())
	_boton("MENÚ PRINCIPAL", func() -> void: Ajustes.ir_a(Ajustes.MENU_PRINCIPAL))
	_boton("SALIR DEL JUEGO", func() -> void: get_tree().quit())

	var pie := UIEstilo.label("[ESC]  VOLVER", 11, Color(UIEstilo.HUESO, 0.4), true)
	pie.anchor_left = 0.13
	pie.anchor_top = 1.0
	pie.anchor_bottom = 1.0
	pie.offset_top = -64.0
	_raiz.add_child(pie)

	_opciones = PanelOpciones.new()
	_raiz.add_child(_opciones)


func _boton(texto: String, accion: Callable) -> void:
	var b := MenuBoton.new(texto, 24)
	b.pressed.connect(accion)
	_contenido.add_child(b)
