extends "res://tools/pruebas/base_prueba.gd"
## Cinemática inicial (CinematicaInicial) con eventos reales, en tres pasadas con tiempos
## acortados (los exports de duración):
##  1) flujo completo: con un diálogo abierto la pulsación la recibe la caja y no la cinemática;
##     se llega a la carta, las pulsaciones bajan página y la última la cierra sin tocar el
##     diálogo; sale el diálogo final y al terminar se carga game.tscn con la carta en el inventario;
##  2) Esc (`ui_cancel`) en medio de un diálogo: lo cierra y salta a game.tscn con carta y misión;
##  3) Esc durante el fundido final: un solo cambio de escena a Game y una sola carta.
## Usa miembros privados de la cinemática (`_pulsado`, `_leyendo_carta`) y de la caja (`_indice`,
## `_escribiendo`, `_paginas`): no hay otra forma de saber en qué punto están.

var cine: CinematicaInicial


func _crear() -> void:
	cine = (load("res://scenes/cinematics/cinematica_inicial.tscn") as PackedScene).instantiate() as CinematicaInicial
	cine.duracion_fundido = 0.05
	cine.duracion_atardecer = 0.3
	cine.espera_antes_atardecer = 0.05
	cine.espera_despues_atardecer = 0.05
	cine.velocidad_mama = 600.0
	get_tree().root.add_child(cine)
	get_tree().current_scene = cine


func _esperar_game() -> bool:
	return await esperar_hasta(func() -> bool: return get_tree().current_scene is Game, 1200)


## Deja el árbol como al empezar: sin Game ni cinemática, partida a cero.
func _limpiar() -> void:
	var actual := get_tree().current_scene
	if actual:
		actual.queue_free()
	await ticks(5)
	Dialogos.cerrar()
	EstadoJuego.reiniciar()
	await ticks(3)


func ejecutar() -> void:
	var caja := Dialogos as CajaDialogo
	await _pasada_completa(caja)
	await _limpiar()
	await _pasada_esc(caja)
	await _limpiar()
	await _pasada_esc_final(caja)


func _pasada_completa(caja: CajaDialogo) -> void:
	_crear()
	ok("1) sale el primer diálogo", await esperar_hasta(func() -> bool: return caja.abierto, 1200))
	# Con un diálogo abierto, una pulsación solo avanza el diálogo.
	await ticks(1)
	var indice := caja._indice
	var escribiendo := caja._escribiendo
	accion(&"interactuar", true)
	await get_tree().process_frame
	ok("1) diálogo abierto: la caja recibe la pulsación (completa el texto)", escribiendo and not caja._escribiendo and caja._indice == indice)
	ok("1) diálogo abierto: la cinemática no la toma", not cine._pulsado and not cine._leyendo_carta)
	accion(&"interactuar", false)
	await ticks(2)
	# Avanzar todos los diálogos hasta la carta.
	for i in 6000:
		await get_tree().process_frame
		if cine._leyendo_carta:
			break
		if caja.abierto:
			await pulsar(&"interactuar")
	ok("1) llega a la carta", cine._leyendo_carta and not caja.abierto)
	var maximo := maxf(0.0, cine.texto.get_line_count() * cine.texto.get_line_height() - cine.recorte.size.y)
	var bajadas := 0
	var cerrada_sin_dialogo := true
	for i in 50:
		var y_antes := cine.texto.position.y
		accion(&"atacar", true)
		await get_tree().process_frame
		accion(&"atacar", false)
		if caja.abierto:
			cerrada_sin_dialogo = false
		await ticks(90) # que termine de bajar la página
		if not cine._leyendo_carta:
			break
		if cine.texto.position.y < y_antes:
			bajadas += 1
	ok("1) las pulsaciones bajan página (%d) y la última cierra la carta" % bajadas,
		not cine._leyendo_carta and (bajadas > 0 or maximo <= 0.5))
	ok("1) cerrar la carta no abre ni avanza un diálogo", cerrada_sin_dialogo)
	ok("1) sale el diálogo final en su primera página", await esperar_hasta(func() -> bool: return caja.abierto, 600)
		and caja._indice == 0 and caja._escribiendo)
	await cerrar_dialogos(&"interactuar", 600)
	ok("1) al terminar cambia a game.tscn", await _esperar_game())
	ok("1) la carta está en el inventario", EstadoJuego.cantidad(&"carta") == 1)


func _pasada_esc(caja: CajaDialogo) -> void:
	_crear()
	ok("2) sale el primer diálogo", await esperar_hasta(func() -> bool: return caja.abierto, 1200))
	accion(&"ui_cancel", true)
	await get_tree().process_frame
	accion(&"ui_cancel", false)
	await ticks(2)
	ok("2) Esc cierra el diálogo", not caja.abierto)
	ok("2) Esc salta a game.tscn", await _esperar_game())
	ok("2) la carta está en el inventario", EstadoJuego.cantidad(&"carta") == 1)
	ok("2) la misión ir_al_templo está activa", EstadoJuego.misiones.has(EstadoJuego.MISION_IR_AL_TEMPLO))


func _pasada_esc_final(caja: CajaDialogo) -> void:
	_crear()
	var cambios := [0]
	var contar := func(n: Node) -> void:
		if n is Game:
			cambios[0] += 1
	get_tree().node_added.connect(contar)
	var llegado := false
	var vio_carta := false
	for i in 8000:
		await get_tree().process_frame
		if cine.carta.visible:
			vio_carta = true
		if cine._leyendo_carta and i % 30 == 0:
			accion(&"atacar", true)
			await get_tree().process_frame
			accion(&"atacar", false)
		elif caja.abierto and vio_carta and not cine.carta.visible and caja._indice == caja._paginas.size() - 1 and not caja._escribiendo:
			llegado = true
			break
		elif caja.abierto and i % 10 == 0:
			accion(&"interactuar", true)
			await get_tree().process_frame
			accion(&"interactuar", false)
	ok("3) llega al último cuadro del diálogo final", llegado)
	# Cerrar el último cuadro y, durante el fundido final, pulsar Esc.
	accion(&"interactuar", true)
	await get_tree().process_frame
	accion(&"interactuar", false)
	await get_tree().process_frame
	accion(&"ui_cancel", true)
	await get_tree().process_frame
	accion(&"ui_cancel", false)
	await _esperar_game()
	await ticks(60)
	get_tree().node_added.disconnect(contar)
	ok("3) un solo cambio de escena a Game (%d)" % cambios[0], cambios[0] == 1)
	ok("3) una sola carta", EstadoJuego.cantidad(&"carta") == 1, str(EstadoJuego.cantidad(&"carta")))
