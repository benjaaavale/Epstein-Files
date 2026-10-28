extends CanvasLayer
class_name Hud

signal documento_cerrado
signal candado_cerrado(abierto: bool)

const HUESO := UIEstilo.HUESO
const SANGRE := UIEstilo.SANGRE
const MARGEN := 44.0
const NOMBRES_LENTE := ["LUZ BLANCA", "LUZ ROJA", "LUZ AZUL", "LUZ MORADA"]
const COLORES_LENTE := [
	Color(0.84, 0.81, 0.74),
	Color(0.85, 0.18, 0.16),
	Color(0.3, 0.5, 0.95),
	Color(0.6, 0.35, 0.95),
]
const SEGUNDOS_INACTIVO := 3.0

var linterna: Linterna = null

var _raiz: Control
var _ruido: ShaderMaterial
var _mira: Mira
var _cinematica := false
var _siguiente_parpadeo := 8.0

var _accion: HBoxContainer
var _accion_tecla: Label
var _accion_texto: Label
var _accion_estado := ""
var _accion_tween: Tween

var _lente: Control
var _lente_rueda: RuedaLentes
var _lente_nombre: Label
var _lente_canal := -1
var _lente_inactivo := 0.0
var _lente_tween: Tween

var _objeto: Control
var _objeto_contenido: VBoxContainer
var _objeto_nombre: Label
var _objeto_visible := false
var _objeto_tween: Tween

var _aviso: VBoxContainer
var _aviso_titulo_sup: Label
var _aviso_titulo: Label
var _aviso_rasgo: Rasgo
var _aviso_tween: Tween

var _subtitulo: Label
var _cola_dialogo: Array[String] = []
var _dialogo_activo := false

var _documento: Control
var _documento_abierto := false

var _bateria: BarraBateria

var _candado: Control
var _candado_ruedas: Array[Label] = []
var _candado_marcos: Array[Panel] = []
var _candado_digitos := PackedInt32Array()
var _candado_sel := 0
var _candado_probar: Callable
var _candado_abierto := false
var _candado_fila: HBoxContainer
var _clic: AudioStreamPlayer

var _destello: ColorRect

#Cosas del inventario
var _inventario_fila: HBoxContainer
var _inv_fondos: Array[ColorRect] = []
var _inv_iconos: Array[TextureRect] = []
var _inv_nombres: Array[Label] = []
var _inv_tweens: Array[Tween] = [null, null, null, null]
var _aviso_lleno: Label
var _aviso_lleno_tween: Tween


func _ready() -> void:
	_raiz = Control.new()
	UIEstilo.llenar(_raiz)
	add_child(_raiz)
	var capa := UIEstilo.capa_ruido({"vignette_amount": 0.75, "grain_amount": 0.06, "flicker_amount": 0.07})
	_ruido = capa.material
	_raiz.add_child(capa)
	_construir_mira()
	_construir_accion()
	_construir_lente()
	_construir_objeto()
	_construir_aviso()
	_construir_subtitulo()
	_construir_documento()
	_construir_candado()
	_construir_inventario()
	_construir_aviso_lleno()
	_destello = ColorRect.new()
	_destello.color = Color(0.02, 0, 0)
	UIEstilo.llenar(_destello)
	_destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_destello.modulate.a = 0.0
	add_child(_destello)


func _process(delta: float) -> void:
	if linterna != null:
		var canal := int(linterna.current_channel)
		if canal != _lente_canal:
			_on_lente_cambiado(canal)
			
		_bateria.nivel = linterna.bateria
		
		# --- ESTA ES LA PARTE CLAVE QUE ACTUALIZA LA LISTA ---
		if _lente_rueda.disponibles.size() != linterna.colores_disponibles.size():
			_lente_rueda.disponibles = linterna.colores_disponibles.duplicate()
			_lente_rueda.queue_redraw() # Obliga a redibujar si recogiste un filtro nuevo
		# -----------------------------------------------------
			
		if _lente_rueda.mostrar_morada != linterna.combo_unlocked:
			_lente_rueda.mostrar_morada = linterna.combo_unlocked
			_lente_rueda.queue_redraw()
			
	if _cinematica:
		return
		
	_lente_inactivo += delta
	var alfa := 1.0 if _lente_inactivo < SEGUNDOS_INACTIVO else 0.5
	_lente.modulate.a = move_toward(_lente.modulate.a, alfa, delta * 1.2)

	# Cada tanto la interfaz "falla" un instante, como una señal que se corta
	_siguiente_parpadeo -= delta
	if _siguiente_parpadeo <= 0.0:
		_siguiente_parpadeo = randf_range(7.0, 16.0)
		_parpadeo()


# ---------- API ----------

func show_prompt(tecla: String, texto: String, habilitado: bool = true) -> void:
	var estado := "%s|%s|%s" % [tecla, texto, habilitado]
	if estado == _accion_estado:
		return
	_accion_estado = estado
	_accion_tecla.visible = tecla != ""
	_accion_tecla.text = "[%s]" % tecla
	_accion_texto.text = texto.to_upper()
	_accion_texto.add_theme_color_override("font_color", HUESO if habilitado else Color(SANGRE, 0.95))
	_mira.objetivo = 1.0
	_mira.bloqueado = not habilitado
	_mira.queue_redraw()
	if _accion_tween:
		_accion_tween.kill()
	_accion_tween = create_tween()
	_accion.modulate.a = 1.0
	_accion_texto.visible_ratio = 0.0
	_accion_tween.tween_property(_accion_texto, "visible_ratio", 1.0, 0.03 * texto.length())


func hide_prompt() -> void:
	if _accion_estado == "":
		return
	_accion_estado = ""
	_mira.objetivo = 0.0
	if _accion_tween:
		_accion_tween.kill()
	_accion_tween = create_tween()
	_accion_tween.tween_property(_accion, "modulate:a", 0.0, 0.12)


func set_held_item(nombre: String) -> void:
	var mostrar := nombre != ""
	if mostrar:
		_objeto_nombre.text = nombre.to_upper()
	if mostrar == _objeto_visible:
		return
	_objeto_visible = mostrar
	if _objeto_tween:
		_objeto_tween.kill()
	_objeto_tween = create_tween().set_parallel(true)
	_objeto_tween.tween_property(_objeto, "modulate:a", 1.0 if mostrar else 0.0, 0.3 if mostrar else 0.2)
	if mostrar:
		_objeto_contenido.position.x = 26.0
		_objeto_tween.tween_property(_objeto_contenido, "position:x", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func toast(titulo: String, titulo_superior: String = "") -> void:
	_aviso_titulo_sup.text = titulo_superior
	_aviso_titulo_sup.visible = titulo_superior != ""
	_aviso_titulo.text = titulo.to_upper()
	_aviso_titulo.visible_ratio = 0.0
	_aviso_rasgo.semilla = randi()
	_aviso_rasgo._generar()
	_aviso_rasgo.set_progreso(0.0)
	if _aviso_tween:
		_aviso_tween.kill()
	_aviso_tween = create_tween().set_parallel(true)
	_aviso_tween.tween_property(_aviso, "modulate:a", 1.0, 0.15)
	_aviso_tween.tween_property(_aviso_titulo, "visible_ratio", 1.0, 0.035 * titulo.length())
	_aviso_tween.tween_method(_aviso_rasgo.set_progreso, 0.0, 1.0, 0.6).set_delay(0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_aviso_tween.tween_method(_temblor, 1.0, 0.0, 0.3)
	_aviso_tween.chain().tween_interval(2.3)
	_aviso_tween.chain().tween_property(_aviso, "modulate:a", 0.0, 0.9)


func set_cinematic(activa: bool) -> void:
	_cinematica = activa
	if activa:
		hide_prompt()
	var t := create_tween().set_parallel(true)
	if activa:
		for c: Control in [_mira, _accion, _lente, _objeto, _inventario_fila]:
			t.tween_property(c, "modulate:a", 0.0, 0.5)
	else:
		_accion_estado = ""
		_accion.modulate.a = 0.0
		t.tween_property(_mira, "modulate:a", 1.0, 0.5)
		t.tween_property(_lente, "modulate:a", 1.0, 0.5)
		t.tween_property(_objeto, "modulate:a", 1.0 if _objeto_visible else 0.0, 0.5)
		t.tween_property(_inventario_fila, "modulate:a", 1.0, 0.5)


# ---------- dialogos y documentos ----------

## Monologo del protagonista en subtitulos. Las lineas se encolan.
func decir(lineas: Array) -> void:
	for l in lineas:
		_cola_dialogo.append(str(l))
	if not _dialogo_activo:
		_siguiente_linea()


func _siguiente_linea() -> void:
	if _cola_dialogo.is_empty():
		_dialogo_activo = false
		return
	_dialogo_activo = true
	var linea: String = _cola_dialogo.pop_front()
	_subtitulo.text = linea
	_subtitulo.visible_ratio = 0.0
	var t := create_tween()
	t.tween_property(_subtitulo, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(_subtitulo, "visible_ratio", 1.0, 0.03 * linea.length())
	t.tween_interval(1.6 + 0.045 * linea.length())
	t.tween_property(_subtitulo, "modulate:a", 0.0, 0.4)
	t.tween_callback(_siguiente_linea)


func mostrar_documento(sup: String, titulo: String, cuerpo: String) -> void:
	var hoja := _documento.get_node("Hoja")
	(hoja.get_node("Margen/Columna/Sup") as Label).text = sup
	(hoja.get_node("Margen/Columna/Titulo") as Label).text = titulo
	(hoja.get_node("Margen/Columna/Cuerpo") as Label).text = cuerpo
	_documento_abierto = true
	_documento.visible = true
	_documento.modulate.a = 0.0
	hoja.position.y += 20.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_documento, "modulate:a", 1.0, 0.25)
	t.tween_property(hoja, "position:y", hoja.position.y - 20.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Ajustes.sonar_hover()


func _input(event: InputEvent) -> void:
	if _candado_abierto:
		_input_candado(event)
		return
	if not _documento_abierto:
		return
	var cerrar := event.is_action_pressed("interactuar")
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		cerrar = true
	if cerrar:
		get_viewport().set_input_as_handled()
		_documento_abierto = false
		var t := create_tween()
		t.tween_property(_documento, "modulate:a", 0.0, 0.2)
		t.tween_callback(func() -> void: _documento.visible = false)
		documento_cerrado.emit()


# ---------- sustos ----------

## Golpe de oscuridad en pantalla (sustos).
func destello(fuerza: float = 0.85, duracion: float = 1.2) -> void:
	var t := create_tween()
	t.tween_property(_destello, "modulate:a", fuerza, 0.05)
	t.tween_property(_destello, "modulate:a", fuerza * 0.4, 0.08)
	t.tween_property(_destello, "modulate:a", fuerza, 0.06)
	t.tween_property(_destello, "modulate:a", 0.0, duracion).set_trans(Tween.TRANS_SINE)
	_parpadeo()


# ---------- candado de combinacion ----------

## Abre la pantalla del candado. "probar" recibe el codigo (String) y devuelve bool.
## Al cerrar emite candado_cerrado(abierto).
func abrir_candado(probar: Callable) -> void:
	_candado_probar = probar
	_candado_abierto = true
	_candado_sel = 0
	for i in _candado_digitos.size():
		_candado_digitos[i] = 0
	_refrescar_candado()
	_candado.visible = true
	_candado.modulate.a = 0.0
	create_tween().tween_property(_candado, "modulate:a", 1.0, 0.25)
	hide_prompt()


func _cerrar_candado(abierto: bool) -> void:
	_candado_abierto = false
	var t := create_tween()
	if abierto:
		t.tween_interval(0.6)
	t.tween_property(_candado, "modulate:a", 0.0, 0.25)
	t.tween_callback(func() -> void:
		_candado.visible = false
		candado_cerrado.emit(abierto))


func _input_candado(event: InputEvent) -> void:
	var dir := 0
	var mover := 0
	if event is InputEventKey and event.pressed:
		match (event as InputEventKey).physical_keycode:
			KEY_W, KEY_UP:
				dir = 1
			KEY_S, KEY_DOWN:
				dir = -1
			KEY_A, KEY_LEFT:
				mover = -1
			KEY_D, KEY_RIGHT:
				mover = 1
			KEY_ENTER, KEY_KP_ENTER, KEY_E:
				if not event.is_echo():
					_probar_candado()
			KEY_G, KEY_Q:
				_cerrar_candado(false)
	elif event is InputEventMouseButton and event.pressed:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP:
				dir = 1
			MOUSE_BUTTON_WHEEL_DOWN:
				dir = -1
			MOUSE_BUTTON_LEFT:
				_probar_candado()
			MOUSE_BUTTON_RIGHT:
				_cerrar_candado(false)
	if event is InputEventKey or event is InputEventMouseButton:
		if not event.is_action("PauseMenu"):
			get_viewport().set_input_as_handled()
	if dir != 0:
		_candado_digitos[_candado_sel] = posmod(_candado_digitos[_candado_sel] + dir, 10)
		_clic.pitch_scale = randf_range(0.95, 1.1)
		_clic.play()
		var rueda := _candado_ruedas[_candado_sel]
		rueda.position.y = -8.0 * dir
		create_tween().tween_property(rueda, "position:y", 0.0, 0.12)
	if mover != 0:
		_candado_sel = posmod(_candado_sel + mover, _candado_digitos.size())
	if dir != 0 or mover != 0:
		_refrescar_candado()


func _probar_candado() -> void:
	if not _candado_abierto:
		return
	var codigo := ""
	for d in _candado_digitos:
		codigo += str(d)
	var ok: bool = _candado_probar.call(codigo)
	if ok:
		for m in _candado_marcos:
			(m.get_theme_stylebox("panel") as StyleBoxFlat).border_color = HUESO
		_cerrar_candado(true)
	else:
		Ajustes.sonar_click()
		var t := create_tween()
		var base_x := _candado_fila.position.x
		for x: float in [14.0, -12.0, 8.0, -5.0, 0.0]:
			t.tween_property(_candado_fila, "position:x", base_x + x, 0.04)
		for m in _candado_marcos:
			(m.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0.3, 0.04, 0.03)
		t.tween_callback(func() -> void:
			for m in _candado_marcos:
				(m.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0.09, 0.075, 0.06))


func _refrescar_candado() -> void:
	for i in _candado_ruedas.size():
		var d := _candado_digitos[i]
		_candado_ruedas[i].text = "%d\n%d\n%d" % [posmod(d + 1, 10), d, posmod(d - 1, 10)]
		var estilo := _candado_marcos[i].get_theme_stylebox("panel") as StyleBoxFlat
		estilo.border_color = SANGRE if i == _candado_sel else Color(HUESO, 0.25)


func _construir_candado() -> void:
	_clic = AudioStreamPlayer.new()
	_clic.stream = load("res://sonidos/clic.wav")
	_clic.volume_db = -6.0
	add_child(_clic)
	_candado = Control.new()
	UIEstilo.llenar(_candado)
	_candado.visible = false
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.8)
	UIEstilo.llenar(fondo)
	_candado.add_child(fondo)

	var col := VBoxContainer.new()
	_colocar(col, 0.5, 0.5, 0.5, 0.5, -260, -190, 260, 190)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	_candado.add_child(col)
	var sup := UIEstilo.label("CANDADO DE COMBINACIÓN", 11, SANGRE, true)
	sup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sup)

	var centro := CenterContainer.new()
	col.add_child(centro)
	_candado_fila = HBoxContainer.new()
	_candado_fila.add_theme_constant_override("separation", 14)
	centro.add_child(_candado_fila)
	_candado_digitos.resize(4)
	for i in 4:
		var marco := Panel.new()
		marco.custom_minimum_size = Vector2(76, 150)
		marco.clip_contents = true
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0.09, 0.075, 0.06)
		estilo.set_border_width_all(2)
		estilo.border_color = Color(HUESO, 0.25)
		estilo.shadow_color = Color(0, 0, 0, 0.6)
		estilo.shadow_size = 8
		marco.add_theme_stylebox_override("panel", estilo)
		var rueda := UIEstilo.label("", 44, HUESO)
		rueda.size = Vector2(76, 150)
		rueda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rueda.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rueda.add_theme_constant_override("line_spacing", -6)
		marco.add_child(rueda)
		# los digitos de arriba y abajo quedan en penumbra, como una rueda real
		var sombra := TextureRect.new()
		sombra.texture = _gradiente_rueda()
		sombra.size = Vector2(76, 150)
		sombra.stretch_mode = TextureRect.STRETCH_SCALE
		sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marco.add_child(sombra)
		_candado_fila.add_child(marco)
		_candado_marcos.append(marco)
		_candado_ruedas.append(rueda)

	var pista := UIEstilo.label("[W/S] GIRAR    [A/D] MOVER    [E] PROBAR    [G] SALIR", 10, Color(HUESO, 0.5), true)
	pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(pista)
	add_child(_candado)


func _gradiente_rueda() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.32, 0.5, 0.68, 1.0])
	g.colors = PackedColorArray([
		Color(0.09, 0.075, 0.06, 0.97), Color(0.09, 0.075, 0.06, 0.55), Color(0.09, 0.075, 0.06, 0.0),
		Color(0.09, 0.075, 0.06, 0.55), Color(0.09, 0.075, 0.06, 0.97)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 64
	return tex


func _construir_subtitulo() -> void:
	_subtitulo = UIEstilo.label("", 19, HUESO)
	_colocar(_subtitulo, 0.15, 1, 0.85, 1, 0, -170, 0, -120)
	_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitulo.custom_minimum_size.x = 500
	_subtitulo.add_theme_constant_override("shadow_outline_size", 10)
	_subtitulo.modulate.a = 0.0
	_raiz.add_child(_subtitulo)


func _construir_documento() -> void:
	_documento = Control.new()
	UIEstilo.llenar(_documento)
	_documento.visible = false
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.78)
	UIEstilo.llenar(fondo)
	_documento.add_child(fondo)

	var hoja := PanelContainer.new()
	hoja.name = "Hoja"
	_colocar(hoja, 0.5, 0.5, 0.5, 0.5, -330, -270, 330, 250)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.78, 0.74, 0.64)
	estilo.border_color = Color(0.55, 0.5, 0.4)
	estilo.set_border_width_all(2)
	estilo.shadow_color = Color(0, 0, 0, 0.6)
	estilo.shadow_size = 18
	hoja.add_theme_stylebox_override("panel", estilo)
	hoja.rotation_degrees = -1.2
	hoja.pivot_offset = Vector2(330, 260)
	_documento.add_child(hoja)

	var margen := MarginContainer.new()
	margen.name = "Margen"
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 36)
	hoja.add_child(margen)
	var col := VBoxContainer.new()
	col.name = "Columna"
	col.add_theme_constant_override("separation", 10)
	margen.add_child(col)
	var tinta := Color(0.12, 0.1, 0.08)
	var sup := UIEstilo.label("", 12, Color(0.35, 0.12, 0.1), true)
	sup.name = "Sup"
	sup.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	var titulo := UIEstilo.label("", 26, tinta)
	titulo.name = "Titulo"
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.custom_minimum_size.x = 580
	titulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	var linea := ColorRect.new()
	linea.color = tinta
	linea.custom_minimum_size = Vector2(0, 2)
	var cuerpo := UIEstilo.label("", 15, tinta)
	cuerpo.name = "Cuerpo"
	cuerpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cuerpo.custom_minimum_size.x = 580
	cuerpo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	cuerpo.add_theme_constant_override("line_spacing", 4)
	col.add_child(sup)
	col.add_child(titulo)
	col.add_child(linea)
	col.add_child(cuerpo)

	var relleno := Control.new()
	relleno.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(relleno)
	var pista := UIEstilo.label("[E] CERRAR", 11, Color(0.4, 0.12, 0.1), true)
	pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pista.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	col.add_child(pista)
	add_child(_documento)


# ---------- construccion ----------

func _construir_mira() -> void:
	_mira = Mira.new()
	_colocar(_mira, 0.5, 0.5, 0.5, 0.5, -24, -24, 24, 24)
	_raiz.add_child(_mira)


func _construir_accion() -> void:
	_accion = HBoxContainer.new()
	_colocar(_accion, 0, 0.5, 1, 0.5, 0, 32, 0, 60)
	_accion.alignment = BoxContainer.ALIGNMENT_CENTER
	_accion.add_theme_constant_override("separation", 10)
	_accion_tecla = UIEstilo.label("[E]", 15, SANGRE)
	_accion_texto = UIEstilo.label("", 15, HUESO, true)
	_accion.add_child(_accion_tecla)
	_accion.add_child(_accion_texto)
	_accion.modulate.a = 0.0
	_raiz.add_child(_accion)


func _construir_lente() -> void:
	_lente = Control.new()
	_colocar(_lente, 0, 1, 0, 1, MARGEN, -MARGEN - 136, MARGEN + 280, -MARGEN)
	_lente.add_child(UIEstilo.label("LENTE", 10, Color(HUESO, 0.45), true))
	_lente_rueda = RuedaLentes.new()
	_lente_rueda.fuente = UIEstilo.fuente()
	_lente_rueda.colores.assign(COLORES_LENTE)
	_lente_rueda.position = Vector2(0, 20)
	_lente_rueda.size = Vector2(240, 48)
	_lente_rueda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lente.add_child(_lente_rueda)
	_lente_nombre = UIEstilo.label("", 17, HUESO, true)
	_lente_nombre.position = Vector2(0, 72)
	_lente.add_child(_lente_nombre)
	_bateria = BarraBateria.new()
	_bateria.fuente = UIEstilo.fuente()
	_bateria.position = Vector2(0, 100)
	_bateria.size = Vector2(240, 14)
	_bateria.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lente.add_child(_bateria)
	var pista := UIEstilo.label("[CLIC DER] CAMBIAR LUZ", 9, Color(HUESO, 0.4), true)
	pista.position = Vector2(0, 120)
	_lente.add_child(pista)
	_raiz.add_child(_lente)


func _construir_objeto() -> void:
	_objeto = Control.new()
	_colocar(_objeto, 1, 1, 1, 1, -MARGEN - 280, -MARGEN - 90, -MARGEN, -MARGEN)
	_objeto_contenido = VBoxContainer.new()
	UIEstilo.llenar(_objeto_contenido)
	_objeto_contenido.alignment = BoxContainer.ALIGNMENT_END
	_objeto_contenido.add_theme_constant_override("separation", 4)

	var sup := UIEstilo.label("EN LA MANO", 10, Color(HUESO, 0.45), true)
	sup.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_objeto_contenido.add_child(sup)
	_objeto_nombre = UIEstilo.label("", 24, HUESO, true)
	_objeto_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_objeto_contenido.add_child(_objeto_nombre)

	var pista := HBoxContainer.new()
	pista.alignment = BoxContainer.ALIGNMENT_END
	pista.add_theme_constant_override("separation", 8)
	pista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pista.add_child(UIEstilo.label("[G]", 12, SANGRE))
	pista.add_child(UIEstilo.label("SOLTAR", 11, Color(HUESO, 0.6), true))
	_objeto_contenido.add_child(pista)

	_objeto.add_child(_objeto_contenido)
	_objeto.modulate.a = 0.0
	_raiz.add_child(_objeto)


func _construir_aviso() -> void:
	_aviso = VBoxContainer.new()
	_colocar(_aviso, 0, 0, 1, 0, 0, 70, 0, 160)
	_aviso.add_theme_constant_override("separation", 6)
	_aviso_titulo_sup = UIEstilo.label("", 10, SANGRE, true)
	_aviso_titulo_sup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso_titulo = UIEstilo.label("", 28, HUESO, true)
	_aviso_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso_rasgo = Rasgo.new(260.0)
	_aviso_rasgo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_aviso.add_child(_aviso_titulo_sup)
	_aviso.add_child(_aviso_titulo)
	_aviso.add_child(_aviso_rasgo)
	_aviso.modulate.a = 0.0
	_raiz.add_child(_aviso)


func _construir_inventario() -> void:
	_inventario_fila = HBoxContainer.new()
	# Ampliamos los offsets laterales (-180 a 180) para dar espacio a la nueva separación
	_colocar(_inventario_fila, 0.5, 1.0, 0.5, 1.0, -180, -76, 180, -20)
	_inventario_fila.alignment = BoxContainer.ALIGNMENT_CENTER
	_inventario_fila.add_theme_constant_override("separation", 24) # Aumentamos el espaciado

	for i in 4:
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(56, 56)
		wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var fondo := ColorRect.new()
		fondo.size = Vector2(56, 56) 
		fondo.color = Color(0.15, 0.15, 0.15, 0.5)
		fondo.pivot_offset = Vector2(28, 28)
		
		# Invertimos los signos (+ para pares, - para impares) y bajamos a 8 grados
		fondo.rotation_degrees = 8.0 if i % 2 == 0 else -8.0
		
		wrapper.add_child(fondo)

		var icono := TextureRect.new()
		icono.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icono.offset_left = 6
		icono.offset_top = 6
		icono.offset_right = -6
		icono.offset_bottom = -6
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fondo.add_child(icono)
		
		# --- NUEVO: El texto que aparece arriba del slot ---
		var nombre := UIEstilo.label("", 10, HUESO, true)
		nombre.custom_minimum_size = Vector2(100, 15)
		nombre.position = Vector2(-22, -22) # Lo centra arriba del cuadro de 56x56
		nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nombre.modulate.a = 0.0 # Oculto por defecto
		wrapper.add_child(nombre)
		_inv_nombres.append(nombre)

		_inventario_fila.add_child(wrapper)
		_inv_fondos.append(fondo)
		_inv_iconos.append(icono)

	_raiz.add_child(_inventario_fila)

func _construir_aviso_lleno() -> void:
	_aviso_lleno = UIEstilo.label("INVENTARIO LLENO", 16, SANGRE, true)
	_colocar(_aviso_lleno, 0.5, 0.0, 0.5, 0.0, -150, 40, 150, 70)
	_aviso_lleno.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso_lleno.modulate.a = 0.0
	_raiz.add_child(_aviso_lleno)

func mostrar_inventario_lleno() -> void:
	if _aviso_lleno_tween:
		_aviso_lleno_tween.kill()
	_aviso_lleno_tween = create_tween()
	_aviso_lleno.modulate.a = 1.0
	_aviso_lleno_tween.tween_interval(1.5)
	_aviso_lleno_tween.tween_property(_aviso_lleno, "modulate:a", 0.0, 0.5)

func mostrar_nombre_slot(indice: int, texto: String) -> void:
	# 1. Apagar forzosamente los nombres de los otros slots
	for i in 4:
		if i != indice:
			if _inv_tweens[i]:
				_inv_tweens[i].kill()
			_inv_nombres[i].modulate.a = 0.0

	# 2. Mostrar el texto del slot actual (si tiene nombre)
	if texto == "":
		return
		
	var lbl := _inv_nombres[indice]
	lbl.text = texto.to_upper()
	
	if _inv_tweens[indice]:
		_inv_tweens[indice].kill()
		
	_inv_tweens[indice] = create_tween()
	lbl.modulate.a = 1.0
	_inv_tweens[indice].tween_interval(1.5) 
	_inv_tweens[indice].tween_property(lbl, "modulate:a", 0.0, 0.5)

func actualizar_icono_inventario(indice: int, textura: Texture2D) -> void:
	_inv_iconos[indice].texture = textura

func limpiar_icono_inventario(indice: int) -> void:
	_inv_iconos[indice].texture = null

func resaltar_slot(indice_activo: int) -> void:
	for i in 4:
		if i == indice_activo:
			_inv_fondos[i].color = Color(0.6, 0.6, 0.6, 0.7) # Seleccionado
		else:
			_inv_fondos[i].color = Color(0.15, 0.15, 0.15, 0.5) # Inactivo


# ---------- helpers ----------

func _colocar(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, or_: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = or_
	c.offset_bottom = ob
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_lente_cambiado(canal: int) -> void:
	var primero := _lente_canal == -1
	_lente_canal = canal
	_lente_rueda.activo = canal
	_lente_inactivo = 0.0
	var color: Color = COLORES_LENTE[canal]
	_lente_nombre.text = NOMBRES_LENTE[canal]
	_lente_nombre.add_theme_color_override("font_color", HUESO.lerp(color, 0.55))
	_ruido.set_shader_parameter("tint", color)
	var tinte_base := 0.0 if canal == Linterna.Channel.WHITE else 0.04
	if primero:
		_set_tinte(tinte_base)
		_lente_rueda.queue_redraw()
		return
	if not _cinematica:
		_lente.modulate.a = 1.0
	if _lente_tween:
		_lente_tween.kill()
	_lente_tween = create_tween().set_parallel(true)
	_lente_tween.tween_method(_set_pulso, 1.0, 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lente_nombre.visible_ratio = 0.0
	_lente_tween.tween_property(_lente_nombre, "visible_ratio", 1.0, 0.3)
	var destello := 0.06 if canal == Linterna.Channel.WHITE else 0.18
	_lente_tween.tween_method(_set_tinte, destello, tinte_base, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _parpadeo() -> void:
	var t := create_tween()
	t.tween_property(_raiz, "modulate:a", 0.35, 0.04)
	t.tween_property(_raiz, "modulate:a", 1.0, 0.05)
	t.tween_property(_raiz, "modulate:a", 0.6, 0.03)
	t.tween_property(_raiz, "modulate:a", 1.0, 0.08)


func _temblor(fuerza: float) -> void:
	_aviso.position.x = randf_range(-3.0, 3.0) * fuerza


func _set_pulso(v: float) -> void:
	_lente_rueda.pulso = v
	_lente_rueda.queue_redraw()


func _set_tinte(v: float) -> void:
	_ruido.set_shader_parameter("tint_amount", v)


# ---------- elementos dibujados ----------

class Mira extends Control:
	const COLOR := Color(0.84, 0.81, 0.74)
	const ROJO := Color(0.62, 0.09, 0.08)
	var enfoque := 0.0
	var objetivo := 0.0
	var bloqueado := false

	func _process(delta: float) -> void:
		var e := move_toward(enfoque, objetivo, delta * 8.0)
		if e != enfoque:
			enfoque = e
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var e := ease(enfoque, -2.0)
		draw_circle(c, 1.6, Color(COLOR, 0.8), true, -1.0, true)
		if enfoque <= 0.01:
			return
		# Cuatro esquinas que se cierran sobre el objeto, como un visor enfocando
		var mitad := lerpf(18.0, 9.0, e)
		var largo := 4.0
		var col := Color(ROJO if bloqueado else COLOR, e * 0.9)
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				var esquina := c + Vector2(sx * mitad, sy * mitad)
				draw_line(esquina, esquina - Vector2(sx * largo, 0.0), col, 1.5, true)
				draw_line(esquina, esquina - Vector2(0.0, sy * largo), col, 1.5, true)


class RuedaLentes extends Control:
	const RADIO := 7.0
	const HUESO_C := Color(0.84, 0.81, 0.74)
	const TECLAS := ["", "", "", "SHIFT"]
	var fuente: Font
	var colores: Array[Color] = []
	var activo := 0
	var pulso := 0.0
	var mostrar_morada := true
	
	# ¡ESTA ES LA LÍNEA QUE FALTABA!
	var disponibles: Array = [] 

	func _x(i: int) -> float:
		return 12.0 + i * 38.0 + (26.0 if i == 3 else 0.0)

	func _draw() -> void:
		var cy := 14.0
		var cantidad := 4 if mostrar_morada else 3
		if mostrar_morada:
			var sx := (_x(2) + _x(3)) * 0.5
			draw_line(Vector2(sx, cy - 8.0), Vector2(sx, cy + 8.0), Color(HUESO_C, 0.15), 1.0, true)
		
		for i in cantidad:
			# Revisamos si está desbloqueado antes de dibujar
			var esta_desbloqueado := false
			
			if i == 3: # El 3 es el índice del Morado (Shift)
				esta_desbloqueado = mostrar_morada
			else:
				for c in disponibles:
					if int(c) == i:
						esta_desbloqueado = true
						break
						
			if not esta_desbloqueado:
				continue # Se salta este color y no dibuja absolutamente nada

			var p := Vector2(_x(i), cy)
			var col: Color = colores[i]
			
			if i == activo:
				draw_circle(p, RADIO + 6.0 + pulso * 8.0, Color(col, 0.08 + 0.15 * pulso), true, -1.0, true)
				draw_circle(p, RADIO * (1.0 + 0.3 * pulso), col, true, -1.0, true)
				var m := RADIO + 5.0
				for sx: float in [-1.0, 1.0]:
					for sy: float in [-1.0, 1.0]:
						var e := p + Vector2(sx * m, sy * m)
						draw_line(e, e - Vector2(sx * 3.0, 0.0), Color(HUESO_C, 0.8), 1.0, true)
						draw_line(e, e - Vector2(0.0, sy * 3.0), Color(HUESO_C, 0.8), 1.0, true)
			else:
				draw_arc(p, RADIO - 1.0, 0.0, TAU, 28, Color(col, 0.5), 1.3, true)
				
			var tecla: String = TECLAS[i]
			var tam := 9 if tecla.length() > 1 else 11
			var col_tecla := Color(HUESO_C, 0.85 if i == activo else 0.35)
			draw_string(fuente, Vector2(p.x - 30.0, cy + 31.0), tecla, HORIZONTAL_ALIGNMENT_CENTER, 60.0, tam, col_tecla)


class BarraBateria extends Control:
	const HUESO_C := Color(0.84, 0.81, 0.74)
	const ROJO := Color(0.75, 0.12, 0.1)
	const CELDAS := 10
	var fuente: Font
	var nivel := 100.0:
		set(v):
			if absf(v - nivel) > 0.05:
				nivel = v
				queue_redraw()
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if nivel < 20.0:
			queue_redraw()

	func _draw() -> void:
		var bajo := nivel < 20.0
		var col := ROJO if bajo else HUESO_C
		if bajo and fmod(_t, 0.8) < 0.3:
			col = Color(col, 0.35)
		draw_string(fuente, Vector2(0, 11), "PILA", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(HUESO_C, 0.45))
		var x0 := 36.0
		var ancho := 12.0
		for i in CELDAS:
			var r := Rect2(x0 + i * (ancho + 3.0), 3, ancho, 7)
			var lleno := clampf(nivel / 100.0 * CELDAS - i, 0.0, 1.0)
			draw_rect(r, Color(col, 0.18), true)
			if lleno > 0.0:
				draw_rect(Rect2(r.position, Vector2(r.size.x * lleno, r.size.y)), col, true)
		draw_string(fuente, Vector2(x0 + CELDAS * (ancho + 3.0) + 6.0, 11), "%d%%" % int(ceil(nivel)), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(col, 0.8))
