class_name ManzanaSuelta
extends Moneda
## Manzana que cae de un manzano al golpearlo. Se comporta como una moneda (salta, rebota,
## se recoge al pisarla) pero suma una manzana al inventario. Si no cabe más, se queda
## en el suelo hasta que haya sitio.

const ESCENA_MANZANA := preload("res://scenes/items/manzana_suelta.tscn")


static func soltar_manzanas(padre: Node, posicion: Vector2, cantidad: int) -> void:
	soltar_escena(ESCENA_MANZANA, padre, posicion, cantidad)


func _dar() -> bool:
	return EstadoJuego.agregar_objeto(EstadoJuego.OBJ_MANZANA, valor)
