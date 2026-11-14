class_name ArticuloTienda
extends Resource
## Un objeto que se vende en una tienda (resources/tienda/*.tres): un `Objeto`
## (resources/objetos/) + su precio. Se edita en el Inspector: el equipo puede cambiar
## el precio sin tocar código; nombre, descripción e icono salen del Objeto.

@export var objeto: Objeto
## Precio en monedas.
@export_range(0, 999) var precio := 3
## Frase corta bajo la lista de la tienda (≤ 26 letras, un renglón). Vacía = la del objeto.
@export var descripcion_tienda := ""

var id: StringName:
	get:
		return objeto.id if objeto else &""
var nombre: String:
	get:
		return objeto.nombre if objeto else "?"
var descripcion: String:
	get:
		if not descripcion_tienda.is_empty() or objeto == null:
			return descripcion_tienda
		return objeto.descripcion
var icono: Texture2D:
	get:
		return objeto.icono if objeto else null
