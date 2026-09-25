extends Node3D
class_name Linterna

@onready var spot_light_3d: SpotLight3D = $SpotLight3D
@onready var camera: Camera3D

enum Channel {WHITE, RED, BLUE, VIOLET}
var current_channel: Channel = Channel.WHITE

var channel_colors: Dictionary = {
	Channel.WHITE: Color(1, 1, 1),
	Channel.RED: Color(1, 0.2, 0.2),
	Channel.BLUE: Color(0.2, 0.4, 1),
	Channel.VIOLET: Color(0.6, 0.2, 1),
}

var channel_masks: Dictionary = {
	Channel.WHITE: 1,         # Solo ilumina la Capa 1 (Mundo normal)
	Channel.RED: 1 ,       # Ilumina la Capa 1 + Capa 2 (Pistas Rojas)
	Channel.BLUE: 1 ,      # Ilumina la Capa 1 + Capa 3 (Pistas Azules)
	Channel.VIOLET: 1      # Ilumina la Capa 1 + Capa 4 (Pistas Violetas)
}

var camera_masks: Dictionary = {
	Channel.WHITE: 1 + 2 + 4 + 8 + 16,
	Channel.RED:   1 + 2 + 4 + 8 + 16,
	Channel.BLUE:  1 + 2 + 4 + 8,      # Solo aquí ocultamos la Capa 5
	Channel.VIOLET: 1 + 2 + 4 + 8 + 16
}

var combo_unlocked: bool = true

func _ready() -> void:
	# Cuando el juego arranca, la linterna busca automáticamente 
	# la cámara principal que esté usando el jugador.
	camera = get_viewport().get_camera_3d()

func _input(event: InputEvent) -> void:
	# Si presiona Blanco, resetea a luz normal
	if event.is_action_pressed("ColorBlanco"):
		set_channel(Channel.WHITE)
		return

	# Evaluamos las pulsaciones de Rojo y Azul
	if event.is_action_pressed("ColorRojo"):
		procesar_input_color(Channel.RED)
	elif event.is_action_pressed("ColorAzul"):
		procesar_input_color(Channel.BLUE)

func procesar_input_color(color_presionado: Channel) -> void:
	var modificador_activo = Input.is_action_pressed("ModificadorColor")
	
	if modificador_activo and combo_unlocked:
		# Lógica del combo: Base + Modificador + Combinar
		# Si estoy en Rojo y toco Azul (con modificador), o si estoy en Azul y toco Rojo
		if (current_channel == Channel.RED and color_presionado == Channel.BLUE) or \
		   (current_channel == Channel.BLUE and color_presionado == Channel.RED):
			set_channel(Channel.VIOLET)
			return
			
	# Si no se cumple el combo (no hay modificador, o tocó el mismo color),
	# simplemente cambia al color base que presionó.
	set_channel(color_presionado)

func set_channel(channel: Channel) -> void:
	if current_channel == channel:
		return 
		
	current_channel = channel
	spot_light_3d.light_color = channel_colors[channel]
	spot_light_3d.light_cull_mask = channel_masks[channel]
	spot_light_3d.shadow_caster_mask = channel_masks[channel]
	
	# --- AÑADIDO 3: Le pasamos la máscara a la cámara ---
	if camera:
		camera.cull_mask = camera_masks[channel]
	print("Canal actual: ", Channel.keys()[channel])
	
func unlock_combo() -> void:
	combo_unlocked = true
	print("Combinación de colores desbloqueada")
