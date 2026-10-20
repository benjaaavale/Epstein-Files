extends Interactuable
class_name Pila

## Pila para la linterna: se toma con E y recarga la bateria al instante.

const SONIDO := preload("res://sonidos/recoger.wav")

@export var carga := 50.0
## Oculta: solo aparece bajo la luz azul (una vez vista, queda a la vista).
@export var oculta := false

var _vista := false


func _ready() -> void:
	_vista = not oculta
	_mostrar(_vista)


func _process(_delta: float) -> void:
	if not _vista and Interactuable.iluminado(_linterna(), global_position, Linterna.Channel.BLUE, 4.0):
		_vista = true
		_mostrar(true)


func _mostrar(si: bool) -> void:
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).set_instance_shader_parameter("force_visible", 1.0 if si else 0.0)


func disponible() -> bool:
	return _vista


func accion() -> String:
	return "Tomar pila"


func interactuar(player: Node) -> void:
	player.linterna.recargar(carga)
	player.hud.toast("Pila", "+%d%% DE BATERÍA" % int(carga))
	_sonar(SONIDO, -4.0)
	player.evento.emit("pila_tomada")
	collision_layer = 0
	queue_free()
