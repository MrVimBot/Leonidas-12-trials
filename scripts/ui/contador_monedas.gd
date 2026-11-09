@tool
class_name ContadorMonedas
extends Control
## Placa de dinero del HUD (lámina "Interfaz" de Jugabilidad.pdf): la placa con la
## dracma y tres dígitos pixelados dibujados encima.
##
## El "0" es el de la maqueta de la artista (4×6 px, cada 7 px, color #391310); el resto
## de dígitos están diseñados con el mismo tamaño y estilo. PROVISIONAL hasta tener el
## PNG de la artista.

@export var placa: Texture2D = preload("res://assets/ui/provisional/placa_dinero.png"):
	set(v):
		placa = v
		queue_redraw()
@export_range(0, 999) var valor := 0:
	set(v):
		valor = clampi(v, 0, 999)
		queue_redraw()
@export var color_digito := Color("391310")
## Posición del primer dígito y separación (en píxeles de la placa).
@export var origen_digitos := Vector2i(17, 3)
@export var paso := 7

const DIGITOS := [
	[".##.", "#..#", "#..#", "#..#", "#..#", ".##."], # 0 (el de la maqueta)
	[".#..", "##..", ".#..", ".#..", ".#..", "###."], # 1
	[".##.", "#..#", "...#", "..#.", ".#..", "####"], # 2
	["###.", "...#", ".##.", "...#", "...#", "###."], # 3
	["#..#", "#..#", "####", "...#", "...#", "...#"], # 4
	["####", "#...", "###.", "...#", "...#", "###."], # 5
	[".##.", "#...", "###.", "#..#", "#..#", ".##."], # 6
	["####", "...#", "..#.", "..#.", ".#..", ".#.."], # 7
	[".##.", "#..#", ".##.", "#..#", "#..#", ".##."], # 8
	[".##.", "#..#", "#..#", ".###", "...#", ".##."], # 9
]


func _draw() -> void:
	if placa:
		draw_texture(placa, Vector2.ZERO)
	var texto := "%03d" % valor
	for i in texto.length():
		var patron: Array = DIGITOS[int(texto[i])]
		var x0 := origen_digitos.x + i * paso
		for fila in patron.size():
			var linea: String = patron[fila]
			for col in linea.length():
				if linea[col] == "#":
					draw_rect(Rect2(x0 + col, origen_digitos.y + fila, 1, 1), color_digito)


func _get_minimum_size() -> Vector2:
	return placa.get_size() if placa else Vector2(39, 12)
