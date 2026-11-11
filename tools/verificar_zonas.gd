extends SceneTree
## CLI: godot --headless --path . --script res://tools/verificar_zonas.gd
## Prueba de aceptación del mapa. Para cada escena de scenes/levels/ comprueba:
##   1. Enlaces: cada SalidaZona lleva a una zona que existe y tiene esa entrada.
##   2. Entradas libres: en cada Entradas/<x> cabe el jugador sin chocar, y está a
##      ≥ 24 px de cualquier SalidaZona (si no, rebotaría entre zonas).
##   3. Se puede caminar: desde cada entrada se llega a cada salida (búsqueda en anchura
##      sobre una rejilla de 8 px con la forma real del jugador).
##   4. Grafo: desde pueblo/inicio se visitan todas las zonas, y desde cueva_jefe (si
##      existe) se vuelve al pueblo.
## Termina con código 1 si algo falla.

const DIR := "res://scenes/levels/"
const INICIO := "res://scenes/levels/pueblo.tscn"
const FINAL := "res://scenes/levels/cueva_jefe.tscn"
const PASO := 8.0
const MASCARA := 1 | 64 # mundo + obstáculo bajo (como el jugador)
const SEPARACION_SALIDA := 24.0

var _forma := RectangleShape2D.new()
var _fallos := 0
# ruta → {entradas: [nombres], salidas: [[nombre, destino, entrada]]}
var _zonas := {}


func _initialize() -> void:
	_forma.size = Vector2(10, 6)
	_correr.call_deferred()


func _correr() -> void:
	var rutas: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".tscn"):
			rutas.append(DIR + f)
	rutas.sort()

	# Primero se leen todas (para poder comprobar los enlaces entre ellas).
	for ruta in rutas:
		var escena := load(ruta) as PackedScene
		if escena == null:
			_fallo(ruta, "no se pudo cargar")
			continue
		var zona := escena.instantiate()
		var info := {"entradas": [], "salidas": []}
		var nodo_entradas := zona.get_node_or_null(^"Entradas")
		if nodo_entradas:
			for m in nodo_entradas.get_children():
				info.entradas.append(String(m.name))
		for s in _salidas(zona):
			info.salidas.append([String(s.name), s.get("zona_destino"), s.get("entrada_destino")])
		_zonas[ruta] = info
		zona.free()

	print("")
	print("%-14s %-48s %-40s %s" % ["ZONA", "ENTRADAS", "SALIDAS", "RESULTADO"])
	for ruta in rutas:
		if not _zonas.has(ruta):
			continue
		var motivos: Array[String] = []
		_enlaces(ruta, motivos)
		await _fisica(ruta, motivos)
		var info: Dictionary = _zonas[ruta]
		var salidas := []
		for s in info.salidas:
			salidas.append("%s→%s" % [s[0], (s[1] as String).get_file().get_basename()])
		print("%-14s %-48s %-40s %s" % [ruta.get_file().get_basename(), ", ".join(info.entradas),
			", ".join(salidas), "OK" if motivos.is_empty() else "FALLO"])
		for m in motivos:
			print("    - " + m)
		_fallos += motivos.size()

	_grafo()
	print("")
	print("RESULTADO: %s (%d fallos)" % ["OK" if _fallos == 0 else "FALLO", _fallos])
	quit(0 if _fallos == 0 else 1)


# 1. Enlaces ---------------------------------------------------------------------

func _enlaces(ruta: String, motivos: Array[String]) -> void:
	for s in _zonas[ruta].salidas:
		var destino: String = s[1]
		if not _zonas.has(destino):
			motivos.append("%s: la zona destino %s no existe" % [s[0], destino])
		elif not s[2] in _zonas[destino].entradas:
			motivos.append("%s: %s no tiene la entrada '%s'" % [s[0], destino.get_file(), s[2]])


# 2 y 3. Física ------------------------------------------------------------------

func _fisica(ruta: String, motivos: Array[String]) -> void:
	var zona := (load(ruta) as PackedScene).instantiate()
	# Enemigos y NPC se mueven: no cuentan como obstáculo fijo (y así no corre su IA).
	_quitar_cuerpos(zona)
	root.add_child(zona)
	await physics_frame
	await physics_frame
	var espacio := root.get_world_2d().direct_space_state

	var limites: Rect2 = Rect2(zona.call("obtener_limites"))
	var salidas: Array = []
	for s in _salidas(zona):
		salidas.append([String(s.name), _rect_salida(s)])
	var nodo_entradas := zona.get_node_or_null(^"Entradas")
	if nodo_entradas == null or nodo_entradas.get_child_count() == 0:
		motivos.append("no tiene Entradas")
	else:
		if nodo_entradas.get_node_or_null(^"inicio") == null:
			motivos.append("falta la entrada 'inicio'")
		for m in nodo_entradas.get_children():
			var p: Vector2 = (m as Node2D).global_position
			if _choca(espacio, p):
				motivos.append("entrada %s %s: el jugador choca con algo" % [m.name, p])
				continue
			for s in salidas:
				var r: Rect2 = s[1]
				if _distancia_rect(p, r) < SEPARACION_SALIDA:
					motivos.append("entrada %s está a < %d px de %s" % [m.name, SEPARACION_SALIDA, s[0]])
			var alcanzadas := _bfs(espacio, p, limites, salidas)
			for s in salidas:
				if not s[0] in alcanzadas:
					motivos.append("desde %s no se llega a %s" % [m.name, s[0]])
	root.remove_child(zona)
	zona.free()


func _quitar_cuerpos(n: Node) -> void:
	for h in n.get_children():
		if h is CharacterBody2D:
			n.remove_child(h)
			h.free()
		else:
			_quitar_cuerpos(h)


func _salidas(zona: Node) -> Array:
	var res := []
	for h in zona.get_children():
		if h is Area2D and h.get("zona_destino") != null:
			res.append(h)
	return res


func _rect_salida(s: Area2D) -> Rect2:
	for h in s.get_children():
		if h is CollisionShape2D and h.shape is RectangleShape2D:
			var tam: Vector2 = h.shape.size
			return Rect2(h.global_position - tam / 2.0, tam)
	return Rect2(s.global_position, Vector2.ZERO)


func _distancia_rect(p: Vector2, r: Rect2) -> float:
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return p.distance_to(q)


## La forma del jugador (10×6 en (0, −3) respecto a los pies) en los pies `p`.
func _choca(espacio: PhysicsDirectSpaceState2D, p: Vector2) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _forma
	q.transform = Transform2D(0.0, p + Vector2(0, -3))
	q.collision_mask = MASCARA
	q.collide_with_bodies = true
	q.collide_with_areas = false
	return not espacio.intersect_shape(q, 1).is_empty()


## Búsqueda en anchura (4 vecinos, paso 8 px) desde `inicio`. Devuelve los nombres de
## las salidas que contienen alguna celda alcanzada.
func _bfs(espacio: PhysicsDirectSpaceState2D, inicio: Vector2, limites: Rect2, salidas: Array) -> Array:
	var alcanzadas := []
	var vistos := {Vector2i.ZERO: true}
	var cola: Array[Vector2i] = [Vector2i.ZERO]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var i := 0
	while i < cola.size():
		var c := cola[i]
		i += 1
		var p := inicio + Vector2(c) * PASO
		for s in salidas:
			if not s[0] in alcanzadas and (s[1] as Rect2).grow(0.01).has_point(p):
				alcanzadas.append(s[0])
		if alcanzadas.size() == salidas.size():
			break
		for d in dirs:
			var n: Vector2i = c + d
			if vistos.has(n):
				continue
			vistos[n] = true
			var pn := inicio + Vector2(n) * PASO
			if pn.x < limites.position.x or pn.y < limites.position.y \
					or pn.x > limites.end.x or pn.y > limites.end.y:
				continue
			if _choca(espacio, pn):
				continue
			cola.append(n)
	return alcanzadas


# 4. Grafo -----------------------------------------------------------------------

func _grafo() -> void:
	print("")
	if not _zonas.has(INICIO):
		print("GRAFO: FALLO, no existe %s" % INICIO)
		_fallos += 1
		return
	var desde_inicio := _alcanzables(INICIO)
	var faltan := []
	for r in _zonas:
		if not r in desde_inicio:
			faltan.append((r as String).get_file().get_basename())
	if faltan.is_empty():
		print("GRAFO: desde pueblo se visitan las %d zonas" % _zonas.size())
	else:
		print("GRAFO: FALLO, desde pueblo no se llega a: %s" % ", ".join(faltan))
		_fallos += 1
	if _zonas.has(FINAL):
		if INICIO in _alcanzables(FINAL):
			print("GRAFO: desde cueva_jefe se vuelve a pueblo")
		else:
			print("GRAFO: FALLO, desde cueva_jefe no se vuelve a pueblo")
			_fallos += 1


func _alcanzables(desde: String) -> Dictionary:
	var vistos := {desde: true}
	var cola := [desde]
	while not cola.is_empty():
		var r: String = cola.pop_front()
		for s in _zonas[r].salidas:
			var d: String = s[1]
			if _zonas.has(d) and not vistos.has(d):
				vistos[d] = true
				cola.append(d)
	return vistos


func _fallo(ruta: String, motivo: String) -> void:
	print("%s: FALLO, %s" % [ruta, motivo])
	_fallos += 1
