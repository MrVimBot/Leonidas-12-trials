extends "res://tools/pruebas/base_prueba.gd"
## Ratón en el libro (U5.4): botones con `pressed`. Eventos reales (Input.parse_input_event)
## en coordenadas de VENTANA: punto del lienzo → transformación del Control con el lienzo
## (CanvasLayer + escala del modo CANVAS_ITEMS) → transformación final de la ventana.
## Comprueba: pestañas, casillas (2.º clic usa), Importantes, Guardar, X (hover y clic),
## clic fuera de los botones, áreas de clic = rectángulos de libro.json (esquinas por
## dentro y medio píxel por fuera) en dos tamaños de ventana, y que ningún clic con el
## libro abierto llega al juego. Guarda solo en la partida temporal de las pruebas.

const JSON_LIBRO := "res://assets/ui/libro/libro.json"

var L: MenuLibro
var _clics_al_juego := 0
var _sonda: Sonda
var _sonda_final: Sonda


class Sonda extends Node:
	## Cuenta los clics que llegan sin consumir a `_unhandled_input` (lo que vería el juego).
	var cuenta := 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _unhandled_input(event: InputEvent) -> void:
		var b := event as InputEventMouseButton
		if b and b.pressed:
			cuenta += 1


func _ventana(p_libro: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * L.libro.get_global_transform_with_canvas() * p_libro


func _mover_raton(p_libro: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = _ventana(p_libro)
	m.global_position = m.position
	Input.parse_input_event(m)
	await ticks(1)


func _clic(p_libro: Vector2) -> void:
	await _mover_raton(p_libro)
	for pulsado: bool in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pulsado
		b.position = _ventana(p_libro)
		b.global_position = b.position
		Input.parse_input_event(b)
		await ticks(1)
	await ticks(2)


func _inv(p: int) -> PaginaInventario:
	return L.paginas[p] as PaginaInventario


func _rect_casilla(p: int, i: int) -> Rect2:
	var datos: Dictionary = (load(JSON_LIBRO) as JSON).data
	var n: Array = (datos.casillas[["importantes", "inventario"][p]] as Array)[i]
	return Rect2(n[0], n[1], n[2], n[3])


func _estado() -> String:
	return "p=%d tabs=%s c0=%d c1=%d abierto=%s msg=%s" % [L._pagina, L._en_pestanas,
		_inv(0)._casilla, _inv(1)._casilla, L.abierto, (L.get_node(^"%MensajeGuardar") as Label).text]


func _poner(p: int, pestanas := false) -> void:
	L._pagina = p as MenuLibro.Pagina
	L._en_pestanas = pestanas
	L._refrescar()
	await ticks(1)


func _abrir() -> void:
	if not L.abierto:
		await pulsar(&"inventario")


## Comprueba un rectángulo de clic: dentro (esquinas a medio píxel del borde) hace efecto,
## fuera (medio píxel más allá de cada lado) no hace nada.
func _probar_area(nombre: String, r: Rect2, preparar: Callable, efecto: Callable) -> void:
	var dentro := [r.position + Vector2(0.5, 0.5), r.end - Vector2(0.5, 0.5),
		Vector2(r.position.x + 0.5, r.end.y - 0.5), Vector2(r.end.x - 0.5, r.position.y + 0.5)]
	var fuera := [Vector2(r.position.x - 0.5, r.get_center().y), Vector2(r.end.x + 0.5, r.get_center().y),
		Vector2(r.get_center().x, r.position.y - 0.5), Vector2(r.get_center().x, r.end.y + 0.5)]
	var bien := true
	var detalle := ""
	for q: Vector2 in dentro:
		await preparar.call()
		var antes := _estado()
		await _clic(q)
		if not efecto.call():
			bien = false
			detalle += " dentro%s sin efecto (%s → %s)" % [q, antes, _estado()]
	for q: Vector2 in fuera:
		await preparar.call()
		var antes := _estado()
		await _clic(q)
		if _estado() != antes:
			bien = false
			detalle += " fuera%s con efecto (%s → %s)" % [q, antes, _estado()]
	ok("área de clic: " + nombre, bien, detalle)


func _areas(etiqueta: String) -> void:
	var datos: Dictionary = (load(JSON_LIBRO) as JSON).data
	var py: Array = datos.pestana_y
	for i in MenuLibro.NUM_PAGINAS:
		var t: Array = datos.pestanas[i]
		var otra := (i + 2) % MenuLibro.NUM_PAGINAS
		# Pestaña apagada (y = pestana_y[0]).
		await _probar_area("%s pestaña %d apagada" % [etiqueta, i], Rect2(t[1], py[0], t[2], t[3]),
			func() -> void: await _abrir(); await _poner(otra),
			func() -> bool: return L._pagina == i)
		# Pestaña encendida (y = pestana_y[1]) con el cursor en las pestañas: el clic baja a la página.
		await _probar_area("%s pestaña %d encendida" % [etiqueta, i], Rect2(t[1], py[1], t[2], t[3]),
			func() -> void: await _abrir(); await _poner(i, true),
			func() -> bool: return L._pagina == i and not L._en_pestanas)
	for p in 2:
		for i: int in [0, 3, 5, 11]:
			await _probar_area("%s casilla %d de la página %d" % [etiqueta, i, p], _rect_casilla(p, i),
				func() -> void:
					await _abrir()
					_inv(p)._casilla = 6
					await _poner(p),
				func() -> bool: return L._pagina == p and _inv(p)._casilla == i and L.abierto)
	await _probar_area(etiqueta + " Guardar", Rect2(372, 222, 62, 18),
		func() -> void:
			await _abrir()
			L.paginas[MenuLibro.Pagina.GUARDAR].avisar("")
			borrar_partida_prueba()
			await _poner(MenuLibro.Pagina.MISIONES),
		func() -> bool: return FileAccess.file_exists(RUTA_PARTIDA_PRUEBA) and L._pagina == MenuLibro.Pagina.GUARDAR)
	var s: Array = datos.salir
	await _probar_area(etiqueta + " X", Rect2(s[0], s[1], s[2], s[3]),
		func() -> void: await _abrir(); await _poner(MenuLibro.Pagina.INVENTARIO),
		func() -> bool: return not L.abierto)


func ejecutar() -> void:
	var E := EstadoJuego
	var tamano_original := get_window().size
	await crear_game(true, true)
	# Sonda dentro de Game (ve lo que vería el juego: recibe `_unhandled_input` ANTES que el
	# autoload Libro) y sonda al principio de root (lo recibe la última: después de Libro).
	_sonda = Sonda.new()
	game.add_child(_sonda)
	_sonda_final = Sonda.new()
	get_tree().root.add_child(_sonda_final)
	get_tree().root.move_child(_sonda_final, 0)
	get_window().size = Vector2i(1920, 1080)
	await ticks(2)
	# La ventana real avisa al entrar el ratón (el hover de la GUI lo necesita); en headless no.
	get_window().notification(Node.NOTIFICATION_VP_MOUSE_ENTER)
	L = Libro as MenuLibro
	E.objetos.erase(&"manzana")
	E.agregar_objeto(&"manzana", 3)
	await pulsar(&"inventario")
	ok("abierto", L.abierto)
	# Pestañas.
	for i in MenuLibro.NUM_PAGINAS:
		await _clic(L.pestanas[i].position + L.pestanas[i].size / 2.0)
		ok("clic en pestaña %d → página %d" % [i, i], L._pagina == i and L.abierto, str(L._pagina))
	# Casilla de Inventario: 1.er clic selecciona, 2.º usa (vida baja → come).
	await _clic(L.pestanas[MenuLibro.Pagina.INVENTARIO].position + Vector2(15, 14))
	await _clic(_rect_casilla(1, 2).get_center())
	ok("clic en casilla vacía 2 la selecciona", _inv(1)._casilla == 2 and L.abierto)
	await _clic(_rect_casilla(1, 2).get_center())
	ok("2.º clic en casilla vacía no hace nada", _inv(1)._casilla == 2 and L.abierto)
	await _clic(_rect_casilla(1, 0).get_center())
	ok("clic en casilla 0 la selecciona sin usar", _inv(1)._casilla == 0
		and L.abierto and E.cantidad(&"manzana") == 3)
	ok("el marco sigue a la casilla", L.seleccion.position == Vector2(74, 85) + L._sel_desplazamiento,
		str(L.seleccion.position))
	# Vida llena: 2.º clic avisa.
	j.vida.vida = j.vida.vida_max
	await _clic(_rect_casilla(1, 0).get_center())
	ok("2.º clic con la vida llena avisa", L.abierto and _inv(1)._aviso == "Ya estás bien."
		and E.cantidad(&"manzana") == 3, _inv(1)._aviso)
	j.vida.vida = 4
	await _clic(_rect_casilla(1, 0).get_center())
	ok("2.º clic come la manzana (cierra el libro)", not L.abierto and E.cantidad(&"manzana") == 2
		and j.estado == Jugador.Estado.COMER, "abierto=%s manzanas=%d estado=%d" % [L.abierto, E.cantidad(&"manzana"), j.estado])
	for i in 300:
		await get_tree().physics_frame
		if j.estado == Jugador.Estado.NORMAL:
			break
	ok("curó un corazón", j.vida.vida == 8, str(j.vida.vida))
	await ticks(5)
	# Casilla de Importantes (pliego 0).
	await pulsar(&"inventario")
	await _clic(L.pestanas[MenuLibro.Pagina.IMPORTANTES].position + Vector2(15, 14))
	await _clic(_rect_casilla(0, 1).get_center())
	ok("clic en casilla de Importantes", L._pagina == MenuLibro.Pagina.IMPORTANTES
		and _inv(0)._casilla == 1)
	await _clic(_rect_casilla(0, 1).get_center())
	ok("2.º clic en un objeto importante no hace nada", L.abierto and L._pagina == MenuLibro.Pagina.IMPORTANTES)
	# Casilla de una página oculta: no responde (Inventario está en otro pliego).
	var antes := _estado()
	await _clic(_rect_casilla(1, 5).get_center())
	ok("casilla de un pliego oculto no responde", _estado() == antes, _estado())
	# Guardar.
	await _clic(L.pestanas[MenuLibro.Pagina.GUARDAR].position + Vector2(15, 14))
	await _clic(Rect2(372, 222, 62, 18).get_center())
	ok("clic en Guardar guarda", FileAccess.file_exists(RUTA_PARTIDA_PRUEBA)
		and (L.get_node(^"%MensajeGuardar") as Label).text == "¡Partida guardada!")
	# Clic fuera de cualquier botón (página, tapa y fuera del libro): nada.
	for q: Vector2 in [Vector2(300, 150), Vector2(150, 60), Vector2(20, 20), Vector2(-30, 150)]:
		antes = _estado()
		await _clic(q)
		ok("clic fuera de los botones en %s no hace nada" % q, _estado() == antes, _estado())
	# Teclas Enter/Espacio no activan botones por la GUI (ninguno tiene foco).
	ok("ningún control tiene el foco", get_viewport().gui_get_focus_owner() == null)
	# Pasar por encima de la X la enciende; al salir se apaga.
	var x := L.salir
	await _mover_raton(x.position + x.size / 2.0)
	await ticks(1)
	ok("ratón sobre la X la enciende", x.is_hovered() and x.texture_hover == load("res://assets/ui/libro/salir.png"))
	await _mover_raton(Vector2(300, 150))
	await ticks(1)
	ok("al salir de la X se apaga", not x.is_hovered())
	ok("ningún clic con el libro abierto llegó al juego", _sonda.cuenta == 0 and _sonda_final.cuenta == 0,
		"%d %d" % [_sonda.cuenta, _sonda_final.cuenta])
	await _clic(x.position + x.size / 2.0)
	ok("clic en la X cierra", not L.abierto and not get_tree().paused)
	await ticks(10)
	ok("el jugador no ataca al cerrar con la X", j.estado == Jugador.Estado.NORMAL, str(j.estado))
	# Áreas de clic en dos tamaños de ventana (×3 y ×2 del arte).
	await _abrir()
	ok("a 1920×1080 el libro va a ×3", L.libro.scale.is_equal_approx(Vector2(0.75, 0.75)), str(L.libro.scale))
	await _areas("1920×1080")
	get_window().size = Vector2i(1440, 810)
	await ticks(2)
	await _abrir()
	ok("a 1440×810 el libro va a ×2", L.libro.scale.is_equal_approx(Vector2(2.0 / 3.0, 2.0 / 3.0)), str(L.libro.scale))
	await _areas("1440×810")
	# Clic en una banda negra (fuera de los 480×270): no hay Control ahí, así que no lo
	# consume la GUI; llega a `_unhandled_input` y Libro lo consume (is_action_type()).
	get_window().size = Vector2i(1920, 1200)
	await ticks(2)
	await _abrir()
	_sonda.cuenta = 0
	_sonda_final.cuenta = 0
	antes = _estado()
	for pulsado: bool in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pulsado
		b.position = Vector2(960, 20)
		b.global_position = b.position
		Input.parse_input_event(b)
		await ticks(1)
	ok("clic en la banda negra no hace nada", _estado() == antes, _estado())
	ok("clic en la banda negra: Libro lo consume (no sigue después de él)", _sonda_final.cuenta == 0, str(_sonda_final.cuenta))
	print("INFO clic en la banda negra: lo vio la sonda dentro de Game (nodo ALWAYS) %d vez/veces" % _sonda.cuenta)
	if L.abierto:
		L.cerrar()
	get_window().size = tamano_original
