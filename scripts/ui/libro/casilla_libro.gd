class_name CasillaLibro
extends TextureButton
## Una casilla del libro (páginas Objetos Importantes e Inventario): el icono del objeto
## y, si se pueden llevar varios, cuántos hay. La escena (scenes/ui/libro/casilla_libro.tscn)
## mide 34×34, pero el libro la coloca y le da el tamaño de libro.json
## (`PaginaInventario.colocar`); los datos se los pasa con `mostrar()`.
## Es un TextureButton SIN texturas (no dibuja nada propio: la casilla está pintada en el
## arte de la página) para que el clic llegue por la señal `pressed`, que conecta la
## escena del libro. Actúa al pulsar y nunca toma el foco (el libro lleva su propio cursor).

## La casilla suelta (la del objeto elegido) no enseña la cantidad.
@export var con_cantidad := true

@onready var icono: TextureRect = %Icono
@onready var cantidad: Label = %Cantidad


func _ready() -> void:
	cantidad.visible = con_cantidad


## Enseña `objeto` (null = casilla vacía). `n` (cuántos hay) solo sale si se pueden
## llevar varios (`Objeto.maximo` > 1).
func mostrar(objeto: Objeto, n: int) -> void:
	_poner_icono(objeto.icono if objeto else null)
	cantidad.text = str(n) if objeto and objeto.maximo > 1 else ""


## Centra el icono en la casilla a la mayor escala entera (como mucho ×2) que quepa:
## píxeles del arte nítidos. Sin textura no dibuja nada y su caja da igual.
func _poner_icono(tex: Texture2D) -> void:
	icono.texture = tex
	if tex == null:
		return
	var tam := tex.get_size()
	var escala := clampf(floorf(minf(size.x / tam.x, size.y / tam.y)), 1.0, 2.0)
	icono.size = tam * escala
	icono.position = (size / 2.0 - icono.size / 2.0).floor()
