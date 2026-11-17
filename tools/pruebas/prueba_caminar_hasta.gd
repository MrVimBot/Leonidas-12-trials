extends "res://tools/pruebas/base_prueba.gd"
## `caminar_hasta(destino, velocidad)` del Jugador y de un NPC (cinemáticas): llega exacto, tarda
## distancia/velocidad, usa la animación de caminar durante el trayecto y parado al llegar, y no
## hace nada si ya está a menos de 1 px.

var _t := 0.0
var _midiendo := false
var _anims: Array[String] = []

func _process(delta: float) -> void:
	if _midiendo:
		_t += delta

func _caminar_jugador(destino: Vector2, vel: float) -> void:
	var antes := j.global_position
	var d := antes.distance_to(destino)
	_anims.clear()
	_t = 0.0
	_midiendo = true
	var hilo := [false]
	var f := func() -> void:
		await j.caminar_hasta(destino, vel)
		hilo[0] = true
	f.call()
	while not hilo[0]:
		await get_tree().process_frame
		if not hilo[0]:
			_anims.append(String(j.animador.animacion_actual()))
	_midiendo = false
	var esperado := d / vel
	if d < 1.0:
		ok("dist %.2f < 1: no hace nada" % d, j.global_position == antes and _t < 0.05)
		return
	ok("llega exacto a %s" % destino, j.global_position.is_equal_approx(destino), str(j.global_position))
	ok("tarda %.3f s (medido %.3f)" % [esperado, _t], absf(_t - esperado) < 0.03)
	var todas_caminar := not _anims.is_empty()
	for a in _anims:
		if not a.begins_with("caminar"):
			todas_caminar = false
	ok("animación caminar durante el trayecto (%d fotogramas)" % _anims.size(), todas_caminar, str(_anims.slice(0, 2)))
	ok("al llegar: parado", String(j.animador.animacion_actual()).begins_with("parado"), String(j.animador.animacion_actual()))


func ejecutar() -> void:
	await crear_game(true, false)
	j.bloquear(&"prueba")
	var p := j.global_position
	await _caminar_jugador(p + Vector2(60, 0), 60.0)
	await _caminar_jugador(j.global_position + Vector2(-30, 40), 80.0)
	await _caminar_jugador(j.global_position + Vector2(0, -24), 80.0)
	await _caminar_jugador(j.global_position + Vector2(0.5, 0), 60.0)
	ok("dirección tras ir hacia arriba", j.animador.direccion == Vector2.UP, str(j.animador.direccion))
	j.desbloquear(&"prueba")

	# NPC (sabio)
	var sabio := game.zona_actual.get_node(^"Objetos/NPCs/Sabio1") as NPC
	var animador := sabio.get_node(^"Animador") as AnimadorDireccional
	var s0 := sabio.global_position
	var destino := s0 + Vector2(0, 30)
	_t = 0.0
	_midiendo = true
	var fin := [false]
	var g := func() -> void:
		await sabio.caminar_hasta(destino, 60.0)
		fin[0] = true
	g.call()
	var cam := true
	var n := 0
	while not fin[0]:
		await get_tree().process_frame
		if not fin[0]:
			n += 1
			if not String(animador.animacion_actual()).begins_with("caminar"):
				cam = false
	_midiendo = false
	ok("NPC llega exacto", sabio.global_position.is_equal_approx(destino), str(sabio.global_position))
	ok("NPC tarda 0.5 s (%.3f)" % _t, absf(_t - 0.5) < 0.03)
	ok("NPC caminar durante (%d) y parado al final" % n, cam and n > 0 and String(animador.animacion_actual()).begins_with("parado"))
	var p2 := sabio.global_position
	await sabio.caminar_hasta(p2 + Vector2(0.3, 0), 60.0)
	ok("NPC dist<1 no hace nada", sabio.global_position == p2)
	await sabio.caminar_hasta(s0, 60.0)
