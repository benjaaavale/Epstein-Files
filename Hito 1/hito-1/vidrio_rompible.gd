extends CSGBox3D
class_name VidrioRompible

@export var golpes_necesarios: int = 4

@export_group("Audio")
@export var sonido_golpe: AudioStream
@export var sonido_rotura: AudioStream
@export_range(-20.0, 10.0) var volumen_db: float = 0.0

var _golpes_actuales: int = 0
var _roto: bool = false

func golpear() -> void:
	if _roto:
		return
		
	_golpes_actuales += 1
	var mat := material as ShaderMaterial
	
	if _golpes_actuales >= golpes_necesarios:
		_romper_por_completo()
	else:
		_reproducir_sonido(sonido_golpe, randf_range(0.92, 1.08))
		if mat != null:
			var progreso := float(_golpes_actuales) / float(golpes_necesarios)
			mat.set_shader_parameter("cristalizacion", progreso)

func _romper_por_completo() -> void:
	_roto = true
	# Ocultamos el vidrio y quitamos su colisión de inmediato para que puedas pasar
	visible = false
	use_collision = false
	
	_reproducir_sonido(sonido_rotura, 1.0)
	_generar_esquirlas()
	
	# Esperamos 2.5 segundos a que caigan los cristales y termine el audio antes de borrar el nodo
	await get_tree().create_timer(2.5).timeout
	queue_free()

func _reproducir_sonido(stream: AudioStream, tono: float = 1.0) -> void:
	if stream == null:
		return
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	audio.volume_db = volumen_db
	audio.pitch_scale = tono
	get_tree().current_scene.add_child(audio)
	audio.global_position = global_position
	audio.finished.connect(audio.queue_free)
	audio.play()

func _generar_esquirlas() -> void:
	var particulas := GPUParticles3D.new()
	particulas.emitting = false
	particulas.one_shot = true
	particulas.explosiveness = 0.95
	particulas.amount = 45
	particulas.lifetime = 1.8
	
	# Material visual de los pedazos de cristal
	var mat_cristal := StandardMaterial3D.new()
	mat_cristal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_cristal.albedo_color = Color(0.82, 0.95, 1.0, 0.55)
	mat_cristal.roughness = 0.08
	mat_cristal.metallic = 0.15
	mat_cristal.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# Forma triangular de esquirla
	var malla := PrismMesh.new()
	malla.size = Vector3(0.14, 0.16, 0.015)
	malla.material = mat_cristal
	particulas.draw_pass_1 = malla
	
	# Física de caída y dispersión usando el tamaño real de tu CSGBox3D
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = size * 0.5
	proc.direction = Vector3(0, 0.3, 0)
	proc.spread = 180.0
	proc.initial_velocity_min = 0.8
	proc.initial_velocity_max = 2.6
	proc.gravity = Vector3(0, -9.8, 0)
	proc.angular_velocity_min = -360.0
	proc.angular_velocity_max = 360.0
	proc.scale_min = 0.4
	proc.scale_max = 1.2
	
	particulas.process_material = proc
	get_tree().current_scene.add_child(particulas)
	particulas.global_transform = global_transform
	particulas.emitting = true
	
	# Limpieza automática de las partículas
	get_tree().create_timer(2.2).timeout.connect(particulas.queue_free)
