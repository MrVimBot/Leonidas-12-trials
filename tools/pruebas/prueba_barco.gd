extends "res://tools/pruebas/base_prueba.gd"
## Barco y modo barco: Game + ModoBarco + HUD. Accesos tipados (`Game.actual`, `Jugador.actual`),
## pueblo → playa → mar (Leonidas se oculta y desactiva, aparece el barco, la cámara y el HUD lo
## siguen, micrófono activo), navegar con el viento forzado (`Microfono.nivel_forzado`), premio de
## una moneda por corazón entero al bajar en la orilla contraria (y ninguno al volver), hundirse y
## recargar la zona, tutorial solo la primera vez, y partida cargada directamente en el mar.
## Peligros del mar (tiburón, remolino) y estela: ver la segunda parte. Sin micrófono real.

const PUEBLO := "res://scenes/levels/pueblo.tscn"
const PLAYA := "res://scenes/levels/playa.tscn"
const MAR := "res://scenes/levels/mar.tscn"
const ORILLA := "res://scenes/levels/isla_orilla.tscn"

var modos: Array = []


func al_modo(en_barco: bool, vida: ComponenteVida) -> void:
	modos.append([en_barco, vida])


func ir_barco(ruta: String, entrada: String) -> Dictionary:
	var info := {"visto_cambiando": false}
	game.cambiar_zona(ruta, entrada)
	await get_tree().process_frame
	info.visto_cambiando = game.cambiando
	await esperar_hasta(func() -> bool: return not game.cambiando, 600)
	await ticks(10)
	return info


func cuartos_hud(hud: HUD) -> int:
	var c := 0
	for n in hud.corazones.get_children():
		c += hud._estados.find((n as TextureRect).texture)
	return c


func ejecutar() -> void:
	EstadoJuego.tutorial_barco_visto = true
	Microfono.nivel_forzado = 0.0
	await crear_game(true, true)
	var hud := game.get_node(^"HUD") as HUD
	game.modo_cambio.connect(al_modo)

	# S4: accesos tipados y grupos de escena
	ok("S4 Game.actual", Game.actual(self) == game)
	ok("S4 Jugador.actual", Jugador.actual(self) == j)
	ok("S4 Game en grupo 'game' (escena)", game.is_in_group(&"game"))
	ok("S4 Game.actual fuera del árbol -> null", Game.actual(Node.new()) == null)
	ok("h) depurar_* en debug: misión dada", OS.is_debug_build() and EstadoJuego.mision_recibida)
	ok("h) ruta_zona inicial", game.ruta_zona == PUEBLO, game.ruta_zona)
	ok("h) cambiando false en reposo", not game.cambiando)
	ok("pueblo: sin barco, HUD sin medidor", game.barco == null and not hud.medidor_viento.visible)

	# a) pueblo -> playa -> mar
	var info := await ir_barco(PLAYA, "desde_bosque")
	ok("h) cambiando true durante el fundido", info.visto_cambiando)
	ok("h) cambiando false después; ruta_zona = playa", not game.cambiando and game.ruta_zona == PLAYA, game.ruta_zona)
	modos.clear()
	await ir_barco(MAR, "desde_playa")
	var barco := game.barco
	ok("a) hay barco", barco != null)
	if barco == null:
		terminar()
		return
	ok("a) barco hijo de Game y en grupo 'barco'", barco.get_parent() == game and barco.is_in_group(&"barco"))
	ok("a) jugador oculto y DISABLED", not j.visible and j.process_mode == Node.PROCESS_MODE_DISABLED)
	ok("a) cámara sigue al barco", game.camara.objetivo == barco)
	ok("a) micrófono activo", Microfono.esta_activo())
	ok("a) modo_cambio(true, vida del barco)", modos.size() == 1 and modos[0][0] == true and modos[0][1] == barco.vida, str(modos))
	ok("a) HUD: medidor visible, ranura oculta", hud.medidor_viento.visible and not hud.ranura_objeto.visible)
	ok("a) HUD: sigue la vida del barco", hud._vida == barco.vida and cuartos_hud(hud) == barco.vida.vida)
	ok("a) barco libre (no bloqueado)", not barco.esta_bloqueado())

	# b) navegar
	var p0 := barco.global_position
	var med0 := hud.medidor_viento.valor
	Microfono.nivel_forzado = 1.0
	var dir := &"mover_abajo" if barco.rumbo.y > 0 else &"mover_arriba"
	Input.action_press(dir)
	await ticks(40)
	var med1 := hud.medidor_viento.valor
	var p1 := barco.global_position
	Input.action_release(dir)
	Microfono.nivel_forzado = 0.0
	ok("b) el barco se mueve", p1.distance_to(p0) > 10.0, "%s -> %s" % [p0, p1])
	ok("b) medidor sube", med1 > med0 and med1 > 0.9, "%.2f -> %.2f" % [med0, med1])

	# Cambiar la vida del barco para que el premio sea distinguible: 9 cuartos = 2 corazones enteros
	barco.vida.vida = 9
	var m0 := EstadoJuego.monedas
	# c) cruzar a la otra orilla
	modos.clear()
	await ir_barco(ORILLA, "desde_mar")
	ok("c) premio = corazones enteros (2)", EstadoJuego.monedas - m0 == 2, "%d -> %d" % [m0, EstadoJuego.monedas])
	ok("c) Leonidas a pie: visible, INHERIT", j.visible and j.process_mode == Node.PROCESS_MODE_INHERIT)
	ok("c) micrófono cerrado, game.barco null", not Microfono.esta_activo() and game.barco == null)
	ok("c) HUD sin medidor, sigue la vida del jugador", not hud.medidor_viento.visible and hud.ranura_objeto.visible and hud._vida == j.vida)
	ok("c) modo_cambio(false, vida del jugador)", modos.size() == 1 and modos[0][0] == false and modos[0][1] == j.vida)
	ok("c) cámara sigue al jugador", game.camara.objetivo == j)

	# d) volver por donde se entró: sin premio
	await ir_barco(MAR, "desde_isla")
	ok("d) de nuevo en barco", game.barco != null)
	m0 = EstadoJuego.monedas
	await ir_barco(ORILLA, "desde_mar")
	ok("d) volver a la orilla de salida: sin premio", EstadoJuego.monedas == m0, "%d -> %d" % [m0, EstadoJuego.monedas])
	# y desde la playa, volver a la playa: sin premio
	await ir_barco(PLAYA, "desde_bosque")
	await ir_barco(MAR, "desde_playa")
	m0 = EstadoJuego.monedas
	await ir_barco(PLAYA, "desde_mar")
	ok("d) mar -> playa (origen): sin premio", EstadoJuego.monedas == m0)

	# e) hundirse
	await ir_barco(MAR, "desde_playa")
	var viejo := game.barco
	var pos_entrada := viejo.global_position
	m0 = EstadoJuego.monedas
	var visto_cambiando := false
	viejo.vida.recibir_danio(99)
	for i in 900:
		await get_tree().physics_frame
		if game.cambiando:
			visto_cambiando = true
		if visto_cambiando and not game.cambiando:
			break
	await ticks(10)
	var nuevo := game.barco
	ok("e) fundido durante el hundimiento", visto_cambiando)
	ok("e) barco nuevo con vida llena", nuevo != null and nuevo != viejo and nuevo.vida.vida == nuevo.vida.vida_max)
	ok("e) misma zona y entrada", game.ruta_zona == MAR and nuevo != null and nuevo.global_position.distance_to(pos_entrada) < 1.0)
	ok("e) sin premio", EstadoJuego.monedas == m0)
	ok("e) barco nuevo libre y HUD lo sigue", nuevo != null and not nuevo.esta_bloqueado() and hud._vida == nuevo.vida)
	# Tras hundirse se conserva el origen: volver a la playa sigue sin premio, a la orilla sí
	m0 = EstadoJuego.monedas
	await ir_barco(ORILLA, "desde_mar")
	ok("e) tras hundirse, la otra orilla da premio (3)", EstadoJuego.monedas - m0 == 3, "%d" % (EstadoJuego.monedas - m0))

	# f) tutorial la primera vez
	EstadoJuego.tutorial_barco_visto = false
	game.cambiar_zona(MAR, "desde_isla")
	var abierto := false
	for i in 600:
		await get_tree().physics_frame
		if Dialogos.abierto:
			abierto = true
			break
	var b_tut := game.barco
	ok("f) sale el tutorial", abierto)
	ok("f) barco bloqueado durante el tutorial", b_tut != null and b_tut.esta_bloqueado())
	for i in 60:
		if not Dialogos.abierto:
			break
		await get_tree().process_frame
		await pulsar(&"interactuar")
	ok("f) tutorial cerrado por eventos", not Dialogos.abierto)
	await ticks(90) # calibrar (0,5 s)
	ok("f) barco libre después", b_tut != null and not b_tut.esta_bloqueado())
	ok("f) marcado como visto", EstadoJuego.tutorial_barco_visto)
	await ir_barco(ORILLA, "desde_mar")
	game.cambiar_zona(MAR, "desde_isla")
	var reabre := false
	for i in 200:
		await get_tree().physics_frame
		if Dialogos.abierto:
			reabre = true
	ok("f) no se repite la segunda vez", not reabre)
	await liberar_game()

	# Peligros del mar (tiburón, remolino)
	EstadoJuego.tutorial_barco_visto = true
	await crear_game(true, true)
	await ir_barco(MAR, "desde_playa")
	ok("b) hay barco", game.barco != null)
	for ronda in 2:
		var barco_r := game.barco
		var tib: Node2D = null
		for n in game.find_children("*", "Tiburon", true, false):
			tib = n
			break
		var rem: Remolino = game.find_children("*", "Remolino", true, false)[0]
		# Tiburón
		(tib as Node2D).set("estado", 0)
		barco_r.global_position = tib.global_position + Vector2(50, 0)
		barco_r.velocity = Vector2.ZERO
		await ticks(5)
		var td: ComponenteDeteccion = tib.get(&"deteccion")
		ok("b) ronda %d: tiburón detecta al barco" % ronda, td.viendo() and td.objetivo == barco_r)
		# Remolino
		barco_r.global_position = rem.global_position + Vector2(30, 0)
		barco_r.velocity = Vector2.ZERO
		await ticks(1)
		var v0 := barco_r.velocity
		await ticks(6)
		ok("b) ronda %d: remolino arrastra al barco" % ronda, barco_r.velocity.x < v0.x - 0.5 or barco_r.velocity.length() > 0.5, str(barco_r.velocity))
		if ronda == 0:
			barco_r.vida.recibir_danio(99)
			for i in 900:
				await get_tree().physics_frame
				if game.barco != barco_r and is_instance_valid(game.barco) and not game.cambiando:
					break
			await ticks(20)
			ok("b) barco recreado tras hundirse", game.barco != barco_r and game.barco != null)

	await liberar_game()

	# g) partida cargada directamente en el mar
	var lg := DatosLugar.new()
	lg.zona = MAR
	lg.entrada = "desde_playa"
	lg.vida = 7
	EstadoJuego.lugar_cargado = lg
	game = (load("res://game.tscn") as PackedScene).instantiate() as Game
	get_tree().root.add_child(game) # _ready síncrono
	hud = game.get_node(^"HUD") as HUD
	j = game.get_node(^"Jugador") as Jugador
	ok("g) ya hay barco tras _ready", game.barco != null)
	ok("g) HUD en modo barco sin esperar un fotograma", hud.medidor_viento.visible and not hud.ranura_objeto.visible and game.barco != null and hud._vida == game.barco.vida)
	ok("g) vida del jugador cargada (7) aunque se vea la del barco", j.vida.vida == 7)
	await get_tree().process_frame
	ok("g) primer fotograma: medidor visible", hud.medidor_viento.visible)
	ok("g) ruta_zona = mar", game.ruta_zona == MAR)

	# Estela del barco: emite rápido, no emite quieto (barco suelto, sin Game)
	await liberar_game()
	var suelto := (load("res://scenes/player/barco.tscn") as PackedScene).instantiate() as Barco
	get_tree().root.add_child(suelto)
	for i in 3:
		suelto.velocity = Vector2(100, 0)
		await get_tree().physics_frame
	ok("barco rápido: la estela emite", suelto.estela.emitting)
	suelto.velocity = Vector2.ZERO
	await ticks(2)
	ok("barco quieto: la estela no emite", not suelto.estela.emitting)
	suelto.free()
