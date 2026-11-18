class_name BotonesConMarca
extends BoxContainer
## Contenedor (vertical u horizontal) de los botones de un menú (principal, pausa, Game Over) que pone la marca "> " delante
## del botón con el foco. Se asigna como script del VBoxContainer/HBoxContainer que tiene los botones.
##
## En `_ready` guarda el texto de cada botón y conecta `focus_entered` (cambia la marca) y
## `mouse_entered` (pasar el ratón por encima = seleccionar). Quien abre el menú y da el
## foco con `grab_focus()` desde fuera de la señal debe llamar a `actualizar_marcas()`.

const MARCA := "> "

## Último botón con foco de este menú: el sonido de cambio solo suena si el foco pasa de un
## botón a otro (no al abrir el menú, cuando se le da el foco por primera vez).
var _ultimo_foco: Button


func _ready() -> void:
	for b: Button in get_children():
		b.set_meta(&"texto", b.text)
		b.focus_entered.connect(_al_recibir_foco.bind(b))
		b.mouse_entered.connect(b.grab_focus)
		b.pressed.connect(SonidosUI.aceptar)
	visibility_changed.connect(_al_cambiar_visibilidad)


func _al_recibir_foco(boton: Button) -> void:
	if _ultimo_foco != null and _ultimo_foco != boton:
		SonidosUI.mover()
	_ultimo_foco = boton
	actualizar_marcas()


## Al cerrarse el menú se olvida el foco: al reabrirlo no suena el primer botón.
func _al_cambiar_visibilidad() -> void:
	if not is_visible_in_tree():
		_ultimo_foco = null


## Pone "> " delante del botón que tiene el foco y la quita de los demás.
func actualizar_marcas() -> void:
	var foco := get_viewport().gui_get_focus_owner()
	for b: Button in get_children():
		var base: String = b.get_meta(&"texto")
		b.text = (MARCA + base) if b == foco else base
