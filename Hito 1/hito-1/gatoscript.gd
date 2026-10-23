extends Sprite3D
class_name GatoOculto

@export var only_visible_with_red_light: bool = true
@export var fade_speed: float = 3.0 ## Qué tan rápido aparece/desaparece (mayor = más rápido)

var linterna: Linterna = null

func _ready() -> void:
	# Si debe estar oculto, iniciamos su transparencia (canal Alfa) en 0
	if only_visible_with_red_light:
		modulate.a = 0.0
	else:
		modulate.a = 1.0

func _process(delta: float) -> void:
	if only_visible_with_red_light:
		# Definimos el objetivo: 1.0 (totalmente visible) o 0.0 (invisible)
		var target_alpha: float = 1.0 if _lit_by_red_light() else 0.0
		
		# move_toward hace la transición suave a lo largo del tiempo (delta)
		modulate.a = move_toward(modulate.a, target_alpha, fade_speed * delta)

func _lit_by_red_light() -> bool:
	if linterna == null:
		linterna = get_tree().current_scene.find_child("Linterna", true, false) as Linterna
		if linterna == null:
			return false
			
	if linterna.current_channel != Linterna.Channel.RED:
		return false
		
	var spot := linterna.spot_light_3d
	if not spot.visible:
		return false
		
	if global_position.distance_to(spot.global_position) > spot.spot_range:
		return false
		
	var light_dir := -spot.global_transform.basis.z
	var to_item := (global_position - spot.global_position).normalized()
	
	return to_item.dot(light_dir) > cos(deg_to_rad(spot.spot_angle - 2.0))
