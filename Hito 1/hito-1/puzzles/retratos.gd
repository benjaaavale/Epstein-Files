extends Node3D

## Puzzle de los retratos: hay que enderezarlos en el orden de sus numeros (I, II, III, IV).
## Si se equivoca, todos se tuercen de nuevo. Al terminar abre "premio".

const GOLPE := preload("res://sonidos/golpe.wav")

@export var premio: NodePath

var _siguiente := 1
var _resuelto := false
var _retratos: Array[RetratoTorcido] = []


func _ready() -> void:
	for c in get_children():
		if c is RetratoTorcido:
			_retratos.append(c)
			(c as RetratoTorcido).enderezado.connect(_on_enderezado)


func _on_enderezado(r: RetratoTorcido) -> void:
	if _resuelto:
		return
	if r.numero != _siguiente:
		_siguiente = 1
		await get_tree().create_timer(0.6).timeout
		_sonar_golpe()
		for otro in _retratos:
			otro.torcer()
		_evento("retratos_error")
		return
	_siguiente += 1
	if _siguiente > _retratos.size():
		_resuelto = true
		await get_tree().create_timer(0.8).timeout
		var nodo := get_node_or_null(premio)
		if nodo != null and nodo.has_method("abrir"):
			nodo.abrir()
		_evento("retratos_resueltos")


func _sonar_golpe() -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = GOLPE
	p.volume_db = -2.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _evento(nombre: String) -> void:
	var player := get_tree().current_scene.find_child("Player", true, false)
	if player != null:
		player.evento.emit(nombre)
