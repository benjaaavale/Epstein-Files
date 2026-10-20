extends Node

## Autoload: ajustes guardados, cambio de escenas y sonidos de interfaz.

const RUTA := "user://ajustes.cfg"
const MENU_PRINCIPAL := "res://menu_principal.tscn"
const NIVEL_1 := "uid://d1b3xe03jkqbu"

var sensibilidad := 1.0
var volumen := 0.8
var pantalla_completa := true
var inicio_nivel_ms := 0

var _hover: AudioStreamPlayer
var _click: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hover = _crear_sonido("res://sonidos/ui_hover.wav", -18.0)
	_click = _crear_sonido("res://sonidos/ui_click.wav", -6.0)
	cargar()
	aplicar()


func _crear_sonido(ruta: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(ruta)
	p.volume_db = db
	p.max_polyphony = 4
	add_child(p)
	return p


func sonar_hover() -> void:
	_hover.pitch_scale = randf_range(0.9, 1.1)
	_hover.play()


func sonar_click() -> void:
	_click.play()


func aplicar() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volumen, 0.0001)))
	var modo := DisplayServer.window_get_mode()
	var es_completa := modo == DisplayServer.WINDOW_MODE_FULLSCREEN or modo == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if es_completa != pantalla_completa:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if pantalla_completa else DisplayServer.WINDOW_MODE_WINDOWED)


func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA) != OK:
		return
	sensibilidad = cfg.get_value("juego", "sensibilidad", sensibilidad)
	volumen = cfg.get_value("juego", "volumen", volumen)
	pantalla_completa = cfg.get_value("juego", "pantalla_completa", pantalla_completa)


func guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("juego", "sensibilidad", sensibilidad)
	cfg.set_value("juego", "volumen", volumen)
	cfg.set_value("juego", "pantalla_completa", pantalla_completa)
	cfg.save(RUTA)


func ir_a(ruta: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(ruta)


func reiniciar_nivel() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
