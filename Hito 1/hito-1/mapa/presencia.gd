extends Node3D
class_name Presencia

## "Ella": una silueta que aparece un instante al fondo de una sala y se esfuma
## si la luz la toca (o al terminar el tiempo). Se arma sola con mallas negras.

const SUSURRO := preload("res://sonidos/susurro.wav")

var _visible_t := 0.0
var _iluminada := 0.0
var _mat: StandardMaterial3D


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.0, 0.0, 0.0)
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_parte(_capsula(0.24, 1.55), Vector3(0, 0.95, 0), Vector3(0, 0, 0))
	_parte(_esfera(0.13), Vector3(0, 1.82, 0.02), Vector3.ZERO)
	var pelo := BoxMesh.new()
	pelo.size = Vector3(0.3, 0.75, 0.12)
	_parte(pelo, Vector3(0, 1.5, -0.06), Vector3(0.1, 0, 0))
	for lado: float in [-1.0, 1.0]:
		_parte(_capsula(0.045, 0.8), Vector3(0.26 * lado, 1.15, 0.02), Vector3(0, 0, 0.08 * lado))
	visible = false


func _capsula(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


func _esfera(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


func _parte(m: Mesh, pos: Vector3, rot: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Aparece unos segundos (o hasta que la luz la toque).
func aparecer(segundos: float = 4.0) -> void:
	visible = true
	_mat.albedo_color.a = 1.0
	_visible_t = segundos
	_iluminada = 0.0
	var p := AudioStreamPlayer3D.new()
	p.stream = SUSURRO
	p.volume_db = 2.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _process(delta: float) -> void:
	if not visible:
		return
	_visible_t -= delta
	var lin := get_tree().current_scene.find_child("Linterna", true, false) as Linterna
	if lin != null and lin.spot_light_3d.visible:
		var spot := lin.spot_light_3d
		var v := global_position + Vector3.UP * 1.3 - spot.global_position
		if v.length() < 14.0 and v.normalized().dot(-spot.global_transform.basis.z) > cos(deg_to_rad(spot.spot_angle)):
			_iluminada += delta
	if _visible_t <= 0.0 or _iluminada > 0.25:
		_esfumar()


func _esfumar() -> void:
	set_process(false)
	var t := create_tween()
	t.tween_property(_mat, "albedo_color:a", 0.0, 0.12)
	t.tween_callback(func() -> void:
		visible = false
		set_process(true))
