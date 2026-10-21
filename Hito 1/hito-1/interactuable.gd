extends StaticBody3D
class_name Interactuable

## Base para todo lo que se usa con E (pilas, cofres, retratos, palancas).
## El jugador pregunta disponible() y accion(), y llama interactuar() al apretar E.


var _linterna_cache: Linterna


## false = el rayo lo ignora (oculto, ya usado, etc.)
func disponible() -> bool:
	return true


## Texto del aviso en pantalla, ej. "Abrir cofre".
func accion() -> String:
	return ""


## false = el aviso sale en rojo y sin tecla.
func habilitado() -> bool:
	return true


func interactuar(_player: Node) -> void:
	pass


## Busca la linterna del jugador (para objetos que se revelan con luz).
func _linterna() -> Linterna:
	if _linterna_cache == null:
		_linterna_cache = get_tree().current_scene.find_child("Linterna", true, false) as Linterna
	return _linterna_cache


## true si la linterna apunta a "punto" con el canal indicado.
static func iluminado(linterna: Linterna, punto: Vector3, canal: Linterna.Channel, distancia := 6.0) -> bool:
	if linterna == null or linterna.current_channel != canal or not linterna.spot_light_3d.visible:
		return false
	var spot := linterna.spot_light_3d
	var v := punto - spot.global_position
	if v.length() > distancia:
		return false
	if v.normalized().dot(-spot.global_transform.basis.z) <= cos(deg_to_rad(spot.spot_angle - 2.0)):
		return false
	# que no haya una pared entre la linterna y el punto
	var q := PhysicsRayQueryParameters3D.create(spot.global_position, punto, 1)
	var hit := linterna.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or (hit.position as Vector3).distance_to(punto) < 0.3


func _sonar(stream: AudioStream, db := 0.0, pitch := 1.0) -> void:
	# el sonido vive en la escena: sigue sonando aunque este objeto desaparezca
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch
	get_tree().current_scene.add_child(p)
	p.global_position = global_position
	p.play()
	p.finished.connect(p.queue_free)
