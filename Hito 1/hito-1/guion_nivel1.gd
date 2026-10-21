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
@export var nota_path: NodePath = ^"../Cofre/Nota"

const GOLPE := preload("res://sonidos/golpe.wav")
const SUSURRO := preload("res://sonidos/susurro.wav")

# puntos de referencia del nivel para los monologos
const PISADAS := Vector3(-1.0, 0.1, -4.6)
const FIN_RASTRO := Vector3(-4.3, 0.1, -2.1)
const CODIGO := Vector3(-4.0, 1.6, -2.535)
const TABLERO := Vector3(-0.1, 1.45, 9.0)
const CABLES := Vector3(-0.075, 2.55, 8.0)

var _player
var _hud: Hud
var _linterna: Linterna
var _llave: Item
var _dicho := {}
var _intro_activa := false
var _saltar := false
var _nota: Leible
var _revisar := 0.0


func _ready() -> void:
	_player = get_node(player_path)
	await get_tree().process_frame
	_hud = _player.hud
	_linterna = _player.linterna
	_llave = get_node_or_null(llave_inicial_path) as Item
	_nota = get_node_or_null(nota_path) as Leible
	_player.evento.connect(_on_evento)
	_linterna.bateria_agotada.connect(func() -> void:
		_decir_una_vez("bateria_agotada", ["Se agotó... la luz blanca se recupera sola, pero para los colores necesito pilas."]))
	_linterna.sin_bateria.connect(func() -> void: _hud.toast("Sin batería", "LA LUZ DE COLOR NO ENCIENDE"))
	if mostrar_intro:
		await _intro()
	await get_tree().create_timer(1.2).timeout
	_decir_una_vez("despertar", [
		"¿Dónde... estoy?",
		"Mi linterna se siente rara. Como si alguien la hubiera modificado.",
	])


func _process(delta: float) -> void:
	if _intro_activa or _linterna == null:
		return
	if _linterna.current_channel != Linterna.Channel.WHITE:
		_decir_una_vez("primer_color", ["Esta luz... muestra cosas que antes no estaban."])
	if is_instance_valid(_llave) and not _llave.held and _llave.is_revealed():
		_decir_una_vez("llave_vista", ["¿Eso estaba ahí antes?"])
	_revisar -= delta
	if _revisar > 0.0:
		return
	_revisar = 0.2
	var pos: Vector3 = _player.global_position
	if _linterna.bateria < 20.0:
		_decir_una_vez("bateria_baja", ["La linterna se está debilitando. Los colores gastan la batería."])
	if Interactuable.iluminado(_linterna, PISADAS, Linterna.Channel.RED, 6.0):
		_decir_una_vez("pisadas", ["Pisadas... con sangre.", "Alguien caminó descalzo por aquí. Voy a seguirlas."])
	if _dicho.has("pisadas") and pos.distance_to(FIN_RASTRO) < 1.6:
		_decir_una_vez("fin_rastro", ["Las pisadas terminan en la pared.", "Tal vez otra luz muestre lo que hay aquí."])
	if Interactuable.iluminado(_linterna, CODIGO, Linterna.Channel.BLUE, 5.0):
		_decir_una_vez("codigo", ["Ocho... tres... cinco... cero.", "Tengo que recordarlo."])
	if pos.distance_to(TABLERO) < 2.5:
		_decir_una_vez("tablero", ["Un tablero eléctrico, con tres palancas.", "¿Hacia dónde irán los cables?"])
	if Interactuable.iluminado(_linterna, CABLES, Linterna.Channel.VIOLET, 5.0):
		_decir_una_vez("cables", ["Cables... solo se ven con esta luz. Uno de ellos va a la puerta."])


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
			if _nota != null and _nota.leido:
				_decir_una_vez("nota", ["Cuatro retratos en la sala del este...", "Y la llave que dejó a la vista es una trampa."])
			else:
				_decir_una_vez("noticia", ["La mansión Shade... Estoy dentro de la casa de la noticia."])
		"objeto_tomado":
			var en_mano: Item = _player.held_item
			if en_mano != null and en_mano.abre != "":
				_decir_una_vez("llave_real", ["Esta llave es distinta. Pesada... antigua."])
			else:
				_decir_una_vez("llave", ["Una llave. Ojalá sea de esa puerta."])
		"puerta_abierta":
			_decir_una_vez("salida", ["Tengo que encontrar la salida antes de que sea tarde."])
		"pila_tomada":
			_decir_una_vez("pila", ["Pilas. Las voy a necesitar."])
		"candado_error":
			_decir_una_vez("candado_error", ["No es esa combinación. Los números tienen que estar escritos en algún lado."])
		"cofre_abierto":
			_decir_una_vez("cofre", ["Una página arrancada... y algo más."])
		"retratos_error":
			_sonido(SUSURRO, -10.0)
			_decir_una_vez("retratos_error", ["Se torcieron otra vez... todos a la vez.", "Ese no era el orden."])
		"retratos_resueltos":
			_decir_una_vez("retratos_ok", ["Algo se abrió junto a los cuadros."])
		"llave_falsa":
			_susto_llave()
		"puerta_sin_energia":
			_decir_una_vez("sin_energia", ["La llave entra, pero no gira. Algo la traba por dentro.", "Escucho un zumbido... ¿electricidad?"])
		"circuito_error":
			_player.sacudir(0.03, 0.5)
			_hud.destello(0.6, 0.8)
			_decir_una_vez("circuito_error", ["¡Ah! Esa no era.", "Tengo que seguir el cable correcto."])
		"circuito_ok":
			_decir_una_vez("circuito_ok", ["Algo zumba detrás de la puerta. Ahora sí debería girar."])


## La llave falsa se parte: apagon, golpe y un susurro.
func _susto_llave() -> void:
	get_tree().call_group("lamparas", "apagon", 3.2)
	_linterna.apagon(2.4)
	_sonido(GOLPE, 2.0)
	_hud.destello(0.9, 2.2)
	_player.sacudir(0.06, 0.8)
	await get_tree().create_timer(1.4).timeout
	_sonido(SUSURRO, -4.0)
	_decir_una_vez("llave_falsa", ["¡Se partió dentro!", "Esa no era la llave... y no estoy solo aquí."])


func _sonido(stream: AudioStream, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


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
