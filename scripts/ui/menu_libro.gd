class_name MenuLibro
extends CanvasLayer
## El libro de Leonidas: inventario, mapa, misiones y guardar. Es un AUTOLOAD llamado
## `Libro` (scenes/ui/menu_libro.tscn). Se abre solo con la acción `inventario` (I /
## Select) si `EstadoJuego.tiene_libro` y Leonidas está a pie sin hacer nada (no en
## diálogos, tienda, cinemáticas, cambios de zona ni en el barco). Mientras está abierto
## el juego está en pausa (`get_tree().paused`).
##
## Plan y medidas: docs/design/plan_inventario_libro.md. El arte es el de la artista
## reducido a ×0,4 (448×230, assets/ui/inventario/); todas las coordenadas de abajo son
## del lienzo reducido. Si llega el arte redibujado, volver a medirlas.
##
## Páginas (en orden; cada pestaña es una página):
##   0 Objetos Importantes (pag_1, derecha)   1 Inventario (pag_2y3, izq.)
##   2 Mapa (pag_2y3, der.)                   3 Misiones (pag_4y5, izq.)
##   4 Guardar (pag_4y5, der.)
## Navegación: flechas/WASD mueven el marco por la rejilla; al salir por un lado se pasa a
## la página vecina; ↑ desde la fila de arriba sube a las pestañas (←/→ cambian de página,
## ↓ o E/J entran). Q/R pasan de página desde cualquier sitio. E/J usa el objeto (comer
## la manzana) o guarda. I, Esc, Espacio/K o la X cierran. El ratón también vale para
## pestañas, casillas, el botón Guardar y la X.
## Todo el texto lo escribe el juego con la fuente Gravity (no es de píxeles: Bold ≥ 10 px).

signal abierto_cambio(abierto: bool)

enum Pagina { IMPORTANTES, INVENTARIO, MAPA, MISIONES, GUARDAR }

const NUM_PAGINAS := 5
const COLUMNAS := 4
const FILAS := 3
## Columnas (x) de las casillas: Inventario (página izquierda) e Importantes (derecha).
const CASILLAS_X_IZQ: Array[int] = [52, 89, 127, 164]
const CASILLAS_X_DER: Array[int] = [254, 291, 328, 366]
const CASILLAS_Y: Array[int] = [58, 94, 129]
const TAM_CASILLA := 27
## Casilla suelta (artículo seleccionado) y hueco del texto a su derecha.
const SUELTA_IZQ := Vector2(53, 174)
const SUELTA_DER := Vector2(254, 174)
const TAM_SUELTA := 29
const ANCHO_TEXTO := 110
## Pestañas: x de cada una (orden de `Pagina`), y apagada / encendida.
const PESTANAS_X: Array[int] = [43, 74, 104, 136, 166]
const PESTANA_Y_OFF := -2
const PESTANA_Y_ON := -9
const PESTANA_APAGADA := Color(0.33, 0.33, 0.33)
const SALIR_POS := Vector2(10, 182)
const TAM_PESTANA := Vector2(26, 22)
## Misiones: y (arriba del «!») de cada renglón; el texto va a la derecha del «!».
const MISIONES_Y_PRINCIPALES: Array[int] = [66, 87, 108]
const MISIONES_Y_SECUNDARIAS: Array[int] = [142, 163, 184]
const MISIONES_X := 62
const MISIONES_ANCHO := 140
## Guardar: dónde van los valores (a la derecha de los rótulos pintados) y el botón.
const GUARDAR_TIEMPO := Vector2(313, 121)
const GUARDAR_JEFES := Vector2(326, 139)
const GUARDAR_BOTON := Rect2(296, 166, 56, 16)
const GUARDAR_MENSAJE := Rect2(246, 152, 160, 13)
## Mapa: zona oscura donde se dibuja el esquema y cartela del nombre de la zona.
const MAPA_CAJAS := Rect2(258, 58, 80, 140)
const CARTELA := Rect2(352, 184, 58, 14)

const TINTA := Color("1c2254")
const TINTA_GRIS := Color(0.11, 0.13, 0.33, 0.45)
const COLOR_AVISO := Color("8a1c12")
const DURACION_AVISO := 1.6

## Zonas del mapa provisional, de norte a sur: [archivo, nombre en el mapa, cartela ≤ 6].
const ZONAS := [
	["casa_arbol", "Casa árbol", "Casa"],
	["pueblo", "Pueblo", "Pueblo"],
	["bosque", "Bosque", "Bosque"],
	["playa", "Playa", "Playa"],
	["mar", "Mar", "Mar"],
	["isla_orilla", "Orilla", "Orilla"],
	["isla", "Isla", "Isla"],
	["cueva_medusa", "Cueva", "Cueva"],
	["cueva_jefe", "Guarida", "Cueva"],
]

@export var fuente: Font = preload("res://assets/fonts/gravity_bold.otf")
@export var paginas_arte: Array[Texture2D] = [
	preload("res://assets/ui/inventario/pag_1.png"),
	preload("res://assets/ui/inventario/pag_2y3.png"),
	preload("res://assets/ui/inventario/pag_4y5.png"),
]

var abierto := false

var _pagina: Pagina = Pagina.INVENTARIO
var _en_pestanas := false
## Casilla elegida en cada página con rejilla (índice = fila * COLUMNAS + columna).
var _casilla := { Pagina.IMPORTANTES: 0, Pagina.INVENTARIO: 0 }
var _frame_apertura := -1
var _tiempo := 0.0
var _aviso := ""
var _tiempo_aviso := 0.0
var _mensaje_guardar := ""

## Nodos creados en _ready.
var _iconos := { Pagina.IMPORTANTES: [], Pagina.INVENTARIO: [] }
var _cantidades := { Pagina.IMPORTANTES: [], Pagina.INVENTARIO: [] }
var _suelta_icono := {}
var _suelta_texto := {}
var _misiones: Array[Label] = []
var _tachados: Array[ColorRect] = []
var _tiempo_label: Label
var _jefes_label: Label
var _marca_guardar: Label
var _mensaje_label: Label
var _cartela: Label

@onready var libro: Control = $Libro
@onready var pagina_arte: TextureRect = $Libro/Pagina
@onready var pestanas: Array[TextureRect] = [
	$Libro/Pestanas/Importantes, $Libro/Pestanas/Inventario, $Libro/Pestanas/Mapa,
	$Libro/Pestanas/Misiones, $Libro/Pestanas/Guardar,
]
@onready var seleccion: TextureRect = $Libro/Seleccion
@onready var contenido: Control = $Libro/Contenido
@onready var mapa: Control = $Libro/Contenido/Mapa


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var tema := Theme.new()
	tema.default_font = fuente
	tema.default_font_size = 10
	tema.set_color(&"font_color", &"Label", TINTA)
	tema.set_constant(&"line_spacing", &"Label", -3)
	libro.theme = tema
	for i in NUM_PAGINAS:
		pestanas[i].position = Vector2(PESTANAS_X[i], PESTANA_Y_OFF)
	_crear_rejilla(Pagina.IMPORTANTES, CASILLAS_X_DER, SUELTA_DER)
	_crear_rejilla(Pagina.INVENTARIO, CASILLAS_X_IZQ, SUELTA_IZQ)
	_crear_misiones()
	_crear_guardar()
	_cartela = _etiqueta(CARTELA.position, CARTELA.size.x, &"Mapa")
	_cartela.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mapa.draw.connect(_dibujar_mapa)
	EstadoJuego.objetos_cambio.connect(func(_id: StringName, _n: int) -> void: _refrescar())
	EstadoJuego.misiones_cambio.connect(_refrescar)


func _etiqueta(pos: Vector2, ancho: float, pagina: StringName, alto := 13.0) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(ancho, alto)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.get_node(NodePath(pagina)).add_child(l)
	return l


func _icono(padre: Control) -> TextureRect:
	var t := TextureRect.new()
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(t)
	return t


func _nombre_nodo(p: Pagina) -> StringName:
	return [&"Importantes", &"Inventario", &"Mapa", &"Misiones", &"Guardar"][p]


func _crear_rejilla(p: Pagina, columnas: Array[int], suelta: Vector2) -> void:
	var padre := contenido.get_node(NodePath(_nombre_nodo(p))) as Control
	for fila in FILAS:
		for col in COLUMNAS:
			var pos := Vector2(columnas[col], CASILLAS_Y[fila])
			var ico := _icono(padre)
			ico.position = pos
			ico.size = Vector2(TAM_CASILLA, TAM_CASILLA)
			_iconos[p].append(ico)
			var n := Label.new()
			n.position = pos + Vector2(0, TAM_CASILLA - 13)
			n.size = Vector2(TAM_CASILLA - 1, 13)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			n.add_theme_color_override(&"font_color", Color.WHITE)
			n.add_theme_color_override(&"font_outline_color", TINTA)
			n.add_theme_constant_override(&"outline_size", 3)
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			padre.add_child(n)
			_cantidades[p].append(n)
	var s := _icono(padre)
	s.position = suelta
	s.size = Vector2(TAM_SUELTA, TAM_SUELTA)
	_suelta_icono[p] = s
	var t := Label.new()
	t.position = suelta + Vector2(TAM_SUELTA + 4, -3)
	t.size = Vector2(ANCHO_TEXTO, 36)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.clip_text = true
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(t)
	_suelta_texto[p] = t


func _crear_misiones() -> void:
	for y in MISIONES_Y_PRINCIPALES + MISIONES_Y_SECUNDARIAS:
		var l := _etiqueta(Vector2(MISIONES_X, y - 3), MISIONES_ANCHO, &"Misiones")
		l.clip_text = true
		_misiones.append(l)
		var raya := ColorRect.new()
		raya.color = TINTA_GRIS
		raya.mouse_filter = Control.MOUSE_FILTER_IGNORE
		raya.visible = false
		contenido.get_node(^"Misiones").add_child(raya)
		_tachados.append(raya)


func _crear_guardar() -> void:
	_tiempo_label = _etiqueta(GUARDAR_TIEMPO, 80, &"Guardar")
	_jefes_label = _etiqueta(GUARDAR_JEFES, 60, &"Guardar")
	_marca_guardar = _etiqueta(GUARDAR_BOTON.position + Vector2(-2, 0), 10, &"Guardar")
	_marca_guardar.text = ">"
	_mensaje_label = _etiqueta(GUARDAR_MENSAJE.position, GUARDAR_MENSAJE.size.x, &"Guardar")
	_mensaje_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# --- Abrir y cerrar -------------------------------------------------------------------

## ¿Se puede abrir ahora? Con el libro, a pie, sin diálogo/tienda/cambio de zona.
func puede_abrir() -> bool:
	if abierto or not EstadoJuego.tiene_libro or get_tree().paused:
		return false
	if Dialogos.abierto or Tienda.abierto:
		return false
	var game := get_tree().get_first_node_in_group(&"game") as Game
	if game == null or game.barco != null or game.cambiando():
		return false
	var jugador := game.jugador
	return jugador != null and jugador.puede_usar_objeto()


## Abre el libro (en Inventario, o en `pagina`). Devuelve false si ahora no se puede.
func abrir(pagina: Pagina = Pagina.INVENTARIO) -> bool:
	if not puede_abrir():
		return false
	abierto = true
	_frame_apertura = Engine.get_process_frames()
	_pagina = pagina
	_en_pestanas = false
	_aviso = ""
	_mensaje_guardar = ""
	get_tree().paused = true
	visible = true
	_refrescar()
	abierto_cambio.emit(true)
	return true


func cerrar() -> void:
	if not abierto:
		return
	abierto = false
	visible = false
	get_tree().paused = false
	abierto_cambio.emit(false)


func _process(delta: float) -> void:
	if not abierto:
		if Input.is_action_just_pressed(&"inventario"):
			abrir()
		return
	_tiempo += delta
	if _tiempo_aviso > 0.0:
		_tiempo_aviso -= delta
		if _tiempo_aviso <= 0.0:
			_aviso = ""
			_mensaje_guardar = ""
			_refrescar()
	_animar()
	if Engine.get_process_frames() <= _frame_apertura:
		return
	if Input.is_action_just_pressed(&"inventario") or Input.is_action_just_pressed(&"ui_cancel") \
			or Input.is_action_just_pressed(&"pirueta"):
		cerrar()
	elif Input.is_action_just_pressed(&"pagina_anterior"):
		_ir_a_pagina(_pagina - 1, false)
	elif Input.is_action_just_pressed(&"pagina_siguiente"):
		_ir_a_pagina(_pagina + 1, true)
	elif Input.is_action_just_pressed(&"mover_izquierda"):
		_mover(Vector2i.LEFT)
	elif Input.is_action_just_pressed(&"mover_derecha"):
		_mover(Vector2i.RIGHT)
	elif Input.is_action_just_pressed(&"mover_arriba"):
		_mover(Vector2i.UP)
	elif Input.is_action_just_pressed(&"mover_abajo"):
		_mover(Vector2i.DOWN)
	elif Input.is_action_just_pressed(&"interactuar") or Input.is_action_just_pressed(&"atacar"):
		_confirmar()


# --- Navegación -----------------------------------------------------------------------

func _tiene_rejilla(p: Pagina) -> bool:
	return p == Pagina.IMPORTANTES or p == Pagina.INVENTARIO


## Va a la página `p` (si existe). `desde_izquierda`: se entra por su lado izquierdo
## (la casilla de la primera columna) o por el derecho (la última).
func _ir_a_pagina(p: int, desde_izquierda: bool) -> void:
	if p < 0 or p >= NUM_PAGINAS or p == _pagina:
		return
	var fila: int = _casilla[_pagina] / COLUMNAS if _tiene_rejilla(_pagina) else 0
	_pagina = p as Pagina
	if _tiene_rejilla(_pagina):
		_casilla[_pagina] = fila * COLUMNAS + (0 if desde_izquierda else COLUMNAS - 1)
	_aviso = ""
	_refrescar()


func _mover(d: Vector2i) -> void:
	if _en_pestanas:
		if d.x != 0:
			_ir_a_pagina(_pagina + d.x, d.x > 0)
		elif d.y > 0:
			_en_pestanas = false
			_refrescar()
		return
	if not _tiene_rejilla(_pagina):
		if d.x != 0:
			_ir_a_pagina(_pagina + d.x, d.x > 0)
		elif d.y < 0:
			_en_pestanas = true
			_refrescar()
		return
	var i: int = _casilla[_pagina]
	var col := i % COLUMNAS + d.x
	var fila := i / COLUMNAS + d.y
	if fila < 0:
		_en_pestanas = true
	elif fila >= FILAS:
		return
	elif col < 0:
		_ir_a_pagina(_pagina - 1, false)
		return
	elif col >= COLUMNAS:
		_ir_a_pagina(_pagina + 1, true)
		return
	else:
		_casilla[_pagina] = fila * COLUMNAS + col
	_aviso = ""
	_refrescar()


func _confirmar() -> void:
	if _en_pestanas:
		_en_pestanas = false
		_refrescar()
		return
	match _pagina:
		Pagina.INVENTARIO:
			_usar(_objeto_en(Pagina.INVENTARIO, _casilla[Pagina.INVENTARIO]))
		Pagina.GUARDAR:
			_guardar()


func _usar(id: StringName) -> void:
	var o := EstadoJuego.objeto(id) if id != &"" else null
	if o == null or o.tipo != Objeto.Tipo.CONSUMIBLE:
		return
	var game := get_tree().get_first_node_in_group(&"game") as Game
	var jugador := game.jugador if game else null
	if jugador == null:
		return
	if o.cura > 0 and jugador.vida.vida >= jugador.vida.vida_max:
		_avisar("Ya estás bien.")
		return
	if not EstadoJuego.gastar_objeto(id):
		return
	# Se cierra el libro para ver a Leonidas comer.
	cerrar()
	jugador.comer(o)


func _guardar() -> void:
	if EstadoJuego.guardar():
		_mensaje_guardar = "¡Partida guardada!"
	else:
		_mensaje_guardar = "No se pudo guardar."
	_tiempo_aviso = DURACION_AVISO
	_refrescar()


func _avisar(t: String) -> void:
	_aviso = t
	_tiempo_aviso = DURACION_AVISO
	_refrescar()


# --- Ratón ----------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not abierto:
		return
	var boton := event as InputEventMouseButton
	if boton == null or not boton.pressed or boton.button_index != MOUSE_BUTTON_LEFT:
		return
	var pos := boton.position - libro.position
	get_viewport().set_input_as_handled()
	if Rect2(SALIR_POS, TAM_PESTANA).has_point(pos):
		cerrar()
		return
	for i in NUM_PAGINAS:
		if Rect2(pestanas[i].position, TAM_PESTANA).has_point(pos):
			_ir_a_pagina(i, true)
			_en_pestanas = false
			_refrescar()
			return
	for p: Pagina in [Pagina.IMPORTANTES, Pagina.INVENTARIO]:
		if not _pagina_visible(p):
			continue
		var cols := CASILLAS_X_DER if p == Pagina.IMPORTANTES else CASILLAS_X_IZQ
		for fila in FILAS:
			for col in COLUMNAS:
				var r := Rect2(cols[col], CASILLAS_Y[fila], TAM_CASILLA, TAM_CASILLA)
				if r.has_point(pos):
					var i := fila * COLUMNAS + col
					var ya: bool = _pagina == p and _casilla[p] == i and not _en_pestanas
					_pagina = p
					_en_pestanas = false
					_casilla[p] = i
					_aviso = ""
					if ya: # segundo clic = usar
						_confirmar()
					else:
						_refrescar()
					return
	if _pagina_visible(Pagina.GUARDAR) and GUARDAR_BOTON.has_point(pos):
		_pagina = Pagina.GUARDAR
		_en_pestanas = false
		_guardar()


# --- Dibujo ---------------------------------------------------------------------------

## Par de páginas que se ve (índice de `paginas_arte`).
func _pliego(p: Pagina) -> int:
	return [0, 1, 1, 2, 2][p]


func _pagina_visible(p: Pagina) -> bool:
	return _pliego(p) == _pliego(_pagina)


## Objetos de una página con rejilla, en orden.
func _objetos_de(p: Pagina) -> Array[StringName]:
	var tipo := Objeto.Tipo.IMPORTANTE if p == Pagina.IMPORTANTES else Objeto.Tipo.CONSUMIBLE
	return EstadoJuego.objetos_de_tipo(tipo)


func _objeto_en(p: Pagina, i: int) -> StringName:
	var lista := _objetos_de(p)
	return lista[i] if i < lista.size() else &""


func _refrescar() -> void:
	if not is_node_ready():
		return
	pagina_arte.texture = paginas_arte[_pliego(_pagina)]
	for i in NUM_PAGINAS:
		var activa := i == _pagina
		pestanas[i].modulate = Color.WHITE if activa else PESTANA_APAGADA
		pestanas[i].position.y = PESTANA_Y_ON if activa else PESTANA_Y_OFF
	for p in NUM_PAGINAS:
		(contenido.get_child(p) as CanvasItem).visible = _pagina_visible(p)
	for p: Pagina in [Pagina.IMPORTANTES, Pagina.INVENTARIO]:
		_refrescar_rejilla(p)
	_refrescar_misiones()
	_refrescar_guardar()
	_refrescar_mapa()
	# Marco de selección: solo en las rejillas y fuera de las pestañas.
	seleccion.visible = not _en_pestanas and _tiene_rejilla(_pagina)
	if seleccion.visible:
		var i: int = _casilla[_pagina]
		var cols := CASILLAS_X_DER if _pagina == Pagina.IMPORTANTES else CASILLAS_X_IZQ
		seleccion.position = Vector2(cols[i % COLUMNAS], CASILLAS_Y[i / COLUMNAS]) - Vector2(3, 3)


func _poner_icono(t: TextureRect, tex: Texture2D, caja: float) -> void:
	t.texture = tex
	if tex == null:
		return
	# Iconos pequeños a ×2 (escala entera) para que se vean en la casilla.
	var tam := tex.get_size()
	var escala := 2.0 if maxf(tam.x, tam.y) * 2.0 <= caja - 4.0 else 1.0
	var centro := t.position + t.size / 2.0
	t.size = tam * escala
	t.position = (centro - t.size / 2.0).round()


func _refrescar_rejilla(p: Pagina) -> void:
	var lista := _objetos_de(p)
	var cols := CASILLAS_X_DER if p == Pagina.IMPORTANTES else CASILLAS_X_IZQ
	for i in COLUMNAS * FILAS:
		var ico: TextureRect = _iconos[p][i]
		var num: Label = _cantidades[p][i]
		ico.position = Vector2(cols[i % COLUMNAS], CASILLAS_Y[i / COLUMNAS])
		ico.size = Vector2(TAM_CASILLA, TAM_CASILLA)
		var id: StringName = lista[i] if i < lista.size() else &""
		var o := EstadoJuego.objeto(id) if id != &"" else null
		_poner_icono(ico, o.icono if o else null, TAM_CASILLA)
		num.text = str(EstadoJuego.cantidad(id)) if o and o.maximo > 1 else ""
	# Casilla suelta: el elegido (icono + nombre, cantidad y descripción).
	var elegido := _objeto_en(p, _casilla[p])
	var obj := EstadoJuego.objeto(elegido) if elegido != &"" else null
	var s: TextureRect = _suelta_icono[p]
	s.position = SUELTA_DER if p == Pagina.IMPORTANTES else SUELTA_IZQ
	s.size = Vector2(TAM_SUELTA, TAM_SUELTA)
	_poner_icono(s, obj.icono if obj else null, TAM_SUELTA)
	var texto: Label = _suelta_texto[p]
	texto.remove_theme_color_override(&"font_color")
	if p == _pagina and not _aviso.is_empty():
		texto.text = _aviso
		texto.add_theme_color_override(&"font_color", COLOR_AVISO)
	elif obj:
		var titulo := obj.nombre
		if obj.maximo > 1:
			titulo += " x%d" % EstadoJuego.cantidad(elegido)
		texto.text = titulo + "\n" + obj.descripcion
	else:
		texto.text = ""


func _refrescar_misiones() -> void:
	var principales: Array[StringName] = []
	var secundarias: Array[StringName] = []
	for id in EstadoJuego.misiones:
		var m := EstadoJuego.mision(id)
		if m == null:
			continue
		(principales if m.principal else secundarias).append(id)
	var renglones: Array[StringName] = []
	for i in 3:
		renglones.append(principales[i] if i < principales.size() else &"")
	for i in 3:
		renglones.append(secundarias[i] if i < secundarias.size() else &"")
	for i in renglones.size():
		var l := _misiones[i]
		var raya := _tachados[i]
		var id := renglones[i]
		var m := EstadoJuego.mision(id) if id != &"" else null
		l.text = m.titulo if m else ""
		var hecha := m != null and EstadoJuego.mision_completada(id)
		if hecha:
			l.add_theme_color_override(&"font_color", TINTA_GRIS)
		else:
			l.remove_theme_color_override(&"font_color")
		raya.visible = hecha
		if hecha:
			var ancho := minf(fuente.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x,
				MISIONES_ANCHO)
			raya.position = l.position + Vector2(0, 7)
			raya.size = Vector2(ancho, 1)


func _refrescar_guardar() -> void:
	_tiempo_label.text = EstadoJuego.tiempo_texto()
	_jefes_label.text = str(EstadoJuego.jefes_derrotados)
	_mensaje_label.text = _mensaje_guardar
	_marca_guardar.visible = _pagina == Pagina.GUARDAR and not _en_pestanas


func _zona_actual() -> int:
	var game := get_tree().get_first_node_in_group(&"game") as Game
	if game == null:
		return -1
	var archivo := game.ruta_zona().get_file().get_basename()
	for i in ZONAS.size():
		if ZONAS[i][0] == archivo:
			return i
	return -1


func _refrescar_mapa() -> void:
	var z := _zona_actual()
	_cartela.text = ZONAS[z][2] if z >= 0 else ""
	mapa.queue_redraw()


## Esquema PROVISIONAL del mundo (plan_mapa_mundo.md) hasta que la artista pinte el mapa:
## una caja por zona, de norte a sur, unidas por una línea; la actual parpadea.
func _dibujar_mapa() -> void:
	var paso := MAPA_CAJAS.size.y / ZONAS.size()
	var alto := paso - 4.0
	var linea := Color("c79a6e")
	var actual := _zona_actual()
	var x := MAPA_CAJAS.position.x
	for i in ZONAS.size():
		var r := Rect2(x, MAPA_CAJAS.position.y + i * paso, MAPA_CAJAS.size.x, alto)
		r.position = r.position.round()
		if i > 0:
			var cx := roundf(r.get_center().x)
			mapa.draw_line(Vector2(cx, r.position.y - 4), Vector2(cx, r.position.y), linea)
		var es_actual := i == actual
		var encendida := es_actual and fmod(_tiempo, 0.8) < 0.5
		var relleno := Color("3e6395") if ZONAS[i][0] == "mar" else Color("3a3034")
		if encendida:
			relleno = Color("e8c88a")
		mapa.draw_rect(r, relleno)
		mapa.draw_rect(r.grow(-0.5), linea, false, 1.0)
		var texto_color := TINTA if encendida else Color("e8d2b0")
		var ancho := fuente.get_string_size(ZONAS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var pos := Vector2(roundf(r.get_center().x - ancho / 2.0), r.position.y + alto - 2.0)
		mapa.draw_string(fuente, pos, ZONAS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, texto_color)


func _animar() -> void:
	# La pestaña elegida parpadea un poco cuando el cursor está en las pestañas.
	if _en_pestanas:
		var on := fmod(_tiempo, 0.6) < 0.4
		pestanas[_pagina].modulate = Color.WHITE if on else Color(0.75, 0.75, 0.75)
	if _pagina_visible(Pagina.MAPA):
		mapa.queue_redraw()
	if _pagina == Pagina.GUARDAR:
		_tiempo_label.text = EstadoJuego.tiempo_texto()
		_marca_guardar.modulate.a = 1.0 if fmod(_tiempo, 0.8) < 0.55 else 0.0
