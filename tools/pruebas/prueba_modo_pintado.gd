extends "res://tools/pruebas/base_prueba.gd"
## Zonas pintadas (`Zona.pintada`, nivel 2): Game pone la ventana en CANVAS_ITEMS al entrar en
## una y en VIEWPORT al volver a una normal; el libro y el Game Over, al cerrarse, vuelven al
## modo de la zona (`Pantalla.restaurar`) y no al normal. `ComponenteAjustePixel` deja el
## `Visual` del jugador en píxeles enteros aunque el cuerpo esté en medio píxel.
## No comprueba el aspecto (headless), solo el modo y las posiciones.

const C := Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
const V := Window.CONTENT_SCALE_MODE_VIEWPORT
const PUEBLO := "res://scenes/levels/pueblo.tscn"
const PINTADAS := [
	"res://scenes/levels/isla_orilla.tscn",
	"res://scenes/levels/isla.tscn",
	"res://scenes/levels/cueva_medusa.tscn",
	"res://scenes/levels/cueva_jefe.tscn",
]


func modo() -> int:
	return get_window().content_scale_mode


func ejecutar() -> void:
	# Las zonas del nivel 2 salen marcadas del generador; las demás no.
	for ruta: String in PINTADAS:
		var z := (load(ruta) as PackedScene).instantiate() as Zona
		ok("%s: pintada" % ruta.get_file(), z.pintada)
		z.free()
	for ruta: String in [PUEBLO, "res://scenes/levels/mar.tscn", "res://scenes/levels/playa.tscn"]:
		var z := (load(ruta) as PackedScene).instantiate() as Zona
		ok("%s: no pintada" % ruta.get_file(), not z.pintada)
		z.free()

	await crear_game(true, true)
	ok("pueblo: VIEWPORT", game.zona_actual.nombre_zona != "" and not game.zona_actual.pintada and modo() == V)

	await ir(PINTADAS[0], "inicio")
	ok("isla_orilla: CANVAS_ITEMS", game.zona_actual.pintada and modo() == C)

	# Libro: abrir y cerrar no devuelve la ventana al modo normal.
	EstadoJuego.tiene_libro = true
	await pulsar(&"inventario")
	ok("libro abierto", Libro.abierto and modo() == C)
	await pulsar(&"inventario")
	ok("libro cerrado: sigue en CANVAS_ITEMS", not Libro.abierto and modo() == C)

	# Game Over → Continuar: vuelve al de la zona.
	await _morir_y_continuar()
	ok("Game Over → Continuar: sigue en CANVAS_ITEMS", modo() == C)

	# ComponenteAjustePixel: el cuerpo en medio píxel, el dibujo en uno entero.
	var visual := j.get_node(^"Visual") as Node2D
	var medio := game.zona_actual.punto_entrada("inicio").round() + Vector2(0.5, 0.5)
	j.global_position = medio
	await get_tree().physics_frame
	await get_tree().physics_frame
	var g := visual.global_position
	ok("Visual en píxeles enteros con el jugador en medio píxel", j.global_position == medio
		and g == g.round() and g.distance_to(j.global_position) <= 0.75, "%s / %s" % [g, j.global_position])

	# De vuelta a una zona normal (el viaje real pasa por el mar en barco: aquí directo).
	await ir(PUEBLO, "inicio")
	ok("pueblo otra vez: VIEWPORT", modo() == V)
	await ir(PINTADAS[3], "inicio")
	ok("cueva_jefe: CANVAS_ITEMS", modo() == C)
	await ir("res://scenes/levels/mar.tscn", "inicio", false)
	ok("mar (barco, no pintada): VIEWPORT", modo() == V)


func _morir_y_continuar() -> void:
	var pg := game.get_node(^"PantallaGameOver") as PantallaGameOver
	await esperar_hasta(func() -> bool: return not j.vida.es_invulnerable(), 900)
	j.vida.recibir_danio(999)
	await esperar_hasta(func() -> bool: return pg.abierta, 900)
	ok("Game Over abierto en CANVAS_ITEMS", pg.abierta and modo() == C)
	var boton := pg.get_node(^"%Continuar") as Button
	await esperar_hasta(func() -> bool: return not boton.disabled, 900)
	await pulsar(&"ui_accept")
	await esperar_normal()
