extends Interactuable
class_name FiltroLinterna

## Filtro de color para la linterna: un lente redondo de vidrio tenido (como una lupa sin mango).
## Al tomarlo con E se monta en la linterna y desbloquea ese color.

enum ColorFiltro { ROJO, AZUL, VIOLETA }
@export var color_a_desbloquear: ColorFiltro = ColorFiltro.ROJO

const COLORES := {
	ColorFiltro.ROJO: Color(1.0, 0.08, 0.05),
	ColorFiltro.AZUL: Color(0.1, 0.35, 1.0),
	ColorFiltro.VIOLETA: Color(0.62, 0.12, 1.0),
}
const NOMBRES := {
	ColorFiltro.ROJO: "rojo",
	ColorFiltro.AZUL: "azul",
	ColorFiltro.VIOLETA: "violeta",
}
const SONIDO := preload("res://sonidos/recoger.wav")

@onready var lente: Node3D = $Lente
@onready var vidrio: MeshInstance3D = $Lente/Vidrio
@onready var brillo: OmniLight3D = $Brillo

var _tomado := false
var _t := 0.0


func _ready() -> void:
	# estrias del aro (como el cabezal de la linterna)
	var estria := (lente.get_node("Aro") as MeshInstance3D)
	for i in 24:
		var e := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.004, 0.018, 0.006)
		e.mesh = b
		e.material_override = estria.material_override
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * i / 24.0
		e.position = Vector3(cos(a), 0.0, sin(a)) * 0.0885
		e.rotation.y = -a
		lente.add_child(e)
	var c: Color = COLORES[color_a_desbloquear]
	var mat := (vidrio.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.albedo_color = Color(c, 0.32)
	mat.emission = c
	vidrio.material_override = mat
	brillo.light_color = c
	_t = randf() * TAU


func _process(delta: float) -> void:
	# un pulso suave para que se note en la oscuridad
	_t += delta
	if not _tomado:
		brillo.light_energy = 0.25 + 0.15 * sin(_t * 2.2)


func disponible() -> bool:
	return not _tomado


func accion() -> String:
	return "Tomar filtro " + NOMBRES[color_a_desbloquear]


func interactuar(player: Node) -> void:
	_tomado = true
	collision_layer = 0
	_sonar(SONIDO, -4.0, 1.2)
	match color_a_desbloquear:
		ColorFiltro.ROJO:
			player.linterna.desbloquear_rojo()
			player.hud.toast("Filtro rojo", "CLIC DERECHO PARA CAMBIAR LA LUZ")
		ColorFiltro.AZUL:
			player.linterna.desbloquear_azul()
			player.hud.toast("Filtro azul", "CLIC PARA ELEGIR LA LUZ AZUL")
		ColorFiltro.VIOLETA:
			player.linterna.desbloquear_violeta()
			player.hud.toast("Filtro violeta", "SHIFT + CLIC: LUZ MORADA")
	player.evento.emit("filtro_" + NOMBRES[color_a_desbloquear])
	# el lente vuela hacia la linterna y se encoge
	var destino: Vector3 = player.linterna.global_position
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "global_position", destino, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(lente, "scale", Vector3.ONE * 0.2, 0.35)
	t.tween_property(brillo, "light_energy", 0.0, 0.3)
	t.chain().tween_callback(queue_free)
