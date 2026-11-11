class_name MenuTienda
extends CanvasLayer
## Menú de compra de una tienda. Es un AUTOLOAD llamado `Tienda`
## (scenes/ui/menu_tienda.tscn). Lo abre ComponenteTienda:
##
##   await Tienda.abrir(tienda)   # espera a que el jugador salga
##
## Usa la caja de diálogo de la artista (mismo sitio que CajaDialogo), con el nombre
## del vendedor en la pestaña. Texto: 2 renglones de lista ("> icono Nombre (cuántos
## tienes)  precio", y "Salir"; se desplaza si hay más artículos) y 1 renglón de
## información (descripción del elegido o el aviso de la última compra).
## Controles: arriba/abajo eligen · E/J compran (o salen en "Salir") · Espacio/K/Esc salen.
## Bloquea al jugador mientras está abierto. Las monedas se ven en el HUD.
## Diseño PROVISIONAL: no hay maqueta de la tienda en los PDF (ver guia_interfaz.md).

signal cerrado

const FILAS_VISIBLES := 2
const ALTO_FILA := 16
const MARCA := "> "
## Segundos que se ve un aviso ("¡Gracias!", "No te alcanza") antes de volver a la descripción.
const DURACION_AVISO := 1.4

@export var color_aviso := Color("8a1c12")

var abierto := false

var _tienda: ComponenteTienda
var _indice := 0
var _desplazamiento := 0
var _frame_apertura := -1
var _aviso := ""
var _tiempo_aviso := 0.0
var _filas: Array[Dictionary] = []

@onready var caja: Control = $Caja
@onready var nombre: Label = $Caja/Nombre
@onready var lista: Control = $Caja/Lista
@onready var info: Label = $Caja/Info
@onready var _color_info: Color = info.get_theme_color(&"font_color")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	caja.visible = false
	# Cada fila: "> " · icono · nombre (cuántos tienes) · precio a la derecha.
	for i in FILAS_VISIBLES:
		var y := i * ALTO_FILA
		var marca := _etiqueta(Vector2(0, y), 18)
		var icono := TextureRect.new()
		icono.position = Vector2(18, y + 3)
		icono.size = Vector2(10, 10)
		icono.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lista.add_child(icono)
		var texto := _etiqueta(Vector2(30, y), 150)
		var precio := _etiqueta(Vector2(180, y), 60)
		precio.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_filas.append({ "marca": marca, "icono": icono, "texto": texto, "precio": precio })


func _etiqueta(pos: Vector2, ancho: float) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(ancho, ALTO_FILA)
	l.clip_text = true
	lista.add_child(l)
	return l


## Abre el menú con los artículos de `tienda` y espera a que se cierre.
func abrir(tienda: ComponenteTienda) -> void:
	if abierto or tienda == null:
		return
	_tienda = tienda
	_indice = 0
	_desplazamiento = 0
	_aviso = ""
	abierto = true
	_frame_apertura = Engine.get_process_frames()
	nombre.text = CajaDialogo.adaptar_a_fuente(tienda.nombre_vendedor)
	caja.visible = true
	_bloquear_jugador(true)
	_refrescar()
	await cerrado


func _process(delta: float) -> void:
	if not abierto:
		return
	# Otro sistema (el cierre diferido de CajaDialogo) puede haber desbloqueado al jugador.
	_bloquear_jugador(true)
	if _tiempo_aviso > 0.0:
		_tiempo_aviso -= delta
		if _tiempo_aviso <= 0.0:
			_aviso = ""
			_refrescar()
	# La pulsación que cerró el saludo no debe comprar nada.
	if Engine.get_process_frames() <= _frame_apertura + 1:
		return
	if Input.is_action_just_pressed(&"mover_arriba"):
		_mover(-1)
	elif Input.is_action_just_pressed(&"mover_abajo"):
		_mover(1)
	elif Input.is_action_just_pressed(&"interactuar") or Input.is_action_just_pressed(&"atacar"):
		_elegir()
	elif Input.is_action_just_pressed(&"pirueta") or Input.is_action_just_pressed(&"ui_cancel"):
		_cerrar()


## Número de opciones: los artículos + "Salir".
func _opciones() -> int:
	return _tienda.articulos.size() + 1


func _mover(paso: int) -> void:
	_indice = wrapi(_indice + paso, 0, _opciones())
	if _indice < _desplazamiento:
		_desplazamiento = _indice
	elif _indice >= _desplazamiento + FILAS_VISIBLES:
		_desplazamiento = _indice - FILAS_VISIBLES + 1
	_aviso = ""
	_refrescar()


func _elegir() -> void:
	if _indice >= _tienda.articulos.size():
		_cerrar()
		return
	var articulo := _tienda.articulos[_indice]
	match _tienda.comprar(articulo):
		ComponenteTienda.Resultado.COMPRADO:
			_avisar("¡Gracias!")
		ComponenteTienda.Resultado.SIN_MONEDAS:
			_avisar("No te alcanza.")
		ComponenteTienda.Resultado.LLENO:
			_avisar("No puedes llevar más.")


func _avisar(t: String) -> void:
	_aviso = t
	_tiempo_aviso = DURACION_AVISO
	_refrescar()


func _refrescar() -> void:
	var n := _tienda.articulos.size()
	for i in FILAS_VISIBLES:
		var fila := _filas[i]
		var opcion := _desplazamiento + i
		fila.marca.text = MARCA if opcion == _indice else ""
		fila.icono.texture = null
		fila.texto.text = ""
		fila.precio.text = ""
		if opcion < n:
			var a := _tienda.articulos[opcion]
			fila.icono.texture = a.icono
			fila.texto.text = CajaDialogo.adaptar_a_fuente("%s (%d)" % [a.nombre, ComponenteTienda.cantidad(a)])
			fila.precio.text = "%d mon." % a.precio
		elif opcion == n:
			fila.texto.text = "Salir"
	if not _aviso.is_empty():
		info.text = CajaDialogo.adaptar_a_fuente(_aviso)
		info.add_theme_color_override(&"font_color", color_aviso)
	else:
		info.add_theme_color_override(&"font_color", _color_info)
		info.text = CajaDialogo.adaptar_a_fuente(
			_tienda.articulos[_indice].descripcion if _indice < n else "Hasta luego.")


func _cerrar() -> void:
	abierto = false
	caja.visible = false
	_tienda = null
	cerrado.emit()
	# Como CajaDialogo: que la misma pulsación no vuelva a abrir la conversación.
	await get_tree().process_frame
	await get_tree().physics_frame
	if not abierto and not Dialogos.abierto:
		_bloquear_jugador(false)


func _bloquear_jugador(bloquear: bool) -> void:
	var jugador := get_tree().get_first_node_in_group(&"jugador") as Jugador
	if jugador == null:
		return
	var esta_bloqueado := jugador.estado == Jugador.Estado.BLOQUEADO
	if bloquear != esta_bloqueado:
		jugador.set_bloqueado(bloquear)
