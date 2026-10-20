extends Interactuable
class_name Palanca

## Palanca del tablero electrico. La coordina el padre (Circuito).

signal accionada(palanca: Palanca)

const SONIDO := preload("res://sonidos/palanca.wav")

@onready var brazo: Node3D = $Brazo

var bloqueada := false


func disponible() -> bool:
	return not bloqueada


func accion() -> String:
	return "Bajar palanca"


func interactuar(_player: Node) -> void:
	bloqueada = true
	_sonar(SONIDO, -2.0)
	var t := create_tween()
	t.tween_property(brazo, "rotation_degrees:x", 140.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	accionada.emit(self)


## Vuelve arriba (palanca equivocada).
func soltar() -> void:
	var t := create_tween()
	t.tween_property(brazo, "rotation_degrees:x", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished
	bloqueada = false
