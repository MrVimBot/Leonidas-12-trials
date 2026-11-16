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
## Bloquea al jugador mientras está abierto (motivo &"tienda"). Las monedas se ven en el HUD.
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
	nombre.text = CajaDialogo.adaptar_a_fuente(tienda.nombre_vendedor)
	caja.visible = true
	var jugador := _jugador()
	if jugador:
		jugador.bloquear(&"tienda")
	_refrescar()
	await cerrado


func _process(delta: float) -> void:
	if not abierto:
		return
	if _tiempo_aviso > 0.0:
		_tiempo_aviso -= delta
		if _tiempo_aviso <= 0.0:
			_aviso = ""
			_refrescar()


## Mientras está abierta se consume toda pulsación de una acción, para que nadie más la
## vea. Orden de reparto: la escena actual la recibe antes (el Jugador, BLOQUEADO, no la
## toca; la pausa no se abre con la tienda abierta, así que Esc llega aquí y cierra);
## después esta tienda y luego `Dialogos`. Así la pulsación que cierra el saludo la
## consume la caja (la tienda aún no estaba abierta) y no compra, y la que cierra la
## tienda no avanza la despedida que se abre en ese mismo momento.
func _unhandled_input(event: InputEvent) -> void:
	if not abierto:
		return
	if _pulsada(event, &"mover_arriba"):
		_mover(-1)
	elif _pulsada(event, &"mover_abajo"):
		_mover(1)
	elif event.is_action_pressed(&"interactuar") or event.is_action_pressed(&"atacar"):
		_elegir()
	elif event.is_action_pressed(&"pirueta") or event.is_action_pressed(&"ui_cancel"):
		_cerrar()
	if event.is_action_type():
		get_viewport().set_input_as_handled()


## ¿`event` empieza a pulsar `accion`? Para las de mover, que también van con el stick:
## cada movimiento del stick más allá de la zona muerta es un evento "pulsado", así que
## solo cuenta el primero (`is_action_just_pressed_by_event`), como un botón.
static func _pulsada(event: InputEvent, accion: StringName) -> bool:
	return event.is_action_pressed(accion) and Input.is_action_just_pressed_by_event(accion, event)


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
	# Se emite antes de quitar el motivo: quien esperaba `cerrado` sigue en el acto y abre
	# la despedida (motivo &"dialogo"), así el jugador no pasa por NORMAL entre medias.
	# La pulsación ya está consumida.
	cerrado.emit()
	if not abierto:
		var jugador := _jugador()
		if jugador:
			jugador.desbloquear(&"tienda")


func _jugador() -> Jugador:
	return get_tree().get_first_node_in_group(&"jugador") as Jugador
