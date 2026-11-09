class_name ComponenteInteraccion
extends Area2D


@export var animador: AnimadorDireccional
@export var distancia := 10.0
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
