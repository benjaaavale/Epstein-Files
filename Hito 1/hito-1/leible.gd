extends StaticBody3D
class_name Leible

## Objeto que se puede leer con E (periodicos, notas, cartas).

@export var accion := "Leer"
@export var encabezado := ""
@export var titulo := ""
@export_multiline var cuerpo := ""

var leido := false
