class_name PanelOpciones
extends Control

signal cerrado

var _sensibilidad: HSlider
var _sensibilidad_valor: Label
var _volumen: HSlider
var _volumen_valor: Label
var _pantalla: MenuBoton
var _titulo: TituloTerror


func _ready() -> void:
	UIEstilo.llenar(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.0, 0.0, 0.85)
	UIEstilo.llenar(fondo)
	add_child(fondo)
	add_child(UIEstilo.capa_ruido({"vignette_amount": 0.9, "grain_amount": 0.08}))

	var col := UIEstilo.columna_izquierda(560.0, 420.0)
	add_child(col)
	col.add_child(UIEstilo.label("— AJUSTES", 11, UIEstilo.SANGRE, true))
	_titulo = TituloTerror.new("OPCIONES", 54)
	col.add_child(_titulo)
	col.add_child(Rasgo.new(300.0))
	col.add_child(UIEstilo.espacio(14))

	var fila_sens := _fila(col, "SENSIBILIDAD DEL MOUSE", 0.3, 2.5, 0.05)
	_sensibilidad = fila_sens[0]
	_sensibilidad_valor = fila_sens[1]
	_sensibilidad.value_changed.connect(_on_sensibilidad)

	var fila_vol := _fila(col, "VOLUMEN", 0.0, 1.0, 0.05)
	_volumen = fila_vol[0]
	_volumen_valor = fila_vol[1]
	_volumen.value_changed.connect(_on_volumen)

	col.add_child(UIEstilo.espacio(10))
	_pantalla = MenuBoton.new("", 20)
	_pantalla.pressed.connect(_on_pantalla)
	col.add_child(_pantalla)
	var volver := MenuBoton.new("VOLVER", 20)
	volver.pressed.connect(cerrar)
	col.add_child(volver)


func _fila(padre: Control, titulo: String, minimo: float, maximo: float, paso: float) -> Array:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	caja.add_child(UIEstilo.label(titulo, 11, Color(UIEstilo.HUESO, 0.6), true))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 18)
	var slider := HSlider.new()
	slider.min_value = minimo
	slider.max_value = maximo
	slider.step = paso
	slider.custom_minimum_size = Vector2(320, 22)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIEstilo.estilizar_slider(slider)
	var valor := UIEstilo.label("", 16)
	valor.custom_minimum_size.x = 70
	fila.add_child(slider)
	fila.add_child(valor)
	caja.add_child(fila)
	padre.add_child(caja)
	return [slider, valor]


func abrir() -> void:
	_sensibilidad.set_value_no_signal(Ajustes.sensibilidad)
	_volumen.set_value_no_signal(Ajustes.volumen)
	_actualizar_textos()
	visible = true
	modulate.a = 0.0
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(self, "modulate:a", 1.0, 0.25)
	_titulo.glitch(0.25)


func cerrar() -> void:
	if not visible:
		return
	Ajustes.guardar()
	visible = false
	cerrado.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		cerrar()
		get_viewport().set_input_as_handled()


func _on_sensibilidad(v: float) -> void:
	Ajustes.sensibilidad = v
	_actualizar_textos()


func _on_volumen(v: float) -> void:
	Ajustes.volumen = v
	Ajustes.aplicar()
	_actualizar_textos()


func _on_pantalla() -> void:
	Ajustes.pantalla_completa = not Ajustes.pantalla_completa
	Ajustes.aplicar()
	_actualizar_textos()


func _actualizar_textos() -> void:
	_sensibilidad_valor.text = "%.2fx" % Ajustes.sensibilidad
	_volumen_valor.text = "%d%%" % roundi(Ajustes.volumen * 100.0)
	_pantalla.text = "PANTALLA COMPLETA: " + ("SÍ" if Ajustes.pantalla_completa else "NO")
