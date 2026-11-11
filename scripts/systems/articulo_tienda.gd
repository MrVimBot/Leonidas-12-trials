class_name ArticuloTienda
extends Resource
## Un objeto que se vende en una tienda (resources/tienda/*.tres).
## Se edita en el Inspector: el equipo puede cambiar el precio o el texto sin tocar código.
## Qué se recibe al comprarlo lo decide `id` (ver ComponenteTienda.entregar).

## Identificador del objeto: manzana (por ahora es el único que existe).
@export var id: StringName = &"manzana"
## Nombre en la lista de la tienda (≤ 12 letras para que quepa con el precio).
@export var nombre := "Manzana"
## Una frase corta debajo de la lista (≤ 26 letras, un renglón).
@export var descripcion := ""
## Precio en monedas.
@export_range(0, 999) var precio := 3
## Icono de 16×16 aprox. junto al nombre.
@export var icono: Texture2D
