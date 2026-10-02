extends RigidBody3D
class_name Item

@export var item_name: String = "Item"
@export var only_visible_with_violet_light: bool = true

@onready var interact_zone: Area3D = $InteractZone

var held: bool = false
var linterna: Linterna = null

func _ready() -> void:
	_set_forced_visible(not only_visible_with_violet_light)

func _set_forced_visible(forced: bool) -> void:
	for child in find_children("*", "GeometryInstance3D", true, false):
		child.set_instance_shader_parameter("force_visible", 1.0 if forced else 0.0)

func is_revealed() -> bool:
	return not only_visible_with_violet_light or held or _lit_by_violet_light()

func _lit_by_violet_light() -> bool:
	if linterna == null:
		linterna = get_tree().current_scene.find_child("Linterna", true, false) as Linterna
		if linterna == null:
			return false
	if linterna.current_channel != Linterna.Channel.VIOLET:
		return false
	var spot := linterna.spot_light_3d
	var light_dir := -spot.global_transform.basis.z
	var to_item := (global_position - spot.global_position).normalized()
	return to_item.dot(light_dir) > cos(deg_to_rad(spot.spot_angle - 2.0))

func pick_up() -> void:
	held = true
	_set_forced_visible(true)
	freeze = true
	collision_layer = 0
	collision_mask = 0
	interact_zone.collision_layer = 0

func drop() -> void:
	held = false
	_set_forced_visible(not only_visible_with_violet_light)
	freeze = false
	collision_layer = 1
	collision_mask = 1
	interact_zone.collision_layer = 4
