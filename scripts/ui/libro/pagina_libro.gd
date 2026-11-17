class_name PaginaLibro
extends Control
## Base de las páginas del libro: el script de cada nodo `Libro/Contenido/<Pagina>` de
## scenes/ui/menu_libro.tscn hereda de esta clase. El coordinador (`MenuLibro`,
## scripts/ui/menu_libro.gd) decide qué página tiene el cursor, las enseña u oculta y les
## reparte la entrada de teclado/mando; cada página solo pinta sus datos, mueve su propio
## cursor y avisa con señales de lo que no le toca hacer (usar un objeto, guardar).
##
## Interfaz (todo es opcional: por defecto no hace nada):
##   refrescar()                   vuelve a leer EstadoJuego y lo pinta. El coordinador
##                                 pone `con_cursor` justo antes.
##   animar(tiempo)                cada fotograma con el libro abierto (parpadeos).
##   mover(d) -> bool              flecha con el cursor en la página: true = el movimiento
##                                 se quedó dentro; false = sale (d.x → página vecina,
##                                 d.y < 0 → pestañas; el coordinador lo resuelve).
##   confirmar()                   E/J con el cursor en la página.
##   entrar(fila, desde_izquierda) el cursor llega desde la página vecina.
##   fila() -> int                 fila del cursor (para entrar en la vecina por la misma).
##   avisar(texto)                 mensaje temporal de la página ("" = borrarlo).
##   casilla_marcada() -> Control  dónde va el marco de selección (null = sin marco).
## Señales hacia el coordinador (conectadas en la escena): `cursor_pedido` aquí; las
## propias de cada página (`usar_objeto`, `pide_guardar`) en su script.

## Un clic del ratón quiere el cursor en esta página (el coordinador la hace la actual).
## La emiten las páginas hijas con botones; aquí no, de ahí el aviso silenciado.
@warning_ignore("unused_signal")
signal cursor_pedido(pagina: PaginaLibro)

## El cursor está en esta página y no en las pestañas. Lo pone el coordinador.
var con_cursor := false


func refrescar() -> void:
	pass


func animar(_tiempo: float) -> void:
	pass


func mover(_d: Vector2i) -> bool:
	return false


func confirmar() -> void:
	pass


func entrar(_fila: int, _desde_izquierda: bool) -> void:
	pass


func fila() -> int:
	return 0


func avisar(_texto: String) -> void:
	pass


func casilla_marcada() -> Control:
	return null
