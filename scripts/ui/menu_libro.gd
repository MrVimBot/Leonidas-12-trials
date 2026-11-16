class_name MenuLibro
extends CanvasLayer
## El libro de Leonidas: inventario, mapa, misiones y guardar. Es un AUTOLOAD llamado
## `Libro` (scenes/ui/menu_libro.tscn). Se abre solo con la acción `inventario` (I /
## Select) si `EstadoJuego.tiene_libro` y Leonidas está a pie sin hacer nada (no en
## diálogos, tienda, cinemáticas, cambios de zona ni en el barco). Mientras está abierto
## el juego está en pausa (`get_tree().paused`).
##
## ARTE Y ESCALA (decidido el 2026-11-14, ver docs/design/plan_inventario_libro.md):
## el libro es la maqueta por capas de la artista a 559×300 (assets/ui/libro/, la exporta
## tools/export_libro.lua), que no cabe en los 480×270 del juego. En vez de reducirla, al
## abrir el libro la ventana pasa a `CONTENT_SCALE_MODE_CANVAS_ITEMS` (como la cinemática)
## y `Libro` se escala para que cada píxel del arte ocupe un número ENTERO de píxeles de
## pantalla (×3 en 1920×1080, ×2 en 1440×810). Detrás se ve una captura del último
## fotograma del juego (así el mundo no cambia de aspecto con el cambio de modo).
## Todas las coordenadas de este script están en píxeles del lienzo de 559×300. Las de
## casillas, pestañas, X y marco salen de assets/ui/libro/libro.json; las de los textos
## (misiones, guardar, mapa) son constantes medidas sobre el arte: si la artista mueve esas
## páginas, volver a medirlas.
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
## Todo el texto lo escribe el juego con la fuente Gravity (no es de píxeles: se dibuja a la
## resolución de la pantalla, con filtro lineal).

signal abierto_cambio(abierto: bool)

enum Pagina { IMPORTANTES, INVENTARIO, MAPA, MISIONES, GUARDAR }

const NUM_PAGINAS := 5
const COLUMNAS := 4
const FILAS := 3
const DIR_ARTE := "res://assets/ui/libro/"
const NOMBRES_PAGINA: Array[StringName] = [&"importantes", &"inventario", &"mapa", &"misiones", &"guardar"]
## Tamaño de la pantalla lógica del juego (project.godot).
const PANTALLA := Vector2(480, 270)

## Tamaños de letra (px del lienzo; en 1920×1080 cada uno son 3 px de pantalla).
const LETRA := 9
const LETRA_CANTIDAD := 8
## Texto a la derecha de la casilla suelta (artículo elegido).
const TEXTO_SEPARACION := 6
const TEXTO_ANCHO := 132
const TEXTO_ALTO := 44
## Misiones: renglón (y de la raya pintada) de cada misión; el texto va encima, tras el «!».
const MISIONES_RAYAS: Array[int] = [113, 139, 166, 208, 234, 261]
const MISIONES_X := 76
const MISIONES_ANCHO := 168
## Guardar: valores a la derecha de los rótulos pintados, botón y mensaje.
const GUARDAR_TIEMPO := Vector2(401, 166)
const GUARDAR_JEFES := Vector2(418, 181)
const GUARDAR_BOTON := Rect2(372, 222, 62, 18)
const GUARDAR_MENSAJE := Rect2(305, 197, 192, 14)
## Mapa: columna de cajas dentro de la zona oscura y cartela (entre los laureles).
const MAPA_CAJAS := Rect2(316, 80, 108, 180)
const CARTELA := Rect2(457, 246, 38, 14)

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

var abierto := false

var _pagina: Pagina = Pagina.INVENTARIO
var _en_pestanas := false
## Casilla elegida en cada página con rejilla (índice = fila * COLUMNAS + columna).
var _casilla := { Pagina.IMPORTANTES: 0, Pagina.INVENTARIO: 0 }
var _tiempo := 0.0
var _aviso := ""
var _tiempo_aviso := 0.0
var _mensaje_guardar := ""
var _modo_original: Window.ContentScaleMode

## Medidas de libro.json (px del lienzo).
var _rejilla := {}          # Pagina → Array[Rect2] (12 casillas)
var _suelta := {}           # Pagina → Rect2 (casilla del artículo elegido)
var _pestana_x: Array[int] = []
var _pestana_y := Vector2i(19, 11) # apagada, encendida
var _pestana_tam := Vector2(31, 28)
var _salir := Rect2(11, 239, 31, 28)
var _sel_desplazamiento := Vector2(-3, -4)
var _paginas_arte: Array[Texture2D] = []
var _tex_pestana := {}      # nombre → [encendida, apagada]

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
var _raton_en_salir := false

@onready var fondo: TextureRect = $Fondo
@onready var libro: Control = $Libro
@onready var cobertura: TextureRect = $Libro/Cobertura
@onready var pagina_arte: TextureRect = $Libro/Pagina
@onready var pestanas: Array[TextureRect] = [
	$Libro/Pestanas/Importantes, $Libro/Pestanas/Inventario, $Libro/Pestanas/Mapa,
	$Libro/Pestanas/Misiones, $Libro/Pestanas/Guardar,
]
@onready var salir: TextureRect = $Libro/Salir
@onready var seleccion: TextureRect = $Libro/Seleccion
@onready var contenido: Control = $Libro/Contenido
@onready var mapa: Control = $Libro/Contenido/Mapa


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_cargar_arte()
	var tema := Theme.new()
	tema.default_font = fuente
	tema.default_font_size = LETRA
	tema.set_color(&"font_color", &"Label", TINTA)
	tema.set_constant(&"line_spacing", &"Label", -2)
	libro.theme = tema
	_crear_rejilla(Pagina.IMPORTANTES)
	_crear_rejilla(Pagina.INVENTARIO)
	_crear_misiones()
	_crear_guardar()
	_cartela = _etiqueta(CARTELA.position, CARTELA.size.x, &"Mapa", CARTELA.size.y)
	_cartela.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mapa.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR # su texto
	mapa.draw.connect(_dibujar_mapa)
	EstadoJuego.objetos_cambio.connect(func(_id: StringName, _n: int) -> void: _refrescar())
	EstadoJuego.misiones_cambio.connect(_refrescar)
	EstadoJuego.estado_restablecido.connect(_refrescar)
	get_window().size_changed.connect(_colocar)


## Texturas y medidas que exporta tools/export_libro.lua.
func _cargar_arte() -> void:
	cobertura.texture = load(DIR_ARTE + "cobertura.png")
	for nombre: String in ["pag_1", "pag_2y3", "pag_4y5"]:
		_paginas_arte.append(load(DIR_ARTE + nombre + ".png"))
	var datos: Dictionary = (load(DIR_ARTE + "libro.json") as JSON).data
	libro.size = Vector2(datos.lienzo[0], datos.lienzo[1])
	_pestana_y = Vector2i(datos.pestana_y[0], datos.pestana_y[1])
	for i in NUM_PAGINAS:
		var p: Array = datos.pestanas[i]
		_pestana_x.append(int(p[1]))
		_pestana_tam = Vector2(p[2], p[3])
		_tex_pestana[p[0]] = [load(DIR_ARTE + "pestana_%s.png" % p[0]),
			load(DIR_ARTE + "pestana_%s_apagada.png" % p[0])]
	_salir = Rect2(datos.salir[0], datos.salir[1], datos.salir[2], datos.salir[3])
	salir.position = _salir.position
	_tex_pestana[&"salir"] = [load(DIR_ARTE + "salir.png"), load(DIR_ARTE + "salir_apagada.png")]
	seleccion.texture = load(DIR_ARTE + "seleccion.png")
	_sel_desplazamiento = Vector2(datos.seleccion[2], datos.seleccion[3])
	for p: Pagina in [Pagina.IMPORTANTES, Pagina.INVENTARIO]:
		var lista: Array = datos.casillas[String(NOMBRES_PAGINA[p])]
		assert(lista.size() == COLUMNAS * FILAS + 1, "libro.json: faltan casillas en " + NOMBRES_PAGINA[p])
		var rects: Array[Rect2] = []
		for c: Array in lista:
			rects.append(Rect2(c[0], c[1], c[2], c[3]))
		_suelta[p] = rects.pop_back()
		_rejilla[p] = rects


## Escala entera de pantalla para el libro y lo centra. Se llama al abrir y si cambia la
## ventana. Con el modo CANVAS_ITEMS una unidad lógica son `f` píxeles de pantalla.
func _colocar() -> void:
	if not abierto:
		return
	# Con escala entera y aspecto fijo, el juego ocupa PANTALLA × f píxeles de la ventana
	# (lo demás son bandas negras, donde no se puede dibujar).
	var ventana := Vector2(get_window().size)
	var f := maxf(1.0, floorf(minf(ventana.x / PANTALLA.x, ventana.y / PANTALLA.y)))
	var area := PANTALLA * f
	var k := maxf(1.0, floorf(minf(area.x / libro.size.x, area.y / libro.size.y)))
	var escala := k / f
	libro.scale = Vector2(escala, escala)
	# Esquina en un píxel entero de pantalla.
	libro.position = ((PANTALLA - libro.size * escala) / 2.0 * f).round() / f


func _etiqueta(pos: Vector2, ancho: float, pagina: StringName, alto := 13.0) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(ancho, alto)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	contenido.get_node(NodePath(pagina)).add_child(l)
	return l


func _icono(padre: Control) -> TextureRect:
	var t := TextureRect.new()
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(t)
	return t


func _nombre_nodo(p: Pagina) -> StringName:
	return [&"Importantes", &"Inventario", &"Mapa", &"Misiones", &"Guardar"][p]


func _crear_rejilla(p: Pagina) -> void:
	var padre := contenido.get_node(NodePath(_nombre_nodo(p))) as Control
	for r: Rect2 in _rejilla[p]:
		_iconos[p].append(_icono(padre))
		var n := Label.new()
		n.position = r.position + Vector2(0, r.size.y - 12)
		n.size = Vector2(r.size.x - 1, 12)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		n.add_theme_font_size_override(&"font_size", LETRA_CANTIDAD)
		n.add_theme_color_override(&"font_color", Color.WHITE)
		n.add_theme_color_override(&"font_outline_color", TINTA)
		n.add_theme_constant_override(&"outline_size", 3)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		padre.add_child(n)
		_cantidades[p].append(n)
	_suelta_icono[p] = _icono(padre)
	var s: Rect2 = _suelta[p]
	var t := Label.new()
	t.position = Vector2(s.end.x + TEXTO_SEPARACION, s.position.y - 2)
	t.size = Vector2(TEXTO_ANCHO, TEXTO_ALTO)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.clip_text = true
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	padre.add_child(t)
	_suelta_texto[p] = t


func _crear_misiones() -> void:
	for y in MISIONES_RAYAS:
		var l := _etiqueta(Vector2(MISIONES_X, y - 14), MISIONES_ANCHO, &"Misiones")
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
	_marca_guardar = _etiqueta(GUARDAR_BOTON.position + Vector2(-8, 1), 10, &"Guardar")
	_marca_guardar.text = ">"
	_mensaje_label = _etiqueta(GUARDAR_MENSAJE.position, GUARDAR_MENSAJE.size.x, &"Guardar",
		GUARDAR_MENSAJE.size.y)
	_mensaje_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# --- Abrir y cerrar -------------------------------------------------------------------

## ¿Se puede abrir ahora? Con el libro, a pie, sin diálogo/tienda/cambio de zona.
func puede_abrir() -> bool:
	if abierto or not EstadoJuego.tiene_libro or get_tree().paused:
		return false
	if Dialogos.abierto or Tienda.abierto:
		return false
	var game := Game.actual(self)
	if game == null or game.barco != null or game.cambiando:
		return false
	var jugador := game.jugador
	return jugador != null and jugador.puede_usar_objeto()


## Abre el libro (en Inventario, o en `pagina`). Devuelve false si ahora no se puede.
func abrir(pagina: Pagina = Pagina.INVENTARIO) -> bool:
	if not puede_abrir():
		return false
	# Captura del juego tal como se ve ahora (a 480×270): será el fondo mientras la
	# ventana está en modo CANVAS_ITEMS.
	var captura := get_viewport().get_texture().get_image()
	fondo.texture = ImageTexture.create_from_image(captura) if captura else null
	abierto = true
	_pagina = pagina
	_en_pestanas = false
	_aviso = ""
	_mensaje_guardar = ""
	_raton_en_salir = false
	_modo_original = get_window().content_scale_mode
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().paused = true
	visible = true
	_colocar()
	_refrescar()
	abierto_cambio.emit(true)
	return true


func cerrar() -> void:
	if not abierto:
		return
	abierto = false
	visible = false
	fondo.texture = null
	get_window().content_scale_mode = _modo_original
	get_tree().paused = false
	abierto_cambio.emit(false)


func _process(delta: float) -> void:
	if not abierto:
		return
	_tiempo += delta
	if _tiempo_aviso > 0.0:
		_tiempo_aviso -= delta
		if _tiempo_aviso <= 0.0:
			_aviso = ""
			_mensaje_guardar = ""
			_refrescar()
	_animar()


## Teclado y mando (el ratón va en `_input`). Cerrado: solo abre con `inventario`.
## Abierto (árbol en pausa; este autoload sigue recibiendo eventos) consume toda pulsación
## de una acción. Orden de reparto: la escena actual recibe antes; `MenuPausa` no se abre
## con el libro abierto ni consume el Esc, que llega aquí y cierra el libro. La pulsación
## que cierra el libro se consume aquí mismo, así que no lo vuelve a abrir.
func _unhandled_input(event: InputEvent) -> void:
	if not abierto:
		if event.is_action_pressed(&"inventario") and puede_abrir():
			get_viewport().set_input_as_handled()
			abrir()
		return
	if event.is_action_pressed(&"inventario") or event.is_action_pressed(&"ui_cancel") \
			or event.is_action_pressed(&"pirueta"):
		cerrar()
	elif event.is_action_pressed(&"pagina_anterior"):
		_ir_a_pagina(_pagina - 1, false)
	elif event.is_action_pressed(&"pagina_siguiente"):
		_ir_a_pagina(_pagina + 1, true)
	elif _mover_pulsado(event, &"mover_izquierda"):
		_mover(Vector2i.LEFT)
	elif _mover_pulsado(event, &"mover_derecha"):
		_mover(Vector2i.RIGHT)
	elif _mover_pulsado(event, &"mover_arriba"):
		_mover(Vector2i.UP)
	elif _mover_pulsado(event, &"mover_abajo"):
		_mover(Vector2i.DOWN)
	elif event.is_action_pressed(&"interactuar") or event.is_action_pressed(&"atacar"):
		_confirmar()
	if event.is_action_type():
		get_viewport().set_input_as_handled()


## ¿`event` mueve el marco con `accion`? Las teclas mantenidas se repiten (eventos `echo`);
## del stick solo cuenta el evento que empieza la pulsación: cada movimiento más allá de
## la zona muerta es otro evento "pulsado" y el marco saldría disparado.
static func _mover_pulsado(event: InputEvent, accion: StringName) -> bool:
	if event.is_echo():
		return event.is_action_pressed(accion, true)
	return event.is_action_pressed(accion) and Input.is_action_just_pressed_by_event(accion, event)


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
	@warning_ignore("integer_division") # índice de casilla → fila
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
	var game := Game.actual(self)
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
	var game := Game.actual(self)
	if game != null and EstadoJuego.guardar(game.datos_guardado()):
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

## Posición del ratón en píxeles del lienzo del libro.
func _en_libro(pos: Vector2) -> Vector2:
	return libro.get_global_transform().affine_inverse() * pos


func _input(event: InputEvent) -> void:
	if not abierto:
		return
	var movimiento := event as InputEventMouseMotion
	if movimiento:
		var encima := _salir.has_point(_en_libro(movimiento.position))
		if encima != _raton_en_salir:
			_raton_en_salir = encima
			_refrescar()
		return
	var boton := event as InputEventMouseButton
	if boton == null or not boton.pressed or boton.button_index != MOUSE_BUTTON_LEFT:
		return
	var pos := _en_libro(boton.position)
	get_viewport().set_input_as_handled()
	if _salir.has_point(pos):
		cerrar()
		return
	for i in NUM_PAGINAS:
		if Rect2(pestanas[i].position, _pestana_tam).has_point(pos):
			_ir_a_pagina(i, true)
			_en_pestanas = false
			_refrescar()
			return
	for p: Pagina in [Pagina.IMPORTANTES, Pagina.INVENTARIO]:
		if not _pagina_visible(p):
			continue
		var rects: Array[Rect2] = _rejilla[p]
		for i in rects.size():
			if rects[i].has_point(pos):
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

## Par de páginas que se ve (índice de `_paginas_arte`).
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
	pagina_arte.texture = _paginas_arte[_pliego(_pagina)]
	for i in NUM_PAGINAS:
		var activa := i == _pagina
		pestanas[i].texture = _tex_pestana[NOMBRES_PAGINA[i]][0 if activa else 1]
		pestanas[i].position = Vector2(_pestana_x[i], _pestana_y.y if activa else _pestana_y.x)
		pestanas[i].modulate = Color.WHITE
	salir.texture = _tex_pestana[&"salir"][0 if _raton_en_salir else 1]
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
		var r: Rect2 = _rejilla[_pagina][_casilla[_pagina]]
		seleccion.position = r.position + _sel_desplazamiento


## Coloca el icono centrado en la caja, a la mayor escala entera (máx. ×2) que quepa.
func _poner_icono(t: TextureRect, tex: Texture2D, caja: Rect2) -> void:
	t.texture = tex
	if tex == null:
		return
	var tam := tex.get_size()
	var escala := clampf(floorf(minf(caja.size.x / tam.x, caja.size.y / tam.y)), 1.0, 2.0)
	t.size = tam * escala
	t.position = (caja.get_center() - t.size / 2.0).floor()


func _refrescar_rejilla(p: Pagina) -> void:
	var lista := _objetos_de(p)
	var rects: Array[Rect2] = _rejilla[p]
	for i in rects.size():
		var ico: TextureRect = _iconos[p][i]
		var num: Label = _cantidades[p][i]
		var id: StringName = lista[i] if i < lista.size() else &""
		var o := EstadoJuego.objeto(id) if id != &"" else null
		_poner_icono(ico, o.icono if o else null, rects[i])
		num.text = str(EstadoJuego.cantidad(id)) if o and o.maximo > 1 else ""
	# Casilla suelta: el elegido (icono + nombre, cantidad y descripción).
	var elegido := _objeto_en(p, _casilla[p])
	var obj := EstadoJuego.objeto(elegido) if elegido != &"" else null
	_poner_icono(_suelta_icono[p], obj.icono if obj else null, _suelta[p])
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
			var ancho := minf(fuente.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, LETRA).x,
				MISIONES_ANCHO)
			raya.position = l.position + Vector2(0, 7)
			raya.size = Vector2(ancho, 1)


func _refrescar_guardar() -> void:
	_tiempo_label.text = EstadoJuego.tiempo_texto()
	_jefes_label.text = str(EstadoJuego.jefes_derrotados)
	_mensaje_label.text = _mensaje_guardar
	_marca_guardar.visible = _pagina == Pagina.GUARDAR and not _en_pestanas


func _zona_actual() -> int:
	var game := Game.actual(self)
	if game == null:
		return -1
	var archivo := game.ruta_zona.get_file().get_basename()
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
		var ancho := fuente.get_string_size(ZONAS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, LETRA).x
		var base := r.position.y + (alto + fuente.get_ascent(LETRA) - fuente.get_descent(LETRA)) / 2.0
		var pos := Vector2(r.get_center().x - ancho / 2.0, base)
		mapa.draw_string(fuente, pos, ZONAS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, LETRA, texto_color)


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
