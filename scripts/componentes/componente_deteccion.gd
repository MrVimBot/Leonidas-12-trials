class_name ComponenteDeteccion
extends Node
## "Ojos" de un enemigo: busca al jugador (grupo `grupo`) por distancia desde `cuerpo`.
## Lo detecta al entrar en `radio_vision` y lo pierde al salir de `radio_perder`
## (mayor, para que no parpadee en el borde). Sin raycast: se ve a través de árboles.
## Ignora a un jugador muerto.

signal detecto(objetivo: Node2D)
signal perdio

@export var cuerpo: Node2D
@export var radio_vision := 64.0
@export var radio_perder := 112.0
@export var grupo := &"jugador"

var objetivo: Node2D = null


func _ready() -> void:
	if cuerpo == null:
		cuerpo = get_parent() as Node2D
	assert(cuerpo != null, "ComponenteDeteccion necesita un Node2D")


func _physics_process(_delta: float) -> void:
	var candidato := get_tree().get_first_node_in_group(grupo) as Node2D
	if candidato == null or not _vivo(candidato):
		_perder()
		return
	var d := cuerpo.global_position.distance_to(candidato.global_position)
	if objetivo == null and d <= radio_vision:
		objetivo = candidato
		detecto.emit(candidato)
	elif objetivo != null and d > radio_perder:
		_perder()


func viendo() -> bool:
	return objetivo != null


func distancia() -> float:
	return cuerpo.global_position.distance_to(objetivo.global_position) if objetivo else INF


## Vector (sin normalizar) desde el cuerpo hasta el objetivo.
func vector_hacia() -> Vector2:
	return objetivo.global_position - cuerpo.global_position if objetivo else Vector2.ZERO


func direccion() -> Vector2:
	return vector_hacia().normalized()


func _perder() -> void:
	if objetivo != null:
		objetivo = null
		perdio.emit()


func _vivo(nodo: Node) -> bool:
	var vida := nodo.get_node_or_null(^"Vida") as ComponenteVida
	return vida == null or not vida.muerto
