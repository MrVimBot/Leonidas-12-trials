class_name Pantalla
extends RefCounted
## Modo de escala de la ventana. El juego va en "viewport" (480×270 a píxel entero, como
## fija project.godot: display/window/stretch/mode); las pinturas, la carta y el libro
## se dibujan a la resolución real con "canvas_items".
## Sin estado: no se recuerda "el modo anterior", así que un fallo en una pantalla no se
## propaga a la siguiente. `Game._ready()` lo vuelve a poner por si acaso.

## Pone la ventana de `nodo` en modo pintura (`activo`) o en el modo normal del juego.
static func modo_pintura(nodo: Node, activo: bool) -> void:
	nodo.get_window().content_scale_mode = (
		Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if activo else Window.CONTENT_SCALE_MODE_VIEWPORT)
