class_name ComponenteCarga
extends Node
## Cargar y lanzar `ObjetoAgarrable` (vasijas...): `levantar()` lo sube a `punto_carga`,
## `lanzar()` lo manda en una dirección a una distancia (o `soltar()` lo deja caer a los pies).
## Decidir cuándo hacerlo es cosa del cerebro; quién se acerca a qué objeto lo busca
## `ComponenteInteraccion`.

## Al levantar un objeto (con él) o al lanzarlo/soltarlo (con `null`).
signal cambio(objeto: ObjetoAgarrable)

## Punto sobre el que se coloca el objeto cargado (obligatorio, p. ej. sobre la cabeza).
@export var punto_carga: Node2D
## Quien carga, de donde sale el objeto al lanzarlo. Si está vacío usa el nodo padre.
@export var portador: Node2D
## Distancia (px) a la que cae un objeto lanzado con `lanzar()` sin distancia propia.
@export var distancia_lanzamiento := 72.0

## Objeto que se carga ahora, o null.
var objeto: ObjetoAgarrable = null


func _ready() -> void:
	if portador == null:
		portador = get_parent() as Node2D
	assert(punto_carga != null, "ComponenteCarga necesita un punto_carga")


func cargando() -> bool:
	return objeto != null


func levantar(obj: ObjetoAgarrable) -> void:
	if cargando() or obj == null:
		return
	objeto = obj
	obj.levantar(punto_carga)
	cambio.emit(objeto)


func lanzar(direccion: Vector2, distancia := -1.0) -> void:
	if not cargando():
		return
	var obj := objeto
	objeto = null
	obj.lanzar(direccion, distancia if distancia >= 0.0 else distancia_lanzamiento, portador.global_position)
	cambio.emit(null)


func soltar(direccion: Vector2) -> void:
	lanzar(direccion, 0.0)
