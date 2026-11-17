@tool
class_name ComponenteInteraccion
extends Area2D
## "Manos" del jugador: `buscar()` coloca el área delante de él (según la dirección del
## animador) y devuelve lo más cercano que pueda interactuar: un nodo con `interactuar(quien)`
## (NPC, carteles) o un `ObjetoAgarrable`. Usa `Hitbox.consultar()` (consulta directa al
## espacio físico), igual que `Hitbox`. La máscara del área decide qué capas mira.
## No se mueve sola: el cerebro llama a `buscar()`.
## `@tool` solo para avisar en el editor de lo que falta; en el editor no hace nada más.

## Animador cuya dirección dice hacia dónde se busca. Sin él, el área no se mueve.
@export var animador: AnimadorDireccional
## Distancia (px) desde la entidad hasta el centro del área, en la dirección en que mira.
@export var distancia := 10.0
## Desplazamiento vertical del área (negativo = hacia arriba, a la altura de las manos).
@export var altura := -6.0
## Entidad desde la que se mide la cercanía. Si está vacío usa el nodo padre.
@export var portador: Node2D:
	set(valor):
		portador = valor
		update_configuration_warnings()

var _consultas: Dictionary = {}


func _ready() -> void:
	# En el editor no toca `monitoring`/`monitorable` ni `portador` (se guardarían en la escena).
	if Engine.is_editor_hint():
		return
	if portador == null:
		portador = get_parent() as Node2D
	monitoring = false
	monitorable = false


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	# `Hitbox.consultar()` solo usa CollisionShape2D (no CollisionPolygon2D). Que no tenga
	# ninguna forma ya lo avisa el propio Area2D.
	if not get_children().any(func(c: Node) -> bool: return c is CollisionShape2D):
		avisos.append("Necesita un CollisionShape2D hijo (marca dónde se busca; CollisionPolygon2D no sirve).")
	if portador == null and not get_parent() is Node2D:
		avisos.append("Asigna `portador` o ponlo como hijo de un Node2D (desde donde se mide la cercanía).")
	return avisos


func buscar() -> Node2D:
	if animador:
		position = animador.direccion * distancia + Vector2(0, altura)
	var mejor: Node2D = null
	var mejor_d := INF
	for n in Hitbox.consultar(self, collision_mask, _consultas):
		if not (n.has_method(&"interactuar") or n is ObjetoAgarrable):
			continue
		var d := portador.global_position.distance_squared_to((n as Node2D).global_position)
		if d < mejor_d:
			mejor_d = d
			mejor = n
	return mejor
