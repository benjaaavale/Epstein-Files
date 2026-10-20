extends Interactuable
class_name RetratoTorcido

## Cuadro torcido: E lo endereza. Con luz roja muestra su numero (I-IV).
## Lo coordina el padre (Retratos), que revisa el orden.

signal enderezado(retrato: RetratoTorcido)

const SONIDO := preload("res://sonidos/crujido_3.wav")

@export_range(1, 4) var numero := 1
@export var inclinacion := 9.0
## Que cuadro se ve (mapa/deco/retrato_N.tscn).
@export_range(1, 2) var pintura := 1

@onready var numeral: MeshInstance3D = $Numeral

var derecho := false
var _tween: Tween


func _ready() -> void:
	add_child(load("res://mapa/deco/retrato_%d.tscn" % pintura).instantiate())
	var mat := (numeral.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	mat.set_shader_parameter("albedo_texture", load("res://mapa/texturas/numeral_%d.png" % numero))
	numeral.material_override = mat
	rotation_degrees.z = inclinacion


func disponible() -> bool:
	return not derecho


func accion() -> String:
	return "Enderezar cuadro"


func interactuar(_player: Node) -> void:
	derecho = true
	_sonar(SONIDO, -4.0, randf_range(1.2, 1.4))
	_girar(0.0, 0.5)
	enderezado.emit(self)


## Vuelve a torcerse (orden equivocado).
func torcer() -> void:
	derecho = false
	_girar(inclinacion * randf_range(0.8, 1.3), 0.35)


func _girar(grados: float, duracion: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "rotation_degrees:z", grados, duracion).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
