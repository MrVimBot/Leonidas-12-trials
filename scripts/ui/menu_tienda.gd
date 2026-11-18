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

## Justo después de abrirse (para que, p. ej., las burbujas de los NPC se escondan).
signal se_abrio
signal cerrado

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
## Las filas de la lista (hijos de Caja/Lista en la escena). Si hay más artículos que filas,
## la lista se desplaza.
var _filas: Array[Fila] = []

@onready var caja: Control = $Caja
@onready var nombre: Label = $Caja/Nombre
@onready var lista: Control = $Caja/Lista
@onready var info: Label = $Caja/Info
@onready var _color_info: Color = info.get_theme_color(&"font_color")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	caja.visible = false
	# Cada fila de la escena: "> " · icono · nombre (cuántos tienes) · precio a la derecha.
	for nodo in lista.get_children():
		var fila := Fila.new()
		fila.marca = nodo.get_node(^"Marca") as Label
		fila.icono = nodo.get_node(^"Icono") as TextureRect
		fila.texto = nodo.get_node(^"Texto") as Label
		fila.precio = nodo.get_node(^"Precio") as Label
		_filas.append(fila)


## Abre el menú con los artículos de `tienda` y espera a que se cierre.
func abrir(tienda: ComponenteTienda) -> void:
	if abierto or tienda == null:
		return
	_tienda = tienda
	_indice = 0
	_desplazamiento = 0
	_aviso = ""
	abierto = true
	se_abrio.emit()
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
	SonidosUI.mover()
	if _indice < _desplazamiento:
		_desplazamiento = _indice
	elif _indice >= _desplazamiento + _filas.size():
		_desplazamiento = _indice - _filas.size() + 1
	_aviso = ""
	_refrescar()


func _elegir() -> void:
	if _indice >= _tienda.articulos.size():
		_cerrar()
		return
	var articulo := _tienda.articulos[_indice]
	match _tienda.comprar(articulo):
		ComponenteTienda.Resultado.COMPRADO:
			SonidosUI.aceptar()
			_avisar("¡Gracias!")
		ComponenteTienda.Resultado.SIN_MONEDAS:
			SonidosUI.volver()
			_avisar("No te alcanza.")
		ComponenteTienda.Resultado.LLENO:
			SonidosUI.volver()
			_avisar("No puedes llevar más.")


func _avisar(t: String) -> void:
	_aviso = t
	_tiempo_aviso = DURACION_AVISO
	_refrescar()


func _refrescar() -> void:
	var n := _tienda.articulos.size()
	for i in _filas.size():
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
	SonidosUI.volver()
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
	return Jugador.actual(self)


## Los cuatro nodos de una fila de la lista.
class Fila:
	var marca: Label
	var icono: TextureRect
	var texto: Label
	var precio: Label
