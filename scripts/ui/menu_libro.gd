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
## Todas las coordenadas de este script están en píxeles del lienzo de 559×300.
##
## QUÉ ESTÁ EN LA ESCENA Y QUÉ EN EL SCRIPT: la interfaz (texturas, tema
## resources/ui/tema_libro.tres, botones, casillas, renglones de misiones, etiquetas de
## Guardar y la cartela del mapa) está en la escena y se retoca en el editor; si la artista
## mueve los textos de Misiones, Guardar o el mapa, se recolocan allí. Lo único que coloca
## el script es lo que mide assets/ui/libro/libro.json (casillas, casilla suelta y su
## texto, pestañas, X y marco), porque se regenera solo cuando la artista cambia el arte.
##
## COORDINADOR Y PÁGINAS: este script abre y cierra el libro, lo escala y coloca, enseña
## el pliego y las pestañas, cambia de página y reparte la entrada. Cada página
## (`Libro/Contenido/<Pagina>`) tiene su script en scripts/ui/libro/ (base `PaginaLibro`,
## que documenta la interfaz común): pinta sus datos y mueve su propio cursor; lo que no
## le toca (usar un objeto, guardar, tomar el cursor con el ratón) lo pide con señales
## conectadas en la escena.
##
## Páginas (en orden; cada pestaña es una página):
##   0 Objetos Importantes (pag_1, derecha)   1 Inventario (pag_2y3, izq.)
##   2 Mapa (pag_2y3, der.)                   3 Misiones (pag_4y5, izq.)
##   4 Guardar (pag_4y5, der.)
## Navegación: flechas/WASD mueven el marco por la rejilla; al salir por un lado se pasa a
## la página vecina; ↑ desde la fila de arriba sube a las pestañas (←/→ cambian de página,
## ↓ o E/J entran). Q/R pasan de página desde cualquier sitio. E/J usa el objeto (comer
## la manzana) o guarda. I, Esc, Espacio/K o la X cierran.
## Ratón: pestañas, X, casillas y Guardar son botones (TextureButton) con `pressed`
## conectado en la escena; actúan al pulsar, no al soltar (`action_mode`). Ninguno toma el
## foco (`focus_mode` None): el teclado/mando sigue con el cursor propio de este script.
## `Oscuro` (mouse_filter Stop) se traga los clics fuera de los botones. Los de las bandas
## negras (fuera de los 480×270) no tocan ningún Control: los consume `_unhandled_input`
## (`is_action_type()` es true para los botones del ratón).
## Todo el texto lo escribe el juego con la fuente Gravity (no es de píxeles: se dibuja a la
## resolución de la pantalla, con filtro lineal).

signal abierto_cambio(abierto: bool)

enum Pagina { IMPORTANTES, INVENTARIO, MAPA, MISIONES, GUARDAR }

const NUM_PAGINAS := 5
const LIBRO_JSON := "res://assets/ui/libro/libro.json"
const NOMBRES_PAGINA: Array[StringName] = [&"importantes", &"inventario", &"mapa", &"misiones", &"guardar"]
## Lo que dura un aviso de página («Ya estás bien.», «¡Partida guardada!»).
const DURACION_AVISO := 1.6

## Arte de las páginas por pliego (pag_1, pag_2y3, pag_4y5) y de las pestañas, en el orden
## de `Pagina`. Las texturas fijas (tapa, marco, X) van directamente en sus nodos.
@export var pliegos: Array[Texture2D] = []
@export var pestanas_encendidas: Array[Texture2D] = []
@export var pestanas_apagadas: Array[Texture2D] = []

var abierto := false

var _pagina: Pagina = Pagina.INVENTARIO
var _en_pestanas := false
var _tiempo := 0.0
var _tiempo_aviso := 0.0

## Pantalla lógica del juego (display/window/size/viewport_*), leída en _ready.
var _pantalla := Vector2.ZERO

## Medidas de libro.json (px del lienzo) que hacen falta después de colocar los nodos.
var _pestana_x: Array[float] = []
var _pestana_y := Vector2(19, 11) # apagada, encendida
var _sel_desplazamiento := Vector2(-3, -4)

@onready var fondo: TextureRect = $Fondo
@onready var libro: Control = $Libro
@onready var pagina_arte: TextureRect = $Libro/Pagina
@onready var pestanas: Array[TextureButton] = [
	$Libro/Pestanas/Importantes, $Libro/Pestanas/Inventario, $Libro/Pestanas/Mapa,
	$Libro/Pestanas/Misiones, $Libro/Pestanas/Guardar,
]
@onready var salir: TextureButton = $Libro/Salir
@onready var seleccion: TextureRect = $Libro/Seleccion
## Contenido de cada página, en el orden de `Pagina`.
@onready var paginas: Array[PaginaLibro] = [
	$Libro/Contenido/Importantes, $Libro/Contenido/Inventario, $Libro/Contenido/Mapa,
	$Libro/Contenido/Misiones, $Libro/Contenido/Guardar,
]


func _ready() -> void:
	var ancho: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var alto: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	_pantalla = Vector2(ancho, alto)
	_leer_medidas()
	EstadoJuego.objetos_cambio.connect(func(_id: StringName, _n: int) -> void: _refrescar())
	EstadoJuego.misiones_cambio.connect(_refrescar)
	EstadoJuego.estado_restablecido.connect(_refrescar)
	get_window().size_changed.connect(_colocar)


## Coloca lo que mide tools/export_libro.lua en assets/ui/libro/libro.json. El tamaño de
## cada botón (pestañas, X, casillas) es su área de clic.
func _leer_medidas() -> void:
	var datos: Dictionary = (load(LIBRO_JSON) as JSON).data
	libro.size = _vector(datos.lienzo)
	_pestana_y = _vector(datos.pestana_y)
	for i in NUM_PAGINAS:
		var p: Array = datos.pestanas[i]
		assert(p[0] == String(NOMBRES_PAGINA[i]), "libro.json: pestañas en otro orden")
		var medidas := _numeros(p.slice(1))
		_pestana_x.append(medidas[0])
		pestanas[i].size = Vector2(medidas[1], medidas[2])
	var x := _rect(datos.salir)
	salir.position = x.position
	salir.size = x.size
	var sel := _numeros(datos.seleccion)
	_sel_desplazamiento = Vector2(sel[2], sel[3])
	for i in NUM_PAGINAS:
		var rejilla := paginas[i] as PaginaInventario
		if rejilla == null:
			continue
		var rects: Array[Rect2] = []
		for r: Variant in datos.casillas[String(NOMBRES_PAGINA[i])]:
			rects.append(_rect(r))
		rejilla.colocar(rects)


## Números de libro.json. El JSON solo da `Variant`: aquí se fija el tipo, una vez.
static func _numeros(valor: Variant) -> PackedFloat64Array:
	var lista: Array = valor
	return PackedFloat64Array(lista)


static func _vector(valor: Variant) -> Vector2:
	var n := _numeros(valor)
	return Vector2(n[0], n[1])


static func _rect(valor: Variant) -> Rect2:
	var n := _numeros(valor)
	return Rect2(n[0], n[1], n[2], n[3])


## Posición de `c` en píxeles del lienzo (sus contenedores dentro de `Libro` no se escalan).
func _posicion_en_libro(c: Control) -> Vector2:
	var pos := Vector2.ZERO
	var n := c
	while n != libro and n != null:
		pos += n.position
		n = n.get_parent_control()
	return pos


## Escala entera de pantalla para el libro y lo centra. Se llama al abrir y si cambia la
## ventana. Con el modo CANVAS_ITEMS una unidad lógica son `f` píxeles de pantalla.
func _colocar() -> void:
	if not abierto:
		return
	# Con escala entera y aspecto fijo, el juego ocupa _pantalla × f píxeles de la ventana
	# (lo demás son bandas negras, donde no se puede dibujar).
	var ventana := Vector2(get_window().size)
	var f := maxf(1.0, floorf(minf(ventana.x / _pantalla.x, ventana.y / _pantalla.y)))
	var area := _pantalla * f
	var k := maxf(1.0, floorf(minf(area.x / libro.size.x, area.y / libro.size.y)))
	var escala := k / f
	libro.scale = Vector2(escala, escala)
	# Esquina en un píxel entero de pantalla.
	libro.position = ((_pantalla - libro.size * escala) / 2.0 * f).round() / f


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
	for p in paginas:
		p.avisar("")
	Pantalla.modo_pintura(self, true)
	get_tree().paused = true
	visible = true
	_colocar()
	_refrescar()
	abierto_cambio.emit(true)
	return true


## También lo llama la X (señal `pressed` de `Salir`, conectada en la escena).
func cerrar() -> void:
	if not abierto:
		return
	abierto = false
	visible = false
	fondo.texture = null
	Pantalla.modo_pintura(self, false)
	get_tree().paused = false
	abierto_cambio.emit(false)


func _process(delta: float) -> void:
	if not abierto:
		return
	_tiempo += delta
	if _tiempo_aviso > 0.0:
		_tiempo_aviso -= delta
		if _tiempo_aviso <= 0.0:
			for p in paginas:
				p.avisar("")
			_refrescar()
	_animar()


## Teclado y mando (el ratón lo atienden los botones). Cerrado: solo abre con `inventario`.
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

## Va a la página `p` (si existe). `desde_izquierda`: se entra por su lado izquierdo
## (la primera columna) o por el derecho (la última), en la fila que se deja.
func _ir_a_pagina(p: int, desde_izquierda: bool) -> void:
	if p < 0 or p >= NUM_PAGINAS or p == _pagina:
		return
	var fila := paginas[_pagina].fila()
	_pagina = p as Pagina
	paginas[_pagina].entrar(fila, desde_izquierda)
	_refrescar()


func _mover(d: Vector2i) -> void:
	if _en_pestanas:
		if d.x != 0:
			_ir_a_pagina(_pagina + d.x, d.x > 0)
		elif d.y > 0:
			_en_pestanas = false
			_refrescar()
		return
	if paginas[_pagina].mover(d):
		_refrescar()
	elif d.x != 0:
		_ir_a_pagina(_pagina + d.x, d.x > 0)
	elif d.y < 0:
		_en_pestanas = true
		_refrescar()


func _confirmar() -> void:
	if _en_pestanas:
		_en_pestanas = false
		_refrescar()
		return
	paginas[_pagina].confirmar()


## Señal `usar_objeto` de las páginas con rejilla: solo se usan los consumibles.
func _usar(id: StringName) -> void:
	var o := EstadoJuego.objeto(id) if id != &"" else null
	if o == null or o.tipo != Objeto.Tipo.CONSUMIBLE:
		return
	var game := Game.actual(self)
	var jugador := game.jugador if game else null
	if jugador == null:
		return
	if o.cura > 0 and jugador.vida.vida >= jugador.vida.vida_max:
		_avisar(Pagina.INVENTARIO, "Ya estás bien.")
		return
	if not EstadoJuego.gastar_objeto(id):
		return
	# Se cierra el libro para ver a Leonidas comer.
	cerrar()
	jugador.comer(o)


## Señal `pide_guardar` de la página Guardar.
func _guardar() -> void:
	var game := Game.actual(self)
	var hecho := game != null and EstadoJuego.guardar(game.datos_guardado())
	_avisar(Pagina.GUARDAR, "¡Partida guardada!" if hecho else "No se pudo guardar.")


func _avisar(p: Pagina, texto: String) -> void:
	paginas[p].avisar(texto)
	_tiempo_aviso = DURACION_AVISO
	_refrescar()


# --- Ratón (señales de los botones, conectadas en la escena) ---------------------------

func _on_pestana_pressed(p: Pagina) -> void:
	_ir_a_pagina(p, true)
	_en_pestanas = false
	_refrescar()


## Una página quiere el cursor (clic en una de sus casillas o en Guardar).
func _on_pagina_cursor_pedido(pagina: PaginaLibro) -> void:
	_pagina = paginas.find(pagina) as Pagina
	_en_pestanas = false
	_refrescar()


# --- Dibujo ---------------------------------------------------------------------------

## Par de páginas que se ve (índice de `pliegos`).
func _pliego(p: Pagina) -> int:
	return [0, 1, 1, 2, 2][p]


func _pagina_visible(p: Pagina) -> bool:
	return _pliego(p) == _pliego(_pagina)


func _refrescar() -> void:
	if not is_node_ready():
		return
	pagina_arte.texture = pliegos[_pliego(_pagina)]
	for i in NUM_PAGINAS:
		var activa := i == _pagina
		pestanas[i].texture_normal = pestanas_encendidas[i] if activa else pestanas_apagadas[i]
		pestanas[i].position = Vector2(_pestana_x[i], _pestana_y.y if activa else _pestana_y.x)
		pestanas[i].modulate = Color.WHITE
	for i in NUM_PAGINAS:
		var p := paginas[i]
		p.visible = _pagina_visible(i)
		p.con_cursor = i == _pagina and not _en_pestanas
		p.refrescar()
	# Marco de selección: en la casilla elegida de la página con el cursor.
	var marcada := paginas[_pagina].casilla_marcada() if not _en_pestanas else null
	seleccion.visible = marcada != null
	if marcada:
		seleccion.position = _posicion_en_libro(marcada) + _sel_desplazamiento


func _animar() -> void:
	# La pestaña elegida parpadea un poco cuando el cursor está en las pestañas.
	if _en_pestanas:
		var on := fmod(_tiempo, 0.6) < 0.4
		pestanas[_pagina].modulate = Color.WHITE if on else Color(0.75, 0.75, 0.75)
	for p in paginas:
		p.animar(_tiempo)
