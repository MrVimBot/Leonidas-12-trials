extends "res://tools/pruebas/base_prueba.gd"
## PrecargaZonas (hijo de Game): al entrar en una zona se cargan en segundo plano las zonas a las
## que llevan sus salidas; al cruzar una, Game usa la ya cargada; la zona de la que se viene se
## conserva si es vecina de la nueva (sin volver a cargarla) y las que dejan de ser vecinas se
## sueltan.

const PUEBLO := "res://scenes/levels/pueblo.tscn"
const BOSQUE := "res://scenes/levels/bosque.tscn"
const PLAYA := "res://scenes/levels/playa.tscn"
const CASA := "res://scenes/levels/casa_arbol.tscn"


func listas() -> Array:
	return game.precarga._listas.keys()


func ejecutar() -> void:
	await crear_game(true, true)
	ok("empieza en el pueblo", game.ruta_zona == PUEBLO, game.ruta_zona)
	var cargadas := await esperar_hasta(func() -> bool: return BOSQUE in listas() and CASA in listas(), 1200)
	ok("precarga las vecinas del pueblo (bosque, casa del árbol)", cargadas, str(listas()))
	var bosque: PackedScene = game.precarga._listas.get(BOSQUE)
	ok("escena() devuelve la precargada", game.precarga.escena(BOSQUE) == bosque)

	var pueblo_antes: PackedScene = game._escena_actual
	await ir(BOSQUE, "desde_pueblo")
	ok("ya en el bosque", game.ruta_zona == BOSQUE)
	ok("el bosque se cargó de la precarga", game._escena_actual == bosque)
	ok("conserva el pueblo (de donde se viene) sin recargarlo",
			game.precarga._listas.get(PUEBLO) == pueblo_antes and pueblo_antes != null)
	ok("suelta la casa del árbol (ya no es vecina)", not CASA in listas(), str(listas()))
	var playa := await esperar_hasta(func() -> bool: return PLAYA in listas(), 1200)
	ok("precarga la playa (vecina del bosque)", playa, str(listas()))
	await liberar_game()
