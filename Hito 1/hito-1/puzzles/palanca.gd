extends Interactuable
class_name Palanca

## Palanca del tablero electrico. La coordina el padre (Circuito).

signal accionada(palanca: Palanca)

const SONIDO := preload("res://sonidos/palanca.wav")
const ROMANOS := ["I", "II", "III", "IV", "V"]

@export var numero := 1

@onready var brazo: Node3D = $Brazo

var bloqueada := false
var abajo := false


func disponible() -> bool:
	return true


func habilitado() -> bool:
	return not bloqueada


func accion() -> String:
	if abajo:
		return "Palanca %s bajada" % ROMANOS[numero - 1]
	if bloqueada:
		return "Palanca %s" % ROMANOS[numero - 1]
	return "Bajar palanca %s" % ROMANOS[numero - 1]


func interactuar(_player: Node) -> void:
	if bloqueada:
		return
	bloqueada = true
	_sonar(SONIDO, -2.0)
	var t := create_tween()
	t.tween_property(brazo, "rotation_degrees:x", 140.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	abajo = true
	accionada.emit(self)


## Vuelve arriba (palanca equivocada).
func soltar() -> void:
	var t := create_tween()
	t.tween_property(brazo, "rotation_degrees:x", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished
	abajo = false
	bloqueada = false
