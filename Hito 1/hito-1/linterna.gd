extends Node3D
class_name Linterna

@onready var spot_light_3d: SpotLight3D = $SpotLight3D

enum Channel {WHITE, RED, BLUE, VIOLET}
var current_channel: Channel = Channel.WHITE

var channel_colors: Dictionary = {
	Channel.WHITE: Color(1, 1, 1),
	Channel.RED: Color(1, 0.2, 0.2),
	Channel.BLUE: Color(0.2, 0.4, 1),
	Channel.VIOLET: Color(0.6, 0.2, 1),
}

# Máscaras de luz (Para que la luz pinte los objetos de la capa correcta)
var channel_masks: Dictionary = {
	Channel.WHITE: 1,         
	Channel.RED: 1 + 2,       
	Channel.BLUE: 1 + 4,      
	Channel.VIOLET: 1 + 8     
}

var combo_unlocked: bool = true 

# --- NUEVO: Comunicación constante con el Shader Mágico ---
func _process(_delta: float) -> void:
	# Enviamos la posición de la linterna
	RenderingServer.global_shader_parameter_set("flashlight_pos", spot_light_3d.global_position)
	
	# Enviamos la dirección hacia donde apunta
	var forward_dir = -spot_light_3d.global_transform.basis.z
	RenderingServer.global_shader_parameter_set("flashlight_dir", forward_dir)
	
	# Le decimos al Shader si el jugador tiene puesto el filtro azul (o violeta)
	var is_blue = (current_channel == Channel.BLUE or current_channel == Channel.VIOLET)
	RenderingServer.global_shader_parameter_set("is_blue_light_on", is_blue)
# ----------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ColorBlanco"):
		set_channel(Channel.WHITE)
		return
	if event.is_action_pressed("ColorRojo"):
		procesar_input_color(Channel.RED)
	elif event.is_action_pressed("ColorAzul"):
		procesar_input_color(Channel.BLUE)

func procesar_input_color(color_presionado: Channel) -> void:
	var modificador_activo = Input.is_action_pressed("ModificadorColor")
	
	if modificador_activo and combo_unlocked:
		if (current_channel == Channel.RED and color_presionado == Channel.BLUE) or \
		   (current_channel == Channel.BLUE and color_presionado == Channel.RED):
			set_channel(Channel.VIOLET)
			return
			
	set_channel(color_presionado)

func set_channel(channel: Channel) -> void:
	if current_channel == channel:
		return 
		
	current_channel = channel
	spot_light_3d.light_color = channel_colors[channel]
	
	# Mantenemos las colisiones de luz para los otros puzzles (textos, etc)
	spot_light_3d.light_cull_mask = channel_masks[channel]
	spot_light_3d.shadow_caster_mask = channel_masks[channel]
	
	print("Canal actual: ", Channel.keys()[channel])
