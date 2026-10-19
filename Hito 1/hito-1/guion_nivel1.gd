extends Node

## Guion del nivel 1: introduccion, monologos del protagonista y momentos clave.

const INTRO := [
	"No recuerdo cómo terminé dentro de este lugar.",
	"Estaba investigando los rumores... las desapariciones de las últimas semanas.",
	"Recorría el patio cuando sentí un golpe seco en la nuca.",
	"Después... nada.",
]

@export var player_path: NodePath = ^"../Player"
@export var llave_inicial_path: NodePath = ^"../Item"
@export var mostrar_intro := true

var _player
var _hud: Hud
var _linterna: Linterna
var _llave: Item
var _dicho := {}
var _intro_activa := false
var _saltar := false


func _ready() -> void:
	_player = get_node(player_path)
	await get_tree().process_frame
	_hud = _player.hud
	_linterna = _player.linterna
	_llave = get_node_or_null(llave_inicial_path) as Item
	_player.evento.connect(_on_evento)
	if mostrar_intro:
		await _intro()
	await get_tree().create_timer(1.2).timeout
	_decir_una_vez("despertar", [
		"¿Dónde... estoy?",
		"Mi linterna se siente rara. Como si alguien la hubiera modificado.",
	])


func _process(_delta: float) -> void:
	if _intro_activa or _linterna == null:
		return
	if _linterna.current_channel != Linterna.Channel.WHITE:
		_decir_una_vez("primer_color", ["Esta luz... muestra cosas que antes no estaban."])
	if _llave != null and not _llave.held and _llave.is_revealed():
		_decir_una_vez("llave_vista", ["¿Eso estaba ahí antes?"])


func _unhandled_input(event: InputEvent) -> void:
	if not _intro_activa:
		return
	var tecla: bool = event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_SPACE
	var clic: bool = event is InputEventMouseButton and event.pressed
	if tecla or clic or event.is_action_pressed("interactuar"):
		_saltar = true
		get_viewport().set_input_as_handled()


func _on_evento(nombre: String) -> void:
	match nombre:
		"puerta_bloqueada":
			_decir_una_vez("puerta", ["Está cerrada. La llave tiene que estar en esta habitación."])
		"documento_leido":
			_decir_una_vez("noticia", ["La mansión Shade... Estoy dentro de la casa de la noticia."])
		"objeto_tomado":
			_decir_una_vez("llave", ["Una llave. Ojalá sea de esa puerta."])
		"puerta_abierta":
			_decir_una_vez("salida", ["Tengo que encontrar la salida antes de que sea tarde."])


func _decir_una_vez(clave: String, lineas: Array) -> void:
	if _dicho.has(clave):
		return
	_dicho[clave] = true
	_hud.decir(lineas)


# ---------- introduccion ----------

func _intro() -> void:
	_intro_activa = true
	_player.bloqueado = true
	_linterna.set_process_input(false)
	_hud.set_cinematic(true)

	var capa := CanvasLayer.new()
	capa.layer = 90
	add_child(capa)
	var negro := ColorRect.new()
	negro.color = Color.BLACK
	UIEstilo.llenar(negro)
	capa.add_child(negro)
	capa.add_child(UIEstilo.capa_ruido({"vignette_amount": 0.8, "grain_amount": 0.08, "flicker_amount": 0.06}))
	var texto := UIEstilo.label("", 22, UIEstilo.HUESO)
	texto.anchor_left = 0.15
	texto.anchor_right = 0.85
	texto.anchor_top = 0.5
	texto.anchor_bottom = 0.5
	texto.offset_top = -40.0
	texto.offset_bottom = 40.0
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	capa.add_child(texto)
	var pista := UIEstilo.label("[ESPACIO] SALTAR", 10, Color(UIEstilo.HUESO, 0.35), true)
	pista.anchor_left = 1.0
	pista.anchor_right = 1.0
	pista.anchor_top = 1.0
	pista.anchor_bottom = 1.0
	pista.offset_left = -220.0
	pista.offset_right = -48.0
	pista.offset_top = -56.0
	pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	capa.add_child(pista)

	await _esperar(1.0)
	for linea: String in INTRO:
		if _saltar:
			break
		texto.text = linea
		texto.visible_ratio = 0.0
		texto.modulate.a = 1.0
		var escribir := create_tween()
		escribir.tween_property(texto, "visible_ratio", 1.0, 0.045 * linea.length())
		await _esperar(0.045 * linea.length() + 1.8)
		if _saltar:
			break
		var borrar := create_tween()
		borrar.tween_property(texto, "modulate:a", 0.0, 0.5)
		await _esperar(0.7)

	texto.modulate.a = 0.0
	pista.visible = false
	var fundido := create_tween()
	fundido.tween_property(negro, "modulate:a", 0.0, 2.0).set_trans(Tween.TRANS_SINE)
	await fundido.finished
	capa.queue_free()

	_intro_activa = false
	_player.bloqueado = false
	_linterna.set_process_input(true)
	_hud.set_cinematic(false)


func _esperar(segundos: float) -> void:
	var t := 0.0
	while t < segundos and not _saltar:
		await get_tree().process_frame
		t += get_process_delta_time()
