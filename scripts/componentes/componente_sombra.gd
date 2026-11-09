@tool
class_name ComponenteSombra
extends Node2D
## Sombra ovalada pixelada en el suelo, al estilo de la artista
## (assets/sprites/entorno/sombra.png: óvalo opaco #106165 de 29×9).
##
## Se dibuja fila a fila con rectángulos de 1 px, así queda nítida a cualquier tamaño
## (escalar el PNG la deformaría). El centro del óvalo es la posición del nodo.
## Debe ir ANTES que el sprite en el árbol para dibujarse debajo.
## Sirve para decorados, el jugador, enemigos, NPC...

@export var tamano := Vector2i(29, 9):
	set(valor):
		tamano = valor
		queue_redraw()
@export var color := Color("106165"):
	set(valor):
		color = valor
		queue_redraw()

## Proporción alto/ancho de la sombra de la artista (9/29).
const PROPORCION := 9.0 / 29.0


## Tamaño con la proporción de la artista para un ancho dado.
static func tamano_para_ancho(ancho: float) -> Vector2i:
	var w := maxi(roundi(ancho), 4)
	return Vector2i(w, maxi(roundi(w * PROPORCION), 3))


func _draw() -> void:
	var w := tamano.x
	var h := tamano.y
	if w <= 0 or h <= 0:
		return
	var medio_h := h / 2.0
	for fila in h:
		var dy := (fila + 0.5 - medio_h) / medio_h
		var mitad := (w / 2.0) * sqrt(maxf(0.0, 1.0 - dy * dy))
		var x0 := roundi(-mitad)
		var x1 := roundi(mitad)
		if x1 > x0:
			draw_rect(Rect2(x0, floorf(-medio_h) + fila, x1 - x0, 1), color)
