@tool
class_name BarraEstamina
extends Control
## Barra pixelada de estamina (sin arte todavía: se dibuja con rectángulos).
## Colores sacados de la paleta del juego (borde de la caja de diálogo, hierba clara).

## 0..1
@export_range(0.0, 1.0) var valor := 1.0:
	set(v):
		valor = clampf(v, 0.0, 1.0)
		queue_redraw()
@export var color_borde := Color("1b2246")
@export var color_fondo := Color("100c13")
@export var color_relleno := Color("a4dc5c")
## Color cuando no alcanza para una pirueta (por debajo de `umbral_bajo`).
@export var color_bajo := Color("c0503a")
@export_range(0.0, 1.0) var umbral_bajo := 0.35


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size).abs()
	draw_rect(r, color_borde)
	var interior := r.grow(-1)
	draw_rect(interior, color_fondo)
	var lleno := interior
	lleno.size.x = floorf(interior.size.x * valor)
	if lleno.size.x > 0:
		draw_rect(lleno, color_relleno if valor >= umbral_bajo else color_bajo)
