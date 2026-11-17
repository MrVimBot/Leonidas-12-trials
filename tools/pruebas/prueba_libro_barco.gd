extends "res://tools/pruebas/base_prueba.gd"
## El libro no se abre en barco (ni con la acción `inventario` ni con `Libro.abrir()`); a pie sí,
## y el mapa marca la zona actual en cada zona visitada (`PaginaMapa._zona_actual`, privado).


func ejecutar() -> void:
	EstadoJuego.tutorial_barco_visto = true
	await crear_game(true, true)
	var mapa := Libro.paginas[MenuLibro.Pagina.MAPA] as PaginaMapa
	ok("a pie en el pueblo se puede abrir", Libro.puede_abrir())
	ok("mapa: zona actual = Pueblo", mapa._zona_actual() == 1, str(mapa._zona_actual()))
	await ir("res://scenes/levels/mar.tscn", "desde_playa", false)
	ok("en barco", game.barco != null)
	ok("mapa: zona actual = Mar", mapa._zona_actual() == 4, str(mapa._zona_actual()))
	ok("en barco no se puede abrir", not Libro.puede_abrir())
	await pulsar(&"inventario")
	ok("la acción inventario no lo abre en barco", not Libro.abierto and not get_tree().paused)
	ok("Libro.abrir() devuelve false en barco", not Libro.abrir() and not Libro.abierto)
	await ir("res://scenes/levels/playa.tscn", "desde_mar")
	ok("de vuelta a pie", game.barco == null)
	ok("mapa: zona actual = Playa (Orilla del mar)", mapa._zona_actual() == 3, str(mapa._zona_actual()))
	await pulsar(&"inventario")
	ok("a pie se abre", Libro.abierto)
	ok("la cartela dice Playa", (Libro.get_node(^"%Cartela") as Label).text == "Playa")
	await pulsar(&"inventario")
	ok("se cierra", not Libro.abierto)
