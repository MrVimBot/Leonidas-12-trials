extends "res://tools/pruebas/base_prueba.gd"
## Combate completo con Medusa en `cueva_jefe` (plan 06, M4–M8), con la Medusa y la
## `EscenaMedusa` que pone la zona:
## 1) al pisar la sala: diálogo, salida cerrada, Medusa sale de INACTIVA y la barra se ve (gris);
## 2) 2 cíclopes: un golpe no le quita vida; muertos, la barra deja el gris y ya recibe daño;
## 3) Leonidas quieto donde cae la espada pierde 4 cuartos;
## 4) a mitad de vida, 2 cíclopes nuevos; muertos, cae algún `TrozoEstatua`;
## 5) a 0: súplica y trato, cabeza de piedra (en la mano y en el inventario), misión completada,
##    `jefes_derrotados` 1, `corazones_extra` 1, vida 16/16 y 4 corazones en el HUD; Medusa se
##    queda DERROTADA con su recordatorio, sin barra y con la salida abierta;
## 6) guardar y cargar: sigue con 16 y Medusa derrotada (sin escena ni combate);
## 7) morir a mitad: el combate se reinicia y vuelve a empezar al pisar la sala (también si se
##    reaparece dentro de ella).

const DENTRO := Vector2(272, 290) # ya en la sala, justo encima del pasillo
const QUIETO := Vector2(300, 205)

var zona: Zona
var medusa: Medusa
var escena: EscenaMedusa
var barra: BarraJefe


func nodos_de(clase: String) -> Array[Node]:
	return game.find_children("*", clase, true, false).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())


func matar_ciclopes() -> void:
	for c in medusa.ciclopes_vivos():
		c.vida.recibir_danio(99)
	await ticks(2)


## Leonidas no muere en los pasos 1–4: mucha vida (la entrega la deja en 16 de nuevo).
func mucha_vida() -> void:
	j.vida.fijar_maximo(400, true)


func entrar_en_la_cueva() -> void:
	await ir("res://scenes/levels/cueva_jefe.tscn", "desde_cueva")
	zona = game.zona_actual
	medusa = zona.get_node_or_null(^"Objetos/Jefe/Medusa") as Medusa
	escena = zona.get_node_or_null(^"Objetos/Eventos/EscenaMedusa") as EscenaMedusa
	barra = (game.get_node(^"HUD") as HUD).barra_jefe


## ¿El pasillo está cerrado? (prueba el movimiento del cuerpo de Leonidas hacia la salida)
func salida_cerrada() -> bool:
	return j.test_move(Transform2D(0.0, Vector2(272, 300)), Vector2(0, 60))


func ejecutar() -> void:
	tiempo_maximo = 240.0
	await crear_game(true, true)
	await entrar_en_la_cueva()
	ok("0) la zona trae a Medusa y su escena", medusa != null and escena != null)
	if medusa == null or escena == null:
		return
	ok("0) Medusa INACTIVA, sin barra, salida abierta", medusa.estado == Medusa.Estado.INACTIVA and not barra.visible and not salida_cerrada())
	ok("0) puntos de invocación de la zona", medusa.puntos_invocacion.size() == 4)

	# 1) Encuentro.
	j.global_position = DENTRO
	var abre := await esperar_hasta(func() -> bool: return Dialogos.abierto, 900)
	ok("1) al entrar en la sala sale el diálogo", abre)
	ok("1) Leonidas en su sitio y bloqueado", j.esta_bloqueado() and j.global_position.distance_to(escena.punto_leonidas.global_position) < 1.0, str(j.global_position))
	ok("1) salida cerrada", salida_cerrada())
	ok("1) Medusa aún INACTIVA durante el diálogo", medusa.estado == Medusa.Estado.INACTIVA)
	await cerrar_dialogos()
	await ticks(3)
	ok("1) Medusa empieza (INVOCAR)", medusa.estado == Medusa.Estado.INVOCAR, str(medusa.estado))
	ok("1) barra visible con Medusa", barra.visible and barra.jefe() == medusa and barra.nombre.text == "Medusa")
	ok("1) barra: 5 corazones llenos", barra.corazones.get_child_count() == 5 and barra.corazones.cuartos_visibles() == 20)
	ok("1) barra gris (invulnerable)", barra.esta_gris())
	ok("1) Leonidas libre", not j.esta_bloqueado())
	mucha_vida()

	# 2) Cíclopes e invulnerabilidad.
	var llegaron := await esperar_hasta(func() -> bool: return medusa.ciclopes_vivos().size() == 2, 300)
	ok("2) hay 2 cíclopes", llegaron)
	medusa.hurtbox.recibir_golpe(1, j.global_position)
	await ticks(2)
	ok("2) un golpe no le quita vida", medusa.vida.vida == 20, str(medusa.vida.vida))
	await matar_ciclopes()
	ok("2) muertos: la barra deja el gris", not barra.esta_gris())
	medusa.hurtbox.recibir_golpe(1, j.global_position)
	await ticks(2)
	ok("2) ya recibe daño (y la barra lo enseña)", medusa.vida.vida == 19 and barra.corazones.cuartos_visibles() == 19, str(medusa.vida.vida))

	# 3) Golpe al suelo sobre Leonidas quieto.
	mucha_vida()
	var danos: Array[int] = []
	var al_danar := func(c: int, _o: Vector2) -> void: danos.append(c)
	j.vida.danado.connect(al_danar)
	var golpe := await esperar_hasta(func() -> bool:
		j.global_position = QUIETO
		return 4 in danos, 1500)
	j.vida.danado.disconnect(al_danar)
	ok("3) el espadazo quita 4 cuartos", golpe, str(danos))

	# 4) Mitad de vida: cíclopes nuevos y, muertos, trozos de estatua.
	mucha_vida()
	await esperar_hasta(func() -> bool: return not medusa.vida.es_invulnerable(), 120)
	medusa.vida.recibir_danio(medusa.vida.vida - 10)
	llegaron = await esperar_hasta(func() -> bool: return medusa.ciclopes_vivos().size() == 2, 900)
	ok("4) a mitad de vida, 2 cíclopes nuevos", llegaron)
	ok("4) barra gris otra vez", barra.esta_gris())
	await matar_ciclopes()
	var trozo := await esperar_hasta(func() -> bool:
		j.global_position = QUIETO
		mucha_vida()
		return not nodos_de("TrozoEstatua").is_empty(), 1500)
	ok("4) cae algún trozo de estatua", trozo)

	# 5) Derrota y recompensa.
	await esperar_hasta(func() -> bool: return not medusa.vida.es_invulnerable(), 120)
	medusa.vida.recibir_danio(99)
	await ticks(2)
	ok("5) Medusa DERROTADA", medusa.estado == Medusa.Estado.DERROTADA)
	ok("5) sin barra", not barra.visible)
	ok("5) Leonidas bloqueado", j.esta_bloqueado())
	var en_mano := j.get_node(^"Visual/ObjetoEnMano") as Sprite2D
	var vio_cabeza := [false]
	var todo := await esperar_hasta(func() -> bool:
		if Dialogos.abierto:
			if en_mano.visible and en_mano.texture == EstadoJuego.objeto(EstadoJuego.OBJ_CABEZA_PIEDRA).icono:
				vio_cabeza[0] = true
			accion(&"interactuar", true)
			accion(&"interactuar", false)
		return not is_instance_valid(escena), 3000)
	await ticks(5)
	await cerrar_dialogos() # por si la última pulsación habló con Medusa (recordatorio)
	ok("5) súplica, trato y avisos hasta el final", todo)
	ok("5) la cabeza de piedra en la mano durante el aviso", vio_cabeza[0])
	ok("5) cabeza de piedra en el inventario", EstadoJuego.cantidad(EstadoJuego.OBJ_CABEZA_PIEDRA) == 1)
	ok("5) misión completada", EstadoJuego.mision_completada(EstadoJuego.MISION_DERROTAR_MEDUSA))
	ok("5) misión «Regresa con los sabios» activa", EstadoJuego.mision_empezada(EstadoJuego.MISION_REGRESAR_CON_SABIOS) and not EstadoJuego.mision_completada(EstadoJuego.MISION_REGRESAR_CON_SABIOS))
	ok("5) jefes_derrotados = 1", EstadoJuego.jefes_derrotados == 1, str(EstadoJuego.jefes_derrotados))
	ok("5) corazones_extra = 1 y medusa_derrotada", EstadoJuego.corazones_extra == 1 and EstadoJuego.medusa_derrotada)
	ok("5) vida 16/16", j.vida.vida_max == 16 and j.vida.vida == 16, "%d/%d" % [j.vida.vida, j.vida.vida_max])
	var hud := game.get_node(^"HUD") as HUD
	ok("5) HUD: 4 corazones llenos", hud.corazones.get_child_count() == 4 and hud.corazones.cuartos_visibles() == 16)
	ok("5) Leonidas libre", not j.esta_bloqueado())
	ok("5) Medusa se queda, quieta, con su recordatorio", is_instance_valid(medusa) and medusa.estado == Medusa.Estado.DERROTADA and medusa.charla.dialogo != null)
	ok("5) salida abierta", not salida_cerrada())

	# 6) Guardar y cargar.
	j.global_position = Vector2(272, 260)
	await ticks(2)
	ok("6) guarda", EstadoJuego.guardar(game.datos_guardado()))
	await liberar_game()
	EstadoJuego.reiniciar()
	ok("6) carga", EstadoJuego.cargar())
	await crear_game(false, false)
	zona = game.zona_actual
	medusa = zona.get_node_or_null(^"Objetos/Jefe/Medusa") as Medusa
	barra = (game.get_node(^"HUD") as HUD).barra_jefe
	await ticks(30)
	ok("6) en cueva_jefe", game.ruta_zona == "res://scenes/levels/cueva_jefe.tscn", game.ruta_zona)
	ok("6) vida 16/16 y 4 corazones", j.vida.vida_max == 16 and j.vida.vida == 16 and (game.get_node(^"HUD") as HUD).corazones.get_child_count() == 4)
	ok("6) Medusa derrotada con recordatorio", medusa != null and medusa.estado == Medusa.Estado.DERROTADA and medusa.charla.dialogo != null)
	ok("6) sin escena del encuentro", zona.get_node_or_null(^"Objetos/Eventos/EscenaMedusa") == null)
	ok("6) sin diálogo ni barra", not Dialogos.abierto and not barra.visible and not j.esta_bloqueado())
	ok("6) cabeza y misión siguen", EstadoJuego.cantidad(EstadoJuego.OBJ_CABEZA_PIEDRA) == 1 and EstadoJuego.mision_completada(EstadoJuego.MISION_DERROTAR_MEDUSA))

	# 7) Morir a mitad del combate (partida nueva).
	await liberar_game()
	EstadoJuego.reiniciar()
	await crear_game(true, true)
	await entrar_en_la_cueva()
	ok("7) vida base 12 en partida nueva", j.vida.vida_max == 12)

	# Primero con el Game Over de verdad (pausa el árbol; Continuar reaparece en la entrada).
	j.global_position = DENTRO
	await esperar_hasta(func() -> bool: return Dialogos.abierto, 900)
	await cerrar_dialogos()
	await esperar_hasta(func() -> bool: return not j.vida.es_invulnerable(), 300)
	j.vida.recibir_danio(99)
	var pg := game.pantalla_game_over
	await esperar_hasta(func() -> bool: return pg.abierta, 900)
	var continuar := pg.get_node(^"%Continuar") as Button
	await esperar_hasta(func() -> bool: return not continuar.disabled, 900)
	await pulsar(&"ui_accept")
	await esperar_hasta(func() -> bool: return not pg.abierta and not game.cambiando, 900)
	await ticks(30)
	ok("7) Game Over: reaparece en la entrada", j.global_position.distance_to(zona.punto_entrada("desde_cueva")) < 4.0, str(j.global_position))
	ok("7) Game Over: Medusa reiniciada y el encuentro NO empieza solo", medusa.estado == Medusa.Estado.INACTIVA
		and escena.fase == EscenaMedusa.Fase.ESPERANDO and not Dialogos.abierto and not j.esta_bloqueado())

	# El resto, reapareciendo sin pantalla de Game Over.
	j.reaparecer_automatico = true
	j.murio.disconnect(game._al_morir_jugador)
	j.global_position = DENTRO
	await esperar_hasta(func() -> bool: return Dialogos.abierto, 900)
	await cerrar_dialogos()
	await esperar_hasta(func() -> bool: return medusa.ciclopes_vivos().size() == 2, 300)
	await matar_ciclopes()
	await esperar_hasta(func() -> bool: return not medusa.vida.es_invulnerable(), 120)
	medusa.vida.recibir_danio(3)
	await ticks(2)
	ok("7) combate en marcha", medusa.vida.vida == 17 and barra.visible and salida_cerrada())
	await esperar_hasta(func() -> bool: return not j.vida.es_invulnerable(), 300)
	j.vida.recibir_danio(99)
	var reaparece := await esperar_hasta(func() -> bool: return j.estado == Jugador.Estado.NORMAL and not j.vida.muerto, 900)
	await ticks(5)
	ok("7) reaparece", reaparece)
	ok("7) en la entrada", j.global_position.distance_to(zona.punto_entrada("desde_cueva")) < 4.0, str(j.global_position))
	ok("7) Medusa reiniciada (INACTIVA, vida llena)", medusa.estado == Medusa.Estado.INACTIVA and medusa.vida.vida == 20)
	ok("7) sin cíclopes ni trozos", nodos_de("CiclopeSerpiente").is_empty() and nodos_de("TrozoEstatua").is_empty())
	ok("7) sin barra y salida abierta", not barra.visible and not salida_cerrada())
	ok("7) nada ganado", not EstadoJuego.medusa_derrotada and EstadoJuego.corazones_extra == 0)
	j.global_position = DENTRO
	abre = await esperar_hasta(func() -> bool: return Dialogos.abierto, 900)
	ok("7) al volver a la sala empieza otra vez", abre)
	await cerrar_dialogos()
	await ticks(3)
	ok("7) Medusa vuelve a invocar", medusa.estado == Medusa.Estado.INVOCAR and barra.visible)

	# Reaparecer DENTRO de la sala (p. ej. partida guardada allí): empieza solo.
	await esperar_hasta(func() -> bool: return not j.vida.es_invulnerable(), 300)
	j.punto_control = Vector2(272, 260)
	j.vida.recibir_danio(99)
	abre = await esperar_hasta(func() -> bool: return Dialogos.abierto, 1200)
	ok("7) reapareciendo dentro, el encuentro empieza solo", abre and medusa.estado == Medusa.Estado.INACTIVA)
	await cerrar_dialogos()
	await ticks(3)
	ok("7) y el combate también", medusa.estado == Medusa.Estado.INVOCAR)
