class_name BotonesConMarca
extends VBoxContainer
## Contenedor de los botones de un menú (principal, pausa) que pone la marca "> " delante
## del botón con el foco. Se asigna como script del VBoxContainer que tiene los botones.
##
## En `_ready` guarda el texto de cada botón y conecta `focus_entered` (cambia la marca) y
## `mouse_entered` (pasar el ratón por encima = seleccionar). Quien abre el menú y da el
## foco con `grab_focus()` desde fuera de la señal debe llamar a `actualizar_marcas()`.

const MARCA := "> "


func _ready() -> void:
	for b: Button in get_children():
		b.set_meta(&"texto", b.text)
		b.focus_entered.connect(actualizar_marcas)
		b.mouse_entered.connect(b.grab_focus)


## Pone "> " delante del botón que tiene el foco y la quita de los demás.
func actualizar_marcas() -> void:
	var foco := get_viewport().gui_get_focus_owner()
	for b: Button in get_children():
		var base: String = b.get_meta(&"texto")
		b.text = (MARCA + base) if b == foco else base
