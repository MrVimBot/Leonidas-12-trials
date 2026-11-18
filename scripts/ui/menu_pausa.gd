class_name MenuPausa
extends CanvasLayer
## Menú de pausa: Continuar, Controles, Daltonismo y Salir.
## Va dentro de `game.tscn`. La interfaz (paneles, botones, textos y tema) está
## en `scenes/ui/menu_pausa.tscn` y se edita desde el editor; los botones llaman
## a este script con señales conectadas en la escena.
##
## Se abre y cierra con la acción `pausa` (Esc / Start). Abierto =
## `get_tree().paused`. En la pantalla de controles, `pausa` o `ui_accept` (Enter, Espacio, E/J) vuelven al menú.
## El Esc se lee en `_unhandled_input`. Esta escena (dentro de Game) lo recibe antes que
## los autoload `Libro`, `Tienda` y `Dialogos`: con alguno de ellos abierto la pausa ni se
## abre ni consume el evento (`_puede_abrir`), así que sigue hasta él y es él quien se
## cierra con ese Esc.
##
## «Daltonismo» pasa al siguiente filtro del autoload `Daltonismo` (No → Protanopía →
## Deuteranopía) y el botón muestra el elegido: «Daltonismo: No».
## «Salir» vuelve al menú principal (sin guardar: se guarda desde el libro).

var abierto := false

var _viendo_controles := false

@onready var _panel_menu: Control = %PanelMenu
@onready var _panel_controles: Control = %PanelControles
@onready var _botones: BotonesConMarca = %Botones
@onready var _boton_continuar: Button = %Continuar
@onready var _boton_controles: Button = %Controles
@onready var _boton_daltonismo: Button = %Daltonismo


func _ready() -> void:
	visible = false
	# El texto de la escena («Daltonismo») es el rótulo; se le añade el filtro elegido.
	_boton_daltonismo.set_meta(&"rotulo", _boton_daltonismo.text)
	_actualizar_daltonismo()


## ¿Se puede abrir ahora? No con el libro, la tienda o un diálogo abiertos, ni
## durante un cambio de zona.
func _puede_abrir() -> bool:
	if get_tree().paused:
		return false
	if Libro.abierto or Tienda.abierto or Dialogos.abierto:
		return false
	var game := Game.actual(self)
	return game != null and not game.cambiando


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pausa"):
		if abierto:
			get_viewport().set_input_as_handled()
			if _viendo_controles:
				_volver_de_controles()
			else:
				_cerrar()
		elif _puede_abrir():
			get_viewport().set_input_as_handled()
			_abrir()
		return
	# Con el menú abierto, los botones con foco reciben `ui_accept` por la GUI (Enter, Espacio, E,
	# J...). Solo la pantalla de controles, que no tiene botones, lo lee aquí para volver.
	if abierto and _viendo_controles and event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_volver_de_controles()


func _abrir() -> void:
	abierto = true
	_viendo_controles = false
	_panel_menu.visible = true
	_panel_controles.visible = false
	visible = true
	get_tree().paused = true
	_boton_continuar.grab_focus()
	_botones.actualizar_marcas()


func _cerrar() -> void:
	abierto = false
	visible = false
	get_tree().paused = false


func _mostrar_controles() -> void:
	_viendo_controles = true
	_panel_menu.visible = false
	_panel_controles.visible = true


func _volver_de_controles() -> void:
	_viendo_controles = false
	_panel_controles.visible = false
	_panel_menu.visible = true
	_boton_controles.grab_focus()


func _filtro_daltonismo() -> void:
	Daltonismo.siguiente()
	_actualizar_daltonismo()
	_botones.actualizar_marcas()


## BotonesConMarca pinta el texto guardado en la meta `texto` (con o sin "> ").
func _actualizar_daltonismo() -> void:
	var rotulo: String = _boton_daltonismo.get_meta(&"rotulo")
	var texto := "%s: %s" % [rotulo, Daltonismo.nombre()]
	_boton_daltonismo.set_meta(&"texto", texto)
	_boton_daltonismo.text = texto


func _salir() -> void:
	abierto = false
	get_tree().paused = false
	var escena_principal: String = ProjectSettings.get_setting("application/run/main_scene")
	get_tree().change_scene_to_file(escena_principal)
