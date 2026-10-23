extends Interactuable
class_name FiltroLinterna

# Menú para elegir qué color da este filtro en el Inspector
enum ColorFiltro { ROJO, AZUL, VIOLETA }
@export var color_a_desbloquear: ColorFiltro = ColorFiltro.ROJO

# 1. El texto que aparece en la pantalla cuando lo miras
func accion() -> String:
	match color_a_desbloquear:
		ColorFiltro.ROJO:
			return "Tomar filtro rojo"
		ColorFiltro.AZUL:
			return "Tomar filtro azul"
		ColorFiltro.VIOLETA:
			return "Tomar filtro violeta"
	return "Tomar filtro"

# 2. Lo que pasa cuando presionas la E
func interactuar(player: Node) -> void:
	# Como indica tu archivo base, la linterna ya vive dentro del "player"
	match color_a_desbloquear:
		ColorFiltro.ROJO:
			player.linterna.desbloquear_rojo()
			# Aprovechamos el sistema de tu juego para mostrar un aviso bonito en pantalla
			if player.get("hud"):
				player.hud.toast("¡Luz ROJA desbloqueada!")
				
		ColorFiltro.AZUL:
			player.linterna.desbloquear_azul()
			if player.get("hud"):
				player.hud.toast("¡Luz AZUL desbloqueada!")
				
		ColorFiltro.VIOLETA:
			player.linterna.desbloquear_violeta()
			if player.get("hud"):
				player.hud.toast("¡Combinación VIOLETA (Shift) desbloqueada!")
	
	# Destruimos el objeto del mapa
	queue_free()
