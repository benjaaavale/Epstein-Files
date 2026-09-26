extends CanvasLayer

@onready var resume: Button = %Resume
@onready var quit: Button = %Quit

func _ready() -> void:
	hide()
	resume.pressed.connect(_on_resume)
	quit.pressed.connect(func() -> void: get_tree().quit())

func _input(event: InputEvent) -> void:
	
	if event.is_action_pressed("PauseMenu"):
		get_tree().paused = not get_tree().paused
		visible = get_tree().paused
		
		# Liberar y capturar el mouse al pausar/despausar en primera persona
		if get_tree().paused:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume() -> void:
	get_tree().paused = false
	hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) # Vuelve a ocultar el mouse al resumir
	
	
