extends Node3D

## Alacena empotrada: se abre sola cuando se resuelve un puzzle.
## El objeto de "contenido" no se puede tomar hasta que se abre.

const SONIDO := preload("res://sonidos/crujido_1.wav")

@export var contenido: NodePath

@onready var puerta: Node3D = $Bisagra


func _ready() -> void:
	await get_tree().process_frame
	var item := get_node_or_null(contenido) as Item
	if item != null:
		item.interact_zone.collision_layer = 0


func abrir() -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = SONIDO
	p.pitch_scale = 0.8
	add_child(p)
	p.play()
	var t := create_tween()
	t.tween_property(puerta, "rotation_degrees:y", -110.0, 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var item := get_node_or_null(contenido) as Item
	if item != null:
		item.interact_zone.collision_layer = 4
