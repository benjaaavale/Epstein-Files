extends Sprite3D
class_name ScreamerGato

@export var trigger_distance: float = 2.5 ## Qué tan cerca (en metros) debe estar el jugador para activarlo
@export var tiempo_visible: float = 0.5 ## Cuántos segundos dura la imagen en pantalla antes de desaparecer
@export var fuerza_temblor: float = 0.06 ## Qué tan violento es el temblor de la cámara
@export var duracion_temblor: float = 0.6 ## Cuánto dura el temblor de la pantalla

@onready var audio_screamer: AudioStreamPlayer = $AudioStreamPlayer 

var linterna: Linterna = null
var ya_activado: bool = false

func _ready() -> void:
	# Comienza totalmente invisible
	modulate.a = 0.0 

func _process(_delta: float) -> void:
	# Si ya nos asustó, no hacemos nada más
	if ya_activado:
		return
		
	# Comprobamos constantemente si la luz lo toca y estamos cerca
	if _lit_by_red_light_and_close():
		_activar_screamer()

func _lit_by_red_light_and_close() -> bool:
	if linterna == null:
		linterna = get_tree().current_scene.find_child("Linterna", true, false) as Linterna
		if linterna == null:
			return false
			
	if linterna.current_channel != Linterna.Channel.RED:
		return false
		
	var spot := linterna.spot_light_3d
	if not spot.visible:
		return false
		
	# 1. Verificar la distancia para que no se active de lejos
	if global_position.distance_to(spot.global_position) > trigger_distance:
		return false
		
	# 2. Verificar que la luz lo esté apuntando directamente
	var light_dir := -spot.global_transform.basis.z
	var to_item := (global_position - spot.global_position).normalized()
	
	return to_item.dot(light_dir) > cos(deg_to_rad(spot.spot_angle - 2.0))

func _activar_screamer() -> void:
	ya_activado = true # Bloquea futuras activaciones
	
	# 1. Hacer que aparezca de golpe (sin fade)
	modulate.a = 1.0 
	
	# 2. Reproducir el grito/sonido fuerte
	if audio_screamer != null:
		audio_screamer.play()
		
	# 3. Buscar al jugador y hacer temblar la pantalla
	var player = get_tree().current_scene.find_child("player", true, false)
	# Fallback por si la primera letra está en mayúscula en tu árbol de nodos
	if player == null:
		player = get_tree().current_scene.find_child("Player", true, false)
		
	if player != null and player.has_method("sacudir"):
		player.sacudir(fuerza_temblor, duracion_temblor)
		
	# 4. Esperar el tiempo indicado en 'tiempo_visible'
	await get_tree().create_timer(tiempo_visible).timeout
	
	# 5. Desaparecer y eliminar el nodo para siempre
	queue_free()
