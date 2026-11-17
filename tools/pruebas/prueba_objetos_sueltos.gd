extends "res://tools/pruebas/base_prueba.gd"
## Objetos sueltos (ObjetoSuelto: monedas y manzanas) y ComponenteManzano en el bosque: el manzano
## se sacude con cada golpe de espada y suelta 1-2 manzanas entre el 3.er y el 5.º, el pino no
## reacciona, recogida al pisar, inventario lleno las deja en el suelo, la seta suelta monedas que
## saltan y se recogen, caducidad con parpadeo, moneda bajo el jugador, y el manzano vuelve a dar
## al reentrar en la zona.

const ESC_MANZANA := "res://scenes/items/manzana_suelta.tscn"
const ESC_MONEDA := "res://scenes/items/moneda.tscn"


func esperar_zona() -> void:
	for i in 600:
		await get_tree().physics_frame
		if not game.cambiando and j.estado == Jugador.Estado.NORMAL:
			break
	await ticks(20)


func sueltos(padre: Node, de_manzana: bool) -> Array:
	return padre.get_children().filter(func(n: Node) -> bool:
		return n is ObjetoSuelto and ((n as ObjetoSuelto).objeto != null) == de_manzana)


func componente(d: Decorado) -> ComponenteManzano:
	for c in d.get_children():
		if c is ComponenteManzano:
			return c
	return null


func dormir_enemigos() -> void:
	for n in game.find_children("*", "SetaBomba", true, false) + game.find_children("*", "FlorFalsa", true, false):
		(n as Node).process_mode = Node.PROCESS_MODE_DISABLED


func lejos() -> void:
	j.global_position = Vector2(60, 60)
	j.velocity = Vector2.ZERO


func vaciar_manzanas() -> void:
	EstadoJuego.gastar_objeto(EstadoJuego.OBJ_MANZANA, EstadoJuego.cantidad(EstadoJuego.OBJ_MANZANA))


func buscar_arbol() -> Decorado:
	for n in game.find_children("Manzano11", "Decorado", true, false):
		return n
	return null


func ejecutar() -> void:
	await crear_game(true, true)
	game.cambiar_zona("res://scenes/levels/bosque.tscn", "desde_pueblo")
	await ticks(5)
	await esperar_zona()
	dormir_enemigos()
	vaciar_manzanas()
	j.vida.vida_max = 999
	j.vida.restaurar()

	# --- Manzano con la espada ---
	var arbol := buscar_arbol()
	var comp := componente(arbol)
	ok("manzano tiene ComponenteManzano", comp != null)
	ok("manzano en capa interactuable", arbol.get_collision_layer_value(Capas.NUMERO_INTERACTUABLE))
	var pino: Decorado = null
	for n in game.find_children("*", "Decorado", true, false):
		var d := n as Decorado
		if d.textura and d.textura.resource_path.get_file().begins_with("pino"):
			pino = d
			break
	ok("pino sin componente ni capa interactuable", pino != null and componente(pino) == null and not pino.get_collision_layer_value(Capas.NUMERO_INTERACTUABLE))
	var forma_a := (arbol.get_node(^"Colision") as CollisionShape2D).shape
	var forma_p := (pino.get_node(^"Colision") as CollisionShape2D).shape
	ok("formas propias (no compartidas)", forma_a != forma_p)
	# La forma se reutiliza al cambiar propiedades.
	arbol.base = Vector2(38, 11)
	ok("_actualizar reutiliza su forma", (arbol.get_node(^"Colision") as CollisionShape2D).shape == forma_a)
	arbol.base = Vector2.ZERO

	var padre := arbol.get_parent()
	var golpes := [0]
	arbol.golpeado.connect(func() -> void: golpes[0] += 1)
	var sprite := arbol.get_node(^"Sprite") as Sprite2D
	var sacudidas := 0
	var golpe_suelta := -1
	for intento in 9:
		j.global_position = arbol.global_position + Vector2(-27, -5)
		j.velocity = Vector2.ZERO
		j.animador.mirar(Vector2.RIGHT)
		await ticks(2)
		var g0: int = golpes[0]
		var vista := false
		accion(&"atacar", true)
		for t in 120:
			await get_tree().physics_frame
			if t == 3:
				accion(&"atacar", false)
			if sprite.position.x != 0.0:
				vista = true
			if comp._sin_manzanas and golpe_suelta < 0:
				golpe_suelta = golpes[0]
				lejos() # que no las recoja al caer
		if golpes[0] > g0 and vista:
			sacudidas += 1
		if golpe_suelta >= 0 and golpes[0] >= golpe_suelta + 3:
			break
		if golpe_suelta >= 0:
			continue
	lejos()
	await ticks(150)
	var manz := sueltos(padre, true)
	ok("espada: cae entre el golpe 3 y 5", golpe_suelta >= 3 and golpe_suelta <= 5, "golpe %d" % golpe_suelta)
	ok("espada: caen 1-2 manzanas", manz.size() >= 1 and manz.size() <= 2, str(manz.size()))
	ok("se sacude con cada golpe", sacudidas == golpes[0] and golpes[0] >= golpe_suelta + 3, "%d sacudidas / %d golpes" % [sacudidas, golpes[0]])
	var delante := true
	for m in manz:
		var o := m as ObjetoSuelto
		delante = delante and o._en_suelo and o.global_position.distance_to(arbol.global_position + Vector2(0, 8)) < 45.0
	ok("manzanas en el suelo delante del tronco", delante)
	ok("no da más tras seguir golpeando", sueltos(padre, true).size() == manz.size())

	# --- Pino: no reacciona ---
	var sp := pino.get_node(^"Sprite") as Sprite2D
	var hijos := pino.get_parent().get_child_count()
	j.global_position = pino.global_position + Vector2(-27, -5)
	j.animador.mirar(Vector2.RIGHT)
	var movido := false
	accion(&"atacar", true)
	for t in 100:
		await get_tree().physics_frame
		if t == 3:
			accion(&"atacar", false)
		movido = movido or sp.position.x != 0.0
	pino.recibir_golpe(1, Vector2.ZERO)
	await ticks(10)
	ok("pino no reacciona", not movido and sp.position.x == 0.0 and pino.get_parent().get_child_count() == hijos)
	lejos()

	# --- Recoger manzanas ---
	vaciar_manzanas()
	for m in manz:
		j.global_position = (m as Node2D).global_position
		await ticks(4)
	ok("manzanas recogidas al pisarlas", EstadoJuego.cantidad(EstadoJuego.OBJ_MANZANA) == manz.size(), str(EstadoJuego.cantidad(EstadoJuego.OBJ_MANZANA)))
	lejos()
	await ticks(60)

	# --- Inventario lleno: se queda hasta que haya sitio ---
	EstadoJuego.agregar_objeto(EstadoJuego.OBJ_MANZANA, 9 - EstadoJuego.cantidad(EstadoJuego.OBJ_MANZANA))
	var pos_m := arbol.global_position + Vector2(0, 40)
	ObjetoSuelto.soltar(load(ESC_MANZANA) as PackedScene, padre, pos_m, 1)
	await ticks(150)
	var llena := sueltos(padre, true)
	ok("manzana suelta a mano", llena.size() == 1)
	var mz := llena[0] as ObjetoSuelto
	j.global_position = mz.global_position
	await ticks(30)
	ok("con 9 se queda en el suelo", is_instance_valid(mz) and not mz._recogida and EstadoJuego.cantidad(EstadoJuego.OBJ_MANZANA) == 9)
	EstadoJuego.gastar_objeto(EstadoJuego.OBJ_MANZANA)
	await ticks(5)
	ok("al gastar una se recoge", mz._recogida and EstadoJuego.cantidad(EstadoJuego.OBJ_MANZANA) == 9)
	lejos()
	await ticks(60)

	# --- Seta: monedas ---
	var seta := game.find_children("*", "SetaBomba", true, false)[0] as SetaBomba
	var p_seta := seta.get_parent()
	var muerte := seta.get_node(^"Muerte") as ComponenteMuerte
	var monedas0 := EstadoJuego.monedas
	seta.vida.recibir_danio(99)
	await ticks(2)
	var mons := sueltos(p_seta, false)
	ok("seta suelta moneda(s)", mons.size() == muerte.monedas and mons.size() > 0, "%d de %d" % [mons.size(), muerte.monedas])
	ok("escena_moneda de respaldo cargada", muerte.escena_moneda != null and muerte.escena_moneda.resource_path == ESC_MONEDA)
	var salto := false
	for t in 150:
		await get_tree().physics_frame
		for m in mons:
			if is_instance_valid(m) and (m as ObjetoSuelto)._altura > 2.0:
				salto = true
	ok("monedas saltan", salto)
	var en_suelo := mons.all(func(m: ObjetoSuelto) -> bool: return m._en_suelo)
	ok("monedas aterrizan", en_suelo)
	for m in mons:
		j.global_position = (m as Node2D).global_position
		await ticks(4)
	ok("monedas recogidas", EstadoJuego.monedas == monedas0 + mons.size(), "%d -> %d" % [monedas0, EstadoJuego.monedas])
	lejos()

	# --- Caducidad ---
	var cad := (load(ESC_MONEDA) as PackedScene).instantiate() as ObjetoSuelto
	cad.duracion = 1.0
	cad.tiempo_parpadeo = 0.6
	cad.position = arbol.global_position + Vector2(80, 60)
	padre.add_child(cad)
	var oculto := false
	for t in 240:
		await get_tree().physics_frame
		if not is_instance_valid(cad):
			break
		oculto = oculto or not cad.sprite.visible
	ok("moneda parpadea y caduca", oculto and not is_instance_valid(cad))

	# --- Jugador ya encima al aterrizar ---
	j.global_position = arbol.global_position + Vector2(80, 60)
	j.velocity = Vector2.ZERO
	await ticks(5)
	var m1 := EstadoJuego.monedas
	ObjetoSuelto.soltar(load(ESC_MONEDA) as PackedScene, padre, j.global_position, 1)
	await ticks(200)
	ok("moneda con el jugador encima se recoge al aterrizar", EstadoJuego.monedas == m1 + 1, "%d -> %d" % [m1, EstadoJuego.monedas])
	lejos()

	# --- Al volver a entrar, el manzano vuelve a dar ---
	game.cambiar_zona("res://scenes/levels/bosque.tscn", "desde_pueblo")
	await ticks(5)
	await esperar_zona()
	dormir_enemigos()
	arbol = buscar_arbol()
	comp = componente(arbol)
	padre = arbol.get_parent()
	ok("zona recargada: manzano nuevo con manzanas", comp != null and not comp._sin_manzanas)
	for i in 5:
		arbol.recibir_golpe(1, Vector2.ZERO)
	await ticks(5)
	var n2 := sueltos(padre, true).size()
	ok("vuelve a dar al reentrar", n2 >= 1 and n2 <= 2, str(n2))
