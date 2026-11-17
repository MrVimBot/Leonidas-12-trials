extends "res://tools/pruebas/base_prueba.gd"
## Navegación del libro con teclado por EVENTOS reales (InputEventKey): rejilla, salir por los
## lados a la página vecina (por la fila correcta), pestañas, Q/R, E (usar, aviso, guardar),
## y que Enter/Espacio no activan botones por la GUI. Guarda solo en la partida temporal.

var L: MenuLibro


func _casilla(p: int) -> int:
	return (L.paginas[p] as PaginaInventario)._casilla


func _aviso() -> String:
	return (L.paginas[MenuLibro.Pagina.INVENTARIO] as PaginaInventario)._aviso


func _msg() -> String:
	return (L.get_node(^"%MensajeGuardar") as Label).text


func _tecla(codigo: Key) -> void:
	await pulsar_tecla(codigo)


func _teclas(codigos: Array[Key]) -> void:
	for c in codigos:
		await _tecla(c)


func _estado() -> String:
	return "p=%d tabs=%s c0=%d c1=%d sel=%s abierto=%s" % [L._pagina, L._en_pestanas,
		_casilla(0), _casilla(1), L.seleccion.visible, L.abierto]


func _marco_en(p: int, i: int) -> bool:
	var sel: Control = L.seleccion
	var casillas: Node = L.get_node(NodePath("Libro/Contenido/%s" % ["Importantes", "Inventario"][p])).get_child(0)
	var c := casillas.get_child(i) as Control
	return sel.visible and sel.position == c.position + Vector2(-3, -4)


func _es(nombre: String, p: int, tabs: bool, c := -1) -> void:
	var bien: bool = L._pagina == p and L._en_pestanas == tabs and L.abierto
	if c >= 0:
		bien = bien and _casilla(p) == c and _marco_en(p, c)
	if tabs or p >= 2:
		bien = bien and not L.seleccion.visible
	ok(nombre, bien, _estado())


func ejecutar() -> void:
	var E := EstadoJuego
	await crear_game(true, true)
	L = Libro as MenuLibro
	E.objetos.erase(&"manzana")
	E.agregar_objeto(&"manzana", 3)
	j.vida.vida = j.vida.vida_max
	await _tecla(KEY_I)
	_es("I abre en Inventario, casilla 0", 1, false, 0)
	await _teclas([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	_es("→→→ casilla 3", 1, false, 3)
	await _tecla(KEY_RIGHT)
	_es("→ desde la última columna pasa al Mapa", 2, false)
	await _tecla(KEY_LEFT)
	_es("← desde el Mapa vuelve a Inventario por la derecha (fila 0, casilla 3)", 1, false, 3)
	await _teclas([KEY_DOWN, KEY_DOWN])
	_es("↓↓ casilla 11", 1, false, 11)
	await _tecla(KEY_DOWN)
	_es("↓ en la última fila no hace nada", 1, false, 11)
	await _teclas([KEY_LEFT, KEY_LEFT, KEY_LEFT])
	_es("←←← casilla 8", 1, false, 8)
	await _tecla(KEY_LEFT)
	_es("← desde la 1.ª columna pasa a Importantes por la derecha en la misma fila (11)", 0, false, 11)
	await _teclas([KEY_LEFT, KEY_LEFT, KEY_LEFT])
	_es("←←← casilla 8 de Importantes", 0, false, 8)
	await _tecla(KEY_LEFT)
	_es("← en la 1.ª columna de la 1.ª página no sale", 0, false, 8)
	await _teclas([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _tecla(KEY_RIGHT)
	_es("→ desde la última columna de Importantes entra en Inventario por la izquierda (fila 2 → 8)", 1, false, 8)
	await _teclas([KEY_UP, KEY_UP])
	_es("↑↑ casilla 0", 1, false, 0)
	await _tecla(KEY_UP)
	_es("↑ desde la fila de arriba sube a las pestañas", 1, true)
	await _teclas([KEY_RIGHT, KEY_RIGHT])
	_es("→→ en las pestañas: Misiones", 3, true)
	await _tecla(KEY_LEFT)
	_es("← en las pestañas: Mapa", 2, true)
	await _tecla(KEY_DOWN)
	_es("↓ vuelve a la página", 2, false)
	await _tecla(KEY_UP)
	_es("↑ en el Mapa sube a las pestañas", 2, true)
	await _tecla(KEY_E)
	_es("E en las pestañas entra en la página", 2, false)
	await _tecla(KEY_Q)
	_es("Q desde el Mapa: Inventario por la derecha (casilla 3)", 1, false, 3)
	await _tecla(KEY_R)
	_es("R: Mapa", 2, false)
	await _teclas([KEY_Q, KEY_Q])
	_es("QQ: Importantes (fila 0, entra por la derecha: casilla 3)", 0, false, 3)
	await _tecla(KEY_Q)
	_es("Q en la 1.ª página no hace nada", 0, false, 3)
	await _teclas([KEY_UP, KEY_RIGHT, KEY_DOWN])
	_es("↑ → ↓: Inventario desde las pestañas (entra por la izquierda: casilla 0)", 1, false, 0)
	# E sobre la manzana con la vida llena: aviso; al moverse se borra.
	await _tecla(KEY_E)
	ok("E con la vida llena: «Ya estás bien.» y sigue abierto", _aviso() == "Ya estás bien." and L.abierto
		and E.cantidad(&"manzana") == 3, _aviso())
	ok("el aviso se ve en el texto", (L.get_node(^"Libro/Contenido/Inventario/TextoInventario") as Label).text == "Ya estás bien.")
	await _tecla(KEY_RIGHT)
	ok("al mover el cursor se borra el aviso", _aviso() == "")
	await _tecla(KEY_E)
	ok("E en casilla vacía no hace nada", L.abierto and _aviso() == "")
	await _tecla(KEY_LEFT)
	# Enter / Intro del teclado numérico: ni usan el objeto ni activan botones.
	j.vida.vida = 4
	var antes := _estado()
	await _teclas([KEY_ENTER, KEY_KP_ENTER])
	ok("Enter no usa el objeto ni activa botones", _estado() == antes and E.cantidad(&"manzana") == 3, _estado())
	await _tecla(KEY_E)
	ok("E con la vida baja: come y cierra el libro", not L.abierto and E.cantidad(&"manzana") == 2
		and j.estado == Jugador.Estado.COMER, str(j.estado))
	for i in 300:
		await get_tree().physics_frame
		if j.estado == Jugador.Estado.NORMAL:
			break
	await ticks(5)
	await _tecla(KEY_I)
	await _teclas([KEY_R, KEY_R, KEY_R])
	_es("RRR: Guardar", 4, false)
	ok("la marca de Guardar se ve", (L.get_node(^"%MarcaGuardar") as Label).visible)
	await _teclas([KEY_ENTER, KEY_KP_ENTER])
	ok("Enter en Guardar no guarda", not FileAccess.file_exists(RUTA_PARTIDA_PRUEBA) and _msg() == "")
	await _tecla(KEY_E)
	ok("E en Guardar guarda", FileAccess.file_exists(RUTA_PARTIDA_PRUEBA) and _msg() == "¡Partida guardada!", _msg())
	await _tecla(KEY_UP)
	ok("en las pestañas no se ve la marca de Guardar", not (L.get_node(^"%MarcaGuardar") as Label).visible)
	await _tecla(KEY_DOWN)
	# El mensaje se borra solo (1,6 s).
	for i in 400:
		await get_tree().process_frame
		if _msg() == "":
			break
	ok("el mensaje se borra solo", _msg() == "")
	await _tecla(KEY_SPACE)
	ok("Espacio cierra el libro (acción pirueta)", not L.abierto and not get_tree().paused)
	await ticks(5)
	ok("…y Leonidas no hace la voltereta", j.estado == Jugador.Estado.NORMAL, str(j.estado))
