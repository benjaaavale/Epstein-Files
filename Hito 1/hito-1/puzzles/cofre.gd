extends Interactuable
class_name Cofre

## Cofre con candado de combinacion. E abre la pantalla del candado en el HUD.

signal abierto

const SONIDO_ABRE := preload("res://sonidos/candado.wav")
const SONIDO_TAPA := preload("res://sonidos/crujido_2.wav")

@export var codigo := "8350"

@onready var tapa: Node3D = $Tapa
@onready var candado: Node3D = $Candado
@onready var forma: CollisionShape3D = $CollisionShape3D

var _abierto := false
var _player: Node


func disponible() -> bool:
	return not _abierto


func accion() -> String:
	return "Usar candado"


func interactuar(player: Node) -> void:
	_player = player
	player.bloquear(true)
	player.hud.abrir_candado(_probar)
	var ok: bool = await player.hud.candado_cerrado
	player.bloquear(false)
	if ok:
		_abrir()


func _probar(intento: String) -> bool:
	var ok := intento == codigo
	if not ok:
		_player.evento.emit("candado_error")
	return ok


func _abrir() -> void:
	_abierto = true
	forma.disabled = true
	_sonar(SONIDO_ABRE)
	var t := create_tween()
	# el candado se suelta y cae
	t.tween_property(candado, "rotation:x", 0.6, 0.15)
	t.tween_property(candado, "position:y", candado.position.y - 0.2, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(candado.hide)
	t.tween_callback(_sonar.bind(SONIDO_TAPA, -6.0, 1.3))
	t.tween_property(tapa, "rotation:x", deg_to_rad(-105.0), 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished
	abierto.emit()
	_player.evento.emit("cofre_abierto")
