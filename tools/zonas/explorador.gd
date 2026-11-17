extends RefCounted
## Motor común de los verificadores (verificar_zonas.gd, verificar_barreras_pueblo.gd):
## ¿puede el jugador pisar esta posición? y búsqueda en anchura sobre una rejilla con su forma.
##
## Uso (sin class_name: tools/ no se exporta con el juego). Con la zona ya dentro del árbol
## y esperados un par de `physics_frame`:
##   const Explorador := preload("res://tools/zonas/explorador.gd")
##   Explorador.quitar_cuerpos(zona)                       # antes de añadirla al árbol
##   var ex := Explorador.new(root.get_world_2d().direct_space_state)
##   ex.recorrer(inicio, limites, 8.0, func(p): ..., func(p): ...)

## Colisiona con lo mismo que el jugador (mundo y obstáculos bajos: sin voltereta).
const MASCARA := Capas.MUNDO | Capas.OBSTACULO_BAJO
## La forma del jugador (10×6) está en (0, −3) respecto a los pies.
const TAMANO_FORMA := Vector2(10, 6)
const DESPLAZAMIENTO_FORMA := Vector2(0, -3)
const _DIRECCIONES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var espacio: PhysicsDirectSpaceState2D
var _forma := RectangleShape2D.new()


func _init(espacio_fisico: PhysicsDirectSpaceState2D) -> void:
	espacio = espacio_fisico
	_forma.size = TAMANO_FORMA


## Quita enemigos y NPC (CharacterBody2D): se mueven, no cuentan como obstáculo fijo (y así
## no corre su IA). Llamar antes de añadir la zona al árbol.
static func quitar_cuerpos(n: Node) -> void:
	for h in n.get_children():
		if h is CharacterBody2D:
			n.remove_child(h)
			h.free()
		else:
			quitar_cuerpos(h)


## true si la forma del jugador, con los pies en `p`, choca con algo.
func choca(p: Vector2) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _forma
	q.transform = Transform2D(0.0, p + DESPLAZAMIENTO_FORMA)
	q.collision_mask = MASCARA
	q.collide_with_bodies = true
	q.collide_with_areas = false
	return not espacio.intersect_shape(q, 1).is_empty()


## Búsqueda en anchura (4 vecinos, paso `paso` px) desde `inicio`, que cuenta como visitado
## sin comprobar colisión. Una celda vecina se descarta si cae fuera de `limites`
## (`limite_inclusivo`: el borde derecho/inferior cuenta como dentro; Rect2.has_point no),
## si `choca()` o si `bloqueado.call(p)` es true (muros extra opcionales).
## Por cada celda alcanzada llama a `al_visitar.call(p)`; si devuelve true, la búsqueda
## termina. Devuelve cuántas celdas se visitaron.
func recorrer(inicio: Vector2, limites: Rect2, paso: float, al_visitar: Callable,
		bloqueado := Callable(), limite_inclusivo := false) -> int:
	var vistos := {Vector2i.ZERO: true}
	var cola: Array[Vector2i] = [Vector2i.ZERO]
	var i := 0
	while i < cola.size():
		var c := cola[i]
		i += 1
		if al_visitar.call(inicio + Vector2(c) * paso):
			break
		for d in _DIRECCIONES:
			var n: Vector2i = c + d
			if vistos.has(n):
				continue
			vistos[n] = true
			var pn := inicio + Vector2(n) * paso
			if not _dentro(pn, limites, limite_inclusivo) or choca(pn):
				continue
			if bloqueado.is_valid() and bloqueado.call(pn):
				continue
			cola.append(n)
	return i


func _dentro(p: Vector2, limites: Rect2, inclusivo: bool) -> bool:
	if inclusivo:
		return p.x >= limites.position.x and p.y >= limites.position.y \
				and p.x <= limites.end.x and p.y <= limites.end.y
	return limites.has_point(p)
