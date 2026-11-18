extends "res://tools/pruebas/base_prueba.gd"
## NPC y enemigos que se mueven por su cuenta: paseo dentro de `radio_paseo`, fijos que no se
## mueven, fachada NPC → ZonaDialogo (diálogo, burbuja de tienda, recordatorio de sabio), parar al
## hablar y reanudar, NPC contra un muro; y en el bosque la seta (deambula, persigue, explota, se
## esconde y vuelve) y la flor (reaparece sobre suelo y dentro de su radio).
## Usa miembros privados (`_destino`, `_caminando`, `_origen`, `_burbuja`) sin alternativa pública.

func npc(nombre: String) -> NPC:
	return game.zona_actual.find_child(nombre, true, false) as NPC


func ejecutar() -> void:
	await crear_game(true, true)
	var burro := npc("Burro")
	var zorro := npc("Zorro")
	var tend := npc("Tendedera")
	var sabios: Array[NPC] = [npc("Sabio1"), npc("Sabio2"), npc("Sabio3"), npc("Sabio4")]
	j.vida.invulnerable_extra = true
	# Lejos de todos para que ninguna burbuja ni nada moleste.
	j.global_position = Vector2(920, 1000)
	var c_burro := burro.global_position
	var c_zorro := zorro.global_position
	var c_tend := tend.global_position
	var c_sab: Array[Vector2] = []
	for s in sabios:
		c_sab.append(s.global_position)
	var max_b := 0.0
	var max_z := 0.0
	var mov_tend := 0.0
	var mov_sab := 0.0
	for t in 3600: # 30 s a 120 ticks/s
		await get_tree().physics_frame
		max_b = maxf(max_b, burro.global_position.distance_to(c_burro))
		max_z = maxf(max_z, zorro.global_position.distance_to(c_zorro))
		mov_tend = maxf(mov_tend, tend.global_position.distance_to(c_tend))
		for i in 4:
			mov_sab = maxf(mov_sab, sabios[i].global_position.distance_to(c_sab[i]))
	ok("Burro pasea sin salirse de radio_paseo", max_b > 3.0 and max_b <= burro.radio_paseo + 3.0, "max=%.1f radio=%.0f" % [max_b, burro.radio_paseo])
	ok("Zorro pasea sin salirse de radio_paseo", max_z > 3.0 and max_z <= zorro.radio_paseo + 3.0, "max=%.1f radio=%.0f" % [max_z, zorro.radio_paseo])
	ok("Tendedera y sabios no se mueven", mov_tend == 0.0 and mov_sab == 0.0)
	ok("sprite aplicado por %Sprite", burro.get_node(^"Sprite").sprite_frames != null and (burro.get_node(^"Sprite") as AnimatedSprite2D).offset == burro.desplazamiento_sprite)

	# Hablar con el burro.
	var zb := burro.get_node(^"ZonaDialogo") as ZonaDialogo
	ok("fachada: dialogo del burro copiado a ZonaDialogo", zb.dialogo == burro.dialogo and zb.dialogo != null)
	j.global_position = burro.global_position + Vector2(30, 0)
	zb.interactuar(j) # sin await: abre el diálogo
	await ticks(10)
	ok("hablar: estado HABLANDO y mira al jugador", burro.estado == NPC.Estado.HABLANDO and burro.get_node(^"Animador").direccion == Vector2.RIGHT, str(burro.get_node(^"Animador").direccion))
	var p0 := burro.global_position
	await ticks(60)
	ok("hablar: no se mueve", burro.global_position.distance_to(p0) < 1.0)
	for i in 40:
		if not Dialogos.abierto:
			break
		await pulsar(&"interactuar")
	ok("diálogo cerrado", not Dialogos.abierto)
	ok("vuelve a pasear", burro.estado == NPC.Estado.PASEANDO)
	j.global_position = Vector2(920, 1000)
	var c2 := burro.global_position
	var mov := 0.0
	for t in 1200:
		await get_tree().physics_frame
		mov = maxf(mov, burro.global_position.distance_to(c2))
	ok("tras hablar se vuelve a mover (%.1f)" % mov, mov > 3.0)

	# Tendedera: burbuja de tienda y tienda.
	var zt := tend.get_node(^"ZonaDialogo") as ZonaDialogo
	ok("fachada: tienda y burbuja copiadas", zt.tienda != null and zt.tienda == tend.tienda and zt.tipo == ZonaDialogo.Tipo.TIENDA and zt.posicion_burbuja == Vector2(0, -36))
	j.global_position = tend.global_position + Vector2(0, 14)
	await ticks(20)
	ok("Tendedera muestra la burbuja $", zt._burbuja.visible and zt._burbuja.texture == ZonaDialogo.BURBUJAS[ZonaDialogo.Tipo.TIENDA] and zt._burbuja.position == Vector2(0, -36))
	EstadoJuego.monedas = 20
	zt.interactuar(j)
	await ticks(10)
	for i in 40:
		if Tienda.abierto:
			break
		await pulsar(&"interactuar")
	ok("se abre la tienda", Tienda.abierto)
	for i in 10:
		if not Tienda.abierto:
			break
		await pulsar(&"pirueta")
	ok("se cierra la tienda", not Tienda.abierto)
	for i in 40:
		if not Dialogos.abierto:
			break
		await pulsar(&"interactuar")

	# Sabios con misión: «…» y recordatorio.
	var sb := sabios[0]
	var zs := sb.get_node(^"ZonaDialogo") as ZonaDialogo
	j.global_position = sb.global_position + Vector2(0, 16)
	await ticks(20)
	ok("sabio: recordatorio asignado y burbuja «…»", zs.dialogo != null and zs.dialogo == sb.dialogo and zs._burbuja.visible and zs._burbuja.texture == ZonaDialogo.BURBUJAS[ZonaDialogo.Tipo.HABLAR] and zs._burbuja.position == Vector2(0, -60))
	zs.interactuar(j)
	await ticks(10)
	ok("sabio: habla", Dialogos.abierto)
	for i in 40:
		if not Dialogos.abierto:
			break
		await pulsar(&"interactuar")

	# NPC contra un muro.
	var raiz := Node2D.new()
	get_tree().root.add_child(raiz)
	var muro := StaticBody2D.new()
	muro.collision_layer = 1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(20, 400)
	cs.shape = r
	muro.add_child(cs)
	muro.position = Vector2(5000 + 10 + 6, 5000) # cara izquierda en x = 5006
	raiz.add_child(muro)
	var n := (load("res://scenes/npcs/npc.tscn") as PackedScene).instantiate() as NPC
	n.sprite_frames = load("res://resources/sprite_frames/npc_burro.tres")
	n.radio_paseo = 60.0
	n.position = Vector2(4980, 5000)
	raiz.add_child(n)
	var pas := n.get_node(^"Paseo") as ComponentePaseo
	pas.rng.seed = 5
	var choques := 0
	var parados_tras_choque := 0
	var max_x := -INF
	var ult_dest := Vector2.INF
	var cambios := 0
	var se_aleja_tras_choque := false
	# Choque contra el muro en este tick (normal hacia la izquierda), visto por la señal.
	var choco_muro := [false]
	(n.get_node(^"Movimiento") as ComponenteMovimiento).choco.connect(
		func(c: KinematicCollision2D) -> void: choco_muro[0] = choco_muro[0] or c.get_normal().x < -0.5)
	# ¿Iba andando hacia un punto detrás del muro (inalcanzable) al empezar este tick?
	var iba_hacia_muro := false
	for t in 12000:
		choco_muro[0] = false
		await get_tree().physics_frame
		max_x = maxf(max_x, n.global_position.x)
		if pas._destino != ult_dest:
			cambios += 1
			ult_dest = pas._destino
		# Regla: si choca yendo HACIA el muro, se para en ese mismo tick. Pegado pero alejándose
		# no cuenta como choque contra él: debe seguir andando (antes se paraba en el acto y se
		# quedaba en la pared para siempre).
		if choco_muro[0] and iba_hacia_muro:
			choques += 1
			if not pas._caminando:
				parados_tras_choque += 1
		if choques > 0 and n.global_position.x < 4990.0:
			se_aleja_tras_choque = true
		iba_hacia_muro = pas._caminando and pas._destino.x > n.global_position.x + 0.5
	ok("NPC no atraviesa el muro (max x %.2f, límite 5000)" % max_x, max_x <= 5000.1)
	ok("choca contra el muro (%d) y se para (%d) y sigue eligiendo destinos (%d)" % [choques, parados_tras_choque, cambios], choques > 0 and parados_tras_choque == choques and cambios > 5)
	ok("tras chocar se despega del muro y sigue paseando", se_aleja_tras_choque)
	raiz.queue_free()

	# Bosque.
	game.cambiar_zona("res://scenes/levels/bosque.tscn", "inicio")
	await ticks(20)
	for i in 600:
		await get_tree().physics_frame
		if not game.cambiando:
			break
	await ticks(5)
	var zona := game.zona_actual as Zona
	ok("zona bosque cargada", zona != null and zona.scene_file_path.ends_with("bosque.tscn"))
	j.vida.invulnerable_extra = true
	var setas: Array[SetaBomba] = []
	var flores: Array[FlorFalsa] = []
	for h in zona.find_children("*", "SetaBomba", true, false):
		setas.append(h as SetaBomba)
	for h in zona.find_children("*", "FlorFalsa", true, false):
		flores.append(h as FlorFalsa)
	ok("hay setas y flores", setas.size() >= 1 and flores.size() >= 1, "%d/%d" % [setas.size(), flores.size()])
	var seta := setas[0]
	var origen := seta.global_position
	j.global_position = origen + Vector2(600, 600) # lejos
	var maxd := 0.0
	for t in 4800:
		await get_tree().physics_frame
		maxd = maxf(maxd, seta.global_position.distance_to(origen))
	ok("seta deambula (%.1f) dentro de radio_deambular %.0f" % [maxd, seta.radio_deambular], maxd > 3.0 and maxd <= seta.radio_deambular + 3.0)
	# persigue
	var dir_u := Vector2(1, 0)
	j.global_position = seta.global_position + dir_u * 60.0
	await ticks(20)
	ok("seta persigue al verlo", seta.estado == SetaBomba.Estado.PERSEGUIR)
	var vio_explotar := false
	var vio_escondida := false
	for t in 2000:
		await get_tree().physics_frame
		# El jugador se queda quieto cerca de la seta para provocar la explosión.
		if seta.estado == SetaBomba.Estado.PERSEGUIR:
			j.global_position = seta.global_position + Vector2(18, 0)
		if seta.estado == SetaBomba.Estado.EXPLOTAR:
			vio_explotar = true
		if seta.estado == SetaBomba.Estado.ESCONDIDA:
			vio_escondida = true
			j.global_position = seta.global_position + Vector2(500, 500)
		if vio_escondida and seta.estado == SetaBomba.Estado.DEAMBULAR:
			break
	ok("seta explota, se esconde y vuelve a deambular", vio_explotar and vio_escondida and seta.estado == SetaBomba.Estado.DEAMBULAR, str(seta.estado))
	var p1 := seta.global_position
	var camino := 0.0
	for t in 1200:
		await get_tree().physics_frame
		camino = maxf(camino, seta.global_position.distance_to(p1))
	ok("la seta anda otra vez (%.1f)" % camino, camino > 3.0)
	# Flor: reapariciones forzadas.
	var flor := flores[0]
	var f_origen: Vector2 = flor._origen
	var libres := 0
	var bien := true
	for i in 60:
		flor._reaparecer_en_otro_sitio()
		var p: Vector2 = flor.global_position
		var celda := zona.suelo.local_to_map(zona.suelo.to_local(p))
		if zona.suelo.get_cell_source_id(celda) == -1 or p.distance_to(f_origen) > flor.radio_reaparicion + 1.0:
			bien = false
		libres += 1
	ok("flor: 60 reapariciones sobre suelo y a <= radio_reaparicion del origen", bien and Zona.de(flor) == zona)
	# Flor: reaparición natural.
	flor.tiempo_fuera = 0.5
	var pf := flor.global_position
	j.global_position = flor.global_position + Vector2(40, 0)
	var salio := false
	var reaparecio := false
	for t in 3000:
		await get_tree().physics_frame
		if flor.estado == FlorFalsa.Estado.ESCONDERSE:
			salio = true
		if salio and flor.estado == FlorFalsa.Estado.ESCONDIDA:
			reaparecio = true
			break
	ok("flor sale, se esconde y reaparece (a %.1f de su origen)" % flor.global_position.distance_to(f_origen), reaparecio and flor.global_position.distance_to(f_origen) <= flor.radio_reaparicion + 1.0)
