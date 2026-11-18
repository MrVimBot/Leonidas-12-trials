extends "res://tools/pruebas/base_prueba.gd"
## Efectos de sonido: el bus `SFX` existe, los recursos de variantes cargan y cada evento del
## juego hace sonar su reproductor (espada, voltereta, daño, caída, golpe a enemigo, pasos,
## rotura de vasija, caída de piedra y golpe del barco). Se mira `playing` del reproductor:
## no se oye nada en headless, pero el servidor de audio sí registra la reproducción.

const RECURSOS := ["paso", "espada", "vasija_romper", "piedra_caer", "golpe_enemigo",
	"leonidas_caer", "barco_golpe", "leonidas_danio", "voltereta"]


func sonando(nodo: String) -> bool:
	return (j.get_node(nodo) as AudioStreamPlayer).playing


func parar_todos() -> void:
	for hijo in j.get_children():
		if hijo is AudioStreamPlayer:
			hijo.stop()


func ejecutar() -> void:
	# 0) Bus y recursos.
	ok("0) existe el bus SFX", AudioServer.get_bus_index(&"SFX") != -1)
	for nombre in RECURSOS:
		var r := load("res://resources/audio/sfx_%s.tres" % nombre) as AudioStreamRandomizer
		ok("0) sfx_%s carga y tiene variantes" % nombre, r != null and r.streams_count >= 1)

	await crear_game(true, true)
	game.cambiar_zona("res://scenes/levels/bosque.tscn", "desde_pueblo")
	await ticks(5)
	await esperar_normal()
	for e in get_tree().get_nodes_in_group(&"enemigos"):
		e.queue_free()
	await ticks(5)
	j.vida.restaurar()
	for nodo in ["SonidoPaso", "SonidoEspada", "SonidoGolpe", "SonidoVoltereta", "SonidoDanio", "SonidoCaer"]:
		var p := j.get_node(nodo) as AudioStreamPlayer
		ok("0) %s tiene stream y bus SFX" % nodo, p.stream != null and p.bus == &"SFX")
	ok("0) el jugador tiene la espada", EstadoJuego.tiene_espada)

	# 1) Espadazo (por la acción real: pasa por la señal `ataque_empezado` de la escena).
	parar_todos()
	pulsar(&"atacar")
	await ticks(4)
	ok("1) atacar hace sonar la espada", sonando("SonidoEspada"))
	await esperar_normal()

	# 2) Voltereta.
	parar_todos()
	pulsar(&"pirueta")
	await ticks(4)
	ok("2) la voltereta suena", sonando("SonidoVoltereta"))
	await esperar_normal()
	await ticks(60)

	# 3) Golpe a enemigo: solo con un Hurtbox activo; con otra cosa (vasija, jugador) no.
	parar_todos()
	j.ataque.hitbox.golpeo.emit(j) # no es un Hurtbox
	ok("3) golpear algo que no es enemigo no suena", not sonando("SonidoGolpe"))
	j.ataque.hitbox.golpeo.emit(j.hurtbox)
	ok("3) golpear un Hurtbox activo suena", sonando("SonidoGolpe"))
	j.hurtbox.activo = false
	parar_todos()
	j.ataque.hitbox.golpeo.emit(j.hurtbox)
	ok("3) un Hurtbox inactivo no suena", not sonando("SonidoGolpe"))
	j.hurtbox.activo = true

	# 4) Daño sin morir: suena el daño, no la caída.
	j.vida.restaurar() # da invulnerabilidad: esperar a que acabe
	await ticks(200)
	parar_todos()
	j.vida.recibir_danio(1, j.global_position + Vector2(10, 0))
	ok("4) recibir daño suena", sonando("SonidoDanio"))
	ok("4) y no suena la caída", not sonando("SonidoCaer"))

	# 5) Pasos: el fotograma de apoyo de `caminar` suena; otro fotograma, o parado, no.
	var sprite := j.get_node(^"Visual/Sprite") as AnimatedSprite2D
	parar_todos()
	sprite.play(&"caminar_frente")
	sprite.frame = 3
	ok("5) fuera de un fotograma de apoyo no suena", not sonando("SonidoPaso"))
	sprite.frame = 1
	ok("5) fotograma de apoyo suena", sonando("SonidoPaso"))
	parar_todos()
	sprite.play(&"parado_frente")
	sprite.frame = 1
	ok("5) parado no suena", not sonando("SonidoPaso"))

	# 6) Vasija y piedra.
	var vasija := (load("res://scenes/items/vasija_azul.tscn") as PackedScene).instantiate() as ObjetoAgarrable
	game.get_node(^"Mundo").add_child(vasija)
	vasija.global_position = j.global_position + Vector2(40, 0) # suelo libre (su botín salta)
	var s_vasija := vasija.sonido_rotura
	ok("6) la vasija tiene sonido de rotura", s_vasija != null)
	vasija.romper()
	ok("6) romper la vasija suena", s_vasija.playing)
	var piedra := (load("res://scenes/items/piedra.tscn") as PackedScene).instantiate() as ObjetoAgarrable
	game.get_node(^"Mundo").add_child(piedra)
	piedra.global_position = j.global_position + Vector2(-40, 0)
	ok("6) la piedra tiene sonido de caída", piedra.sonido_caida != null)
	piedra._aterrizar()
	ok("6) la piedra al caer suena", piedra.sonido_caida.playing)
	ok("6) la piedra no se rompe", not piedra._roto)

	# 7) Barco: cada golpe suena (también el que lo hunde).
	var barco := (load("res://scenes/player/barco.tscn") as PackedScene).instantiate() as Barco
	game.add_child(barco)
	await ticks(3)
	ok("7) el barco tiene sonido de golpe", barco.sonido_golpe != null)
	barco.vida.recibir_danio(1, barco.global_position + Vector2(10, 0))
	ok("7) el barco golpeado suena", barco.sonido_golpe.playing)
	barco.queue_free()

	# 8) Comer y curar (lote 2). Un golpe mientras come corta el sonido de comer.
	j.vida.restaurar()
	await ticks(200)
	j.vida.recibir_danio(2, j.global_position + Vector2(10, 0)) # para que haya algo que curar
	await ticks(200)
	parar_todos()
	var manzana := load("res://resources/objetos/manzana.tres") as Objeto
	j.comer(manzana)
	ok("8) comer suena", sonando("SonidoComer"))
	await esperar_hasta(func() -> bool: return j.estado == Jugador.Estado.NORMAL, 600)
	ok("8) al curarse suena curar", sonando("SonidoCurar") or j.vida.vida == j.vida.vida_max)
	parar_todos()
	j.vida.curar(1)
	ok("8) curar suena (curado directo)", sonando("SonidoCurar") or j.vida.vida == j.vida.vida_max)
	j.vida.restaurar()
	await ticks(200)
	j.comer(manzana)
	j.vida.recibir_danio(1, j.global_position + Vector2(10, 0))
	ok("8) un golpe corta el sonido de comer", not sonando("SonidoComer"))
	await ticks(200)

	# 9) Recoger moneda y manzana.
	for escena in ["moneda", "manzana_suelta"]:
		var suelto := (load("res://scenes/items/%s.tscn" % escena) as PackedScene).instantiate() as ObjetoSuelto
		game.get_node(^"Mundo").add_child(suelto)
		suelto.global_position = j.global_position + Vector2(0, 40)
		ok("9) %s tiene sonido de recoger" % escena, suelto.sonido_recoger != null and suelto.sonido_recoger.bus == &"SFX")
		suelto._recoger()
		ok("9) recoger %s suena" % escena, suelto.sonido_recoger.playing)

	# 10) Interfaz: SonidosUI y los botones con marca (el primer foco no suena, el cambio sí).
	for nombre in ["Mover", "Aceptar", "Volver"]:
		var p := SonidosUI.get_node(nombre) as AudioStreamPlayer
		p.stop()
		SonidosUI.call(nombre.to_lower())
		ok("10) SonidosUI.%s suena" % nombre.to_lower(), p.playing)
	var menu := BotonesConMarca.new()
	for n in 2:
		var b := Button.new()
		b.text = "Op %d" % n
		menu.add_child(b)
	get_tree().root.add_child(menu)
	await ticks(2)
	var s_mover := SonidosUI.get_node(^"Mover") as AudioStreamPlayer
	s_mover.stop()
	menu.get_child(0).grab_focus()
	await ticks(2)
	ok("10) el primer foco del menú no suena", not s_mover.playing)
	menu.get_child(1).grab_focus()
	await ticks(2)
	ok("10) cambiar de botón suena", s_mover.playing)
	var s_aceptar := SonidosUI.get_node(^"Aceptar") as AudioStreamPlayer
	s_aceptar.stop()
	(menu.get_child(1) as Button).pressed.emit()
	ok("10) pulsar un botón suena aceptar", s_aceptar.playing)
	menu.queue_free()

	# 11) Diálogo: abrir suena, el blip por letra solo si está activado, y continuar suena.
	parar_todos()
	var caja_abrir := Dialogos.sonido_abrir
	var caja_avanzar := Dialogos.sonido_avanzar
	var caja_letra := Dialogos.sonido_letra
	ok("11) la caja tiene sus tres sonidos", caja_abrir != null and caja_avanzar != null and caja_letra != null)
	Dialogos.mostrar_texto("Kathita: Hola, Leonidas.\nZeus: Adios.")
	await ticks(2)
	ok("11) abrir el diálogo suena", caja_abrir.playing)
	ok("11) sin activar, el blip por letra no suena", not caja_letra.playing)
	await ticks(400) # termina la máquina de escribir sola
	caja_avanzar.stop()
	pulsar(&"interactuar")
	await ticks(2)
	ok("11) continuar suena", caja_avanzar.playing)
	Dialogos.cerrar()
	await ticks(3)
	Dialogos.sonar_letras = true
	Dialogos.tonos_por_nombre = {"Zeus": 0.7}
	caja_letra.stop()
	Dialogos.mostrar_texto("Zeus: Hola, mortal.")
	await ticks(10)
	ok("11) con el blip activado suena y usa el tono del hablante", caja_letra.playing and is_equal_approx(caja_letra.pitch_scale, 0.7), str(caja_letra.pitch_scale))
	Dialogos.sonar_letras = false
	Dialogos.tonos_por_nombre = {}
	Dialogos.cerrar()
	await ticks(5)

	# 13) Lote 3, mundo: muerte de enemigos, arbusto, agarrar/lanzar y manzano.
	var base := j.global_position
	for escena in ["seta_bomba", "gamba"]:
		var enemigo := (load("res://scenes/enemies/%s.tscn" % escena) as PackedScene).instantiate() as Node2D
		game.get_node(^"Mundo").add_child(enemigo)
		enemigo.global_position = base + Vector2(0, -60)
		var s_muerte := enemigo.get_node(^"SonidoMuerte") as AudioStreamPlayer2D
		ok("13) %s tiene SonidoMuerte en SFX" % escena, s_muerte.stream != null and s_muerte.bus == &"SFX")
		(enemigo.get_node(^"Vida") as ComponenteVida).recibir_danio(100)
		ok("13) %s al morir suena" % escena, s_muerte.playing)
	var arbusto := (load("res://scenes/items/arbusto.tscn") as PackedScene).instantiate() as ObjetoAgarrable
	game.get_node(^"Mundo").add_child(arbusto)
	arbusto.global_position = base + Vector2(60, 0)
	arbusto.romper()
	ok("13) cortar un arbusto suena", arbusto.sonido_rotura != null and arbusto.sonido_rotura.playing)
	var v1 := (load("res://scenes/items/vasija_azul.tscn") as PackedScene).instantiate() as ObjetoAgarrable
	game.get_node(^"Mundo").add_child(v1)
	v1.global_position = base + Vector2(-60, 0)
	parar_todos()
	j.carga.levantar(v1)
	ok("13) agarrar suena", sonando("SonidoAgarrar"))
	j.carga.lanzar(Vector2.RIGHT)
	ok("13) lanzar suena", sonando("SonidoLanzar"))
	var v2 := (load("res://scenes/items/vasija_naranja.tscn") as PackedScene).instantiate() as ObjetoAgarrable
	game.get_node(^"Mundo").add_child(v2)
	v2.global_position = base + Vector2(-60, 20)
	j.carga.levantar(v2)
	parar_todos()
	j.carga.soltar(Vector2.DOWN)
	ok("13) soltar sin impulso no suena a lanzar", not sonando("SonidoLanzar"))
	var manzano := (load("res://scenes/entorno/manzano.tscn") as PackedScene).instantiate() as Decorado
	game.get_node(^"Mundo").add_child(manzano)
	manzano.global_position = base + Vector2(0, 80)
	var s_gol := manzano.get_node(^"SonidoGolpe") as AudioStreamPlayer
	var s_man := manzano.get_node(^"SonidoManzanas") as AudioStreamPlayer
	manzano.recibir_golpe(1, base)
	ok("13) golpear el manzano suena", s_gol.playing)
	var cayeron := false
	for n in 6:
		manzano.recibir_golpe(1, base)
		if s_man.playing:
			cayeron = true
			break
	ok("13) al caer las manzanas suena", cayeron)

	# 14) Lote 3, interfaz: SonidosUI (todos sus sonidos), objeto obtenido, libro y guardar.
	var sonidos_ui := {"libro_abrir": "LibroAbrir", "libro_cerrar": "LibroCerrar", "libro_pagina": "LibroPagina",
		"guardar": "Guardar", "mision_nueva": "MisionNueva", "game_over": "GameOver", "zona_cambio": "ZonaCambio"}
	for metodo in sonidos_ui:
		var pl := SonidosUI.get_node(sonidos_ui[metodo]) as AudioStreamPlayer
		pl.stop()
		SonidosUI.call(metodo)
		ok("14) SonidosUI.%s suena" % metodo, pl.playing and pl.bus == &"SFX")
	SonidosUI.mision_nueva()
	SonidosUI.objeto_importante()
	ok("14) objeto_importante corta mision_nueva",
		(SonidosUI.get_node(^"ObjetoImportante") as AudioStreamPlayer).playing and not (SonidosUI.get_node(^"MisionNueva") as AudioStreamPlayer).playing)
	(SonidosUI.get_node(^"ObjetoImportante") as AudioStreamPlayer).stop()
	j.mostrar_objeto_obtenido(load("res://assets/ui/inventario/objetos/icono_espada.png") as Texture2D, 0.1)
	ok("14) mostrar un objeto obtenido suena", (SonidosUI.get_node(^"ObjetoImportante") as AudioStreamPlayer).playing)
	j.ocultar_objeto_obtenido()
	if not EstadoJuego.tiene_libro:
		EstadoJuego.agregar_objeto(EstadoJuego.OBJ_LIBRO)
	await esperar_normal()
	ok("14) el libro se puede abrir", Libro.abrir())
	ok("14) abrir el libro suena", (SonidosUI.get_node(^"LibroAbrir") as AudioStreamPlayer).playing)
	(SonidosUI.get_node(^"LibroPagina") as AudioStreamPlayer).stop()
	Libro.call(&"_ir_a_pagina", 2, true)
	ok("14) cambiar de página suena", (SonidosUI.get_node(^"LibroPagina") as AudioStreamPlayer).playing)
	(SonidosUI.get_node(^"Guardar") as AudioStreamPlayer).stop()
	Libro.call(&"_guardar")
	ok("14) guardar suena", (SonidosUI.get_node(^"Guardar") as AudioStreamPlayer).playing)
	Libro.cerrar()
	ok("14) cerrar el libro suena", (SonidosUI.get_node(^"LibroCerrar") as AudioStreamPlayer).playing)
	await ticks(3)

	# 15) Cambio de zona: suena el whoosh al empezar el fundido.
	(SonidosUI.get_node(^"ZonaCambio") as AudioStreamPlayer).stop()
	game.cambiar_zona("res://scenes/levels/playa.tscn", "desde_bosque")
	ok("15) cambiar de zona suena", (SonidosUI.get_node(^"ZonaCambio") as AudioStreamPlayer).playing)
	await get_tree().process_frame
	await esperar_normal()
	await ticks(10)

	# 16) Lote 4: enemigos (posicionales), Medusa, barco y remolino.
	var mundo := game.get_node(^"Mundo")
	var pos0 := j.global_position + Vector2(0, -90)
	var seta := (load("res://scenes/enemies/seta_bomba.tscn") as PackedScene).instantiate() as Node2D
	mundo.add_child(seta)
	seta.global_position = pos0
	seta.set_physics_process(false)
	seta.call(&"_explotar")
	ok("16) la seta al inflarse suena", (seta.get_node(^"SonidoInflar") as AudioStreamPlayer2D).playing)
	seta.call(&"_soltar_nube")
	ok("16) la seta al explotar suena", (seta.get_node(^"SonidoExplota") as AudioStreamPlayer2D).playing)

	var flor := (load("res://scenes/enemies/flor_falsa.tscn") as PackedScene).instantiate() as Node2D
	mundo.add_child(flor)
	flor.global_position = pos0 + Vector2(50, 0)
	flor.set_physics_process(false)
	(flor.get_node(^"Ataque") as ComponenteAtaque).golpe_activado.emit()
	ok("16) el mordisco de la flor suena (señal golpe_activado)", (flor.get_node(^"SonidoMordisco") as AudioStreamPlayer2D).playing)

	var gamba := (load("res://scenes/enemies/gamba.tscn") as PackedScene).instantiate() as Gamba
	gamba.semilla = 3
	mundo.add_child(gamba)
	gamba.global_position = j.global_position + Vector2(40, 0)
	gamba.set_physics_process(false)
	gamba.call(&"_morder") # el sonido llega en el fotograma del mordisco, no al empezar
	var s_gamba := gamba.get_node(^"SonidoMordisco") as AudioStreamPlayer2D
	ok("16) la gamba no suena al empezar a morder", not s_gamba.playing)
	var mordio := await esperar_hasta(func() -> bool: return s_gamba.playing, 600)
	ok("16) la gamba suena al morder", mordio)

	var pez := (load("res://scenes/enemies/pez_espada.tscn") as PackedScene).instantiate() as Node2D
	mundo.add_child(pez)
	pez.global_position = pos0 + Vector2(-50, 0)
	pez.set_physics_process(false)
	pez.call(&"_avisar")
	ok("16) el pez avisa", (pez.get_node(^"SonidoAviso") as AudioStreamPlayer2D).playing)
	pez.call(&"_correr")
	ok("16) el pez en carrera suena", (pez.get_node(^"SonidoCarrera") as AudioStreamPlayer2D).playing)
	(pez.get_node(^"Ataque") as ComponenteAtaque).golpe_activado.emit()
	ok("16) la estocada del pez suena", (pez.get_node(^"SonidoEstocada") as AudioStreamPlayer2D).playing)

	var ciclope := (load("res://scenes/enemies/ciclope_serpiente.tscn") as PackedScene).instantiate() as Node2D
	mundo.add_child(ciclope)
	ciclope.global_position = pos0 + Vector2(0, -40)
	ciclope.set_physics_process(false)
	ciclope.call(&"_apuntar")
	ok("16) el cíclope al apuntar suena", (ciclope.get_node(^"SonidoApuntar") as AudioStreamPlayer2D).playing)
	ciclope.call(&"_disparar")
	ok("16) el cíclope al disparar suena", (ciclope.get_node(^"SonidoDisparo") as AudioStreamPlayer2D).playing)

	var rayo := (load("res://scenes/enemies/rayo_ciclope.tscn") as PackedScene).instantiate() as Node2D
	mundo.add_child(rayo)
	rayo.global_position = j.global_position + Vector2(0, 60)
	var s_rayo := rayo.get_node(^"SonidoImpacto") as AudioStreamPlayer2D
	rayo.call(&"_acabar")
	await ticks(3)
	ok("16) el impacto del rayo sigue sonando tras liberarse el rayo",
		not is_instance_valid(rayo) or rayo.is_queued_for_deletion())
	ok("16) y su sonido pasó al padre", is_instance_valid(s_rayo) and s_rayo.playing and s_rayo.get_parent() == mundo)

	var tiburon := (load("res://scenes/enemies/tiburon.tscn") as PackedScene).instantiate() as Node2D
	mundo.add_child(tiburon)
	tiburon.global_position = pos0 + Vector2(90, 0)
	tiburon.set_physics_process(false)
	tiburon.call(&"_embestir")
	ok("16) el tiburón al embestir suena", (tiburon.get_node(^"SonidoEmbestida") as AudioStreamPlayer2D).playing)

	var medusa := (load("res://scenes/enemies/medusa.tscn") as PackedScene).instantiate() as Medusa
	mundo.add_child(medusa)
	medusa.global_position = pos0 + Vector2(0, -120)
	medusa.set_physics_process(false)
	medusa.call(&"_invocar")
	ok("16) Medusa al invocar suena", (medusa.get_node(^"SonidoInvocar") as AudioStreamPlayer2D).playing)
	medusa.golpe_suelo.emit(Vector2.ZERO)
	ok("16) el golpe de Medusa al suelo suena (señal)", (medusa.get_node(^"SonidoGolpeSuelo") as AudioStreamPlayer2D).playing)
	medusa.derrotada.emit()
	ok("16) la derrota de Medusa suena (señal)", (medusa.get_node(^"SonidoDerrotada") as AudioStreamPlayer2D).playing)
	if medusa.escena_trozo != null:
		await ticks(3) # que su detección vea a Leonidas (a quien apunta el trozo)
		medusa.call(&"_lanzar_trozos")
		ok("16) Medusa al lanzar un trozo suena", (medusa.get_node(^"SonidoLanzar") as AudioStreamPlayer2D).playing)
	var trozo := (load("res://scenes/enemies/trozo_estatua.tscn") as PackedScene).instantiate() as TrozoEstatua
	mundo.add_child(trozo)
	trozo.cayo.emit(Vector2.ZERO)
	ok("16) el trozo de estatua al caer suena", (trozo.get_node(^"SonidoCae") as AudioStreamPlayer2D).playing)

	# Los sonidos de enemigos son posicionales y acotados (no se oyen desde el otro lado del mapa).
	for nodo in [seta.get_node(^"SonidoInflar"), gamba.get_node(^"SonidoMordisco"), medusa.get_node(^"SonidoInvocar")]:
		var pl := nodo as AudioStreamPlayer2D
		ok("16) %s es posicional y en SFX" % pl.name, pl.bus == &"SFX" and pl.max_distance <= 500.0)

	var remolino := (load("res://scenes/entorno/remolino.tscn") as PackedScene).instantiate() as Node2D
	mundo.add_child(remolino)
	remolino.global_position = j.global_position + Vector2(0, 200)
	await ticks(3)
	ok("16) el remolino suena en bucle", (remolino.get_node(^"SonidoRemolino") as AudioStreamPlayer2D).playing)
	for wav in ["barco_oleaje", "barco_viento", "remolino"]:
		var w := load("res://assets/audio/sfx/%s.wav" % wav) as AudioStreamWAV
		ok("16) %s está importado en bucle" % wav, w != null and w.loop_mode != AudioStreamWAV.LOOP_DISABLED)

	var barco2 := (load("res://scenes/player/barco.tscn") as PackedScene).instantiate() as Barco
	game.add_child(barco2)
	await ticks(3)
	ok("16) el barco tiene el oleaje sonando", barco2.sonido_oleaje.playing)
	ok("16) sin soplar el viento está en silencio", barco2.sonido_viento.volume_db < -40.0)
	Input.action_press(&"pirueta") # el barco sopla con Espacio/K
	await ticks(120)
	ok("16) soplando sube el viento", barco2.sonido_viento.volume_db > -12.0, str(barco2.sonido_viento.volume_db))
	Input.action_release(&"pirueta")
	barco2.call(&"_al_hundirse")
	ok("16) hundirse suena y corta los bucles",
		barco2.sonido_hundir.playing and not barco2.sonido_oleaje.playing and not barco2.sonido_viento.playing)
	barco2.queue_free()
	for e in [seta, flor, gamba, pez, ciclope, tiburon, medusa, trozo, remolino]:
		if is_instance_valid(e):
			e.queue_free()
	await ticks(3)

	# 12) Muerte (al final: Game abre el Game Over y pausa el árbol): suena la caída y no el daño.
	j.vida.restaurar() # da invulnerabilidad: esperar a que acabe
	await ticks(200)
	parar_todos()
	j.vida.recibir_danio(100, j.global_position + Vector2(10, 0))
	ok("12) morir suena la caída", sonando("SonidoCaer"))
	ok("12) y no suena el daño", not sonando("SonidoDanio"))
	var cayo_game_over := await esperar_hasta(func() -> bool: return (SonidosUI.get_node(^"GameOver") as AudioStreamPlayer).playing, 900)
	ok("12) al morir suena el Game Over", cayo_game_over)
