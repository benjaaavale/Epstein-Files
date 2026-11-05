extends CSGBox3D
class_name MuroSecreto

const FADE_DEGREES := 6.0
const PAINT_INTERVAL := 0.05
const MASK_W := 96
const MASK_H := 128
const MASK_MIN := Vector2(-1.0, -1.0) # Puedes ajustar esto según el tamaño de tu CSGBox
const MASK_SIZE := Vector2(2.0, 2.0)  # Puedes ajustar esto según el tamaño de tu CSGBox

@export var secreta := true

var linterna: Linterna = null
var _mask_bytes := PackedByteArray()
var _mask_texture: ImageTexture
var _texel_positions := PackedVector3Array()
var _paint_timer: float = 0.0

func _ready() -> void:
	if not secreta:
		set_instance_shader_parameter("force_visible", 1.0)
		for g in find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).set_instance_shader_parameter("force_visible", 1.0)
		return
		
	# Apagamos la visibilidad forzada (por si la usaste para ver en el editor)
	set_instance_shader_parameter("force_visible", 0.0)
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).set_instance_shader_parameter("force_visible", 0.0)
		
	_mask_bytes.resize(MASK_W * MASK_H)
	_mask_bytes.fill(255) # INVERSIÓN: Llenamos de 255 (blanco) para que inicie sólida
	_mask_texture = ImageTexture.create_from_image(Image.create_from_data(MASK_W, MASK_H, false, Image.FORMAT_R8, _mask_bytes))
	_texel_positions.resize(MASK_W * MASK_H)
	
	for y in MASK_H:
		for x in MASK_W:
			var local := Vector3(
				MASK_MIN.x + (x + 0.5) / MASK_W * MASK_SIZE.x,
				MASK_MIN.y + (1.0 - (y + 0.5) / MASK_H) * MASK_SIZE.y,
				0.045)
			_texel_positions[y * MASK_W + x] = to_global(local)
			
	var world_to_mask := Projection(global_transform.affine_inverse())
	
	for mat in _materiales():
		mat.set_shader_parameter("reveal_mask", _mask_texture)
		mat.set_shader_parameter("use_reveal_mask", true)
		mat.set_shader_parameter("world_to_mask", world_to_mask)
		mat.set_shader_parameter("mask_min", MASK_MIN)
		mat.set_shader_parameter("mask_size", MASK_SIZE)

func _materiales() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	if material != null and material is ShaderMaterial:
		out.append(material)
		
	for g in find_children("*", "GeometryInstance3D", true, false):
		var geom := g as GeometryInstance3D
		
		# Busca en el override general que acabamos de asignar
		if geom.material_override != null and geom.material_override is ShaderMaterial:
			if not out.has(geom.material_override):
				out.append(geom.material_override as ShaderMaterial)
				
		# Busca en los surfaces por si acaso
		var surf_mat = geom.get_surface_override_material(0)
		if surf_mat != null and surf_mat is ShaderMaterial:
			if not out.has(surf_mat):
				out.append(surf_mat as ShaderMaterial)
				
	return out

func _process(delta: float) -> void:
	if not secreta:
		return
	_paint_timer += delta
	if _paint_timer < PAINT_INTERVAL:
		return
	_paint_timer = 0.0
	
	# La pared busca la linterna en el mundo por su cuenta
	if linterna == null:
		linterna = get_tree().current_scene.find_child("Linterna", true, false) as Linterna
		if linterna == null:
			return
			
	# Si la luz violeta está encendida, se activa el borrado
	if linterna.current_channel == Linterna.Channel.VIOLET and linterna.spot_light_3d.visible:
		_paint(linterna.spot_light_3d)

func _paint(spot: SpotLight3D) -> void:
	var origin := spot.global_position
	var dir := -spot.global_transform.basis.z
	var angle := spot.spot_angle - 2.0
	var cos_end := cos(deg_to_rad(angle))
	var cos_start := cos(deg_to_rad(angle - FADE_DEGREES))
	var changed := false
	
	for i in _texel_positions.size():
		var v := _texel_positions[i] - origin
		var c := v.normalized().dot(dir)
		if c <= cos_end:
			continue
			
		var light_intensity := int(clampf((c - cos_end) / (cos_start - cos_end), 0.0, 1.0) * 255.0)
		var inverted_value := 255 - light_intensity
		
		if inverted_value < _mask_bytes[i]:
			_mask_bytes[i] = inverted_value
			changed = true
			
	if changed:
		_mask_texture.update(Image.create_from_data(MASK_W, MASK_H, false, Image.FORMAT_R8, _mask_bytes))
		
		# --- NUEVO: Lógica para desactivar la colisión física ---
		if use_collision:
			var pixeles_borrados = 0
			# Contamos cuántos píxeles están casi invisibles (valor menor a 128)
			for byte in _mask_bytes:
				if byte < 128: 
					pixeles_borrados += 1
			
			# Si más del 30% de la pared ha sido borrada, apagamos la colisión
			if pixeles_borrados > (_mask_bytes.size() * 0.3):
				use_collision = false
