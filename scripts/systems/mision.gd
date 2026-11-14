class_name Mision
extends Resource
## Una misión del libro (resources/misiones/<id>.tres). Se activa con
## `EstadoJuego.empezar_mision(&"id")` y se tacha con `completar_mision(&"id")`.

@export var id: StringName = &""
## Un renglón de la página Misiones (≤ 25 letras).
@export var titulo := ""
## Principales arriba (3 renglones), secundarias abajo (3 renglones).
@export var principal := true
