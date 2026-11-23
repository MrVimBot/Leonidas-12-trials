extends "res://tools/pruebas/base_prueba.gd"
## Nivel 3 (PROVISIONAL): el laberinto del Minotauro, con la zona y la `EscenaMinotauro` reales.
## 0) Isla: sin la misión del Minotauro, la orilla sur de la cueva no deja pasar (BarreraMision,
##    MINOTAURO); con ella, la salida lleva al laberinto (entrada de arriba).
## 1) Recorrido: desde la entrada se llega al cofre del cuerno y al hueco de abajo (Explorador).
## 2) Encuentro al llegar: diálogos, la cámara enseña la salida, se apagan las luces, caen las dos
##    rejas, el Minotauro aparece y se vuelve invisible. Combate: barra gris, sin Hurtbox, golpes
##    de Leonidas no le quitan vida y se acerca por el laberinto.
## 3) Cofre: da el cuerno → se ve, se le puede herir y la barra deja el gris.
## 4) Morir a mitad (reaparecer automático): Minotauro, luces y rejas como al principio y el
##    encuentro vuelve a empezar solo (se reaparece dentro del Disparador), con el cuerno visible.
## 5) Derrota: misión completada, `minotauro_derrotado`, corazón extra, rejas abiertas, luz normal.
## 6) Guardar y cargar: sin escena ni Minotauro; la salida de abajo es el fin de la demo.

const ISLA := "res://scenes/levels/isla.tscn"
const LABERINTO := "res://scenes/levels/laberinto.tscn"
const Explorador := preload("res://tools/zonas/explorador.gd")
## Orilla sur de la cueva de la isla: dentro de la barrera (y fuera de la salida) y en la salida.
const ORILLA_BARRERA := Vector2(2260, 900)
const ORILLA_SALIDA := Vector2(2260, 932)
## Junto al cofre (encima) y en el hueco de abajo a la izquierda.
const JUNTO_AL_COFRE := Vector2(742, 474)
const HUECO_ABAJO := Vector2(145, 524)

var zona: Zona
var minotauro: Minotauro
var escena: EscenaMinotauro
var barra: BarraJefe


func tomar_nodos() -> void:
	zona = game.zona_actual
	minotauro = zona.get_node_or_null(^"Objetos/Jefe/Minotauro") as Minotauro
	escena = zona.get_node_or_null(^"Objetos/Eventos/EscenaMinotauro") as EscenaMinotauro
	barra = (game.get_node(^"HUD") as HUD).barra_jefe


func rejas_cerradas() -> bool:
	for r in escena.rejas:
		if not r.cerrada:
			return false
	return true


## Avanza todos los diálogos hasta que la escena llegue a COMBATE.
func pasar_encuentro() -> bool:
	return await esperar_hasta(func() -> bool:
		if Dialogos.abierto:
			accion(&"interactuar", true)
			accion(&"interactuar", false)
		return escena.fase == EscenaMinotauro.Fase.COMBATE, 4000)


func mucha_vida() -> void:
	j.vida.fijar_maximo(400, true)


func ejecutar() -> void:
	tiempo_maximo = 240.0
	await crear_game(true, true)

	# 0) Isla.
	await ir(ISLA, "desde_cueva")
	ok("0) en la isla", game.ruta_zona == ISLA, game.ruta_zona)
	j.global_position = ORILLA_BARRERA
	var para := await esperar_hasta(func() -> bool: return Dialogos.abierto, 300)
	ok("0) sin la misión: Leonidas se para en la orilla", para and game.ruta_zona == ISLA)
	await cerrar_dialogos()
	await esperar_normal()
	ok("0) y retrocede", j.global_position.y < ORILLA_BARRERA.y - 10.0, str(j.global_position))
	EstadoJuego.empezar_mision(EstadoJuego.MISION_DERROTAR_MINOTAURO)
	j.global_position = ORILLA_SALIDA
	var llega := await esperar_hasta(func() -> bool: return game.ruta_zona == LABERINTO and not game.cambiando, 600)
	ok("0) con la misión: la orilla lleva al laberinto", llega, game.ruta_zona)
	tomar_nodos()
	ok("0) la zona trae al Minotauro, su escena y dos rejas", minotauro != null and escena != null and escena.rejas.size() == 2)
	if minotauro == null or escena == null:
		return
	# Llega a la entrada y ya baja hacia PuntoLeonidas (el encuentro empieza al llegar).
	var entrada := zona.punto_entrada("desde_isla")
	ok("0) aparece en la entrada de arriba", absf(j.global_position.x - entrada.x) < 1.0
		and j.global_position.y >= entrada.y - 1.0 and j.global_position.y <= escena.punto_leonidas.global_position.y + 1.0, str(j.global_position))
	ok("0) Minotauro INACTIVO e invisible", minotauro.estado == Minotauro.Estado.INACTIVO and not minotauro.sprite.visible)

	# 1) Recorrido (con las rejas aún abiertas: el encuentro empieza con diálogos).
	var ex := Explorador.new(zona.get_world_2d().direct_space_state)
	var vistos := {"cofre": false, "hueco": false, "cerca": INF}
	ex.recorrer(zona.punto_entrada("desde_isla"), Rect2(zona.obtener_limites()), 4.0, func(p: Vector2) -> bool:
		if p.distance_to(JUNTO_AL_COFRE) < 6.0:
			vistos.cofre = true
		vistos.cerca = minf(vistos.cerca, p.distance_to(HUECO_ABAJO))
		if p.distance_to(HUECO_ABAJO) < 6.0:
			vistos.hueco = true
		return vistos.cofre and vistos.hueco)
	ok("1) desde la entrada se llega al cofre", vistos.cofre)
	ok("1) y al hueco de abajo", vistos.hueco, "a %.0f px" % vistos.cerca)

	# 2) Encuentro.
	ok("2) el encuentro empieza al llegar", escena.fase == EscenaMinotauro.Fase.ENCUENTRO and j.esta_bloqueado())
	var vio_salida := [false]
	var vio_minotauro := [false]
	var camara := game.camara
	var empieza := await esperar_hasta(func() -> bool:
		if camara.global_position.distance_to(escena.punto_salida.global_position) < 140.0:
			vio_salida[0] = true
		if minotauro.sprite.visible and minotauro.modulate.a > 0.9:
			vio_minotauro[0] = true
		if Dialogos.abierto:
			accion(&"interactuar", true)
			accion(&"interactuar", false)
		return escena.fase == EscenaMinotauro.Fase.COMBATE, 4000)
	await ticks(3)
	ok("2) llega al combate", empieza)
	ok("2) la cámara enseñó la salida de abajo", vio_salida[0])
	ok("2) el Minotauro apareció", vio_minotauro[0])
	ok("2) luces apagadas", escena.oscuridad.color.is_equal_approx(escena.color_oscuro), str(escena.oscuridad.color))
	ok("2) rejas cerradas", rejas_cerradas())
	ok("2) Leonidas libre y la cámara vuelve con él", not j.esta_bloqueado() and not camara.enfocando())
	ok("2) Minotauro persigue, invisible", minotauro.estado != Minotauro.Estado.INACTIVO and not minotauro.sprite.visible and not minotauro.sombra.visible)
	ok("2) barra gris (invulnerable)", barra.visible and barra.jefe() == minotauro and barra.esta_gris())
	minotauro.hurtbox.recibir_golpe(1, j.global_position)
	await ticks(2)
	ok("2) sin cuerno no se le hiere", minotauro.vida.vida == minotauro.vida.vida_max)
	ok("2) ruta preparada", minotauro.ruta.preparado)
	mucha_vida()
	var antes := minotauro.global_position.distance_to(j.global_position)
	var se_acerca := await esperar_hasta(func() -> bool:
		mucha_vida()
		return minotauro.global_position.distance_to(j.global_position) < antes - 40.0, 1500)
	ok("2) se acerca por el laberinto", se_acerca, "%.0f → %.0f" % [antes, minotauro.global_position.distance_to(j.global_position)])

	# 3) El cofre del cuerno.
	var cofre := zona.get_node(^"Objetos/Cofres/CofreCuerno")
	ok("3) el cofre guarda el cuerno", cofre.get("objeto") == EstadoJuego.objeto(EstadoJuego.OBJ_CUERNO))
	j.global_position = JUNTO_AL_COFRE
	await ticks(2)
	cofre.call(&"interactuar", j)
	await esperar_hasta(func() -> bool: return Dialogos.abierto, 300)
	await cerrar_dialogos()
	await ticks(3)
	ok("3) Leonidas tiene el cuerno", Minotauro.tiene_cuerno())
	ok("3) el Minotauro se ve", minotauro.sprite.visible and minotauro.sombra.visible)
	ok("3) la barra deja el gris", not barra.esta_gris())
	await esperar_hasta(func() -> bool: return not minotauro.vida.es_invulnerable(), 300)
	minotauro.hurtbox.recibir_golpe(1, j.global_position)
	await ticks(2)
	ok("3) ya se le hiere", minotauro.vida.vida == minotauro.vida.vida_max - 1, str(minotauro.vida.vida))

	# 4) Morir a mitad: reaparece en la entrada (dentro del Disparador) y vuelve a empezar.
	j.reaparecer_automatico = true
	j.murio.disconnect(game._al_morir_jugador)
	j.vida.fijar_maximo(12, true)
	await esperar_hasta(func() -> bool: return not j.vida.es_invulnerable(), 300)
	j.vida.recibir_danio(99)
	var reinicia := await esperar_hasta(func() -> bool: return escena.fase == EscenaMinotauro.Fase.ENCUENTRO, 1200)
	ok("4) reaparece y el encuentro vuelve a empezar", reinicia)
	ok("4) Minotauro reiniciado (vida llena, INACTIVO)", minotauro.estado == Minotauro.Estado.INACTIVO and minotauro.vida.vida == minotauro.vida.vida_max)
	ok("4) sin barra y rejas abiertas mientras baja", not barra.visible and not rejas_cerradas())
	ok("4) luces encendidas otra vez", escena.oscuridad.color.is_equal_approx(escena.color_penumbra))
	ok("4) el cuerno sigue en el inventario", Minotauro.tiene_cuerno())
	ok("4) nada ganado", not EstadoJuego.minotauro_derrotado and EstadoJuego.corazones_extra == 0)
	empieza = await pasar_encuentro()
	await ticks(3)
	ok("4) segundo encuentro hasta el combate (sin volver a enseñar la salida)", empieza)
	ok("4) con el cuerno se ve desde el principio", minotauro.sprite.visible and not barra.esta_gris())

	# 5) Derrota.
	mucha_vida()
	await esperar_hasta(func() -> bool: return not minotauro.vida.es_invulnerable(), 300)
	minotauro.vida.recibir_danio(99)
	await ticks(2)
	ok("5) sin barra", not barra.visible)
	ok("5) entrega: misión, bandera y jefes", EstadoJuego.mision_completada(EstadoJuego.MISION_DERROTAR_MINOTAURO)
		and EstadoJuego.minotauro_derrotado and EstadoJuego.jefes_derrotados == 1, str(EstadoJuego.jefes_derrotados))
	ok("5) corazón extra", EstadoJuego.corazones_extra == 1 and j.vida.vida_max == 16, str(j.vida.vida_max))
	var termina := await esperar_hasta(func() -> bool:
		if Dialogos.abierto:
			accion(&"interactuar", true)
			accion(&"interactuar", false)
		return not is_instance_valid(escena), 3000)
	await ticks(5)
	ok("5) diálogos hasta el final y la escena se libera", termina)
	ok("5) Leonidas libre", not j.esta_bloqueado())
	var rejas_abiertas := true
	for r in zona.get_node(^"Objetos/Rejas").get_children():
		rejas_abiertas = rejas_abiertas and not (r as Reja).cerrada
	ok("5) rejas abiertas", rejas_abiertas)
	var oscuridad := zona.get_node(^"Oscuridad") as CanvasModulate
	ok("5) vuelve la luz", await esperar_hasta(func() -> bool: return oscuridad.color.is_equal_approx(Color(0.55, 0.55, 0.62)), 600), str(oscuridad.color))
	ok("5) el Minotauro desaparece", await esperar_hasta(func() -> bool: return not is_instance_valid(minotauro), 300))

	# 6) Guardar, cargar y fin de la demo.
	j.global_position = Vector2(489, 140)
	await ticks(2)
	ok("6) guarda", EstadoJuego.guardar(game.datos_guardado()))
	await liberar_game()
	EstadoJuego.reiniciar()
	ok("6) carga", EstadoJuego.cargar())
	await crear_game(false, false)
	await ticks(30)
	zona = game.zona_actual
	ok("6) en el laberinto", game.ruta_zona == LABERINTO, game.ruta_zona)
	ok("6) sin Minotauro ni escena", zona.get_node_or_null(^"Objetos/Jefe/Minotauro") == null
		and zona.get_node_or_null(^"Objetos/Eventos/EscenaMinotauro") == null)
	ok("6) sin diálogo ni bloqueo", not Dialogos.abierto and not j.esta_bloqueado())
	j.global_position = HUECO_ABAJO
	var fin := await esperar_hasta(func() -> bool: return Dialogos.abierto, 300)
	ok("6) la salida de abajo es el fin de la demo", fin and (Dialogos as CajaDialogo).texto.text.length() > 0)
	await cerrar_dialogos()
	await esperar_normal()
	ok("6) y Leonidas vuelve atrás", j.global_position.y < HUECO_ABAJO.y - 10.0, str(j.global_position))
