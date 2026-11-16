class_name MenuPausa
extends CanvasLayer
## Menú de pausa: Continuar, Controles, Filtro de daltonismo y Salir.
## Va dentro de `game.tscn`. La interfaz (paneles, botones, textos y tema) está
## en `scenes/ui/menu_pausa.tscn` y se edita desde el editor; los botones llaman
## a este script con señales conectadas en la escena.
##
## Se abre y cierra con la acción `pausa` (Esc / Start). Abierto =
## `get_tree().paused`. En la pantalla de controles, `pausa` o E/J vuelven al menú.
## El Esc se lee en `_unhandled_input`. Esta escena (dentro de Game) lo recibe antes que
## los autoload `Libro`, `Tienda` y `Dialogos`: con alguno de ellos abierto la pausa ni se
## abre ni consume el evento (`_puede_abrir`), así que sigue hasta él y es él quien se
## cierra con ese Esc.
##
## «Filtro de daltonismo» todavía no hace nada (pendiente).
## «Salir» vuelve al menú principal (sin guardar: se guarda desde el libro).

const MARCA := "> "

var abierto := false

var _viendo_controles := false

@onready var _panel_menu: Control = %PanelMenu
@onready var _panel_controles: Control = %PanelControles
@onready var _botones: VBoxContainer = %Botones
@onready var _boton_continuar: Button = %Continuar
@onready var _boton_controles: Button = %Controles


func _ready() -> void:
	visible = false
	for b: Button in _botones.get_children():
		b.set_meta(&"texto", b.text)
		b.focus_entered.connect(_actualizar_marcas)
		b.mouse_entered.connect(b.grab_focus)


func _actualizar_marcas() -> void:
	var foco := get_viewport().gui_get_focus_owner()
	for b: Button in _botones.get_children():
		var base: String = b.get_meta(&"texto")
		b.text = (MARCA + base) if b == foco else base


## ¿Se puede abrir ahora? No con el libro, la tienda o un diálogo abiertos, ni
## durante un cambio de zona.
func _puede_abrir() -> bool:
	if get_tree().paused:
		return false
	if Libro.abierto or Tienda.abierto or Dialogos.abierto:
		return false
	var game := get_tree().get_first_node_in_group(&"game") as Game
	return game != null and not game.cambiando()


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
	if not abierto:
		return
	if not (event.is_action_pressed(&"interactuar") or event.is_action_pressed(&"atacar")):
		return
	get_viewport().set_input_as_handled()
	if _viendo_controles:
		_volver_de_controles()
		return
	var b := get_viewport().gui_get_focus_owner() as Button
	if b:
		b.pressed.emit()


func _abrir() -> void:
	abierto = true
	_viendo_controles = false
	_panel_menu.visible = true
	_panel_controles.visible = false
	visible = true
	get_tree().paused = true
	_boton_continuar.grab_focus()
	_actualizar_marcas()


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
	pass # pendiente: de momento no muestra nada


func _salir() -> void:
	abierto = false
	get_tree().paused = false
	var escena_principal: String = ProjectSettings.get_setting("application/run/main_scene")
	get_tree().change_scene_to_file(escena_principal)
