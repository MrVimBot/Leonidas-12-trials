extends "res://tools/pruebas/base_prueba.gd"
## Barrera de Zeus (BarreraMision): sin misión recibida, pisarla bloquea al jugador con destello
## y diálogo, lo cierra con eventos reales y Leonidas retrocede 24 px; en ningún fotograma queda
## libre entre el destello, el diálogo y el retroceso.

var _muestras: Array[int] = []
var _muestreando := false


func _process(_delta: float) -> void:
	if _muestreando:
		_muestras.append(j.estado)


func ejecutar() -> void:
	await crear_game(true, false)
	EstadoJuego.mision_recibida = false
	var B := Jugador.Estado.BLOQUEADO
	var N := Jugador.Estado.NORMAL
	var barrera := game.zona_actual.get_node(^"Objetos/Eventos/BarreraNorte") as BarreraMision
	ok("hay BarreraNorte cerrada", barrera != null and not EstadoJuego.mision_recibida)
	j.global_position = barrera.global_position
	var y0 := j.global_position.y
	_muestras.clear()
	_muestreando = true
	for i in 120:
		await get_tree().process_frame
		if Dialogos.abierto:
			break
	ok("sale el diálogo de Zeus", Dialogos.abierto)
	ok("jugador BLOQUEADO con el diálogo", j.estado == B and j.esta_bloqueado(), str(j.estado))
	var cerrados := 0
	for i in 600:
		if not Dialogos.abierto:
			break
		await pulsar(&"interactuar")
		cerrados += 1
	ok("el diálogo se cierra por eventos (%d pulsaciones)" % cerrados, not Dialogos.abierto)
	for i in 300:
		await get_tree().process_frame
		if j.estado == N:
			break
	await ticks(3)
	_muestreando = false
	ok("al final NORMAL y sin motivos", j.estado == N and not j.esta_bloqueado(), str(j.estado))
	ok("retrocedió ~24 px hacia abajo", absf(j.global_position.y - (y0 + 24.0)) < 1.0, "%.1f → %.1f" % [y0, j.global_position.y])
	# Desde el primer BLOQUEADO hasta el NORMAL final no hay ningún fotograma NORMAL.
	var primero := _muestras.find(B)
	var ultimo_b := _muestras.rfind(B)
	var hueco := false
	for k in range(primero, ultimo_b + 1):
		if _muestras[k] != B:
			hueco = true
	ok("ningún fotograma libre entre destello, diálogo y retroceso (%d fotogramas bloqueado)" % (ultimo_b - primero + 1), primero >= 0 and not hueco)
	ok("la barrera ya no está en curso (miembro privado: no hay otra forma de saberlo)", not barrera._en_curso)
