extends Node3D

## Tablero con palancas. Solo "correcta" energiza la puerta; las otras hacen saltar chispas
## y cortan la luz. Los cables (CableVioleta) muestran cual va a la puerta.

const CHISPA := preload("res://sonidos/chispa.wav")
const ZUMBIDO := preload("res://sonidos/zumbido.wav")

@export var puerta: NodePath
@export var correcta := 1

@onready var destello: OmniLight3D = $Destello

var _palancas: Array[Palanca] = []
var _listo := false


func _ready() -> void:
	for c in find_children("*", "Palanca", true, false):
		_palancas.append(c as Palanca)
		(c as Palanca).accionada.connect(_on_accionada)
	destello.light_energy = 0.0


func _on_accionada(p: Palanca) -> void:
	if _listo:
		return
	if _palancas.find(p) == correcta:
		_listo = true
		_sonar(ZUMBIDO, 0.0)
		var d := get_node_or_null(puerta) as Door
		if d != null:
			d.energizada = true
		for otra in _palancas:
			otra.bloqueada = true
		_evento("circuito_ok")
		return
	_sonar(CHISPA, 4.0)
	var t := create_tween()
	for e: float in [7.0, 0.5, 5.0, 0.0, 3.0, 0.0]:
		t.tween_property(destello, "light_energy", e, 0.05)
	get_tree().call_group("lamparas", "apagon", 2.5)
	_evento("circuito_error")
	await get_tree().create_timer(1.2).timeout
	p.soltar()


func _sonar(stream: AudioStream, db: float) -> void:
	var s := AudioStreamPlayer3D.new()
	s.stream = stream
	s.volume_db = db
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)


func _evento(nombre: String) -> void:
	var player := get_tree().current_scene.find_child("Player", true, false)
	if player != null:
		player.evento.emit(nombre)
