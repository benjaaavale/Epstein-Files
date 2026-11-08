extends Node3D

## Caja de musica junto a una muneca: suena sola cuando el jugador entra a la sala y,
## si se acerca demasiado, se corta en seco y la muneca gira la cabeza hacia el.

const MUSICA := preload("res://sonidos/caja_musica.wav")
const CLAC := preload("res://sonidos/crujido_3.wav")

@export var muneca_path: NodePath
@export var radio_suena := 8.0
@export var radio_corta := 2.4

var _muneca: Node3D
var _player: Node3D
var _audio: AudioStreamPlayer3D
var _estado := 0 # 0 espera, 1 sonando, 2 terminado


func _ready() -> void:
	_muneca = get_node_or_null(muneca_path) as Node3D
	_audio = AudioStreamPlayer3D.new()
	var m := MUSICA.duplicate() as AudioStreamWAV
	m.loop_mode = AudioStreamWAV.LOOP_FORWARD
	m.loop_end = int(m.get_length() * m.mix_rate)
	_audio.stream = m
	_audio.volume_db = -6.0
	_audio.unit_size = 3.0
	add_child(_audio)


func _process(_delta: float) -> void:
	if _estado == 2:
		return
	if _player == null:
		_player = get_tree().current_scene.find_child("Player", true, false) as Node3D
		return
	var d := _player.global_position.distance_to(global_position)
	if _estado == 0 and d < radio_suena:
		_estado = 1
		_audio.play()
	elif _estado == 1 and d < radio_corta:
		_estado = 2
		_cortar()


func _cortar() -> void:
	_audio.stop()
	var s := AudioStreamPlayer3D.new()
	s.stream = CLAC
	s.pitch_scale = 0.6
	s.volume_db = 6.0
	add_child(s)
	s.play()
	if _muneca != null:
		var hacia := _player.global_position - _muneca.global_position
		var ang := atan2(hacia.x, hacia.z)
		var t := create_tween()
		t.tween_property(_muneca, "rotation:y", ang, 0.08).set_trans(Tween.TRANS_EXPO)
	if _player.has_method("sacudir"):
		_player.sacudir(0.02, 0.3)
	_player.evento.emit("muneca")
