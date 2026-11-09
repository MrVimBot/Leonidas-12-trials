class_name ComponenteCarga
extends Node

signal cambio(objeto: ObjetoAgarrable) 


@export var punto_carga: Node2D

@export var portador: Node2D
@export var distancia_lanzamiento := 72.0

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
