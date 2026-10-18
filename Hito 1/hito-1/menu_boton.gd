class_name MenuBoton
extends Button

## Boton de texto: al pasar el mouse parpadea y aparece un trazo rojo a la izquierda.

var _resalte := 0.0
var _tween: Tween


func _init(texto: String = "", tamano: int = 24) -> void:
	text = texto
	flat = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	focus_mode = Control.FOCUS_ALL
	add_theme_font_override("font", UIEstilo.fuente())
	add_theme_font_size_override("font_size", tamano)
	var vacio := StyleBoxEmpty.new()
	for estilo in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(estilo, vacio)
	_set_resalte(0.0)
	mouse_entered.connect(grab_focus)
	focus_entered.connect(_on_foco.bind(true))
	focus_exited.connect(_on_foco.bind(false))
	pressed.connect(func() -> void: Ajustes.sonar_click())


func _on_foco(con_foco: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(_set_resalte, _resalte, 1.0 if con_foco else 0.0, 0.16)
	if con_foco:
		Ajustes.sonar_hover()
		var parpadeo := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		parpadeo.tween_property(self, "modulate:a", 0.35, 0.03)
		parpadeo.tween_property(self, "modulate:a", 1.0, 0.04)
		parpadeo.tween_property(self, "modulate:a", 0.6, 0.03)
		parpadeo.tween_property(self, "modulate:a", 1.0, 0.06)


func _set_resalte(v: float) -> void:
	_resalte = v
	var c := Color(UIEstilo.HUESO, 0.55).lerp(Color(1.0, 0.96, 0.9), v)
	for nombre in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(nombre, c)
	queue_redraw()


func _draw() -> void:
	if _resalte <= 0.01:
		return
	var y := size.y * 0.5
	draw_line(Vector2(-34.0, y), Vector2(-34.0 + 22.0 * _resalte, y + 1.0), Color(UIEstilo.SANGRE, _resalte), 2.5, true)
