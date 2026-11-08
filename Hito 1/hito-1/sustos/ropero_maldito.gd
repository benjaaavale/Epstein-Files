extends Interactuable

## La puerta cerrada del ropero. Al acercarse se oyen golpes desde dentro; al abrirlo
## no hay nada... salvo una respiracion, y "Ella" aparece detras del jugador.

const GOLPES := preload("res://sonidos/golpes_puerta.wav")
const RESPIRA := preload("res://sonidos/respiracion.wav")
const STINGER := preload("res://sonidos/stinger.wav")

@export var puerta_path: NodePath
@export var presencia_path: NodePath

var _abierto := false
var _golpeo := false
var _player: Node3D


func _process(_delta: float) -> void:
	if _golpeo or _abierto:
		return
	if _player == null:
		_player = get_tree().current_scene.find_child("Player", true, false) as Node3D
		return
	if _player.global_position.distance_to(global_position) < 3.2:
		_golpeo = true
		_sonar(GOLPES, -2.0, 1.15)
		_player.evento.emit("ropero_golpes")


func disponible() -> bool:
	return not _abierto


func accion() -> String:
	return "Abrir ropero"


func interactuar(player: Node) -> void:
	_abierto = true
	collision_layer = 0
	var puerta := get_node_or_null(puerta_path) as Node3D
	if puerta != null:
		# bisagra en el borde exterior de la puerta
		var bisagra := Node3D.new()
		puerta.get_parent().add_child(bisagra)
		bisagra.position = puerta.position + Vector3(-0.32, 0, 0)
		puerta.reparent(bisagra, true)
		var t := create_tween()
		t.tween_property(bisagra, "rotation_degrees:y", -105.0, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sonar(RESPIRA, 0.0)
	await get_tree().create_timer(2.4).timeout
	# Ella, justo detras
	var presencia := get_node_or_null(presencia_path) as Node3D
	var p := player as Node3D
	if presencia != null and presencia.has_method("aparecer"):
		var atras: Vector3 = p.global_transform.basis.z.normalized()
		presencia.global_position = Vector3(p.global_position.x, p.global_position.y - 1.0, p.global_position.z) + atras * 1.4
		presencia.look_at(p.global_position, Vector3.UP)
		presencia.rotation.x = 0.0
		presencia.aparecer(2.5)
	_sonar(STINGER, 2.0)
	get_tree().call_group("lamparas", "apagon", 2.0)
	player.sacudir(0.05, 0.7)
	player.evento.emit("ropero_abierto")
