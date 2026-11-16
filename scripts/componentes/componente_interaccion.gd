class_name ComponenteInteraccion
extends Area2D
## "Manos" del jugador: `buscar()` coloca el área delante de él (según la dirección del
## animador) y devuelve lo más cercano que pueda interactuar: un nodo con `interactuar(quien)`
## (NPC, carteles) o un `ObjetoAgarrable`. Usa `Hitbox.consultar()` (consulta directa al
## espacio físico) porque un Area2D no detecta StaticBody2D. La máscara del área decide qué capas mira.
## No se mueve sola: el cerebro llama a `buscar()`.

## Animador cuya dirección dice hacia dónde se busca. Sin él, el área no se mueve.
@export var animador: AnimadorDireccional
## Distancia (px) desde la entidad hasta el centro del área, en la dirección en que mira.
@export var distancia := 10.0
## Desplazamiento vertical del área (negativo = hacia arriba, a la altura de las manos).
@export var altura := -6.0


func _ready() -> void:
	monitoring = false
	monitorable = false


func buscar() -> Node2D:
	if animador:
		position = animador.direccion * distancia + Vector2(0, altura)
	var dueno := get_parent() as Node2D
	var mejor: Node2D = null
	var mejor_d := INF
	for n in Hitbox.consultar(self, collision_mask):
		if not (n.has_method(&"interactuar") or n is ObjetoAgarrable):
			continue
		var d := dueno.global_position.distance_squared_to((n as Node2D).global_position)
		if d < mejor_d:
			mejor_d = d
			mejor = n
	return mejor
