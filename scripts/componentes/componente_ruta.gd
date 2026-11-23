@tool
class_name ComponenteRuta
extends Node
## Camino entre paredes para una IA (el Minotauro en su laberinto): una rejilla `AStarGrid2D` con
## las celdas que la forma `tamano` no puede pisar, sacadas del espacio físico (máscara
## `mascara`) una sola vez con `preparar(region)`. Después, cada tick, `siguiente_paso(desde,
## hacia, delta)` da el punto hacia el que caminar.
##
## Por qué no NavigationAgent2D: las zonas pintadas tienen la colisión en cientos de rectángulos
## que genera un script de Python, y el laberinto la cambia en juego (rejas). Una malla de
## navegación habría que hornearla en el editor y rehacerla con cada cambio; la rejilla se saca
## del mismo espacio físico que frena al cuerpo, así que siempre coincide con él.
##
## Coste: una consulta de forma por celda al preparar (~6000 en el laberinto, una vez por combate).

## El cuerpo que se mueve (se excluye de las consultas).
@export var cuerpo: CollisionObject2D:
	set(valor):
		cuerpo = valor
		update_configuration_warnings()
## Lado de cada celda (px de mundo).
@export var celda := 8.0
## Forma (rectángulo) que se prueba en cada celda: algo mayor que la colisión del cuerpo, para
## que la ruta no lo pegue a las esquinas.
@export var tamano := Vector2(22, 12)
## Capas que bloquean el paso.
@export_flags_2d_physics var mascara := 1
## Cada cuántos segundos se recalcula la ruta aunque el destino no cambie de celda.
@export var recalcular := 0.5

## Marca de celda que no existe (no hay libre cerca).
const INVALIDA := -(1 << 30)

## ¿Ya se hizo `preparar()`?
var preparado := false

var _astar := AStarGrid2D.new()
var _ruta := PackedVector2Array()
var _indice := 0
var _espera := 0.0
var _celda_destino := Vector2i(1 << 30, 1 << 30)


func _get_configuration_warnings() -> PackedStringArray:
	if cuerpo == null:
		return PackedStringArray(["Falta `cuerpo` (el CharacterBody2D que sigue la ruta)."])
	return PackedStringArray()


## Rellena la rejilla de `region` (px de mundo, globales). Llamarlo con la física ya al día (las
## colisiones que se acaban de activar con `set_deferred` cuentan al tick siguiente).
func preparar(region: Rect2) -> void:
	var desde := Vector2i((region.position / celda).floor())
	var hasta := Vector2i((region.end / celda).ceil())
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(desde, hasta - desde)
	_astar.cell_size = Vector2(celda, celda)
	_astar.offset = Vector2(celda, celda) / 2.0 # cada punto es el centro de su celda
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	var espacio := cuerpo.get_world_2d().direct_space_state
	var forma := RectangleShape2D.new()
	forma.size = tamano
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.collision_mask = mascara
	consulta.exclude = [cuerpo.get_rid()]
	for y in range(desde.y, hasta.y):
		for x in range(desde.x, hasta.x):
			consulta.transform = Transform2D(0.0, _centro(Vector2i(x, y)))
			if not espacio.intersect_shape(consulta, 1).is_empty():
				_astar.set_point_solid(Vector2i(x, y))
	preparado = true
	olvidar()


## Olvida la ruta actual (al reiniciar o tras un empujón).
func olvidar() -> void:
	_ruta = PackedVector2Array()
	_indice = 0
	_espera = 0.0
	_celda_destino = Vector2i(1 << 30, 1 << 30)


## ¿Se puede estar en `punto` (global)? Fuera de la rejilla o sin preparar: true.
func es_libre(punto: Vector2) -> bool:
	var c := _celda(punto)
	return not preparado or not _astar.is_in_boundsv(c) or not _astar.is_point_solid(c)


## Punto (global) hacia el que caminar desde `desde` para llegar a `hacia`. Sin rejilla, o si
## el cuerpo está en una celda marcada (pegado a una pared), devuelve `hacia` tal cual.
func siguiente_paso(desde: Vector2, hacia: Vector2, delta: float) -> Vector2:
	if not preparado:
		return hacia
	var origen := _libre_cercana(_celda(desde))
	var destino := _celda(hacia)
	if origen.x == INVALIDA:
		return hacia
	_espera -= delta
	if destino != _celda_destino or _espera <= 0.0 or _indice >= _ruta.size():
		_celda_destino = destino
		_espera = recalcular
		if _astar.is_in_boundsv(destino):
			# Con `allow_partial_path`, si el destino está en una celda marcada (junto a una pared)
			# llega a la libre más cercana.
			_ruta = _astar.get_point_path(origen, destino, true)
		else:
			_ruta = PackedVector2Array()
		_indice = 1 if _ruta.size() > 1 else 0 # el primero es la celda donde ya está
	while _indice < _ruta.size() and desde.distance_to(_ruta[_indice]) < celda * 0.5:
		_indice += 1
	if _indice >= _ruta.size():
		return hacia
	return _ruta[_indice]


## La celda `c` si está libre; si no (el cuerpo va pegado a una pared y su celda quedó marcada
## por la forma, que es mayor que su colisión), la libre más cercana a ≤ 3 celdas. Sin ninguna:
## `x` = INVALIDA.
func _libre_cercana(c: Vector2i) -> Vector2i:
	if _astar.is_in_boundsv(c) and not _astar.is_point_solid(c):
		return c
	for r in range(1, 4):
		var mejor := Vector2i(INVALIDA, 0)
		var mejor_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var v := c + Vector2i(dx, dy)
				if _astar.is_in_boundsv(v) and not _astar.is_point_solid(v):
					var d := Vector2(dx, dy).length()
					if d < mejor_d:
						mejor_d = d
						mejor = v
		if mejor.x != INVALIDA:
			return mejor
	return Vector2i(INVALIDA, 0)


func _celda(punto: Vector2) -> Vector2i:
	return Vector2i((punto / celda).floor())


func _centro(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * celda
