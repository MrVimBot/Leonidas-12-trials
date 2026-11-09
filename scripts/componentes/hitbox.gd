class_name Hitbox
extends Area2D

signal golpeo(objetivo: Node)

@export var danio: int = 1


@export var activo: bool = true:
	set(valor):
		if valor and not activo:
			_golpeados.clear() # nueva activación = puede volver a golpear a todos
		activo = valor

@export var continuo: bool = false

var _golpeados: Array[Node] = []


func _ready() -> void:
	monitoring = false


func _physics_process(_delta: float) -> void:
	if not activo:
		return
	for objetivo in consultar(self, collision_mask):
		_golpear(objetivo)


func _golpear(objetivo: Node) -> void:
	if not objetivo.has_method(&"recibir_golpe") or objetivo == owner:
		return
	if not continuo:
		if objetivo in _golpeados:
			return
		_golpeados.append(objetivo)
	objetivo.recibir_golpe(danio, global_position)
	golpeo.emit(objetivo)


static func consultar(area: Area2D, mascara: int) -> Array[Node]:
	var res: Array[Node] = []
	var espacio := area.get_world_2d().direct_space_state
	for c in area.get_children():
		var forma := c as CollisionShape2D
		if forma == null or forma.disabled or forma.shape == null:
			continue
		var q := PhysicsShapeQueryParameters2D.new()
		q.shape = forma.shape
		q.transform = forma.global_transform
		q.collision_mask = mascara
		q.collide_with_areas = true
		q.collide_with_bodies = true
		for h in espacio.intersect_shape(q, 16):
			var n: Node = h.collider
			if n != area and n not in res:
				res.append(n)
	return res
