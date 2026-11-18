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

	# 12) Muerte (al final: Game abre el Game Over y pausa el árbol): suena la caída y no el daño.
	j.vida.restaurar() # da invulnerabilidad: esperar a que acabe
	await ticks(200)
	parar_todos()
	j.vida.recibir_danio(100, j.global_position + Vector2(10, 0))
	ok("12) morir suena la caída", sonando("SonidoCaer"))
	ok("12) y no suena el daño", not sonando("SonidoDanio"))

