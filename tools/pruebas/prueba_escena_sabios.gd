extends "res://tools/pruebas/base_prueba.gd"
## Escena de los sabios (EscenaSabios), con eventos reales:
##  1) en pausa no avanza (los temporizadores de la escena respetan la pausa);
##  2) flujo completo: pose con la espada («comer» + objeto en mano, BLOQUEADO) mientras sale el
##     aviso «Obtuviste…», la J que cierra el cuadro no cuenta como espadazo, el perímetro
##     («no te vayas») devuelve al jugador, el primer J nuevo es el espadazo y la escena termina
##     con el jugador NORMAL y sin motivos;
##  3) con la misión pero sin Medusa vencida: recordatorios de siempre, sin escena;
##  4) regreso con Medusa vencida: burbuja «!», al hablar con un sabio enseña la cabeza
##     (la conserva) y recibe la misión del Minotauro; guardar y cargar no repite la escena.
## Usa miembros privados de la escena (`_esperando_ataque`, `_devolviendo`, `_en_curso`).

var _pose_ok := true
var _pose_muestras := 0
var _escena: EscenaSabios


func _aviso_abierto() -> bool:
	return Dialogos.abierto and (Dialogos as CajaDialogo).texto.text.contains("Obtuviste")


func _process(_delta: float) -> void:
	if j and _aviso_abierto():
		_pose_muestras += 1
		var en_mano := j.get_node(^"Visual/ObjetoEnMano") as Sprite2D
		if j.animador.animacion_actual() != &"comer" or not en_mano.visible or j.estado != Jugador.Estado.BLOQUEADO:
			_pose_ok = false


## Títulos que la página de Misiones del libro escribiría ahora (principales y secundarias).
func _titulos_libro() -> Array[String]:
	var pagina := Libro.get_node(^"Libro/Contenido/Misiones") as PaginaMisiones
	pagina.refrescar()
	var t: Array[String] = []
	for l: Label in pagina._renglones:
		t.append(l.text)
	return t


func ejecutar() -> void:
	# 1) En pausa la escena no avanza
	await crear_game(true, false)
	var escena := game.zona_actual.find_child("EscenaSabios", true, false) as EscenaSabios
	EstadoJuego.tiene_espada = false
	j.global_position = escena.global_position + Vector2(0, 38) # justo en PuntoLeonidas
	await esperar_hasta(func() -> bool: return escena._en_curso, 40)
	ok("la escena de sabios empezó", escena._en_curso)
	get_tree().paused = true
	await get_tree().create_timer(1.2, true).timeout
	ok("en pausa 1.2 s no sale el diálogo", not Dialogos.abierto)
	get_tree().paused = false
	ok("al reanudar sale el diálogo", await esperar_hasta(func() -> bool: return Dialogos.abierto, 240))
	escena.queue_free()
	await ticks(3)
	Dialogos.cerrar()
	await ticks(3)
	ok("sabios liberada a mitad: sin motivos de bloqueo", not j.esta_bloqueado(), str(j._motivos_bloqueo))
	await liberar_game()
	EstadoJuego.reiniciar()

	# 2) Flujo completo
	await crear_game(true, false)
	var B := Jugador.Estado.BLOQUEADO
	var N := Jugador.Estado.NORMAL
	_escena = game.zona_actual.find_child("EscenaSabios", true, false) as EscenaSabios
	ok("hay EscenaSabios y no hay misión", _escena != null and not EstadoJuego.mision_recibida)
	EstadoJuego.tiene_espada = false
	var ataques := [0]
	j.ataque_empezado.connect(func() -> void: ataques[0] += 1)
	j.global_position = _escena.global_position + Vector2(0, 50)
	var vio_aviso := false
	for i in 4000:
		await get_tree().process_frame
		if _escena._esperando_ataque:
			break
		if Dialogos.abierto:
			if _aviso_abierto():
				vio_aviso = true
				await ticks(20) # mirar la pose un rato con el aviso abierto
			await pulsar(&"atacar")
	ok("llega al tutorial de ataque", _escena._esperando_ataque)
	ok("pose con la espada (comer + ObjetoEnMano, BLOQUEADO) mientras sale el aviso (%d fotogramas)" % _pose_muestras, vio_aviso and _pose_ok and _pose_muestras > 20)
	var en_mano := j.get_node(^"Visual/ObjetoEnMano") as Sprite2D
	ok("al cerrar el aviso se quita la espada de la mano", not en_mano.visible)
	await ticks(10)
	ok("la J que cerró el último cuadro no es el espadazo", ataques[0] == 0, "ataques=%d" % ataques[0])
	ok("jugador NORMAL con espada", j.estado == N and j.tiene_espada and not j.esta_bloqueado(), str(j.estado))

	# Perímetro: salir antes de atacar.
	var punto := _escena.get_node(^"PuntoLeonidas") as Marker2D
	j.global_position = _escena.global_position + Vector2(0, 80)
	for i in 240:
		await get_tree().process_frame
		if Dialogos.abierto:
			break
	ok("perímetro: sale «no te vayas»", Dialogos.abierto)
	ok("perímetro: BLOQUEADO", j.estado == B, str(j.estado))
	for i in 600:
		if not Dialogos.abierto:
			break
		await pulsar(&"atacar")
	var libre_antes := false
	for i in 600:
		await get_tree().process_frame
		if j.estado == N:
			break
		if not _escena._devolviendo:
			libre_antes = true
	await ticks(3)
	ok("perímetro: vuelve a su sitio", j.global_position.distance_to(punto.global_position) < 1.0, str(j.global_position))
	ok("perímetro: NORMAL sin motivos, sigue esperando el espadazo", j.estado == N and not j.esta_bloqueado() and _escena._esperando_ataque and not libre_antes)
	ok("perímetro: cerrar con J no fue un espadazo", ataques[0] == 0, "ataques=%d" % ataques[0])

	await pulsar(&"atacar")
	ok("un J nuevo es el espadazo", ataques[0] == 1 and not _escena._esperando_ataque, "ataques=%d" % ataques[0])
	var escena_ref := _escena
	for i in 1500:
		await get_tree().physics_frame
		if not is_instance_valid(escena_ref):
			break
		if Dialogos.abierto:
			await pulsar(&"interactuar")
	await ticks(10)
	ok("escena terminada, jugador NORMAL sin motivos", not is_instance_valid(escena_ref) and j.estado == N and not j.esta_bloqueado(), str(j.estado))

	await liberar_game()
	EstadoJuego.reiniciar()

	# 3) Con misión y Medusa viva: recordatorios de siempre
	EstadoJuego.mision_recibida = true
	await crear_game(true, true)
	var sabio1 := game.zona_actual.find_child("Sabio1", true, false) as NPC
	ok("sin Medusa vencida no queda escena", game.zona_actual.find_child("EscenaSabios", true, false) == null)
	ok("sin Medusa vencida: recordatorio del toro", sabio1.dialogo != null and sabio1.dialogo.resource_path.ends_with("sabios_recordatorio_toro.tres"))
	await liberar_game()
	EstadoJuego.reiniciar()

	# 4) Regreso con la cabeza
	EstadoJuego.mision_recibida = true
	EstadoJuego.medusa_derrotada = true
	EstadoJuego.agregar_objeto(EstadoJuego.OBJ_CABEZA_PIEDRA)
	await crear_game(true, true)
	var regreso := game.zona_actual.find_child("EscenaSabios", true, false) as EscenaSabios
	sabio1 = game.zona_actual.find_child("Sabio1", true, false) as NPC
	var zona := sabio1.get_node(^"%ZonaDialogo") as ZonaDialogo
	ok("regreso: la escena sigue", regreso != null)
	ok("regreso: misión «Regresa con los sabios» activa (partida sin ella)", EstadoJuego.mision_empezada(EstadoJuego.MISION_REGRESAR_CON_SABIOS) and not EstadoJuego.mision_completada(EstadoJuego.MISION_REGRESAR_CON_SABIOS))
	ok("libro: se ve «Regresa con los sabios»", _titulos_libro().has("Regresa con los sabios"), str(_titulos_libro()))
	ok("regreso: burbuja «!» y diálogo de regreso", zona.tipo == ZonaDialogo.Tipo.MISION and sabio1.dialogo.resource_path.ends_with("sabios_regreso.tres"))
	j.global_position = sabio1.global_position + Vector2(0, 20)
	await ticks(3)
	zona.interactuar(j)
	var vio_cabeza := false
	var en_mano2 := j.get_node(^"Visual/ObjetoEnMano") as Sprite2D
	for i in 4000:
		await get_tree().physics_frame
		if not is_instance_valid(regreso):
			break
		if Dialogos.abierto:
			if (Dialogos as CajaDialogo).texto.text.contains("enseña la cabeza"):
				await ticks(5)
				vio_cabeza = vio_cabeza or (en_mano2.visible and j.estado == Jugador.Estado.BLOQUEADO)
			await pulsar(&"interactuar")
	await ticks(10)
	ok("regreso: pose con la cabeza en alto", vio_cabeza)
	ok("regreso: escena terminada, NORMAL sin motivos", not is_instance_valid(regreso) and j.estado == Jugador.Estado.NORMAL and not j.esta_bloqueado(), str(j.estado))
	ok("regreso: misión del Minotauro activa, Medusa completada",
		EstadoJuego.mision_empezada(EstadoJuego.MISION_DERROTAR_MINOTAURO) and not EstadoJuego.mision_completada(EstadoJuego.MISION_DERROTAR_MINOTAURO)
		and EstadoJuego.mision_completada(EstadoJuego.MISION_DERROTAR_MEDUSA))
	ok("regreso: «Regresa con los sabios» completada", EstadoJuego.mision_completada(EstadoJuego.MISION_REGRESAR_CON_SABIOS))
	var titulos := _titulos_libro()
	ok("libro: 4 principales → salen las 3 últimas, con el Minotauro",
		titulos.slice(0, 3) == ["Derrota a Medusa", "Regresa con los sabios", "Derrota al Minotauro"], str(titulos))
	ok("regreso: conserva la cabeza", EstadoJuego.cantidad(EstadoJuego.OBJ_CABEZA_PIEDRA) == 1)
	ok("regreso: recordatorios del Minotauro y burbuja normal", sabio1.dialogo.resource_path.ends_with("sabios_recordatorio_minotauro_toro.tres") and zona.tipo == ZonaDialogo.Tipo.HABLAR)
	ok("hay recurso de la misión del Minotauro", EstadoJuego.mision(EstadoJuego.MISION_DERROTAR_MINOTAURO) != null)

	EstadoJuego.guardar(game.datos_guardado())
	await liberar_game()
	EstadoJuego.reiniciar()
	EstadoJuego.cargar()
	await crear_game(true, false)
	sabio1 = game.zona_actual.find_child("Sabio1", true, false) as NPC
	ok("tras cargar: sin escena y con recordatorio del Minotauro",
		game.zona_actual.find_child("EscenaSabios", true, false) == null
		and sabio1 != null and sabio1.dialogo.resource_path.ends_with("sabios_recordatorio_minotauro_toro.tres"))
