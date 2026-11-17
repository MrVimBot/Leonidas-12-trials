@tool
class_name ComponenteCarga
extends Node
## Cargar y lanzar `ObjetoAgarrable` (vasijas...): `levantar()` lo sube a `punto_carga`,
## `lanzar()` lo manda en una dirección a una distancia (o `soltar()` lo deja caer a los pies).
## Decidir cuándo hacerlo es cosa del cerebro; quién se acerca a qué objeto lo busca
## `ComponenteInteraccion`.
## `@tool` solo para avisar en el editor de lo que falta; en el editor no hace nada más.

## Al levantar un objeto (con él) o al lanzarlo/soltarlo (con `null`).
signal cambio(objeto: ObjetoAgarrable)

## Punto sobre el que se coloca el objeto cargado (obligatorio, p. ej. sobre la cabeza).
@export var punto_carga: Node2D:
	set(valor):
		punto_carga = valor
		update_configuration_warnings()
## Quien carga, de donde sale el objeto al lanzarlo. Si está vacío usa el nodo padre.
@export var portador: Node2D:
	set(valor):
		portador = valor
		update_configuration_warnings()
## Distancia (px) a la que cae un objeto lanzado con `lanzar()` sin distancia propia.
@export var distancia_lanzamiento := 72.0

## Objeto que se carga ahora, o null.
var objeto: ObjetoAgarrable = null


func _ready() -> void:
	# En el editor no rellena `portador` (se guardaría en la escena).
	if Engine.is_editor_hint():
		return
	if portador == null:
		portador = get_parent() as Node2D
	assert(punto_carga != null, "ComponenteCarga necesita un punto_carga")


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if punto_carga == null:
		avisos.append("Asigna en `punto_carga` el Node2D donde se coloca el objeto cargado.")
	if portador == null and not get_parent() is Node2D:
		avisos.append("Asigna `portador` o ponlo como hijo de un Node2D (el que carga).")
	return avisos


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
