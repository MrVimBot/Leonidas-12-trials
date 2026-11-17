@tool
class_name ComponenteAjustePixel
extends Node
## Alinea a la rejilla de píxeles del mundo el dibujo (`objetivo`) de un Node2D que se mueve
## con decimales (p. ej. Leonidas a 60 px/s avanza 0,5 px por tick).
##
## Por qué: en el modo normal (viewport de 480×270) todo se rasteriza a 480×270 y el sprite cae
## solo en un píxel entero. En las zonas pintadas (`Zona.pintada`, CANVAS_ITEMS) cada nodo se
## dibuja a la resolución de la ventana y un sprite en x = 100,5 saldría medio píxel de mundo
## (2 px de pantalla) desplazado respecto a los tiles: temblaría al caminar. Aquí se desplaza el
## `objetivo` (un contenedor `Visual` con la sombra y el sprite) lo justo para que su posición
## global sea entera; el cuerpo, las colisiones y la cámara no se tocan.
## En el modo viewport no cambia nada visible (ya se redondeaba al rasterizar), así que no
## hace falta activarlo ni desactivarlo según la zona.
## `@tool` solo para avisar en el editor de lo que falta; en el editor no hace nada más (no
## mueve el `objetivo`: se guardaría en la escena).

## Nodo visual a alinear (hijo del padre de este componente, normalmente `Visual`).
@export var objetivo: Node2D:
	set(valor):
		objetivo = valor
		update_configuration_warnings()

var _padre: Node2D


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if objetivo == null:
		avisos.append("Asigna en `objetivo` el Node2D que se alinea (p. ej. `Visual`).")
	if not get_parent() is Node2D:
		avisos.append("El padre debe ser un Node2D (el que se mueve).")
	return avisos


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_padre = get_parent() as Node2D
	assert(_padre != null, "ComponenteAjustePixel: el padre debe ser un Node2D")
	assert(objetivo != null, "ComponenteAjustePixel: falta `objetivo`")


# El padre se procesa antes que sus hijos: aquí ya se ha movido en este tick.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_alinear()


# También por fotograma, por si el padre se mueve con un tween (p. ej. `caminar_hasta`).
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_alinear()


func _alinear() -> void:
	var pos := _padre.global_position
	objetivo.position = pos.round() - pos
