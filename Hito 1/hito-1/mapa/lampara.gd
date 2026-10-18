extends Node3D

## Parpadeo de lamparas y velas. "averiada" agrega apagones bruscos.

@export var energia := 1.4
@export_range(0.0, 1.0) var parpadeo := 0.12
@export var averiada := false
@export var luz_path: NodePath = ^"Luz"
@export var foco_path: NodePath = ^"Foco"

var _luz: Light3D
var _foco_mat: StandardMaterial3D
var _emision_base := 1.0
var _ruido := FastNoiseLite.new()
var _t := 0.0
var _apagon := 0.0


func _ready() -> void:
	_luz = get_node(luz_path) as Light3D
	var foco := get_node_or_null(foco_path) as MeshInstance3D
	if foco != null and foco.material_override != null:
		_foco_mat = foco.material_override.duplicate() as StandardMaterial3D
		foco.material_override = _foco_mat
		_emision_base = _foco_mat.emission_energy_multiplier
	_ruido.seed = randi()
	_ruido.frequency = 1.0
	_t = randf() * 100.0


func _process(delta: float) -> void:
	_t += delta
	var f := 1.0 + _ruido.get_noise_1d(_t * 6.0) * parpadeo * 2.0
	if averiada:
		_apagon -= delta
		if _apagon <= 0.0 and randf() < delta * 0.5:
			_apagon = randf_range(0.08, 0.9)
		if _apagon > 0.0:
			f *= 0.03 if randf() < 0.8 else 0.5
	f = maxf(f, 0.0)
	_luz.light_energy = energia * f
	if _foco_mat != null:
		_foco_mat.emission_energy_multiplier = _emision_base * maxf(f, 0.05)
