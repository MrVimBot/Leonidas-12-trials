extends "res://tools/pruebas/base_prueba.gd"
## Entrada por EVENTOS reales (Input.parse_input_event) y su reparto entre capas:
##  a) Jugador: atacar y voltereta por evento; bloqueado no hace nada;
##  b) diálogo con un NPC (Burro): una pulsación completa el texto, los ecos de una tecla
##     mantenida no avanzan, cerrar con `interactuar` o con `atacar` no abre ni ataca después;
##  c) tienda (Tendedera): el evento que cierra el saludo no compra, ↓ mantenida mueve una vez,
##     pirueta/Esc cierran la tienda, Esc con la tienda abierta no abre la pausa;
##  d) libro y pausa: abrir/cerrar con `inventario`, Esc, `ui_cancel`, páginas, flechas con eco,
##     y que cada uno ignora al otro.
## Accede a miembros privados del diálogo/tienda/libro (`_indice`, `_escribiendo`, `_pagina`,
## `_casilla`) porque no hay otra forma de saber en qué cuadro o casilla están.


func ejecutar() -> void:
	await crear_game(true, true)
	ok("arranque en NORMAL", j.estado == Jugador.Estado.NORMAL, str(j.estado))
	await _caso_a()
	await _caso_b()
	await _caso_c()
	await _caso_d()


# --- a) Jugador ----------------------------------------------------------------------

func _caso_a() -> void:
	accion(&"atacar", true)
	await ticks(2)
	ok("a) evento atacar → ATAQUE", j.estado == Jugador.Estado.ATAQUE, str(j.estado))
	accion(&"atacar", false)
	await esperar_normal()
	await ticks(5)
	j.estamina.llenar()
	var antes := j.estamina.estamina
	accion(&"pirueta", true)
	await ticks(2)
	ok("a) evento pirueta → PIRUETA", j.estado == Jugador.Estado.PIRUETA, str(j.estado))
	ok("a) la estamina baja", j.estamina.estamina < antes, "%s → %s" % [antes, j.estamina.estamina])
	accion(&"pirueta", false)
	await esperar_normal()
	await ticks(5)
	j.bloquear(&"prueba")
	j.estamina.llenar()
	await pulsar(&"atacar")
	await pulsar(&"pirueta")
	await pulsar(&"interactuar")
	ok("a) BLOQUEADO: atacar/pirueta/interactuar no hacen nada",
		j.estado == Jugador.Estado.BLOQUEADO and not j.ataque.atacando
		and j.estamina.estamina == j.estamina.estamina_max and not Dialogos.abierto, str(j.estado))
	j.desbloquear(&"prueba")
	await ticks(2)


# --- b) Hablar con el Burro ---------------------------------------------------------------

func _colocar_ante(npc: Node2D) -> void:
	npc.set(&"paseo", false)
	(npc as CharacterBody2D).velocity = Vector2.ZERO
	await ticks(2)
	j.global_position = npc.global_position + Vector2(0, 18)
	j.animador.mirar(Vector2.UP)
	await ticks(3)


func _caso_b() -> void:
	var burro := game.get_node(^"Mundo").find_child("Burro", true, false) as Node2D
	if burro == null:
		ok("b) hay Burro", false)
		return
	for vuelta: StringName in [&"interactuar", &"atacar"]:
		await _colocar_ante(burro)
		accion(&"interactuar", true)
		await ticks(2)
		var caja := Dialogos as CajaDialogo
		ok("b[%s]) el evento interactuar abre el diálogo" % vuelta, caja.abierto)
		if not caja.abierto:
			accion(&"interactuar", false)
			return
		ok("b[%s]) primera página, texto sin completar" % vuelta,
			caja._indice == 0 and caja._escribiendo, "indice=%d escribiendo=%s" % [caja._indice, caja._escribiendo])
		accion(&"interactuar", false)
		await ticks(2)
		# Tecla E mantenida: los ecos no deben hacer nada.
		tecla(KEY_E, true)
		await ticks(2)
		ok("b[%s]) una pulsación completa el texto" % vuelta, caja._indice == 0 and not caja._escribiendo)
		for i in 5:
			tecla(KEY_E, true, true)
			await ticks(1)
		ok("b[%s]) E mantenida (ecos) no avanza" % vuelta, caja._indice == 0 and caja.abierto)
		tecla(KEY_E, false)
		await ticks(2)
		await pulsar(&"interactuar")
		ok("b[%s]) otra pulsación avanza" % vuelta, caja._indice == 1 and caja.abierto, "indice=%d" % caja._indice)
		# Completar y cerrar con la acción de esta vuelta.
		var n := 0
		while caja.abierto and n < 20:
			n += 1
			accion(vuelta, true)
			await ticks(1)
			if not caja.abierto:
				ok("b[%s]) al cerrar: jugador NORMAL en el acto" % vuelta, j.estado == Jugador.Estado.NORMAL, str(j.estado))
			await ticks(1)
			accion(vuelta, false)
			await ticks(2)
		await ticks(30)
		ok("b[%s]) cerrado: no reabre, no ataca, NORMAL" % vuelta,
			not caja.abierto and j.estado == Jugador.Estado.NORMAL and not j.ataque.atacando, str(j.estado))


# --- c) Tienda --------------------------------------------------------------------------

func _caso_c() -> void:
	var tendedera := game.get_node(^"Mundo").find_child("Tendedera", true, false) as Node2D
	if tendedera == null:
		ok("c) hay Tendedera", false)
		return
	EstadoJuego.agregar_monedas(10)
	var tienda := Tienda as MenuTienda
	for vuelta: int in 2:
		await _colocar_ante(tendedera)
		accion(&"interactuar", true)
		await ticks(2)
		accion(&"interactuar", false)
		await ticks(2)
		ok("c%d) saludo abierto" % vuelta, Dialogos.abierto)
		var manzanas := EstadoJuego.cantidad(&"manzana")
		var monedas := EstadoJuego.monedas
		await cerrar_dialogos(&"interactuar", 20)
		ok("c%d) tras el saludo: tienda abierta" % vuelta, tienda.abierto)
		ok("c%d) la pulsación que cierra el saludo no compra" % vuelta,
			EstadoJuego.cantidad(&"manzana") == manzanas and EstadoJuego.monedas == monedas)
		var bloqueado := true
		for i in 20:
			await get_tree().physics_frame
			bloqueado = bloqueado and j.estado == Jugador.Estado.BLOQUEADO
		ok("c%d) jugador BLOQUEADO con la tienda abierta (20 ticks)" % vuelta, bloqueado, str(j.estado))
		if vuelta == 0:
			await pulsar(&"interactuar")
			ok("c0) interactuar compra una manzana",
				EstadoJuego.cantidad(&"manzana") == manzanas + 1 and EstadoJuego.monedas == monedas - 3,
				"manzanas %d→%d monedas %d→%d" % [manzanas, EstadoJuego.cantidad(&"manzana"), monedas, EstadoJuego.monedas])
			# ↓ mantenida: dos "pulsado" seguidos sin soltar = un solo paso.
			accion(&"mover_abajo", true)
			await ticks(2)
			accion(&"mover_abajo", true)
			await ticks(2)
			ok("c0) ↓ mantenida mueve una sola vez", tienda._indice == 1, "indice=%d" % tienda._indice)
			accion(&"mover_abajo", false)
			await ticks(2)
			ok("c0) mover no compra", EstadoJuego.cantidad(&"manzana") == manzanas + 1)
			accion(&"pirueta", true)
			await ticks(2)
			ok("c0) pirueta cierra la tienda", not tienda.abierto)
		else:
			# Esc real: es `pausa` y `ui_cancel` a la vez.
			tecla(KEY_ESCAPE, true)
			await ticks(2)
			ok("c1) Esc cierra la tienda", not tienda.abierto)
			var pausa := game.find_child("MenuPausa", true, false) as MenuPausa
			ok("c1) Esc con la tienda abierta no abre la pausa", pausa != null and not pausa.abierto and not get_tree().paused)
		var caja := Dialogos as CajaDialogo
		ok("c%d) despedida abierta, sin avanzar por la tecla de cerrar" % vuelta,
			caja.abierto and caja._indice == 0 and caja._escribiendo)
		ok("c%d) jugador sigue BLOQUEADO en la despedida" % vuelta, j.estado == Jugador.Estado.BLOQUEADO)
		accion(&"pirueta", false)
		tecla(KEY_ESCAPE, false)
		await ticks(2)
		await cerrar_dialogos(&"interactuar", 20)
		await ticks(30)
		ok("c%d) tras la despedida: NORMAL, nada abierto" % vuelta,
			j.estado == Jugador.Estado.NORMAL and not Dialogos.abierto and not tienda.abierto, str(j.estado))


# --- d) Libro y pausa ---------------------------------------------------------------------

func _caso_d() -> void:
	var libro := Libro as MenuLibro
	var pausa := game.find_child("MenuPausa", true, false) as MenuPausa
	j.global_position = j.punto_control
	await ticks(5)
	ok("d) (precondición) tiene libro y puede abrir", EstadoJuego.tiene_libro and libro.puede_abrir())
	await pulsar(&"inventario")
	ok("d) inventario abre el libro y pausa", libro.abierto and get_tree().paused)
	var pagina := libro._pagina
	await pulsar(&"pagina_siguiente")
	ok("d) pagina_siguiente cambia de página", libro._pagina == pagina + 1, "%d → %d" % [pagina, libro._pagina])
	await pulsar(&"pagina_anterior")
	# Flechas: la tecla mantenida se repite (ecos).
	var casilla: int = (libro.paginas[MenuLibro.Pagina.INVENTARIO] as PaginaInventario)._casilla
	tecla(KEY_LEFT, true)
	await ticks(1)
	tecla(KEY_LEFT, true, true)
	await ticks(1)
	tecla(KEY_LEFT, false)
	await ticks(1)
	ok("d) ← mantenida se repite (eco)", (libro.paginas[MenuLibro.Pagina.INVENTARIO] as PaginaInventario)._casilla == casilla - 2,
		"%d → %d" % [casilla, (libro.paginas[MenuLibro.Pagina.INVENTARIO] as PaginaInventario)._casilla])
	await pulsar(&"inventario")
	ok("d) inventario cierra el libro", not libro.abierto and not get_tree().paused)
	await ticks(20)
	ok("d) no se reabre", not libro.abierto)
	await pulsar(&"inventario")
	tecla(KEY_ESCAPE, true)
	await ticks(2)
	ok("d) Esc cierra el libro", not libro.abierto)
	ok("d) Esc con el libro abierto no abre la pausa", not pausa.abierto and not get_tree().paused)
	tecla(KEY_ESCAPE, false)
	await ticks(2)
	await pulsar(&"inventario")
	await pulsar(&"ui_cancel")
	ok("d) ui_cancel cierra el libro", not libro.abierto and not pausa.abierto)
	await ticks(5)
	await pulsar(&"pausa")
	ok("d) con todo cerrado, pausa abre la pausa", pausa.abierto and get_tree().paused)
	await pulsar(&"inventario")
	ok("d) con la pausa abierta, inventario no abre el libro", not libro.abierto)
	await pulsar(&"pausa")
	ok("d) pausa la cierra", not pausa.abierto and not get_tree().paused)
