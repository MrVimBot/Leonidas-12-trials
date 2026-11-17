class_name PaginaInventario
extends PaginaLibro
## Página con rejilla de objetos del libro: sirve para Objetos Importantes y para
## Inventario (según `tipo`). Doce casillas (`CasillaLibro`, 4 columnas × 3 filas) y, abajo,
## la casilla suelta con el objeto elegido y su texto (nombre, cantidad y descripción, o un
## aviso en rojo). El coordinador las coloca con las medidas de libro.json (`colocar`).
## Ratón: la señal `pressed` de cada casilla está conectada en la escena a
## `_on_casilla_pressed` con su índice; el 2.º clic en la ya elegida usa el objeto.

## E/J (o 2.º clic) sobre un objeto: el coordinador decide si se puede usar.
signal usar_objeto(id: StringName)

const COLUMNAS := 4
const FILAS := 3
## Texto del objeto elegido: a la derecha de la casilla suelta.
const TEXTO_SEPARACION := 6.0
const TEXTO_SUBIDA := -2.0
const COLOR_AVISO := Color("8a1c12")

## Qué objetos enseña la página.
@export var tipo := Objeto.Tipo.CONSUMIBLE
## Contenedor de las 12 casillas, en orden (fila a fila).
@export var casillas: Control
@export var suelta: CasillaLibro
@export var texto: Label

## Casilla elegida (índice = fila * COLUMNAS + columna).
var _casilla := 0
var _aviso := ""


## Pone casillas y suelta en los rectángulos de libro.json (px del lienzo): las 12 de la
## rejilla y, la última, la suelta. El texto va a la derecha de la suelta.
func colocar(rects: Array[Rect2]) -> void:
	var hijos := casillas.get_children()
	assert(hijos.size() == COLUMNAS * FILAS and rects.size() == hijos.size() + 1,
		"libro.json o la escena: faltan casillas en " + name)
	for i in hijos.size():
		_colocar_en(hijos[i] as Control, rects[i])
	var r: Rect2 = rects.back()
	_colocar_en(suelta, r)
	texto.position = Vector2(r.end.x + TEXTO_SEPARACION, r.position.y + TEXTO_SUBIDA)


static func _colocar_en(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size


func refrescar() -> void:
	# El aviso es del cursor: si se va de la página (a otra o a las pestañas), se borra.
	if not con_cursor:
		_aviso = ""
	var lista := EstadoJuego.objetos_de_tipo(tipo)
	var hijos := casillas.get_children()
	for i in hijos.size():
		var id: StringName = lista[i] if i < lista.size() else &""
		var o := EstadoJuego.objeto(id) if id != &"" else null
		(hijos[i] as CasillaLibro).mostrar(o, EstadoJuego.cantidad(id) if o else 0)
	# Casilla suelta: el elegido (icono + nombre, cantidad y descripción).
	var elegido := _objeto_en(_casilla)
	var obj := EstadoJuego.objeto(elegido) if elegido != &"" else null
	suelta.mostrar(obj, EstadoJuego.cantidad(elegido) if obj else 0)
	texto.remove_theme_color_override(&"font_color")
	if not _aviso.is_empty():
		texto.text = _aviso
		texto.add_theme_color_override(&"font_color", COLOR_AVISO)
	elif obj:
		var titulo := obj.nombre
		if obj.maximo > 1:
			titulo += " x%d" % EstadoJuego.cantidad(elegido)
		texto.text = titulo + "\n" + obj.descripcion
	else:
		texto.text = ""


func mover(d: Vector2i) -> bool:
	var col := _casilla % COLUMNAS + d.x
	var f := fila() + d.y
	if f >= FILAS:
		return true # abajo del todo: no pasa nada
	if f < 0 or col < 0 or col >= COLUMNAS:
		return false
	_casilla = f * COLUMNAS + col
	_aviso = ""
	return true


func confirmar() -> void:
	var id := _objeto_en(_casilla)
	if id != &"":
		usar_objeto.emit(id)


func entrar(desde_fila: int, desde_izquierda: bool) -> void:
	_casilla = desde_fila * COLUMNAS + (0 if desde_izquierda else COLUMNAS - 1)


func fila() -> int:
	@warning_ignore("integer_division") # índice de casilla → fila
	return _casilla / COLUMNAS


func avisar(t: String) -> void:
	_aviso = t


func casilla_marcada() -> Control:
	return casillas.get_child(_casilla) as Control


func _objeto_en(i: int) -> StringName:
	var lista := EstadoJuego.objetos_de_tipo(tipo)
	return lista[i] if i < lista.size() else &""


## Clic en la casilla `i` (señal `pressed`, conectada en la escena con su índice).
func _on_casilla_pressed(i: int) -> void:
	var ya := con_cursor and _casilla == i
	_casilla = i
	_aviso = ""
	cursor_pedido.emit(self)
	if ya: # segundo clic = usar
		confirmar()
