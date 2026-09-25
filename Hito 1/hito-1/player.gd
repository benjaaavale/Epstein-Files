extends CharacterBody3D

@export var mouse_sensitivity: float = 0.003 # Ajusta este valor si se mueve muy rápido o lento

@onready var head: Node3D = $Head

func _ready() -> void:
	# Atrapa y oculta el mouse dentro de la ventana al iniciar el juego
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	# Solo rotamos si el mouse está capturado y detectamos movimiento
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		
		# 1. Rotar el cuerpo entero en el eje Y (Mirar a izquierda/derecha)
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# 2. Rotar SOLO la cabeza en el eje X (Mirar arriba/abajo)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		
		# 3. Limitar (Clamp) la rotación vertical para no romperte el cuello hacia atrás
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))
