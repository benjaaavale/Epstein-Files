extends CanvasLayer
class_name Hud

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


func _process(delta: float) -> void:
	if linterna != null:
		var canal := int(linterna.current_channel)
		if canal != _lente_canal:
			_on_lente_cambiado(canal)
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
	for c: Control in [_mira, _accion, _lente, _objeto]:
		t.tween_property(c, "modulate:a", 0.0 if activa else 1.0, 0.5)


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
	_colocar(_lente, 0, 1, 0, 1, MARGEN, -MARGEN - 100, MARGEN + 280, -MARGEN)
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
	var tinte_base := 0.0 if canal == Linterna.Channel.WHITE else 0.12
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
	var destello := 0.12 if canal == Linterna.Channel.WHITE else 0.45
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
	const TECLAS := ["1", "2", "3", "SHIFT+3"]
	var fuente: Font
	var colores: Array[Color] = []
	var activo := 0
	var pulso := 0.0
	var mostrar_morada := true

	func _x(i: int) -> float:
		return 12.0 + i * 38.0 + (26.0 if i == 3 else 0.0)

	func _draw() -> void:
		var cy := 14.0
		var cantidad := 4 if mostrar_morada else 3
		if mostrar_morada:
			var sx := (_x(2) + _x(3)) * 0.5
			draw_line(Vector2(sx, cy - 8.0), Vector2(sx, cy + 8.0), Color(HUESO_C, 0.15), 1.0, true)
		for i in cantidad:
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
