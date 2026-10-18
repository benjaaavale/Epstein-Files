class_name UIEstilo
extends RefCounted

const HUESO := Color(0.84, 0.81, 0.74)
const SANGRE := Color(0.62, 0.09, 0.08)
const SOMBRA := Color(0.0, 0.0, 0.0, 0.8)
const RUIDO := preload("res://ui_ruido.gdshader")

static var _fuente: SystemFont
static var _espaciada: FontVariation


static func fuente() -> Font:
	if _fuente == null:
		_fuente = SystemFont.new()
		_fuente.font_names = PackedStringArray(["American Typewriter", "Courier Prime", "Courier New", "monospace"])
	return _fuente


static func fuente_espaciada() -> Font:
	if _espaciada == null:
		_espaciada = FontVariation.new()
		_espaciada.base_font = fuente()
		_espaciada.spacing_glyph = 3
		_espaciada.variation_embolden = 0.2
	return _espaciada


static func label(texto: String, tamano: int, color: Color = HUESO, espaciada: bool = false) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", fuente_espaciada() if espaciada else fuente())
	l.add_theme_font_size_override("font_size", tamano)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", SOMBRA)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func llenar(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func capa_ruido(parametros: Dictionary = {}) -> ColorRect:
	var rect := ColorRect.new()
	llenar(rect)
	var mat := ShaderMaterial.new()
	mat.shader = RUIDO
	for clave in parametros:
		mat.set_shader_parameter(clave, parametros[clave])
	rect.material = mat
	return rect


static func columna_izquierda(ancho: float, alto: float) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.anchor_left = 0.09
	col.anchor_right = 0.09
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_top = -alto * 0.5
	col.offset_bottom = alto * 0.5
	col.offset_right = ancho
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return col


static func espacio(alto: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, alto)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func estilizar_slider(s: HSlider) -> void:
	var pista := StyleBoxFlat.new()
	pista.bg_color = Color(HUESO, 0.18)
	pista.content_margin_top = 1
	pista.content_margin_bottom = 1
	var lleno := StyleBoxFlat.new()
	lleno.bg_color = SANGRE
	lleno.content_margin_top = 1
	lleno.content_margin_bottom = 1
	s.add_theme_stylebox_override("slider", pista)
	s.add_theme_stylebox_override("grabber_area", lleno)
	s.add_theme_stylebox_override("grabber_area_highlight", lleno)
	s.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	s.add_theme_icon_override("grabber", _rectangulo(Vector2i(6, 18), HUESO))
	s.add_theme_icon_override("grabber_highlight", _rectangulo(Vector2i(6, 18), Color(1.0, 0.95, 0.9)))


static func _rectangulo(tamano: Vector2i, color: Color) -> ImageTexture:
	var img := Image.create_empty(tamano.x, tamano.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
