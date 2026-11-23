class_name PaginaMapa
extends PaginaLibro
## Página del mapa del libro. PROVISIONAL hasta que la artista pinte el mapa: un esquema
## del mundo (docs/design/plan_mapa_mundo.md) dibujado en `_draw`, una caja por zona de
## norte a sur unidas por una línea; la zona actual parpadea y su nombre corto sale en la
## cartela (%Cartela). Sin cursor propio.

## Zonas del mapa, de norte a sur: [`Zona.nombre_zona` de su escena, nombre en el mapa,
## cartela ≤ 6 letras]. La zona actual se reconoce por `nombre_zona`: si se renombra una
## zona en su escena, cambiarla también aquí.
const ZONAS := [
	["Casa del árbol", "Casa árbol", "Casa"],
	["Pueblo", "Pueblo", "Pueblo"],
	["Bosque", "Bosque", "Bosque"],
	["Orilla del mar", "Playa", "Playa"],
	["Mar", "Mar", "Mar"],
	["Orilla de la isla", "Orilla", "Orilla"],
	["Isla de Medusa", "Isla", "Isla"],
	["Cueva de Medusa", "Cueva", "Cueva"],
	["Guarida de Medusa", "Guarida", "Cueva"],
	["Mar del sur", "Mar del sur", "Mar"],
	["Orilla del laberinto", "Orilla sur", "Orilla"],
	["Laberinto del Minotauro", "Laberinto", "Laberinto"],
]
## Índices en ZONAS de los mares (se pintan de azul).
const MARES := [4, 10]
## Columna de cajas dentro de la zona oscura de la página (px del lienzo).
const CAJAS := Rect2(316, 80, 108, 180)
const COLOR_LINEA := Color("c79a6e")
const COLOR_CAJA := Color("3a3034")
const COLOR_MAR := Color("3e6395")
const COLOR_ACTUAL := Color("e8c88a")
const COLOR_NOMBRE := Color("e8d2b0")

## Tiempo del libro abierto (lo da el coordinador en `animar`), para el parpadeo.
var _tiempo := 0.0

@onready var _cartela: Label = %Cartela


func refrescar() -> void:
	var z := _zona_actual()
	_cartela.text = ZONAS[z][2] if z >= 0 else ""
	queue_redraw()


func animar(tiempo: float) -> void:
	_tiempo = tiempo
	if visible:
		queue_redraw()


## Índice en ZONAS de la zona donde está Leonidas (-1 = ninguna o fuera de Game).
func _zona_actual() -> int:
	var game := Game.actual(self)
	if game == null or game.zona_actual == null:
		return -1
	var nombre := game.zona_actual.nombre_zona
	for i in ZONAS.size():
		if ZONAS[i][0] == nombre:
			return i
	return -1


func _draw() -> void:
	var fuente := get_theme_default_font()
	var letra := get_theme_default_font_size()
	var tinta := get_theme_color(&"font_color", &"Label")
	var paso := CAJAS.size.y / ZONAS.size()
	var alto := paso - 4.0
	var actual := _zona_actual()
	var x := CAJAS.position.x
	for i in ZONAS.size():
		var r := Rect2(x, CAJAS.position.y + i * paso, CAJAS.size.x, alto)
		r.position = r.position.round()
		if i > 0:
			var cx := roundf(r.get_center().x)
			draw_line(Vector2(cx, r.position.y - 4), Vector2(cx, r.position.y), COLOR_LINEA)
		var encendida := i == actual and fmod(_tiempo, 0.8) < 0.5
		var relleno := COLOR_MAR if i in MARES else COLOR_CAJA
		if encendida:
			relleno = COLOR_ACTUAL
		draw_rect(r, relleno)
		draw_rect(r.grow(-0.5), COLOR_LINEA, false, 1.0)
		var texto_color := tinta if encendida else COLOR_NOMBRE
		var nombre: String = ZONAS[i][1]
		var ancho := fuente.get_string_size(nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, letra).x
		var base := r.position.y + (alto + fuente.get_ascent(letra) - fuente.get_descent(letra)) / 2.0
		var pos := Vector2(r.get_center().x - ancho / 2.0, base)
		draw_string(fuente, pos, nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, letra, texto_color)
