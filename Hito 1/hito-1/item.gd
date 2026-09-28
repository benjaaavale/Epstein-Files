extends RigidBody3D
class_name Item

@export var item_name: String = "Item"

func pick_up() -> void:
	freeze = true
	collision_layer = 0
	collision_mask = 0

func drop() -> void:
	freeze = false
	collision_layer = 1
	collision_mask = 1
