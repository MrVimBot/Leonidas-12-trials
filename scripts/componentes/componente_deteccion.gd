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

## Último candidato del grupo; solo se vuelve a buscar si se liberó o salió del árbol
## (el barco se recrea al hundirse).
var _candidato: Node2D = null


func _ready() -> void:
	if cuerpo == null:
		cuerpo = get_parent() as Node2D
	assert(cuerpo != null, "ComponenteDeteccion necesita un Node2D")


func _physics_process(_delta: float) -> void:
	var candidato := _buscar_candidato()
	if candidato == null or not _vivo(candidato):
		_perder()
		return
	var d := cuerpo.global_position.distance_to(candidato.global_position)
	if objetivo == null and d <= radio_vision:
		objetivo = candidato
		detecto.emit(candidato)
	elif objetivo != null and d > radio_perder:
		_perder()


func _buscar_candidato() -> Node2D:
	if not is_instance_valid(_candidato) or not _candidato.is_inside_tree():
		_candidato = get_tree().get_first_node_in_group(grupo) as Node2D
	return _candidato


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
	# Jugador y Barco exponen su `vida` como propiedad.
	var vida := nodo.get(&"vida") as ComponenteVida
	return vida == null or not vida.muerto
