extends "res://tools/pruebas/base_prueba.gd"
## Segundo mar (PROVISIONAL): isla (orilla sur de la cueva) → mar_minotauro (barco) →
## orilla_minotauro (a pie) → laberinto, y vuelta orilla → mar → isla, por las SalidaZona reales.
## La barrera sin la misión del Minotauro la comprueba prueba_laberinto.gd (caso 0).
## 0) Isla: el cartel de la orilla tiene su diálogo; con la misión, la salida (ancha) lleva al
##    mar aunque Leonidas no vaya por el centro.
## 1) Mar del sur: hay barco; su salida de abajo lleva a la orilla, a pie.
## 2) Orilla: la salida de abajo lleva al laberinto (entrada de arriba).
## 3) Vuelta: orilla → muelle → mar en barco → salida de arriba → isla, a pie.

const ISLA := "res://scenes/levels/isla.tscn"
const MAR_SUR := "res://scenes/levels/mar_minotauro.tscn"
const ORILLA_SUR := "res://scenes/levels/orilla_minotauro.tscn"
const LABERINTO := "res://scenes/levels/laberinto.tscn"
## Dentro de la salida de la isla, a la izquierda del centro (la forma se agrandó para cubrir
## toda la orilla).
const ORILLA_ISLA_OESTE := Vector2(2170, 950)


func llegar_a(ruta: String) -> bool:
	return await esperar_hasta(func() -> bool: return game.ruta_zona == ruta and not game.cambiando, 900)


func ejecutar() -> void:
	tiempo_maximo = 120.0
	EstadoJuego.tutorial_barco_visto = true
	Microfono.nivel_forzado = 0.0
	await crear_game(true, true)

	# 0) Isla.
	await ir(ISLA, "desde_cueva")
	var cartel := game.zona_actual.get_node_or_null(^"Objetos/Carteles/CartelMarMinotauro/ZonaDialogo")
	ok("0) cartel de la orilla sur con diálogo", cartel != null and cartel.get("dialogo") != null)
	EstadoJuego.empezar_mision(EstadoJuego.MISION_DERROTAR_MINOTAURO)
	j.global_position = ORILLA_ISLA_OESTE
	ok("0) la orilla sur lleva al mar del sur", await llegar_a(MAR_SUR), game.ruta_zona)
	await ticks(10)

	# 1) Mar del sur.
	var barco := game.barco
	ok("1) hay barco y Leonidas está oculto", barco != null and not j.visible)
	if barco == null:
		return
	barco.global_position = (game.zona_actual.get_node(^"SalidaOrilla") as Node2D).global_position
	ok("1) la salida de abajo lleva a la orilla", await llegar_a(ORILLA_SUR), game.ruta_zona)
	await esperar_normal()
	ok("1) en la orilla, a pie", game.barco == null and j.visible)

	# 2) Orilla → laberinto.
	j.global_position = (game.zona_actual.get_node(^"SalidaLaberinto") as Node2D).global_position
	ok("2) la orilla lleva al laberinto", await llegar_a(LABERINTO), game.ruta_zona)
	var entrada := game.zona_actual.punto_entrada("desde_orilla")
	ok("2) aparece en la entrada de arriba", absf(j.global_position.x - entrada.x) < 1.0, str(j.global_position))

	# 3) Vuelta (la escena del Minotauro tiene a Leonidas bloqueado: se va por código).
	await ir(ORILLA_SUR, "desde_mar")
	j.global_position = (game.zona_actual.get_node(^"SalidaMar") as Node2D).global_position
	ok("3) el muelle lleva al mar del sur", await llegar_a(MAR_SUR), game.ruta_zona)
	await ticks(10)
	barco = game.barco
	ok("3) en barco", barco != null)
	if barco == null:
		return
	barco.global_position = (game.zona_actual.get_node(^"SalidaIsla") as Node2D).global_position
	ok("3) la salida de arriba vuelve a la isla", await llegar_a(ISLA), game.ruta_zona)
	await esperar_normal()
	var vuelta := game.zona_actual.punto_entrada("desde_mar_minotauro")
	ok("3) en la orilla sur de la isla, a pie", game.barco == null and j.global_position.distance_to(vuelta) < 2.0, str(j.global_position))
