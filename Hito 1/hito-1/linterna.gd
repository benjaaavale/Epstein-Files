extends Node3D
class_name Linterna

@onready var spot_light_3d: SpotLight3D = $SpotLight3D
@onready var lente: MeshInstance3D = $Modelo/Lente

enum Channel {WHITE, RED, BLUE, VIOLET}
var current_channel: Channel = Channel.WHITE

var channel_colors: Dictionary = {
	Channel.WHITE: Color(1, 1, 1),
	Channel.RED: Color(1, 0.06, 0.04),
	Channel.BLUE: Color(0.08, 0.3, 1),
	Channel.VIOLET: Color(0.62, 0.08, 1),
}

# Máscaras de luz (Para que la luz pinte los objetos de la capa correcta)
var channel_masks: Dictionary = {
	Channel.WHITE: 1,         
	Channel.RED: 1 + 2,       
	Channel.BLUE: 1 + 4,      
	Channel.VIOLET: 1 + 8     
}

const SIGUIENTE := {
	Channel.WHITE: Channel.RED,
	Channel.RED: Channel.BLUE,
	Channel.BLUE: Channel.WHITE,
	Channel.VIOLET: Channel.WHITE,
}

const ANTERIOR = {
	Channel.RED: Channel.WHITE,
	Channel.BLUE: Channel.RED,
	Channel.WHITE: Channel.BLUE,
	Channel.VIOLET: Channel.WHITE,
}

## Colores disponibles. En false, el color no aparece en el HUD ni se puede elegir.
## Arrancan bloqueados: solo hay luz blanca hasta recoger los filtros (FiltroLinterna).
## combo_unlocked es la luz morada. Tambien se pueden cambiar a mano (linterna.rojo_unlocked = true).
var rojo_unlocked: bool = false
var azul_unlocked: bool = false
var combo_unlocked: bool = false

## Lista de colores del ciclo (blanco, rojo, azul), segun lo desbloqueado.
var colores_disponibles: Array[Channel]:
	get:
		var lista: Array[Channel] = [Channel.WHITE]
		if rojo_unlocked:
			lista.append(Channel.RED)
		if azul_unlocked:
			lista.append(Channel.BLUE)
		return lista


func desbloquear_rojo() -> void:
	rojo_unlocked = true


func desbloquear_azul() -> void:
	azul_unlocked = true


func desbloquear_violeta() -> void:
	combo_unlocked = true

## Bateria: las luces de color la gastan, la blanca no (y la recupera un poco).
signal bateria_agotada
signal sin_bateria
const GASTO := {
	Channel.WHITE: 0.0,
	Channel.RED: 1.4,
	Channel.BLUE: 1.4,
	Channel.VIOLET: 2.2,
}
const RECARGA_BLANCA := 0.6
const RESERVA := 30.0
var bateria := 100.0
var _apagon := 0.0
var _falla := 0.0

# La luz blanca alumbra un cono mas ancho que las luces de color
const ANGULOS := {
	Channel.WHITE: 32.0,
	Channel.RED: 20.0,
	Channel.BLUE: 20.0,
	Channel.VIOLET: 20.0,
}

# Las luces de color pierden brillo percibido: se compensan con mas energia
const ENERGIAS := {
	Channel.WHITE: 1.0,
	Channel.RED: 2.6,
	Channel.BLUE: 2.6,
	Channel.VIOLET: 2.8,
}



func _ready() -> void:
	spot_light_3d.spot_angle = ANGULOS[current_channel]
	spot_light_3d.light_energy = ENERGIAS[current_channel]

# --- NUEVO: Comunicación constante con el Shader Mágico ---
func _process(delta: float) -> void:
	_actualizar_bateria(delta)
	var encendida := _encendida(delta)
	spot_light_3d.visible = encendida
	# Enviamos la posición de la linterna
	RenderingServer.global_shader_parameter_set("flashlight_pos", spot_light_3d.global_position)
	
	# Enviamos la dirección hacia donde apunta
	var forward_dir = -spot_light_3d.global_transform.basis.z
	RenderingServer.global_shader_parameter_set("flashlight_dir", forward_dir)
	
	var angulo_shader = (spot_light_3d.spot_angle) - 2.0
	RenderingServer.global_shader_parameter_set("flashlight_angle", angulo_shader)
	
	# Le decimos al Shader exactamente qué color está activo, de forma independiente
	var is_blue = encendida and current_channel == Channel.BLUE
	RenderingServer.global_shader_parameter_set("is_blue_light_on", is_blue)
	
	var is_red = encendida and current_channel == Channel.RED
	RenderingServer.global_shader_parameter_set("is_red_light_on", is_red)
	
	# Nueva señal exclusiva para la luz Violeta
	var is_violet = encendida and current_channel == Channel.VIOLET
	RenderingServer.global_shader_parameter_set("is_violet_light_on", is_violet)
# ----------------------------------------------------------

func _input(event: InputEvent) -> void:
	# Clic derecho rota las luces; Shift + clic derecho activa/desactiva la morada
	# Clic izquierdo rota hacia la izquierda; Shift + clic activa/desactiva la morada
	var derecha: bool = event.is_action_pressed("CambioColorR")
	if not derecha and not event.is_action_pressed("CambioColorI"):
		return
	if Input.is_action_pressed("ModificadorColor"):
		if combo_unlocked:
			set_channel(Channel.WHITE if current_channel == Channel.VIOLET else Channel.VIOLET)
		return
	var tabla: Dictionary = SIGUIENTE if derecha else ANTERIOR
	var canal: Channel = tabla[current_channel]
	# salta los colores bloqueados
	for i in 4:
		if disponible(canal):
			break
		canal = tabla[canal]
	set_channel(canal)


func disponible(canal: Channel) -> bool:
	match canal:
		Channel.RED:
			return rojo_unlocked
		Channel.BLUE:
			return azul_unlocked
		Channel.VIOLET:
			return combo_unlocked
	return true

func set_channel(channel: Channel) -> void:
	if current_channel == channel:
		return 
	if channel != Channel.WHITE and bateria <= 0.5:
		sin_bateria.emit()
		return
		
	current_channel = channel
	spot_light_3d.light_color = channel_colors[channel]
	var t := create_tween().set_parallel(true)
	t.tween_property(spot_light_3d, "spot_angle", ANGULOS[channel], 0.15)
	t.tween_property(spot_light_3d, "light_energy", ENERGIAS[channel], 0.15)
	(lente.material_override as StandardMaterial3D).emission = channel_colors[channel]
	
	# Mantenemos las colisiones de luz para los otros puzzles (textos, etc)
	spot_light_3d.light_cull_mask = channel_masks[channel]
	spot_light_3d.shadow_caster_mask = channel_masks[channel]
	
	print("Canal actual: ", Channel.keys()[channel])


func _actualizar_bateria(delta: float) -> void:
	# si bloquean el color que esta en uso, vuelve a la luz blanca
	if not disponible(current_channel):
		set_channel(Channel.WHITE)
	var gasto: float = GASTO[current_channel]
	if gasto > 0.0:
		bateria = maxf(bateria - gasto * delta, 0.0)
		if bateria <= 0.0:
			set_channel(Channel.WHITE)
			bateria_agotada.emit()
	elif bateria < RESERVA:
		bateria = minf(bateria + RECARGA_BLANCA * delta, RESERVA)


## Parpadeos: apagones forzados (sustos) y fallas cuando queda poca bateria.
func _encendida(delta: float) -> bool:
	if _apagon > 0.0:
		_apagon -= delta
		return randf() < 0.06
	if current_channel != Channel.WHITE and bateria < 12.0:
		_falla -= delta
		if _falla <= 0.0 and randf() < delta * 2.0:
			_falla = randf_range(0.05, 0.25)
		return _falla <= 0.0
	return true


func recargar(cantidad: float) -> void:
	bateria = minf(bateria + cantidad, 100.0)


## La linterna se corta unos segundos (para sustos).
func apagon(segundos: float) -> void:
	_apagon = segundos
