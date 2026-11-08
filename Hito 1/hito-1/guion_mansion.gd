extends Node

## Guion de la mansion Ebner: introduccion, objetivos, monologos y sustos.
##
## Recorrido (cada paso usa lo que dio el anterior):
##  1. Cuarto de servicio: filtro ROJO en la mesa -> pisadas de sangre -> llave sobre una caja.
##  2. Planta baja: la puerta principal no gira (sin energia) y la llave dorada del hall es una trampa.
##  3. Salon: cuatro retratos torcidos; con luz roja se ve su numero -> enderezarlos en orden
##     abre la alacena con el filtro AZUL.
##  4. Biblioteca: con luz azul aparece el codigo 0417 -> cofre del dormitorio (2° piso)
##     con el filtro VIOLETA y el diario.
##  5. La luz morada borra la pared falsa del rellano -> cuarto sellado con la llave antigua (y "Ella").
##  6. Hall: con luz morada se ven los cables del tablero -> la palanca correcta da energia.
##  7. Puerta principal + llave antigua = salida.
## Extra: una pared falsa en el hall esconde el cuarto de los desaparecidos.

const INTRO := [
	"No recuerdo cómo terminé dentro de este lugar.",
	"Estaba investigando las desapariciones... seis personas en un año, todas cerca de la mansión Ebner.",
	"Crucé el portón oxidado cuando sentí un golpe seco en la nuca.",
	"Después... nada.",
]

const GOLPE := preload("res://sonidos/golpe.wav")
const SUSURRO := preload("res://sonidos/susurro.wav")
const PASOS_ARRIBA := preload("res://sonidos/pasos_arriba.wav")
const GOLPES_PUERTA := preload("res://sonidos/golpes_puerta.wav")
const CANDELABRO_CAE := preload("res://sonidos/candelabro_cae.wav")
const ARRASTRE := preload("res://sonidos/arrastre.wav")
const TABLA := preload("res://sonidos/tabla_rota.wav")
const PORTAZO := preload("res://sonidos/portazo.wav")
const LATIDO := preload("res://sonidos/latido.wav")
const STINGER := preload("res://sonidos/stinger.wav")

@export var player_path: NodePath = ^"../Player"
@export var mostrar_intro := true
@export var nota_path: NodePath = ^"../Elementos_piso2/Cofre/Nota"
@export var presencia_path: NodePath = ^"../Elementos_piso2/Presencia"

# puntos de referencia del nivel
const RASTRO := Vector3(-12.0, -0.38, -3.4)
const LLAVE_CAJA := Vector3(-13.7, 0.3, -0.75)
const RETRATOS := Vector3(3.4, 1.3, -8.1)
const CODIGO := Vector3(-8.0, 1.3, -8.06)
const TABLERO := Vector3(3.1, 1.15, 3.3)
const CABLES := Vector3(3.2, 2.7, 3.38)
const PUERTA_PRINCIPAL := Vector3(0.8, 0.6, 3.2)
const TRAMPA := Vector3(-1.45, 0.45, 2.8)
const MURO_ESTE := Vector3(9.42, 3.4, -10.9)
const MURO_OESTE := Vector3(-7.95, 0.7, 1.77)
const ESCALERA_ARRIBA := Vector3(0.0, 2.4, -9.0)
const COFRE := Vector3(-14.2, 2.6, -4.0)
const ALTAR := Vector3(12.3, 3.0, 2.2)
const SALON := Vector3(2.0, 0.6, -11.0)
const HALL_CENTRO := Vector3(0.43, -0.4, -2.34)
const COMEDOR := Vector3(12.3, 0.6, -11.0)
const TABLA_FLOJA := Vector3(3.0, 3.36, -10.4)
const SELLADO := Vector3(12.3, 3.36, -5.0)

var _player
var _hud: Hud
var _linterna: Linterna
var _nota: Leible
var _presencia: Node3D
var _dicho := {}
var _intro_activa := false
var _saltar := false
var _revisar := 0.0
var _en_marcha := false

# progreso
var _salio := false
var _puerta_probada := false
var _codigo_visto := false
var _cofre := false
var _llave_real := false
var _energia := false
var _muro_este := false
var _latido: AudioStreamPlayer


func _ready() -> void:
	_player = get_node(player_path)
	await get_tree().process_frame
	_hud = _player.hud
	_linterna = _player.linterna
	_nota = get_node_or_null(nota_path) as Leible
	_presencia = get_node_or_null(presencia_path) as Node3D
	_player.evento.connect(_on_evento)
	_linterna.bateria_agotada.connect(func() -> void:
		_decir_una_vez("bateria_agotada", ["Se agotó... la luz blanca vuelve sola, pero los colores necesitan pilas."]))
	_linterna.sin_bateria.connect(func() -> void: _hud.toast("Sin batería", "LA LUZ DE COLOR NO ENCIENDE"))
	# si la mansion tiene su menu, se espera a que el jugador entre
	var menu := get_parent().get_node_or_null("MenuInicio")
	if menu != null and menu.get("activo"):
		await menu.empezar
	_en_marcha = true
	if mostrar_intro:
		await _intro()
	_actualizar_objetivo()
	await get_tree().create_timer(1.0).timeout
	_decir_una_vez("despertar", [
		"¿Dónde... estoy?",
		"Mi linterna se siente rara. Alguien le cambió el cabezal: tiene un soporte para filtros.",
	])


# ---------- objetivos ----------

func _actualizar_objetivo() -> void:
	if _hud == null:
		return
	var o := ""
	if not _linterna.rojo_unlocked:
		o = "Revisa la habitación. Algo sobre la mesa podría servir."
	elif not _salio:
		o = "Usa la luz roja (clic derecho) para encontrar la llave de la puerta."
	elif not _linterna.azul_unlocked:
		if _dicho.has("retratos"):
			o = "Endereza los retratos del salón en el orden correcto. La luz roja muestra algo en ellos."
		elif _puerta_probada:
			o = "La puerta principal no abre. Explora la planta baja."
		else:
			o = "Encuentra la salida de la mansión."
	elif not _cofre:
		if _codigo_visto:
			o = "Abre el cofre del dormitorio del segundo piso (0417)."
		else:
			o = "Usa la luz azul. Algo está escrito donde nadie debía verlo."
	elif not _llave_real:
		o = "Con la luz morada (Shift + clic) busca la pared que no existe, en el segundo piso."
	elif not _energia:
		o = "Dale energía a la puerta: sigue el cable morado hasta el tablero del hall."
	else:
		o = "Abre la puerta principal con la llave antigua y escapa."
	_hud.objetivo(o)


# ---------- monologos por lugar y por luz ----------

func _process(delta: float) -> void:
	if not _en_marcha or _intro_activa or _linterna == null:
		return
	_revisar -= delta
	if _revisar > 0.0:
		return
	_revisar = 0.2
	var pos: Vector3 = _player.global_position
	if _linterna.current_channel != Linterna.Channel.WHITE:
		_decir_una_vez("primer_color", ["Esta luz... muestra cosas que antes no estaban."])
	if _linterna.bateria < 20.0:
		_decir_una_vez("bateria_baja", ["La linterna se está debilitando. Los colores gastan la batería."])
	_sustos(pos)
	if Interactuable.iluminado(_linterna, RASTRO, Linterna.Channel.RED, 7.0):
		_decir_una_vez("pisadas", ["Pisadas... con sangre.", "Alguien caminó descalzo por aquí. Voy a seguirlas."])
	if Interactuable.iluminado(_linterna, LLAVE_CAJA, Linterna.Channel.RED, 5.0):
		_decir_una_vez("llave_vista", ["¿Eso estaba ahí antes?"])
	if _salio and pos.distance_to(PUERTA_PRINCIPAL) < 3.0:
		_decir_una_vez("puerta_principal", ["La puerta principal. Por ahí entré."])
	if _salio and pos.distance_to(TRAMPA) < 2.8:
		_decir_una_vez("trampa", ["Una llave dorada, a la vista de cualquiera...", "Demasiado fácil."])
	if pos.distance_to(SALON) < 4.5:
		_decir_una_vez("salon", ["El salón. Los retratos están todos torcidos."])
	if Interactuable.iluminado(_linterna, RETRATOS, Linterna.Channel.RED, 7.0):
		if _decir_una_vez("retratos", ["Números romanos... uno en cada retrato.", "¿El orden en que se fueron?"]):
			_actualizar_objetivo()
	if Interactuable.iluminado(_linterna, CODIGO, Linterna.Channel.BLUE, 7.0):
		if _decir_una_vez("codigo", ["Cero... cuatro... uno... siete.", "«El cofre duerme arriba, junto a su cama.»"]):
			_codigo_visto = true
			_actualizar_objetivo()
	if pos.distance_to(TABLERO) < 3.0:
		_decir_una_vez("tablero", ["Un tablero eléctrico con tres palancas.", "Si bajo la equivocada... mejor saber hacia dónde van los cables."])
	if Interactuable.iluminado(_linterna, CABLES, Linterna.Channel.VIOLET, 7.0):
		_decir_una_vez("cables", ["Cables... solo se ven con esta luz. Se cruzan.", "Tengo que seguir el que llega a la puerta."])
	if pos.distance_to(ESCALERA_ARRIBA) < 2.5:
		_decir_una_vez("arriba", ["El segundo piso. Huele a humedad... y a algo peor."])
	if pos.distance_to(COFRE) < 3.0:
		_decir_una_vez("cofre_visto", ["Un cofre con candado de cuatro números."])
	if _linterna.combo_unlocked and not _muro_este and pos.distance_to(MURO_ESTE) < 4.0:
		_decir_una_vez("muro_cerca", ["Esta pared... el papel es distinto.", "«La pared miente.»"])
	if _linterna.combo_unlocked and pos.distance_to(MURO_OESTE) < 3.5:
		_decir_una_vez("muro_oeste", ["Aquí también hay algo raro en la pared."])
	if _muro_este and pos.distance_to(ALTAR) < 4.0:
		_decir_una_vez("altar", ["Un altar...", "Y seis sillas. Una por cada desaparecido."])


func _unhandled_input(event: InputEvent) -> void:
	if not _intro_activa:
		return
	var tecla: bool = event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_SPACE
	var clic: bool = event is InputEventMouseButton and event.pressed
	if tecla or clic or event.is_action_pressed("interactuar"):
		_saltar = true
		get_viewport().set_input_as_handled()


# ---------- eventos del jugador y de los puzzles ----------

func _on_evento(nombre: String) -> void:
	match nombre:
		"filtro_rojo":
			_decir_una_vez("filtro_rojo", ["Un filtro rojo. Encaja justo en la linterna."])
		"filtro_azul":
			_decir_una_vez("filtro_azul", ["Azul. ¿Qué más esconde esta casa?"])
		"filtro_violeta":
			_decir_una_vez("filtro_violeta", ["Un filtro violeta... se suma a los otros.", "Con esta luz la pared parece... deshacerse."])
		"puerta_bloqueada":
			_decir_una_vez("puerta", ["Está cerrada. Necesito una llave."])
		"documento_leido":
			if _nota != null and _nota.leido:
				_decir_una_vez("nota", ["«Lo que no existe se borra con luz morada.»", "La llave está tras la pared del este."])
			else:
				_decir_una_vez("noticia", ["La mansión Ebner... estoy dentro de la casa de la noticia."])
		"objeto_tomado":
			var en_mano: Item = _player.inventario[_player.slot_activo]
			if en_mano != null and en_mano.abre == "salida":
				_llave_real = true
				_susto_presencia()
			elif en_mano != null and en_mano.item_name == "Llave dorada":
				_decir_una_vez("dorada", ["Brilla demasiado para estar abandonada aquí."])
			elif en_mano != null and en_mano.es_llave:
				_decir_una_vez("llave", ["Una llave. Ojalá sea de esa puerta."])
		"puerta_abierta":
			if not _salio:
				_salio = true
				_decir_una_vez("salida", ["Salí del cuarto. Esta casa es enorme..."])
		"pila_trampa":
			_decir_una_vez("pila_trampa", ["¡Ah! Estaba podrida...", "No todo lo que brilla en esta casa ayuda."])
		"muneca":
			_decir_una_vez("muneca", ["...La música se cortó.", "¿Esa muñeca me está mirando?"])
		"ropero_golpes":
			_decir_una_vez("ropero_golpes", ["Golpes... desde adentro del ropero."])
		"ropero_abierto":
			await get_tree().create_timer(2.6).timeout
			_decir_una_vez("ropero_abierto", ["Estaba... detrás de mí.", "No mires atrás. No mires atrás."])
		"pila_tomada":
			_decir_una_vez("pila", ["Pilas. Las voy a necesitar."])
		"candado_error":
			_decir_una_vez("candado_error", ["No es esa combinación. El código tiene que estar escrito en algún lado."])
		"cofre_abierto":
			_cofre = true
			_decir_una_vez("cofre", ["Un diario... y otro filtro."])
		"retratos_error":
			_sonido(SUSURRO, -10.0)
			_decir_una_vez("retratos_error", ["Se torcieron otra vez... todos a la vez.", "Ese no era el orden."])
		"retratos_resueltos":
			_decir_una_vez("retratos_ok", ["Algo se abrió junto a los cuadros."])
		"llave_falsa":
			_susto_llave()
		"puerta_sin_energia":
			_puerta_probada = true
			_decir_una_vez("sin_energia", ["La llave entra, pero no gira. Algo la traba por dentro.", "Escucho un zumbido... ¿electricidad?"])
		"circuito_error":
			_player.sacudir(0.03, 0.5)
			_hud.destello(0.6, 0.8)
			_decir_una_vez("circuito_error", ["¡Ah! Esa no era.", "Tengo que seguir el cable correcto."])
		"circuito_ok":
			_energia = true
			_decir_una_vez("circuito_ok", ["Algo zumba en la puerta principal. Ahora sí debería girar."])
		"muro_revelado":
			var pos: Vector3 = _player.global_position
			if pos.distance_to(MURO_ESTE) < 6.0:
				_muro_este = true
				_decir_una_vez("muro_este", ["La pared... desapareció.", "Hay un cuarto sellado detrás."])
				_portazo_lejano()
			else:
				_decir_una_vez("muro_secreto", ["Un cuarto escondido...", "Sus fotos. Los seis desaparecidos."])
	_actualizar_objetivo()


# ---------- sustos ----------

func _sustos(pos: Vector3) -> void:
	# pasos pesados cruzando el segundo piso, justo al salir del primer cuarto
	if _salio and pos.x > -7.5 and pos.y < 2.0:
		if _una_vez("pasos_arriba"):
			_sonido_movil(PASOS_ARRIBA, Vector3(-6.0, 3.6, -11.0), Vector3(6.0, 3.6, -11.0), 3.8, 4.0)
			_hud.decir.call_deferred(["...¿Hay alguien arriba?"])
	# tres golpes desde afuera de la puerta principal
	if _salio and pos.distance_to(PUERTA_PRINCIPAL) < 3.5 and _una_vez("golpes_puerta"):
		_sonido_en(GOLPES_PUERTA, PUERTA_PRINCIPAL + Vector3(0, 0.6, 1.4), 6.0)
		_player.sacudir(0.015, 0.4)
		await get_tree().create_timer(2.4).timeout
		_hud.decir(["¿Quién anda afuera? ¡Ayuda!", "...Nadie contesta."])
	# el candelabro grande del hall se viene abajo (de vuelta con la luz azul)
	if _linterna.azul_unlocked and pos.y < 2.0:
		var dh := Vector2(pos.x - HALL_CENTRO.x, pos.z - HALL_CENTRO.z).length()
		if dh < 4.5 and dh > 1.8 and _una_vez("candelabro"):
			_cae_candelabro()
	# una silla del comedor se arrastra sola
	if pos.distance_to(COMEDOR) < 3.4 and _una_vez("silla"):
		var silla := get_node_or_null(^"../Decorado/SillaComedor0") as Node3D
		if silla != null:
			_sonido_en(ARRASTRE, silla.global_position, 4.0)
			var t := create_tween().set_parallel(true)
			t.tween_property(silla, "position", silla.position + Vector3(0.1, 0, -0.55), 1.1).set_trans(Tween.TRANS_SINE)
			t.tween_property(silla, "rotation_degrees:y", silla.rotation_degrees.y + 28.0, 1.1)
			_hud.decir(["Esa silla... se movió sola."])
	# una tabla floja del rellano cede bajo los pies
	if pos.distance_to(TABLA_FLOJA) < 1.6 and _una_vez("tabla"):
		_sonido_en(TABLA, pos + Vector3(0, -1.0, 0), 6.0)
		_player.sacudir(0.06, 0.5)
		_hud.destello(0.5, 0.6)
		var muneca := get_node_or_null(^"../Decorado/MunecaRellano") as Node3D
		if muneca != null:
			create_tween().tween_property(muneca, "rotation_degrees:x", 80.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_hud.decir(["¡El piso cruje!", "Cuidado... esta casa se está cayendo a pedazos."])
	# latido en el cuarto sellado
	var en_sellado := _muro_este and pos.x > 9.6 and pos.y > 2.0 and not _llave_real
	if en_sellado and _latido == null:
		_latido = AudioStreamPlayer.new()
		var lat := LATIDO.duplicate() as AudioStreamWAV
		lat.loop_mode = AudioStreamWAV.LOOP_FORWARD
		lat.loop_end = int(lat.get_length() * lat.mix_rate)
		_latido.stream = lat
		_latido.volume_db = -14.0
		add_child(_latido)
		_latido.play()
	elif _latido != null:
		if en_sellado:
			_latido.volume_db = lerpf(-4.0, -16.0, clampf(pos.distance_to(ALTAR) / 12.0, 0.0, 1.0))
			_latido.pitch_scale = lerpf(1.35, 1.0, clampf(pos.distance_to(ALTAR) / 12.0, 0.0, 1.0))
		else:
			_latido.queue_free()
			_latido = null


func _una_vez(clave: String) -> bool:
	if _dicho.has("_s_" + clave):
		return false
	_dicho["_s_" + clave] = true
	return true


func _cae_candelabro() -> void:
	var c := get_node_or_null(^"../AMBIENTACION GENERAL/CandelabroC") as Node3D
	if c == null:
		return
	_player.sacudir(0.01, 0.6)
	# primero cruje la cadena
	_sonido_en(TABLA, c.global_position, 0.0)
	await get_tree().create_timer(0.7).timeout
	# el aro (1.12 m bajo el origen, escalado) queda apoyado en el piso
	var piso := -0.4 + 1.12 * c.global_transform.basis.get_scale().y
	var t := create_tween()
	t.tween_property(c, "global_position:y", piso, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(c, "rotation_degrees:z", 18.0, 0.55)
	await t.finished
	_sonido_en(CANDELABRO_CAE, c.global_position, 8.0)
	_player.sacudir(0.08, 0.9)
	_hud.destello(0.7, 1.0)
	get_tree().call_group("lamparas", "apagon", 1.5)
	if c.get("averiada") != null:
		c.set("averiada", true)
	await get_tree().create_timer(1.2).timeout
	_hud.decir(["¡Casi me aplasta!", "...¿Lo soltaron o se cayó solo?"])


func _sonido_en(stream: AudioStream, pos: Vector3, db: float) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.unit_size = 4.0
	p.max_distance = 40.0
	get_parent().add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


## Un sonido que se desplaza (pasos que cruzan el piso de arriba).
func _sonido_movil(stream: AudioStream, desde: Vector3, hasta: Vector3, segundos: float, db: float) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.unit_size = 5.0
	p.max_distance = 40.0
	get_parent().add_child(p)
	p.global_position = desde
	p.play()
	create_tween().tween_property(p, "global_position", hasta, segundos)
	p.finished.connect(p.queue_free)


## Al tomar la llave antigua: las velas se apagan y "Ella" aparece al fondo.
func _susto_presencia() -> void:
	_decir_una_vez("llave_real", ["La llave antigua. Pesada... es la de la salida."])
	await get_tree().create_timer(1.2).timeout
	get_tree().call_group("lamparas", "apagon", 3.5)
	_linterna.apagon(1.4)
	_sonido(GOLPE, 0.0)
	_sonido(STINGER, -2.0)
	_player.sacudir(0.04, 0.6)
	if _presencia != null and _presencia.has_method("aparecer"):
		_presencia.aparecer(4.0)
	await get_tree().create_timer(1.6).timeout
	_decir_una_vez("ella", ["¿Quién está ahí?", "...Tengo que salir. Ahora."])


func _portazo_lejano() -> void:
	await get_tree().create_timer(3.0).timeout
	_sonido_en(PORTAZO, Vector3(0.8, 0.8, 2.5), 8.0)
	_player.sacudir(0.03, 0.5)
	await get_tree().create_timer(1.0).timeout
	_hud.decir(["Un portazo, abajo...", "Ya no estoy solo en la casa. Nunca lo estuve."])


## La llave dorada se parte: apagon, golpe y un susurro.
func _susto_llave() -> void:
	get_tree().call_group("lamparas", "apagon", 3.2)
	_linterna.apagon(2.4)
	_sonido(GOLPE, 2.0)
	_hud.destello(0.9, 2.2)
	_player.sacudir(0.06, 0.8)
	await get_tree().create_timer(1.4).timeout
	_sonido(SUSURRO, -4.0)
	_decir_una_vez("llave_falsa", ["¡Se partió dentro!", "Era una trampa... y no estoy solo aquí."])


func _sonido(stream: AudioStream, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Dice las lineas solo la primera vez. Devuelve true si las dijo ahora.
func _decir_una_vez(clave: String, lineas: Array) -> bool:
	if _dicho.has(clave):
		return false
	_dicho[clave] = true
	_hud.decir(lineas)
	return true


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
		escribir.tween_property(texto, "visible_ratio", 1.0, 0.04 * linea.length())
		await _esperar(0.04 * linea.length() + 1.8)
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
