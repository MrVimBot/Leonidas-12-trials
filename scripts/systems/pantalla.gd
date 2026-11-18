class_name Pantalla
extends RefCounted
## Modo de escala de la ventana. El juego va en "viewport" (480×270 a píxel entero, como
## fija project.godot: display/window/stretch/mode); las pinturas, la carta y el libro
## se dibujan a la resolución real con "canvas_items".
## Las zonas con `Zona.pintada` (nivel 2) también van en "canvas_items".
## Sin estado: no se recuerda "el modo anterior", así que un fallo en una pantalla no se
## propaga a la siguiente. Quien cierra una pantalla dentro de la partida (libro, Game Over)
## usa `restaurar()`, que deduce el modo de la zona actual.

## Pone la ventana de `nodo` en modo pintura (`activo`) o en el modo normal del juego.
static func modo_pintura(nodo: Node, activo: bool) -> void:
	nodo.get_window().content_scale_mode = (
		Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if activo else Window.CONTENT_SCALE_MODE_VIEWPORT)


## Pone la ventana en el modo que corresponde a lo que hay en pantalla: el de la zona actual
## de Game (pintada → CANVAS_ITEMS) o el normal si no hay Game (menús, cinemática).
static func restaurar(nodo: Node) -> void:
	var game := Game.actual(nodo)
	modo_pintura(nodo, game != null and game.zona_actual != null and game.zona_actual.pintada)


## Escala y centra `control` (arte de `control.size` px, en un CanvasLayer y en modo pintura)
## para que cada píxel del arte ocupe un número ENTERO de píxeles de pantalla, el mayor
## que quepa en la zona del juego. Devuelve ese número (k). Lo usan el libro y el Game Over.
## Con escala entera y aspecto fijo, el juego ocupa pantalla × f píxeles de la ventana (lo
## demás son bandas negras, donde no se puede dibujar); una unidad lógica son f píxeles.
static func ajustar_a_pixel_entero(control: Control) -> float:
	var ancho: float = ProjectSettings.get_setting("display/window/size/viewport_width")
	var alto: float = ProjectSettings.get_setting("display/window/size/viewport_height")
	var pantalla := Vector2(ancho, alto)
	var ventana := Vector2(control.get_window().size)
	var f := maxf(1.0, floorf(minf(ventana.x / pantalla.x, ventana.y / pantalla.y)))
	var area := pantalla * f
	var k := maxf(1.0, floorf(minf(area.x / control.size.x, area.y / control.size.y)))
	var escala := k / f
	control.scale = Vector2(escala, escala)
	# Esquina en un píxel entero de pantalla.
	control.position = ((pantalla - control.size * escala) / 2.0 * f).round() / f
	return k
