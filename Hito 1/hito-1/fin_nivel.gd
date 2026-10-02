extends CanvasLayer

@onready var fondo: ColorRect = $Fondo
@onready var reiniciar: Button = %Reiniciar
@onready var salir: Button = %Salir

func _ready() -> void:
	var pausa := get_tree().current_scene.find_child("PauseMenu", true, false)
	if pausa:
		pausa.set_process_input(false)
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	fondo.modulate.a = 0.0
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(fondo, "modulate:a", 1.0, 1.0)
	reiniciar.pressed.connect(_on_reiniciar)
	salir.pressed.connect(func() -> void: get_tree().quit())

func _on_reiniciar() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
