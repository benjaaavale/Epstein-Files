extends Node

## Autoload: ajustes guardados, cambio de escenas y sonidos de interfaz.

const RUTA := "user://ajustes.cfg"
const MENU_PRINCIPAL := "res://menu_principal.tscn"
const NIVEL_1 := "uid://d1b3xe03jkqbu"

var sensibilidad := 1.0
var volumen := 0.8
var pantalla_completa := true
## 0 = alta (como esta hecho el juego), 1 = baja (para PCs lentos)
var calidad := 0
var inicio_nivel_ms := 0

var _hover: AudioStreamPlayer
var _click: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hover = _crear_sonido("res://sonidos/ui_hover.wav", -18.0)
	_click = _crear_sonido("res://sonidos/ui_click.wav", -6.0)
	cargar()
	aplicar()
	# los nodos de cada nivel se ajustan a la calidad elegida apenas aparecen
	get_tree().node_added.connect(_ajustar_nodo)


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
	aplicar_calidad()


## Calidad baja: render al 67% (escalado FSR), texturas mas borrosas, y sin SSAO, brillo,
## niebla volumetrica ni sombras de velas. Calidad alta deja todo como se disenio.
func aplicar_calidad() -> void:
	var baja := calidad == 1
	var raiz := get_tree().root
	raiz.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if baja else Viewport.SCALING_3D_MODE_BILINEAR
	raiz.scaling_3d_scale = 0.67 if baja else 1.0
	raiz.texture_mipmap_bias = 1.0 if baja else 0.0
	raiz.positional_shadow_atlas_size = 2048 if baja else 4096
	for n in raiz.find_children("*", "WorldEnvironment", true, false):
		_ajustar_nodo(n)
	for n in raiz.find_children("*", "OmniLight3D", true, false):
		_ajustar_nodo(n)


func _ajustar_nodo(nodo: Node) -> void:
	var baja := calidad == 1
	if nodo is WorldEnvironment:
		var env := (nodo as WorldEnvironment).environment
		if env == null:
			return
		# la primera vez se guarda como estaba; "alta" siempre vuelve a eso
		if not env.has_meta("alta"):
			env.set_meta("alta", {
				"ssao": env.ssao_enabled, "glow": env.glow_enabled, "niebla": env.volumetric_fog_enabled})
		var alta: Dictionary = env.get_meta("alta")
		env.ssao_enabled = alta.ssao and not baja
		env.glow_enabled = alta.glow and not baja
		env.volumetric_fog_enabled = alta.niebla and not baja
	elif nodo is OmniLight3D:
		var luz := nodo as OmniLight3D
		if not luz.has_meta("sombra_alta"):
			luz.set_meta("sombra_alta", luz.shadow_enabled)
		luz.shadow_enabled = luz.get_meta("sombra_alta") and not baja


func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA) != OK:
		return
	sensibilidad = cfg.get_value("juego", "sensibilidad", sensibilidad)
	volumen = cfg.get_value("juego", "volumen", volumen)
	pantalla_completa = cfg.get_value("juego", "pantalla_completa", pantalla_completa)
	calidad = clampi(int(cfg.get_value("juego", "calidad", calidad)), 0, 1)


func guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("juego", "sensibilidad", sensibilidad)
	cfg.set_value("juego", "volumen", volumen)
	cfg.set_value("juego", "pantalla_completa", pantalla_completa)
	cfg.set_value("juego", "calidad", calidad)
	cfg.save(RUTA)


func ir_a(ruta: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(ruta)


func reiniciar_nivel() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
