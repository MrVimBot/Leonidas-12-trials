extends SceneTree
## CLI: godot --headless --path . --script res://tools/verificar_barreras_pueblo.gd [-- ruta.tscn]
## Comprueba que las zonas del pueblo que deben estar cerradas lo siguen estando (después de
## tocar el suelo, las colisiones o mover decorados). Búsqueda en anchura con la forma del
## jugador (10×6 en (0, −3) respecto a los pies), paso de 4 px, desde Entradas/inicio:
##   A. Con BarreraCartel + BarreraCartelOeste como muro no se llega a BarreraNorte/BarreraSur
##      (el rincón de la casa queda cerrado hasta aprender la voltereta).
##   B. Con Disparador + DisparadorOeste (escena de Kathita) como muro no se llega a ninguna
##      barrera (la escena del libro siempre ocurre antes).
##   C. Sin muros se llega a todas (nada se ha cerrado de más).
## Termina con código 1 si algo falla.

const Explorador := preload("res://tools/zonas/explorador.gd")

const PASO := 4.0

var _explorador: Explorador


func _initialize() -> void:
	_correr.call_deferred()


func _correr() -> void:
	var args := OS.get_cmdline_user_args()
	var ruta := args[0] if args.size() > 0 else "res://scenes/levels/pueblo.tscn"
	var zona := (load(ruta) as PackedScene).instantiate()
	Explorador.quitar_cuerpos(zona)
	root.add_child(zona)
	await physics_frame
	await physics_frame
	_explorador = Explorador.new(root.get_world_2d().direct_space_state)
	var limites := Rect2(zona.call("obtener_limites"))
	var inicio: Vector2 = (zona.get_node("Entradas/inicio") as Node2D).global_position

	var r := {}
	for n in ["BarreraNorte", "BarreraSur", "BarreraCartel", "BarreraCartelOeste", "Disparador", "DisparadorOeste"]:
		var nodo := zona.find_child(n, true, false)
		if nodo == null:
			push_error("No encuentro %s" % n)
			quit(1)
			return
		r[n] = _rects(nodo)
	var fallos := 0
	var a := _bfs(inicio, limites, r.BarreraCartel + r.BarreraCartelOeste)
	fallos += _no_llega("A (voltereta)", a, r, ["BarreraNorte", "BarreraSur"])
	var b := _bfs(inicio, limites, r.Disparador + r.DisparadorOeste)
	fallos += _no_llega("B (Kathita)", b, r, ["BarreraNorte", "BarreraSur", "BarreraCartel", "BarreraCartelOeste"])
	var c := _bfs(inicio, limites, [])
	for n in ["BarreraNorte", "BarreraSur", "BarreraCartel", "BarreraCartelOeste", "Disparador", "DisparadorOeste"]:
		if not _toca(c, r[n]):
			print("C (sin muros): NO se llega a %s" % n)
			fallos += 1
	print("RESULTADO: %s (%d fallos)" % ["OK" if fallos == 0 else "MAL", fallos])
	quit(0 if fallos == 0 else 1)


func _no_llega(prueba: String, alcanzadas: Array, r: Dictionary, nombres: Array) -> int:
	var fallos := 0
	for n in nombres:
		if _toca(alcanzadas, r[n]):
			print("%s: se llega a %s ¡hay un hueco!" % [prueba, n])
			fallos += 1
	if fallos == 0:
		print("%s: cerrado (%d posiciones alcanzables)" % [prueba, alcanzadas.size()])
	return fallos


func _toca(puntos: Array, rects: Array) -> bool:
	for p in puntos:
		for rr in rects:
			if (rr as Rect2).has_point(p):
				return true
	return false


func _rects(n: Node) -> Array:
	var res := []
	for h in n.get_children():
		if h is CollisionShape2D and h.shape is RectangleShape2D:
			var tam: Vector2 = h.shape.size * h.global_scale.abs()
			res.append(Rect2(h.global_position - tam / 2.0, tam))
	return res


## Posiciones de los pies alcanzables; `muros` = rectángulos que no se pueden pisar.
func _bfs(inicio: Vector2, limites: Rect2, muros: Array) -> Array:
	var puntos := []
	_explorador.recorrer(inicio, limites, PASO, func(p: Vector2) -> bool:
		puntos.append(p)
		return false
	, func(p: Vector2) -> bool: return _toca([p], muros))
	return puntos
