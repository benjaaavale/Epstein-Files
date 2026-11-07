extends Node3D

## Tablero con palancas. Solo "correcta" (1, 2 o 3) energiza la puerta; las otras hacen saltar
## chispas y cortan la luz. Los cables (CableVioleta) muestran cual va a la puerta.

const CHISPA := preload("res://sonidos/chispa.wav")
const ZUMBIDO := preload("res://sonidos/zumbido.wav")

@export var puerta: NodePath
## Numero de la palanca que funciona (el que lleva la placa: I = 1, II = 2, III = 3).
@export var correcta := 2

@onready var destello: OmniLight3D = $Destello

var _palancas: Array[Palanca] = []
var _focos: Array[MeshInstance3D] = []
var _listo := false


func _ready() -> void:
	for c in find_children("*", "Palanca", true, false):
		_palancas.append(c as Palanca)
		(c as Palanca).accionada.connect(_on_accionada)
	for i in _palancas.size():
		var foco := get_node_or_null("Foco%d" % (i + 1)) as MeshInstance3D
		if foco != null:
			foco.material_override = (foco.material_override as StandardMaterial3D).duplicate()
		_focos.append(foco)
	destello.light_energy = 0.0


func _color_foco(i: int, c: Color, energia: float) -> void:
	var f := _focos[i] if i < _focos.size() else null
	if f == null:
		return
	var m := f.material_override as StandardMaterial3D
	m.albedo_color = c * 0.4
	m.emission = c
	m.emission_energy_multiplier = energia


func _on_accionada(p: Palanca) -> void:
	if _listo:
		return
	var i := _palancas.find(p)
	if p.numero == correcta:
		_listo = true
		_sonar(ZUMBIDO, 0.0)
		_color_foco(i, Color(0.3, 1.0, 0.35), 3.0)
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
	for k in 5:
		_color_foco(i, Color(1.0, 0.15, 0.1), 4.0 if k % 2 == 0 else 0.2)
		await get_tree().create_timer(0.12).timeout
	_color_foco(i, Color(0.2, 0.05, 0.05), 0.0)
	get_tree().call_group("lamparas", "apagon", 2.5)
	_evento("circuito_error")
	await get_tree().create_timer(0.8).timeout
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
