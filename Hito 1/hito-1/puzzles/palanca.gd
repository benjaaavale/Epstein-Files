extends Interactuable
class_name Palanca

## Ranura y palanca del tablero electrico. La coordina el padre (Circuito).

signal accionada(palanca: Palanca)

const SONIDO := preload("res://sonidos/palanca.wav")
const ROMANOS := ["I", "II", "III", "IV", "V"]

@export var numero := 1
## Si es false, empieza como un hueco vacio hasta que el jugador coloque el item "Palanca".
@export var instalada := false

@onready var brazo: Node3D = $Brazo

var bloqueada := false
var abajo := false
var _player: Node = null
var _item_guardado: Item = null


func _ready() -> void:
	brazo.visible = instalada


func _tiene_palanca_en_mano() -> bool:
	if _player == null:
		_player = get_tree().current_scene.find_child("Player", true, false)
	if _player == null:
		return false
	var en_mano: Item = _player.inventario[_player.slot_activo]
	return en_mano != null and en_mano.item_name == "Palanca"


func disponible() -> bool:
	return true


func habilitado() -> bool:
	if bloqueada:
		return false
	if not instalada:
		return _tiene_palanca_en_mano()
	return true


func accion() -> String:
	var num_txt: String = ROMANOS[numero - 1]
	if not instalada:
		if _tiene_palanca_en_mano():
			return "Colocar palanca en ranura %s" % num_txt
		return "Ranura %s vacía (falta palanca)" % num_txt
	if abajo:
		return "Palanca %s bajada" % num_txt
	if bloqueada:
		return "Palanca %s" % num_txt
	return "Bajar palanca %s" % num_txt


func interactuar(player: Node) -> void:
	if bloqueada:
		return
	_player = player
	
	# 1. Si el hueco esta vacio, instalamos la palanca desde la mano del jugador
	if not instalada:
		if not _tiene_palanca_en_mano():
			return
		var slot: int = player.slot_activo
		var item: Item = player.inventario[slot]
		player.inventario[slot] = null
		player.hud.limpiar_icono_inventario(slot)
		player._actualizar_visibilidad_mano()
		
		# Guardamos el item oculto dentro de la ranura por si salta con un cortocircuito
		item.reparent(self, false)
		item.visible = false
		_item_guardado = item
		
		instalada = true
		brazo.rotation_degrees.x = 0.0
		brazo.visible = true
		_sonar(SONIDO, -4.0)
		return

	# 2. Si ya esta instalada, la bajamos para activar el circuito
	bloqueada = true
	_sonar(SONIDO, -2.0)
	var t := create_tween()
	t.tween_property(brazo, "rotation_degrees:x", 140.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	abajo = true
	accionada.emit(self)


## Vuelve arriba y expulsa la palanca si fue colocada en la ranura equivocada.
func soltar() -> void:
	var t := create_tween()
	t.tween_property(brazo, "rotation_degrees:x", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished
	abajo = false
	bloqueada = false
	
	if _item_guardado != null:
		instalada = false
		brazo.visible = false
		var item := _item_guardado
		_item_guardado = null
		
		var adelante := global_transform.basis.z.normalized()
		item.reparent(get_tree().current_scene, false)
		item.global_position = global_position + adelante * 0.35
		item.visible = true
		item.drop()
		item.linear_velocity = adelante * 1.8 + Vector3.UP * 1.5
		if _player != null and _player.has_node("HUD"):
			_player.hud.toast("El cortocircuito expulsó la palanca", "RANURA INCORRECTA")
