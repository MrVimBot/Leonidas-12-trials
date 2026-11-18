extends "res://tools/pruebas/base_prueba.gd"
## Gamba del nivel 2 (`scenes/enemies/gamba.tscn`), instanciada junto al jugador en el bosque:
## pasa a perseguir y se acerca, muerde (2 cuartos) con el jugador quieto, muere a dos espadazos
## y suelta 1 moneda, y tres gambas persiguiendo no se apilan.

const ESCENA := preload("res://scenes/enemies/gamba.tscn")


func nueva_gamba(pos: Vector2, semilla := 7) -> Gamba:
	var g := ESCENA.instantiate() as Gamba
	g.semilla = semilla
	game.get_node(^"Mundo").add_child(g)
	g.global_position = pos
	return g


func ejecutar() -> void:
	await crear_game(true, true)
	game.cambiar_zona("res://scenes/levels/bosque.tscn", "desde_pueblo")
	await ticks(5)
	await esperar_normal()
	await ticks(20)
	# Quita a los enemigos de la zona para que no estorben.
	for e in get_tree().get_nodes_in_group(&"enemigos"):
		e.queue_free()
	await ticks(3)
	j.vida.restaurar()
	ok("0) el jugador tiene la espada", EstadoJuego.tiene_espada)
	var base := j.global_position

	# 1) Persigue: a 60 px la ve (radio 80) y se acerca.
	var g := nueva_gamba(base + Vector2(60, 0))
	await ticks(5)
	ok("1) ve al jugador y persigue", g.estado == Gamba.Estado.PERSEGUIR, str(g.estado))
	var d0 := g.global_position.distance_to(j.global_position)
	await ticks(60)
	ok("1) se acerca", g.global_position.distance_to(j.global_position) < d0 - 10.0,
		"%.1f -> %.1f" % [d0, g.global_position.distance_to(j.global_position)])

	# 2) Muerde al jugador quieto: -2 cuartos (el contacto quita 1: se mira que baje al menos 2).
	var vida_antes := j.vida.vida
	var mordio := await esperar_hasta(func() -> bool: return j.vida.vida <= vida_antes - 2, 900)
	ok("2) muerde y quita vida", mordio, "%d -> %d" % [vida_antes, j.vida.vida])
	ok("2) pasa por ATACAR/RECARGA", g.estado in [Gamba.Estado.ATACAR, Gamba.Estado.RECARGA, Gamba.Estado.DANO, Gamba.Estado.PERSEGUIR])

	# 3) Dos espadazos la matan y suelta 1 moneda.
	g.set_physics_process(false) # sin cerebro ni contacto: solo se prueba el daño recibido
	(g.get_node(^"Contacto") as Hitbox).activo = false
	await esperar_hasta(func() -> bool: return j.estado == Jugador.Estado.NORMAL, 600)
	await ticks(200) # que acabe la invulnerabilidad y el retroceso
	j.vida.restaurar()
	g.global_position = j.global_position + Vector2(-14, 0)
	var sueltos_antes := game.find_children("*", "ObjetoSuelto", true, false).size()
	var monedas_antes := EstadoJuego.monedas
	var golpes := 0
	for i in 6:
		if not is_instance_valid(g) or g.vida.muerto:
			break
		j.global_position = g.global_position + Vector2(14, 0)
		j.velocity = Vector2.ZERO
		j.animador.mirar(Vector2.LEFT)
		await pulsar(&"atacar")
		await ticks(130)
		golpes += 1
	ok("3) muere con dos espadazos", (not is_instance_valid(g) or g.vida.muerto) and golpes == 2, "golpes=%d vida=%d" % [golpes, g.vida.vida if is_instance_valid(g) else 0])
	await ticks(60)
	# La moneda rebota al azar y a veces cae bajo Leonidas, que la recoge: cuenta también esa.
	var sueltos := game.find_children("*", "ObjetoSuelto", true, false).size() - sueltos_antes
	var recogidas := EstadoJuego.monedas - monedas_antes
	ok("3) suelta 1 moneda", sueltos + recogidas == 1, "sueltas=%d recogidas=%d" % [sueltos, recogidas])
	await ticks(200)

	# 4) Tres gambas juntas persiguiendo no se ven apiladas: distancia con la vertical al doble
	# (como `Gamba._separacion`: el dibujo es más ancho que alto) de al menos 14 px.
	j.vida.restaurar()
	j.global_position = base
	var grupo: Array[Gamba] = []
	for i in 3:
		grupo.append(nueva_gamba(base + Vector2(60 + i * 2, i * 3), 11 + i))
	await ticks(240) # 2 s
	var min_d := INF
	for a in 3:
		for b in range(a + 1, 3):
			min_d = minf(min_d, grupo[a].global_position.distance_to(grupo[b].global_position))
	ok("4) tres gambas no se apilan", min_d >= 14.0, "distancia mínima %.1f" % min_d)
	ok("4) todas persiguen o atacan", grupo.all(func(x: Gamba) -> bool: return x.estado != Gamba.Estado.DEAMBULAR))
