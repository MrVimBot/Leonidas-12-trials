extends "res://tools/pruebas/base_prueba.gd"
## Escena de los sabios (EscenaSabios), con eventos reales:
##  1) en pausa no avanza (los temporizadores de la escena respetan la pausa);
##  2) flujo completo: pose con la espada («comer» + objeto en mano, BLOQUEADO) mientras sale el
##     aviso «Obtuviste…», la J que cierra el cuadro no cuenta como espadazo, el perímetro
##     («no te vayas») devuelve al jugador, el primer J nuevo es el espadazo y la escena termina
##     con el jugador NORMAL y sin motivos.
## Usa miembros privados de la escena (`_esperando_ataque`, `_devolviendo`, `_en_curso`).

var _pose_ok := true
var _pose_muestras := 0
var _escena: EscenaSabios


func _aviso_abierto() -> bool:
	return Dialogos.abierto and (Dialogos as CajaDialogo).texto.text.contains("Obtuviste")


func _process(_delta: float) -> void:
	if j and _aviso_abierto():
		_pose_muestras += 1
		var en_mano := j.get_node(^"ObjetoEnMano") as Sprite2D
		if j.animador.animacion_actual() != &"comer" or not en_mano.visible or j.estado != Jugador.Estado.BLOQUEADO:
			_pose_ok = false


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
	var en_mano := j.get_node(^"ObjetoEnMano") as Sprite2D
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
