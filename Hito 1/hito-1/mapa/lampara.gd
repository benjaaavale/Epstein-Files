extends Node3D

## Parpadeo de lamparas y velas. "averiada" agrega apagones bruscos.

@export var energia := 1.4
@export_range(0.0, 1.0) var parpadeo := 0.12
@export var averiada := false
## Pista: cada cierto tiempo la luz se tine de este color (alfa 0 = sin pista).
@export var color_pista := Color(0, 0, 0, 0)
@export var pista_cada := 7.0
@export var pista_dura := 1.8
@export var luz_path: NodePath = ^"Luz"
@export var foco_path: NodePath = ^"Foco"

var _luz: Light3D
var _foco_mat: StandardMaterial3D
var _emision_base := 1.0
var _ruido := FastNoiseLite.new()
var _t := 0.0
var _apagon := 0.0
var _color_base := Color.WHITE
var _emision_color := Color.WHITE
var _pista_t := 0.0


func _ready() -> void:
	_luz = get_node(luz_path) as Light3D
	var foco := get_node_or_null(foco_path) as MeshInstance3D
	if foco != null and foco.material_override != null:
		var original := foco.material_override
		_foco_mat = original.duplicate() as StandardMaterial3D
		# todas las llamas que comparten material parpadean y se tinen juntas
		for g in find_children("*", "GeometryInstance3D", true, false):
			if (g as GeometryInstance3D).material_override == original:
				(g as GeometryInstance3D).material_override = _foco_mat
		_emision_base = _foco_mat.emission_energy_multiplier
	_color_base = _luz.light_color
	if _foco_mat != null:
		_emision_color = _foco_mat.emission
	_pista_t = randf() * pista_cada
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
	if color_pista.a > 0.0:
		_pista_t += delta
		var ciclo := fmod(_pista_t, pista_cada)
		var w := 0.0
		if ciclo < pista_dura:
			w = sin(PI * ciclo / pista_dura)
			f *= 1.0 + 0.6 * w
			if randf() < 0.15:
				w *= 0.4
		_luz.light_color = _color_base.lerp(color_pista, w)
		if _foco_mat != null:
			_foco_mat.emission = _emision_color.lerp(color_pista, w)
	_luz.light_energy = energia * f
	if _foco_mat != null:
		_foco_mat.emission_energy_multiplier = _emision_base * maxf(f, 0.05)
