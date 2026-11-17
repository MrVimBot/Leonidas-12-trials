extends "res://tools/pruebas/base_prueba.gd"
## Combate en el bosque con eventos reales: HUD inicial, parpadeo al recibir daño, matar una seta con
## la espada (suelta monedas), flor escondida invulnerable que despierta al acercarse, contacto de
## la seta que quita vida y el HUD lo refleja, manzano que suelta manzanas, hablar con un NPC,
## detección (`ComponenteDeteccion`, también unitaria) y vida cargada de una partida.
## Usa miembros privados del HUD (`_estados`) porque los corazones solo exponen su textura.

func esperar_zona() -> void:
	await esperar_normal()
	await ticks(20)


func ejecutar() -> void:
	# ---- c) HUD al arrancar (vida 12, estamina llena) ----
	await crear_game(true, true)
	var hud := game.get_node(^"HUD") as HUD
	var cor := hud.corazones
	var llenos := 0
	for c in cor.get_children():
		if (c as TextureRect).texture == hud._estados[4]:
			llenos += 1
	ok("c) HUD: 3 corazones llenos", cor.get_child_count() == 3 and llenos == 3, "%d/%d" % [llenos, cor.get_child_count()])
	ok("c) HUD: estamina valor inicial 1.0", is_equal_approx(hud.barra_estamina.valor, 1.0), str(hud.barra_estamina.valor))

	# ---- d) parpadeo ----
	ok("d) parpadeo parado al inicio", not j.parpadeo.is_processing())
	j.vida.recibir_danio(1)
	await ticks(3)
	ok("d) parpadeo procesando al recibir daño", j.parpadeo.is_processing())
	var visto_bajo := false
	for i in 150:
		await get_tree().physics_frame
		await get_tree().process_frame
		if j.parpadeo.objetivo.modulate.a < 1.0:
			visto_bajo = true
	await ticks(120)
	ok("d) alfa bajó durante el parpadeo", visto_bajo)
	ok("d) al acabar alfa == 1 y process apagado", is_equal_approx(j.parpadeo.objetivo.modulate.a, 1.0) and not j.parpadeo.is_processing())
	j.vida.restaurar()

	# ---- a) combate en el bosque ----
	game.cambiar_zona("res://scenes/levels/bosque.tscn", "desde_pueblo")
	await ticks(5)
	await esperar_zona()
	var setas := game.find_children("*", "SetaBomba", true, false)
	var flores := game.find_children("*", "FlorFalsa", true, false)
	ok("a) hay setas y flores", setas.size() > 0 and flores.size() > 0, "%d/%d" % [setas.size(), flores.size()])
	var seta := setas[0] as SetaBomba
	seta.set_physics_process(false)
	var monedas_antes := game.find_children("*", "ObjetoSuelto", true, false).size()
	j.global_position = seta.global_position + Vector2(-14, 0)
	j.velocity = Vector2.ZERO
	j.animador.mirar(Vector2.RIGHT)
	var vida_ini := seta.vida.vida
	var golpes := 0
	for i in 8:
		if not is_instance_valid(seta) or seta.vida.muerto:
			break
		await pulsar(&"atacar")
		await ticks(130) # animación + fin de la invulnerabilidad
		golpes += 1
		j.global_position = seta.global_position + Vector2(-14, 0) if is_instance_valid(seta) else j.global_position
		j.animador.mirar(Vector2.RIGHT)
	ok("a) seta recibió daño y murió con la espada", not is_instance_valid(seta) or seta.vida.muerto, "vida_ini=%d golpes=%d" % [vida_ini, golpes])
	await ticks(200)
	var monedas_despues := game.find_children("*", "ObjetoSuelto", true, false).size()
	EstadoJuego.monedas = EstadoJuego.monedas
	ok("a) seta soltó monedas", monedas_despues > monedas_antes or EstadoJuego.monedas > 0, "%d -> %d, cartera %d" % [monedas_antes, monedas_despues, EstadoJuego.monedas])

	# Flor escondida: invulnerable; despierta al acercarse
	var flor := flores[0] as FlorFalsa
	flor.set_physics_process(false)
	await ticks(2)
	j.global_position = flor.global_position + Vector2(-14, 0)
	j.animador.mirar(Vector2.RIGHT)
	var vf := flor.vida.vida
	await pulsar(&"atacar")
	await ticks(100)
	ok("a) flor escondida no recibe daño", flor.vida.vida == vf and flor.estado == FlorFalsa.Estado.ESCONDIDA, "vida %d estado %d" % [flor.vida.vida, flor.estado])
	flor.set_physics_process(true)
	await ticks(180)
	ok("a) flor despierta al acercarse", flor.estado != FlorFalsa.Estado.ESCONDIDA, "estado %d" % flor.estado)

	# Contacto de un enemigo (seta viva distinta)
	var seta2: SetaBomba = null
	for s in setas:
		if is_instance_valid(s) and s != seta and not (s as SetaBomba).vida.muerto:
			seta2 = s
			break
	seta2.set_physics_process(false)
	j.global_position = flor.global_position + Vector2(300, 300) # lejos de la flor
	await ticks(200) # que acabe cualquier invulnerabilidad
	j.vida.restaurar()
	await ticks(130)
	j.global_position = seta2.global_position + Vector2(4, 0)
	var antes := j.vida.vida
	await ticks(10)
	ok("a) contacto de seta quita vida", j.vida.vida < antes, "%d -> %d" % [antes, j.vida.vida])
	var cuartos_hud := 0
	for i in cor.get_child_count():
		var t := (cor.get_child(i) as TextureRect).texture
		cuartos_hud += hud._estados.find(t)
	ok("a) HUD refleja la vida", cuartos_hud == j.vida.vida, "hud=%d vida=%d" % [cuartos_hud, j.vida.vida])
	# Manzano
	var arbol: Decorado = null
	for n in game.find_children("*", "Decorado", true, false):
		if (n as Node).get_children().any(func(c: Node) -> bool: return c is ComponenteManzano):
			arbol = n
			break
	if arbol:
		var hijos := arbol.get_parent().get_child_count()
		for i in 6:
			arbol.recibir_golpe(1, Vector2.ZERO)
		await ticks(5)
		ok("a) manzano suelta manzanas", arbol.get_parent().get_child_count() > hijos)
	# Hablar con NPC
	j.vida.restaurar()
	game.cambiar_zona("res://scenes/levels/pueblo.tscn", "inicio")
	await ticks(5)
	await esperar_zona()
	var burro: NPC = null
	for n in game.find_children("Burro", "NPC", true, false):
		burro = n
	burro.set_physics_process(false)
	j.global_position = burro.global_position + Vector2(-12, 0)
	j.animador.mirar(Vector2.RIGHT)
	await ticks(3)
	var obj := j.interaccion.buscar()
	ok("a) interaccion.buscar encuentra al NPC", obj != null, str(obj))
	await pulsar(&"interactuar")
	await ticks(5)
	ok("a) interactuar abre el diálogo", Dialogos.abierto)
	if Dialogos.abierto:
		Dialogos.cerrar()
	await ticks(10)

	# ---- b) detección ----
	game.cambiar_zona("res://scenes/levels/bosque.tscn", "desde_pueblo")
	await ticks(5)
	await esperar_zona()
	var s3 := game.find_children("*", "SetaBomba", true, false)[1] as SetaBomba
	s3.set_physics_process(false)
	j.global_position = s3.global_position + Vector2(400, 0)
	await ticks(5)
	ok("b) seta no ve al jugador lejos", not s3.deteccion.viendo())
	j.global_position = s3.global_position + Vector2(30, 0)
	await ticks(3)
	ok("b) seta ve al jugador cerca", s3.deteccion.viendo())
	j.global_position = s3.global_position + Vector2(400, 0)
	await ticks(3)
	ok("b) seta pierde al jugador", not s3.deteccion.viendo())
	# jugador desactivado (en barco): sigue siendo el candidato como antes
	# Candidato liberado y recreado (unitario)
	var d := ComponenteDeteccion.new()
	var cuerpo := Node2D.new()
	game.add_child(cuerpo)
	d.cuerpo = cuerpo
	d.grupo = &"grupo_prueba_f3"
	cuerpo.add_child(d)
	var a := Node2D.new()
	a.add_to_group(&"grupo_prueba_f3")
	game.add_child(a)
	await ticks(3)
	ok("b) unitario: ve al primero", d.viendo() and d.objetivo == a)
	a.free()
	await ticks(3)
	ok("b) unitario: objetivo liberado -> pierde", not d.viendo())
	var b := Node2D.new()
	b.add_to_group(&"grupo_prueba_f3")
	game.add_child(b)
	await ticks(3)
	ok("b) unitario: ve al nuevo tras recrearse", d.viendo() and d.objetivo == b)
	cuerpo.queue_free()
	b.queue_free()

	# ---- c) vida cargada ----
	var lg := DatosLugar.new()
	lg.zona = "res://scenes/levels/pueblo.tscn"
	lg.vida = 5
	EstadoJuego.lugar_cargado = lg
	await crear_game(true, true)
	hud = game.get_node(^"HUD") as HUD
	var cu := 0
	for i in hud.corazones.get_child_count():
		cu += hud._estados.find((hud.corazones.get_child(i) as TextureRect).texture)
	ok("c) cargada: jugador.vida == 5", j.vida.vida == 5, str(j.vida.vida))
	ok("c) cargada: HUD muestra 5 cuartos", cu == 5, str(cu))
	ok("c) cargada: no muerto", not j.vida.muerto)
