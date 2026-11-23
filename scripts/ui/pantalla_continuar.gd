class_name PantallaContinuar
extends Control
## Pantalla de «Continuar» del menú principal (maqueta de la artista:
## docs/reference/menu/continuar_con_partida.jpg). Enseña la partida guardada antes de
## cargarla: arriba retrato, «Partida 1», tiempo jugado, vida y monedas; abajo los jefes
## vencidos (laureles) y el inventario (consumibles).
## Hay UNA sola partida (decidido el 2026-11-23): la tarjeta de arriba es el botón que la
## carga y la flecha de abajo vuelve al menú.
##
## `abrir()` ya lee la partida con `EstadoJuego.cargar()` (no escribe nada): la pantalla
## enseña lo que hay en EstadoJuego y, si se continúa, Game empieza en `lugar_cargado`.
## Si se vuelve al menú, el estado se queda cargado sin hacer daño: «Jugar» llama a
## `EstadoJuego.reiniciar()`.
##
## ESCALA: el arte (268×149) no cabe a escala entera en 480×270, así que, como el libro y el
## Game Over, `Lienzo` se dibuja en modo pintura (lo pone el menú principal) a la mayor
## escala entera de pantalla (`Pantalla.ajustar_a_pixel_entero`): ×7 en 1920×1080.
## Todas las posiciones de la escena son píxeles del arte.
##
## Entrada: la GUI pulsa el botón con foco con `ui_accept`; arriba/abajo cambian entre la
## tarjeta y la flecha (vecinos de foco en la escena); `ui_cancel` y `pausa` vuelven.
##
## ARTE PROVISIONAL (`assets/ui/provisional/continuar/`, recortado del JPG con
## `tools/menu_continuar/recortar_maqueta.py`): sustituir por el .aseprite de la artista.
## Los trofeos dentro de los laureles son los iconos de los trofeos (también provisionales):
## la maqueta no dice cómo se ve un jefe vencido.

signal continuar_pedido
signal volver_pedido

## Vida de Leonidas sin corazones extra, en cuartos (la de `jugador.tscn`). Hace falta para
## dibujar los corazones vacíos: la partida guarda la vida, no el máximo.
@export var vida_base := 12
## Laureles de los jefes, en orden de la historia: bandera de `EstadoJuego.PROGRESO` que dice
## que está vencido → icono que se pone dentro. Los que sobran se quedan vacíos.
@export var trofeos: Dictionary[StringName, Texture2D] = {}

var abierta := false

@onready var _lienzo: Control = %Lienzo
@onready var _tarjeta: Button = %Tarjeta
@onready var _volver: TextureButton = %Volver
@onready var _titulo: Label = %Titulo
@onready var _tiempo: Label = %Tiempo
@onready var _corazones: FilaCorazones = %Corazones
@onready var _monedas: Label = %Monedas
@onready var _laureles: Control = %Laureles
@onready var _casillas: Control = %Casillas


func _ready() -> void:
	visible = false
	get_window().size_changed.connect(_colocar)


## Lee la partida y abre la pantalla. Devuelve false (y no se abre) si no se pudo leer.
func abrir() -> bool:
	if not EstadoJuego.cargar():
		return false
	_rellenar()
	abierta = true
	visible = true
	_activar(true)
	_colocar()
	_tarjeta.grab_focus()
	return true


func cerrar() -> void:
	abierta = false
	visible = false


func _rellenar() -> void:
	_tiempo.text = "Tiempo jugado: %s" % EstadoJuego.tiempo_texto()
	var vida_max := vida_base + ComponenteVida.CUARTOS_POR_CORAZON * EstadoJuego.corazones_extra
	var lugar := EstadoJuego.lugar_cargado
	var vida := lugar.vida if lugar and lugar.vida >= 0 else vida_max
	_corazones.mostrar(mini(vida, vida_max), vida_max)
	_monedas.text = str(EstadoJuego.monedas)
	_poner_trofeos()
	_poner_inventario()


func _poner_trofeos() -> void:
	var banderas := trofeos.keys()
	for i in _laureles.get_child_count():
		var icono := _laureles.get_child(i).get_child(0) as TextureRect
		icono.texture = null
		if i < banderas.size() and EstadoJuego.get(banderas[i]):
			icono.texture = trofeos[banderas[i]]


func _poner_inventario() -> void:
	var ids := EstadoJuego.objetos_de_tipo(Objeto.Tipo.CONSUMIBLE)
	for i in _casillas.get_child_count():
		var casilla := _casillas.get_child(i) as TextureRect
		var cantidad := casilla.get_child(0) as Label
		var objeto := EstadoJuego.objeto(ids[i]) if i < ids.size() else null
		casilla.texture = objeto.icono if objeto else null
		var n := EstadoJuego.cantidad(ids[i]) if objeto else 0
		cantidad.text = str(n) if objeto and objeto.maximo > 1 else ""


func _colocar() -> void:
	if visible:
		Pantalla.ajustar_a_pixel_entero(_lienzo)


func _continuar() -> void:
	if not abierta:
		return
	_activar(false)
	SonidosUI.aceptar()
	continuar_pedido.emit()


func _volver_al_menu() -> void:
	if not abierta:
		return
	SonidosUI.volver()
	cerrar()
	volver_pedido.emit()


func _activar(si: bool) -> void:
	for b: BaseButton in [_tarjeta, _volver]:
		b.disabled = not si
		b.focus_mode = Control.FOCUS_ALL if si else Control.FOCUS_NONE


func _unhandled_input(event: InputEvent) -> void:
	if not abierta or _tarjeta.disabled:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pausa"):
		get_viewport().set_input_as_handled()
		_volver_al_menu()
