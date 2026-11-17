extends "res://tools/pruebas/base_prueba.gd"
## Objetos agarrables (vasija, piedra, arbusto) con eventos reales, en el claro del bosque:
## levantar un arbusto deja un tocón no sólido; la vasija lanzada quita 1 a una seta y desaparece
## tras su animación; la piedra lanzada quita 3, sigue existiendo y vuelve a ser sólida; el arbusto
## lanzado no daña pero se rompe; el espadazo rompe vasija y arbusto (con tocón) y no la piedra.

const ARBUSTO := "res://scenes/items/arbusto.tscn"
const VASIJA := "res://scenes/items/vasija_azul.tscn"
const PIEDRA := "res://scenes/items/piedra.tscn"


## Pone un objeto delante de Leonidas (que mira a la derecha) y a unos 50 px de `seta`.
func preparar(ruta: String, seta: SetaBomba) -> ObjetoAgarrable:
	j.global_position = seta.global_position + Vector2(-50, 0)
	j.velocity = Vector2.ZERO
	j.animador.mirar(Vector2.RIGHT)
	var o := (load(ruta) as PackedScene).instantiate() as ObjetoAgarrable
	o.botin = null # sin azar en la prueba
	seta.get_parent().add_child(o)
	o.global_position = j.global_position + Vector2(14, 0)
	await ticks(3)
	return o


func levantar_y_lanzar(o: ObjetoAgarrable) -> void:
	await pulsar(&"interactuar")
	await esperar_hasta(func() -> bool: return j.carga.cargando() and j.estado == Jugador.Estado.NORMAL, 240)
	await pulsar(&"interactuar")


## ¿Ya se liberó el objeto? Con `weakref`: una lambda no puede capturar un nodo liberado.
func esta_liberado(ref: WeakRef) -> bool:
	return ref.get_ref() == null


func tocones(padre: Node) -> Array:
	return padre.get_children().filter(func(n: Node) -> bool:
		return n is Decorado and (n as Decorado).textura != null and (n as Decorado).textura.resource_path.ends_with("tocon.png"))


func ejecutar() -> void:
	tiempo_maximo = 180.0
	await crear_game(true, true)
	game.cambiar_zona("res://scenes/levels/bosque.tscn", "desde_pueblo")
	await ticks(5)
	await esperar_normal()
	await ticks(20)
	var setas := game.find_children("*", "SetaBomba", true, false)
	for s in setas:
		(s as SetaBomba).set_physics_process(false)
	ok("hay al menos 3 setas", setas.size() >= 3, str(setas.size()))
	var padre := (setas[0] as Node).get_parent()

	# ---- vasija lanzada ----
	var seta := setas[0] as SetaBomba
	var v := await preparar(VASIJA, seta)
	var vida_ini := seta.vida.vida
	await levantar_y_lanzar(v)
	await esperar_hasta(func() -> bool: return seta.vida.vida < vida_ini, 240)
	ok("vasija lanzada quita 1 a la seta", seta.vida.vida == vida_ini - 1, "%d -> %d" % [vida_ini, seta.vida.vida])
	var se_fue := await esperar_hasta(esta_liberado.bind(weakref(v)), 900)
	ok("la vasija desaparece tras su animación", se_fue)

	# ---- piedra lanzada ----
	seta = setas[1] as SetaBomba
	var p := await preparar(PIEDRA, seta)
	vida_ini = seta.vida.vida
	await levantar_y_lanzar(p)
	await esperar_hasta(func() -> bool: return seta.vida.vida < vida_ini, 240)
	ok("piedra lanzada quita 3 a la seta", seta.vida.vida == vida_ini - 3 or seta.vida.muerto, "%d -> %d" % [vida_ini, seta.vida.vida])
	await ticks(240)
	ok("la piedra sigue existiendo", is_instance_valid(p))
	ok("la piedra vuelve a ser sólida", is_instance_valid(p) and (p.collision_layer & Capas.MUNDO) != 0)

	# ---- arbusto lanzado: sin daño, deja tocón al levantarlo ----
	seta = setas[2] as SetaBomba
	var tocones_antes := tocones(padre).size()
	var a := await preparar(ARBUSTO, seta)
	vida_ini = seta.vida.vida
	await levantar_y_lanzar(a)
	ok("levantar el arbusto deja un tocón", tocones(padre).size() == tocones_antes + 1)
	var toc := tocones(padre).back() as Decorado
	ok("el tocón no es sólido", toc != null and not toc.solido)
	var a_roto := await esperar_hasta(esta_liberado.bind(weakref(a)), 900)
	ok("el arbusto lanzado se rompe y desaparece", a_roto)
	ok("el arbusto lanzado no daña a la seta", seta.vida.vida == vida_ini, "%d -> %d" % [vida_ini, seta.vida.vida])
	ok("lanzarlo no deja un segundo tocón", tocones(padre).size() == tocones_antes + 1)

	# ---- espadazo ----
	j.vida.restaurar()
	var o1 := await preparar(VASIJA, seta)
	await pulsar(&"atacar")
	var vasija_rota := await esperar_hasta(esta_liberado.bind(weakref(o1)), 900)
	ok("el espadazo rompe la vasija", vasija_rota)

	tocones_antes = tocones(padre).size()
	var o2 := await preparar(ARBUSTO, seta)
	await pulsar(&"atacar")
	var arbusto_roto := await esperar_hasta(esta_liberado.bind(weakref(o2)), 900)
	ok("el espadazo rompe el arbusto", arbusto_roto)
	ok("y deja un tocón", tocones(padre).size() == tocones_antes + 1)

	var o3 := await preparar(PIEDRA, seta)
	await pulsar(&"atacar")
	await ticks(240)
	ok("el espadazo no rompe la piedra", is_instance_valid(o3))
