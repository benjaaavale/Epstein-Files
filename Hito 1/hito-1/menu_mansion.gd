extends CanvasLayer
class_name MenuMansion

## Menu principal montado sobre la propia mansion: una camara recorre el hall a oscuras
## mientras un haz de linterna barre las paredes. Al apretar ENTRAR se funde a negro,
## el jugador recupera el control y el guion empieza la introduccion.
## Si el nivel se reinicia (Ajustes.saltar_menu), el menu no aparece.

signal empezar

const PLANOS := [
	# [posicion, mira a, segundos]
	[Vector3(6.8, 1.15, 2.4), Vector3(0.0, 1.6, -6.5), 26.0],
	[Vector3(-5.5, 1.9, 1.8), Vector3(1.0, 2.6, -8.0), 24.0],
	[Vector3(-1.5, 3.9, -12.5), Vector3(0.5, 0.6, 1.5), 24.0],
	[Vector3(5.5, 0.7, -2.0), Vector3(-7.5, 1.4, 2.5), 22.0],
]

const CONTROLES := [
	["W A S D", "Caminar"],
	["SHIFT", "Correr"],
	["C / CTRL", "Agacharse"],
	["ESPACIO", "Saltar"],
	["E", "Usar, tomar, leer"],
	["CLIC DERECHO", "Cambiar el color de la luz"],
	["SHIFT + CLIC", "Luz morada (cuando la tengas)"],
	["1 2 3 4", "Elegir objeto del inventario"],
	["G", "Soltar objeto"],
	["ESC", "Pausa"],
]

var activo := false

var _camara: Camera3D
var _foco: SpotLight3D
var _player: Node
var _contenido: VBoxContainer
var _titulo_a: TituloTerror
var _titulo_b: TituloTerror
var _botones: Array[Control] = []
var _ruido: ColorRect
var _evidencia: Control
var _lema: Label
var _presencia: Presencia
var _proximo_susto := 22.0
var _latido: AudioStreamPlayer
var _negro: ColorRect
var _opciones: PanelOpciones
var _ayuda: Control
var _saliendo := false
var _plano := 0
var _t := 0.0


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_parent().get_node_or_null("Player")
	if Ajustes.saltar_menu:
		Ajustes.saltar_menu = false
		queue_free()
		return
	activo = true
	get_tree().paused = false
	await get_tree().process_frame
	_preparar_escena()
	_construir()
	_animar_entrada()


func _preparar_escena() -> void:
	if _player != null:
		_player.process_mode = Node.PROCESS_MODE_DISABLED
		var hud := _player.get_node_or_null("HUD") as CanvasLayer
		if hud != null:
			hud.visible = false
	var pausa := get_parent().get_node_or_null("PauseMenu")
	if pausa != null:
		pausa.set_process_input(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_camara = Camera3D.new()
	_camara.fov = 62.0
	get_parent().add_child.call_deferred(_camara)
	await get_tree().process_frame
	_camara.make_current()
	# una linterna que nadie sostiene barre el hall
	_foco = SpotLight3D.new()
	_foco.spot_range = 18.0
	_foco.spot_angle = 16.0
	_foco.light_energy = 3.5
	_foco.light_color = Color(1.0, 0.93, 0.82)
	_foco.shadow_enabled = true
	_camara.add_child(_foco)
	# "Ella", arriba de la escalera: se deja ver un instante de vez en cuando
	_presencia = Presencia.new()
	get_parent().add_child(_presencia)
	_presencia.global_position = Vector3(0.2, 2.35, -8.4)
	# latido de fondo, muy bajo
	_latido = AudioStreamPlayer.new()
	var lat := load("res://sonidos/latido.wav") as AudioStreamWAV
	if lat != null:
		lat = lat.duplicate() as AudioStreamWAV
		lat.loop_mode = AudioStreamWAV.LOOP_FORWARD
		lat.loop_end = int(lat.get_length() * lat.mix_rate)
		_latido.stream = lat
	_latido.volume_db = -20.0
	add_child(_latido)
	_latido.play()
	_ir_a_plano(0)


func _ir_a_plano(i: int) -> void:
	_plano = i
	_t = 0.0


func _process(delta: float) -> void:
	if _camara == null or _foco == null or not is_instance_valid(_camara):
		return
	var p: Array = PLANOS[_plano]
	var siguiente: Array = PLANOS[(_plano + 1) % PLANOS.size()]
	_t += delta / float(p[2])
	if _t >= 1.0:
		_ir_a_plano((_plano + 1) % PLANOS.size())
		return
	# avanza lento desde el plano actual un tercio del camino hacia el siguiente
	var k := smoothstep(0.0, 1.0, _t) * 0.35
	var pos: Vector3 = (p[0] as Vector3).lerp(siguiente[0], k)
	var mira: Vector3 = (p[1] as Vector3).lerp(siguiente[1], k)
	pos.y += sin(Time.get_ticks_msec() * 0.0007) * 0.04
	_camara.global_position = pos
	_camara.look_at(mira, Vector3.UP)
	# el haz tiembla y deambula como si alguien buscara algo
	var s := Time.get_ticks_msec() * 0.001
	_foco.rotation = Vector3(sin(s * 0.37) * 0.22 + sin(s * 2.3) * 0.01, sin(s * 0.29 + 1.0) * 0.4, 0.0)
	_foco.light_energy = 3.5 * (0.92 + 0.08 * sin(s * 13.0) * sin(s * 7.1))
	# pulso rojo al ritmo del latido
	if _ruido != null:
		var pulso := pow(maxf(sin(s * TAU / 1.1), 0.0), 8.0)
		(_ruido.material as ShaderMaterial).set_shader_parameter("tint_amount", 0.05 * pulso)
	_proximo_susto -= delta
	if _proximo_susto <= 0.0 and not _saliendo:
		_proximo_susto = randf_range(25.0, 45.0)
		_susto_menu()
	# fundidos entre planos
	if _negro != null and not _saliendo:
		var borde := minf(_t, 1.0 - _t)
		_negro.modulate.a = maxf(_negro.modulate.a - delta * 0.8, 0.0) if borde > 0.04 else clampf(1.0 - borde / 0.04, 0.0, 1.0)


## Un parpadeo de luz y "Ella" aparece arriba de la escalera, apenas un instante.
func _susto_menu() -> void:
	if _presencia == null or _plano > 1:
		return
	_presencia.aparecer(0.35)
	_titulo_b.glitch(0.4)
	var t := create_tween()
	t.tween_property(_foco, "light_energy", 0.0, 0.05)
	t.tween_interval(0.12)
	t.tween_property(_foco, "light_energy", 6.0, 0.04)
	t.tween_interval(0.1)
	t.tween_property(_foco, "light_energy", 3.5, 0.3)


func _construir() -> void:
	var raiz := Control.new()
	UIEstilo.llenar(raiz)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(raiz)

	# oscurece el lado izquierdo para que el texto se lea sobre la casa
	var sombra := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.42, 0.7])
	g.colors = PackedColorArray([Color(0.02, 0, 0, 0.95), Color(0.02, 0, 0, 0.7), Color(0, 0, 0, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 8
	sombra.texture = gt
	sombra.stretch_mode = TextureRect.STRETCH_SCALE
	sombra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	UIEstilo.llenar(sombra)
	raiz.add_child(sombra)
	_ruido = UIEstilo.capa_ruido({"vignette_amount": 0.95, "grain_amount": 0.09, "flicker_amount": 0.08,
		"tint": Color(0.6, 0.02, 0.02), "tint_amount": 0.0})
	raiz.add_child(_ruido)

	_evidencia = _construir_evidencia()
	raiz.add_child(_evidencia)

	# la columna ocupa el alto de la pantalla y centra su contenido: cabe tambien en 720p
	_contenido = UIEstilo.columna_izquierda(640.0, 600.0)
	_contenido.anchor_top = 0.06
	_contenido.anchor_bottom = 0.86
	_contenido.offset_top = 0.0
	_contenido.offset_bottom = 0.0
	_contenido.alignment = BoxContainer.ALIGNMENT_CENTER
	_contenido.add_theme_constant_override("separation", 4)
	raiz.add_child(_contenido)
	_contenido.add_child(UIEstilo.label("EXPEDIENTE N° 0417  ·  SEIS DESAPARECIDOS  ·  CASO ABIERTO", 12, UIEstilo.SANGRE, true))
	_contenido.add_child(UIEstilo.espacio(4))
	_titulo_a = TituloTerror.new("SHADE", 96)
	_titulo_b = TituloTerror.new("MANSION", 96)
	_titulo_b.frecuencia_glitch = 0.2
	_titulo_b.goteo = true
	_contenido.add_child(_titulo_a)
	_contenido.add_child(_titulo_b)
	_contenido.add_child(UIEstilo.espacio(8))
	_lema = UIEstilo.label("La luz revela lo que la casa esconde.", 19, Color(UIEstilo.HUESO, 0.75))
	_lema.visible_ratio = 0.0
	_contenido.add_child(_lema)
	_contenido.add_child(UIEstilo.label("MANSIÓN EBNER  ·  VALDIVIA  ·  ABANDONADA DESDE 1994", 11, Color(UIEstilo.HUESO, 0.38), true))
	_contenido.add_child(UIEstilo.espacio(18))

	_boton("I.", "ENTRAR", _on_jugar)
	_boton("II.", "CÓMO JUGAR", _abrir_ayuda)
	_boton("III.", "OPCIONES", func() -> void: _opciones.abrir())
	_boton("IV.", "SALIR", func() -> void: get_tree().quit())

	var aviso := UIEstilo.label("JUEGA A OSCURAS Y CON AUDÍFONOS", 11, Color(UIEstilo.HUESO, 0.35), true)
	aviso.anchor_left = 0.09
	aviso.anchor_top = 1.0
	aviso.anchor_bottom = 1.0
	aviso.offset_top = -64.0
	raiz.add_child(aviso)
	var estudio := UIEstilo.label("DIDDY GAMES  ·  CC5408", 10, Color(UIEstilo.HUESO, 0.3), true)
	estudio.anchor_left = 0.09
	estudio.anchor_top = 1.0
	estudio.anchor_bottom = 1.0
	estudio.offset_top = -40.0
	raiz.add_child(estudio)

	_ayuda = _construir_ayuda()
	raiz.add_child(_ayuda)
	_opciones = PanelOpciones.new()
	raiz.add_child(_opciones)

	_negro = ColorRect.new()
	_negro.color = Color.BLACK
	UIEstilo.llenar(_negro)
	add_child(_negro)


## Lado derecho: la polaroid de Elena Rivas y un recorte de diario, clavados con cinta.
func _construir_evidencia() -> Control:
	var caja := Control.new()
	caja.anchor_left = 1.0
	caja.anchor_right = 1.0
	caja.anchor_top = 0.5
	caja.anchor_bottom = 0.5
	caja.offset_left = -470.0
	caja.offset_right = -60.0
	caja.offset_top = -270.0
	caja.offset_bottom = 230.0
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# recorte de diario
	var recorte := PanelContainer.new()
	var est := StyleBoxFlat.new()
	est.bg_color = Color(0.62, 0.58, 0.48)
	est.shadow_color = Color(0, 0, 0, 0.7)
	est.shadow_size = 14
	est.content_margin_left = 18
	est.content_margin_right = 18
	est.content_margin_top = 14
	est.content_margin_bottom = 14
	recorte.add_theme_stylebox_override("panel", est)
	recorte.position = Vector2(0, 318)
	recorte.custom_minimum_size = Vector2(330, 0)
	recorte.rotation_degrees = -4.0
	recorte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var tinta := Color(0.1, 0.08, 0.06)
	var sup := UIEstilo.label("EL DIARIO DE VALDIVIA · 14 DE OCTUBRE", 9, Color(0.3, 0.1, 0.08), true)
	sup.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	col.add_child(sup)
	var titular := UIEstilo.label("SEXTA DESAPARICIÓN CERCA DE LA MANSIÓN EBNER", 20, tinta)
	titular.add_theme_font_override("font", UIEstilo.fuente_documento())
	titular.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	titular.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titular.custom_minimum_size.x = 294
	col.add_child(titular)
	var bajada := UIEstilo.label("Vecinos aseguran ver luces rojas y azules tras las ventanas tapiadas.", 12, Color(tinta, 0.8))
	bajada.add_theme_font_override("font", UIEstilo.fuente_documento())
	bajada.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	bajada.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bajada.custom_minimum_size.x = 294
	col.add_child(bajada)
	recorte.add_child(col)
	caja.add_child(recorte)

	# polaroid
	var polaroid := Panel.new()
	var marco := StyleBoxFlat.new()
	marco.bg_color = Color(0.82, 0.79, 0.72)
	marco.shadow_color = Color(0, 0, 0, 0.75)
	marco.shadow_size = 16
	polaroid.add_theme_stylebox_override("panel", marco)
	polaroid.position = Vector2(150, 0)
	polaroid.size = Vector2(220, 272)
	polaroid.pivot_offset = Vector2(110, 0)
	polaroid.rotation_degrees = 5.0
	polaroid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var foto := TextureRect.new()
	# solo la foto (sin el nombre impreso): abajo queda el borde blanco para escribir
	var recorte_foto := AtlasTexture.new()
	recorte_foto.atlas = load("res://mapa/texturas/foto_desaparecido_1.png")
	recorte_foto.region = Rect2(20, 20, 216, 220)
	foto.texture = recorte_foto
	foto.position = Vector2(12, 12)
	foto.size = Vector2(196, 200)
	foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	foto.modulate = Color(0.85, 0.8, 0.75)
	polaroid.add_child(foto)
	var cinta := ColorRect.new()
	cinta.color = Color(0.85, 0.82, 0.65, 0.55)
	cinta.size = Vector2(90, 26)
	cinta.position = Vector2(65, -12)
	cinta.rotation_degrees = -6.0
	polaroid.add_child(cinta)
	var nota := UIEstilo.label("¿LA VISTE?", 26, Color(0.55, 0.04, 0.03))
	nota.add_theme_font_override("font", UIEstilo.fuente_documento())
	nota.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	nota.position = Vector2(28, 220)
	nota.rotation_degrees = -7.0
	polaroid.add_child(nota)
	caja.add_child(polaroid)
	return caja


func _construir_ayuda() -> Control:
	var panel := Control.new()
	UIEstilo.llenar(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.88)
	UIEstilo.llenar(fondo)
	panel.add_child(fondo)
	var col := UIEstilo.columna_izquierda(640.0, 560.0)
	panel.add_child(col)
	col.add_child(UIEstilo.label("— INSTRUCCIONES", 11, UIEstilo.SANGRE, true))
	col.add_child(TituloTerror.new("CÓMO JUGAR", 54))
	col.add_child(Rasgo.new(300.0))
	col.add_child(UIEstilo.espacio(8))
	var grilla := GridContainer.new()
	grilla.columns = 2
	grilla.add_theme_constant_override("h_separation", 28)
	grilla.add_theme_constant_override("v_separation", 6)
	grilla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in CONTROLES:
		var tecla := UIEstilo.label(c[0], 13, UIEstilo.SANGRE, true)
		tecla.custom_minimum_size.x = 170
		grilla.add_child(tecla)
		grilla.add_child(UIEstilo.label(c[1], 15, Color(UIEstilo.HUESO, 0.85)))
	col.add_child(grilla)
	col.add_child(UIEstilo.espacio(10))
	var texto := UIEstilo.label("Tu linterna fue modificada. Cada filtro de color muestra cosas que la luz blanca no ve: rastros, números, cables, paredes que no existen. Los colores gastan batería; busca pilas. La luz blanca se recarga sola.", 14, Color(UIEstilo.HUESO, 0.6))
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size.x = 600
	col.add_child(texto)
	col.add_child(UIEstilo.espacio(10))
	var volver := MenuBoton.new("VOLVER", 20)
	volver.pressed.connect(func() -> void: panel.visible = false)
	col.add_child(volver)
	return panel


func _abrir_ayuda() -> void:
	_ayuda.visible = true
	_ayuda.modulate.a = 0.0
	create_tween().tween_property(_ayuda, "modulate:a", 1.0, 0.2)


func _input(event: InputEvent) -> void:
	if not activo or _saliendo:
		return
	if event.is_action_pressed("PauseMenu"):
		if _opciones.visible:
			_opciones.cerrar()
		elif _ayuda.visible:
			_ayuda.visible = false
		get_viewport().set_input_as_handled()


func _boton(numero: String, texto: String, accion: Callable) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := UIEstilo.label(numero, 14, Color(UIEstilo.SANGRE, 0.8), true)
	n.custom_minimum_size.x = 44
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(n)
	var b := MenuBoton.new(texto, 26)
	b.pressed.connect(accion)
	fila.add_child(b)
	fila.modulate.a = 0.0
	_botones.append(fila)
	_contenido.add_child(fila)


func _animar_entrada() -> void:
	_negro.modulate.a = 1.0
	_contenido.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_negro, "modulate:a", 0.0, 2.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(_contenido, "modulate:a", 1.0, 0.8)
	t.parallel().tween_property(_evidencia, "modulate:a", 1.0, 1.6).from(0.0)
	t.tween_callback(_titulo_a.glitch.bind(0.35))
	t.tween_property(_lema, "visible_ratio", 1.0, 1.4)
	for b in _botones:
		t.tween_property(b, "modulate:a", 1.0, 0.22)


func _on_jugar() -> void:
	if _saliendo:
		return
	_saliendo = true
	_titulo_b.glitch(0.6)
	var t := create_tween()
	t.tween_property(_negro, "modulate:a", 1.0, 1.1)
	await t.finished
	activo = false
	if is_instance_valid(_camara):
		_camara.queue_free()
	if is_instance_valid(_presencia):
		_presencia.queue_free()
	if _player != null:
		_player.process_mode = Node.PROCESS_MODE_INHERIT
		var hud := _player.get_node_or_null("HUD") as CanvasLayer
		if hud != null:
			hud.visible = true
		var cam := _player.get_node_or_null("Head/Camera3D") as Camera3D
		if cam != null:
			cam.make_current()
	var pausa := get_parent().get_node_or_null("PauseMenu")
	if pausa != null:
		pausa.set_process_input(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Ajustes.inicio_nivel_ms = Time.get_ticks_msec()
	empezar.emit()
	# la introduccion del guion arranca en negro: el menu se va sin mostrar la casa
	await get_tree().process_frame
	queue_free()
