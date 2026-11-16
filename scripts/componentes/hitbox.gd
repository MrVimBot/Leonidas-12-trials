class_name Hitbox
extends Area2D
## Zona que HACE daño: cada tick de física, mientras está `activo`, busca qué toca y llama a
## `recibir_golpe(danio, origen)` en cada objetivo que lo implemente (Hurtbox, vasijas,
## arbustos...); `origen` es la posición global del Hitbox. Ignora a su `owner`.
## Por defecto golpea una sola vez a cada objetivo por activación (`continuo` = false: la
## espada); con `continuo` = true repite cada tick (contacto de un enemigo, nube tóxica).
## No usa `get_overlapping_bodies()` ni señales: `consultar()` pregunta directamente al espacio
## físico con las formas del área, así puede golpear en el mismo tick en que se activa
## (`get_overlapping_*` y `body_entered` van con un tick de retraso; comprobado en Godot 4.7.2,
## también con StaticBody2D). Las consultas se reutilizan (una por forma) para no crear
## objetos en cada tick; también la usa `ComponenteInteraccion`. El daño va en cuartos de corazón.
## Capa y máscara: en la capa golpe_jugador/golpe_enemigo, con máscara de lo que puede golpear.

## Al golpear a un objetivo (una vez por objetivo, salvo `continuo`).
signal golpeo(objetivo: Node)

## Daño en cuartos de corazón (4 = un corazón).
@export var danio: int = 1
## Si está activo busca objetivos; al pasar de false a true olvida a quién golpeó ya.
@export var activo: bool = true:
	set(valor):
		if valor and not activo:
			_golpeados.clear() # nueva activación = puede volver a golpear a todos
		activo = valor
## Si es true golpea en cada tick mientras haya contacto, en vez de una vez por activación.
@export var continuo: bool = false

var _golpeados: Array[Node] = []
## Consultas reutilizadas: CollisionShape2D -> PhysicsShapeQueryParameters2D.
var _consultas: Dictionary = {}


func _ready() -> void:
	monitoring = false


func _physics_process(_delta: float) -> void:
	if not activo:
		return
	for objetivo in consultar(self, collision_mask, _consultas):
		_golpear(objetivo)


func _golpear(objetivo: Node) -> void:
	if not objetivo.has_method(&"recibir_golpe") or objetivo == owner:
		return
	if not continuo:
		if objetivo in _golpeados:
			return
		_golpeados.append(objetivo)
	# Duck typing a propósito: Hurtbox, ObjetoAgarrable, Decorado y arbustos lo implementan.
	objetivo.call(&"recibir_golpe", danio, global_position)
	golpeo.emit(objetivo)


## Qué tocan ahora las formas de `area` en las capas de `mascara` (máx. 16 por forma, sin
## el propio `area`). `cache` guarda las consultas de físicas: pasar siempre el mismo
## Dictionary en cada llamada para reutilizarlas (sin él se crean nuevas cada vez).
## Se actualizan transform, forma y máscara por si cambiaron (p. ej. `ComponenteAtaque`).
static func consultar(area: Area2D, mascara: int, cache: Dictionary = {}) -> Array[Node]:
	var res: Array[Node] = []
	var espacio := area.get_world_2d().direct_space_state
	var usadas := 0
	for c in area.get_children():
		var forma := c as CollisionShape2D
		if forma == null or forma.disabled or forma.shape == null:
			continue
		var q: PhysicsShapeQueryParameters2D = cache.get(forma)
		if q == null:
			q = PhysicsShapeQueryParameters2D.new()
			q.collide_with_areas = true
			q.collide_with_bodies = true
			cache[forma] = q
		if q.shape != forma.shape:
			q.shape = forma.shape
		q.transform = forma.global_transform
		q.collision_mask = mascara
		usadas += 1
		for h in espacio.intersect_shape(q, 16):
			var n: Node = h.collider
			if n != area and n not in res:
				res.append(n)
	# Limpia las formas que ya no existen (la clave sería un objeto liberado).
	if cache.size() > usadas:
		for k: Variant in cache.keys():
			if not is_instance_valid(k):
				cache.erase(k)
	return res
