extends Node

## Autoload: ajustes guardados, cambio de escenas y sonidos de interfaz.

const RUTA := "user://ajustes.cfg"
## La mansion es la escena principal: su menu (MenuMansion) aparece encima al cargarla.
const MANSION := "res://diseño_pruebafinal.tscn"
const MENU_PRINCIPAL := MANSION
const NIVEL_1 := MANSION

var sensibilidad := 1.0
var volumen := 0.8
var pantalla_completa := true
## 0 = alta (todo, con SSAO), 2 = media (sin SSAO: es lo que mas cuesta), 1 = baja (para PCs lentos)
const ALTA := 0
const BAJA := 1
const MEDIA := 2
var calidad := MEDIA
var inicio_nivel_ms := 0
## true = la proxima carga de la mansion entra directo al juego (al reiniciar el nivel).
var saltar_menu := false

var _hover: AudioStreamPlayer
var _click: AudioStreamPlayer

## Luces que pueden proyectar sombra. Solo las mas cercanas a la camara la proyectan de verdad:
## cada luz omni con sombra vuelve a dibujar la escena, y eso es lo que mas cuesta.
const SOMBRAS_ALTA := 3
const SOMBRAS_BAJA := 1
## Ancho maximo (en pixeles) al que se dibuja el 3D. En pantallas Retina/4K se escala con FSR.
const ANCHO_3D_MAX := 1920.0
var _luces_sombra: Array[OmniLight3D] = []
var _revisar_luces := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hover = _crear_sonido("res://sonidos/ui_hover.wav", -18.0)
	_click = _crear_sonido("res://sonidos/ui_click.wav", -6.0)
	cargar()
	aplicar()
	# los nodos de cada nivel se ajustan a la calidad elegida apenas aparecen
	get_tree().node_added.connect(_ajustar_nodo)
	get_tree().root.size_changed.connect(_ajustar_escala_3d)


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
	_ajustar_escala_3d()
	raiz.texture_mipmap_bias = 1.0 if baja else 0.0
	raiz.positional_shadow_atlas_size = 1024 if baja else 2048
	for n in raiz.find_children("*", "WorldEnvironment", true, false):
		_ajustar_nodo(n)
	for n in raiz.find_children("*", "OmniLight3D", true, false):
		_ajustar_nodo(n)


## El 3D se dibuja a lo sumo a ANCHO_3D_MAX pixeles de ancho (calidad baja: 67% de eso).
func _ajustar_escala_3d() -> void:
	var raiz := get_tree().root
	var ancho := float(maxi(raiz.size.x, 1))
	var escala := minf(1.0, ANCHO_3D_MAX / ancho)
	if calidad == 1:
		escala *= 0.67
	raiz.scaling_3d_scale = escala
	raiz.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if escala < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR


func _process(delta: float) -> void:
	_revisar_luces -= delta
	if _revisar_luces > 0.0:
		return
	_revisar_luces = 0.25
	var cam := get_viewport().get_camera_3d()
	if cam == null or _luces_sombra.is_empty():
		return
	var origen := cam.global_position
	var vivas: Array[OmniLight3D] = []
	for l in _luces_sombra:
		if is_instance_valid(l) and l.is_inside_tree():
			vivas.append(l)
	_luces_sombra = vivas
	vivas.sort_custom(func(a: OmniLight3D, b: OmniLight3D) -> bool:
		return a.global_position.distance_squared_to(origen) < b.global_position.distance_squared_to(origen))
	var cupo := SOMBRAS_BAJA if calidad == 1 else SOMBRAS_ALTA
	for i in vivas.size():
		vivas[i].shadow_enabled = i < cupo and vivas[i].is_visible_in_tree()


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
		env.ssao_enabled = alta.ssao and calidad == ALTA
		env.glow_enabled = alta.glow and not baja
		env.volumetric_fog_enabled = alta.niebla and not baja
	elif nodo is MeshInstance3D:
		# las piezas chicas (velas, platos, libros...) no se dibujan a mas de 24 m:
		# en una casa con muchas paredes casi nunca se ven desde tan lejos
		var m := nodo as MeshInstance3D
		if m.mesh != null and m.visibility_range_end == 0.0 and m.mesh.get_aabb().size.length() < 1.2:
			m.visibility_range_end = 24.0
	elif nodo is OmniLight3D:
		var luz := nodo as OmniLight3D
		if luz.has_meta("sombra_alta"):
			return
		luz.set_meta("sombra_alta", luz.shadow_enabled)
		# paraboloide doble: 2 pasadas de sombra en vez de 6
		luz.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
		# las luces lejanas se apagan solas (detras de las paredes no se ven igual)
		luz.distance_fade_enabled = true
		luz.distance_fade_begin = 18.0
		luz.distance_fade_length = 4.0
		luz.distance_fade_shadow = 12.0
		if luz.shadow_enabled:
			luz.shadow_enabled = false
			_luces_sombra.append(luz)


func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA) != OK:
		return
	sensibilidad = cfg.get_value("juego", "sensibilidad", sensibilidad)
	volumen = cfg.get_value("juego", "volumen", volumen)
	pantalla_completa = cfg.get_value("juego", "pantalla_completa", pantalla_completa)
	# clave nueva: la calidad por defecto paso a ser MEDIA
	calidad = clampi(int(cfg.get_value("juego", "calidad_v2", calidad)), 0, 2)


func guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("juego", "sensibilidad", sensibilidad)
	cfg.set_value("juego", "volumen", volumen)
	cfg.set_value("juego", "pantalla_completa", pantalla_completa)
	cfg.set_value("juego", "calidad_v2", calidad)
	cfg.save(RUTA)


func ir_a(ruta: String) -> void:
	get_tree().paused = false
	saltar_menu = false
	get_tree().change_scene_to_file(ruta)


func reiniciar_nivel() -> void:
	get_tree().paused = false
	saltar_menu = true
	get_tree().reload_current_scene()
