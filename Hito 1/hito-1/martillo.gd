extends Item

@export var empieza_oculto: bool = true
@export var rango_revelado: float = 8.0

var revelado: bool = false
var _golpeando: bool = false

func _ready() -> void:
	super._ready()
	if empieza_oculto:
		revelado = false
		only_visible_with_red_light = true
		interact_zone.collision_layer = 0
		_actualizar_shader_revelado(false)
	else:
		revelado = true
		only_visible_with_red_light = false
		interact_zone.collision_layer = 4
		_actualizar_shader_revelado(true)

func _process(_delta: float) -> void:
	if revelado:
		return
		
	if linterna == null:
		linterna = get_tree().current_scene.find_child("Linterna", true, false) as Linterna
		if linterna == null:
			return
			
	var canal_violeta: int = Linterna.Channel.get("VIOLET", Linterna.Channel.get("PURPLE", 3))
	if linterna.current_channel != canal_violeta:
		return
		
	var spot := linterna.spot_light_3d
	if spot == null or not spot.visible:
		return
		
	var light_dir := -spot.global_transform.basis.z
	var cos_limite := cos(deg_to_rad(spot.spot_angle + 2.0))
	
	var puntos: Array[Vector3] = [global_position]
	for hijo in find_children("*", "Node3D", true, false):
		puntos.append((hijo as Node3D).global_position)
		
	for punto in puntos:
		var vec := punto - spot.global_position
		if vec.length() <= rango_revelado and vec.normalized().dot(light_dir) > cos_limite:
			_completar_revelado()
			return

func _completar_revelado() -> void:
	revelado = true
	only_visible_with_red_light = false
	interact_zone.collision_layer = 4
	_actualizar_shader_revelado(true)

func is_revealed() -> bool:
	return revelado

func _actualizar_shader_revelado(estado: bool) -> void:
	for nodo in find_children("*", "GeometryInstance3D", true, false):
		var geom := nodo as GeometryInstance3D
		if geom is CSGShape3D and geom.material is ShaderMaterial:
			geom.material.set_shader_parameter("revelado", estado)
		if geom.material_override is ShaderMaterial:
			geom.material_override.set_shader_parameter("revelado", estado)

# --- ANIMACIÓN 1: AL COGER / EQUIPAR EL MARTILLO ---
func animar_equipar(pos_base: Vector3 = Vector3.ZERO) -> void:
	position = pos_base + Vector3(0.0, -0.25, 0.12)
	rotation_degrees = Vector3(35.0, 0.0, -15.0)
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position", pos_base, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees", Vector3(-12.0, 0.0, 0.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- ANIMACIÓN 2: AL GOLPEAR EL VIDRIO ---
func animar_golpe(objetivo: Node, pos_base: Vector3 = Vector3.ZERO) -> void:
	if _golpeando:
		return
	_golpeando = true
	
	var tween := create_tween()
	tween.tween_property(self, "rotation_degrees:x", 28.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position:z", pos_base.z + 0.08, 0.10)
	
	tween.tween_property(self, "rotation_degrees:x", -78.0, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "position:z", pos_base.z - 0.18, 0.09)
	
	tween.tween_callback(func():
		if is_instance_valid(objetivo) and objetivo.has_method("golpear"):
			objetivo.golpear()
	)
	
	tween.tween_property(self, "rotation_degrees:x", -12.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position", pos_base, 0.18)
	tween.tween_callback(func(): _golpeando = false)
