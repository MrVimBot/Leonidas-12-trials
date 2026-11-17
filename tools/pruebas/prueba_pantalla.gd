extends "res://tools/pruebas/base_prueba.gd"
## Modo de escala de la ventana (`content_scale_mode`) en cada escena: el menú, las pinturas y la
## carta de la cinemática van en CANVAS_ITEMS (resolución real), el cuarto y el juego en VIEWPORT
## (480×270), el libro abierto en CANVAS_ITEMS y vuelve a VIEWPORT al cerrarlo. Recorre menú →
## Jugar → cinemática completa → juego → libro → pausa → Salir (vuelve al menú), y aparte
## cinemática → Esc → juego. No comprueba el aspecto, solo el modo.

const C := Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
const V := Window.CONTENT_SCALE_MODE_VIEWPORT


func modo() -> int:
	return get_window().content_scale_mode


func ejecutar() -> void:
	await _recorrido_completo()
	await _esc_en_pintura()


func _recorrido_completo() -> void:
	var menu := (load("res://scenes/ui/menu_principal.tscn") as PackedScene).instantiate() as MenuPrincipal
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await ticks(3)
	ok("menú principal: CANVAS_ITEMS", modo() == C)
	menu.boton_jugar.pressed.emit()
	var cine: CinematicaInicial = null
	for i in 600:
		await get_tree().process_frame
		if get_tree().current_scene is CinematicaInicial:
			cine = get_tree().current_scene
			break
	ok("llega a la cinemática", cine != null)
	var mal := 0
	var vio_cuarto := false
	var vio_carta := false
	var vio_pintura := false
	var caja := Dialogos as CajaDialogo
	var f := 0
	while get_tree().current_scene is CinematicaInicial and f < 60000:
		f += 1
		await get_tree().process_frame
		if not is_instance_valid(cine) or cine.is_queued_for_deletion():
			break
		var en_cuarto := cine.cuarto.visible and not cine.carta.visible
		var esperado := V if en_cuarto else C
		if en_cuarto:
			vio_cuarto = true
		elif cine.carta.visible:
			vio_carta = true
		else:
			vio_pintura = true
		if modo() != esperado:
			mal += 1
			print("   fotograma ", f, " modo ", modo(), " esperado ", esperado)
		if caja.abierto and f % 20 == 0:
			accion(&"interactuar", true)
			await get_tree().process_frame
			accion(&"interactuar", false)
		elif cine._leyendo_carta and f % 60 == 0: # privado: no hay otra forma de saber que lee la carta
			accion(&"atacar", true)
			await get_tree().process_frame
			accion(&"atacar", false)
	ok("pinturas CANVAS, cuarto VIEWPORT y carta CANVAS en todos los fotogramas (mal=%d)" % mal,
		mal == 0 and vio_cuarto and vio_carta and vio_pintura,
		"pintura %s cuarto %s carta %s" % [vio_pintura, vio_cuarto, vio_carta])
	await esperar_hasta(func() -> bool: return get_tree().current_scene is Game, 300)
	await ticks(5)
	ok("game.tscn: VIEWPORT", get_tree().current_scene is Game and modo() == V)
	game = get_tree().current_scene
	j = game.jugador
	await esperar_normal()
	EstadoJuego.tiene_libro = true
	ok("abrir el libro", Libro.abrir())
	await ticks(2)
	ok("libro abierto: CANVAS_ITEMS", modo() == C)
	Libro.cerrar()
	await ticks(2)
	ok("libro cerrado: VIEWPORT", modo() == V)
	# Pausa → Salir
	(game.get_node(^"MenuPausa") as MenuPausa)._salir() # privado: el botón real necesita ratón/foco
	await esperar_hasta(func() -> bool: return get_tree().current_scene is MenuPrincipal, 300)
	await ticks(3)
	ok("pausa → Salir: menú principal en CANVAS_ITEMS", get_tree().current_scene is MenuPrincipal and modo() == C,
		str(get_tree().current_scene))


func _esc_en_pintura() -> void:
	get_tree().current_scene.queue_free()
	await ticks(3)
	EstadoJuego.reiniciar()
	var cine := (load("res://scenes/cinematics/cinematica_inicial.tscn") as PackedScene).instantiate() as CinematicaInicial
	get_tree().root.add_child(cine)
	get_tree().current_scene = cine
	await ticks(5)
	ok("pintura: CANVAS_ITEMS", modo() == C)
	accion(&"ui_cancel", true)
	await get_tree().process_frame
	accion(&"ui_cancel", false)
	await esperar_hasta(func() -> bool: return get_tree().current_scene is Game, 600)
	await ticks(5)
	ok("tras Esc en una pintura: juego en VIEWPORT", get_tree().current_scene is Game and modo() == V)
