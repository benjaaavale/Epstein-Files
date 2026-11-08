extends Pila
class_name PilaTrampa

## Parece una pila mas, pero esta podrida: al tomarla da un chispazo, corta la linterna
## y se come parte de la bateria.

const CHISPA := preload("res://sonidos/chispa.wav")
const STINGER := preload("res://sonidos/stinger.wav")

@export var robo := 35.0


func interactuar(player: Node) -> void:
	collision_layer = 0
	_sonar(CHISPA, 6.0)
	_sonar(STINGER, -6.0)
	player.linterna.bateria = maxf(player.linterna.bateria - robo, 3.0)
	player.linterna.apagon(1.6)
	player.sacudir(0.05, 0.6)
	player.hud.destello(0.8, 1.0)
	player.hud.toast("Pila podrida", "-%d%% DE BATERÍA" % int(robo))
	get_tree().call_group("lamparas", "apagon", 1.2)
	player.evento.emit("pila_trampa")
	queue_free()
