extends "res://tools/pruebas/base_prueba.gd"
## Escena de Kathita (entrega del libro) completa con eventos reales y SIN `depurar_saltar_kathita`:
## al cruzar el disparador el jugador queda BLOQUEADO en todos los fotogramas de la entrega; el
## control vuelve para la primera voltereta (la E que cerró el último cuadro no hace nada más);
## sale la despedida y la escena se libera con el jugador NORMAL y sin motivos de bloqueo.
## Aparte: si la escena se libera a mitad, no quedan Kathitas huérfanas ni el jugador bloqueado.

var _muestras: Array[int] = []
## true si en ese fotograma la escena aún no había devuelto el control.
var _en_entrega: Array[bool] = []
var _muestreando := false
var _escena: EscenaKathitaLibro


func _process(_delta: float) -> void:
	if _muestreando:
		_muestras.append(j.estado)
		_en_entrega.append(not (EstadoJuego.tiene_libro and _escena._bloqueado == null))


func ejecutar() -> void:
	await crear_game(false, false)
	var B := Jugador.Estado.BLOQUEADO
	var N := Jugador.Estado.NORMAL
	var escena := game.zona_actual.get_node(^"Objetos/Eventos/EntregaLibro") as EscenaKathitaLibro
	ok("hay escena de Kathita, sin libro ni voltereta", escena != null and not EstadoJuego.tiene_libro and not EstadoJuego.voltereta_aprendida)
	_escena = escena
	var disparador := escena.get_node(^"Disparador") as Area2D
	_muestras.clear()
	_muestreando = true
	j.global_position = disparador.global_position
	# Entrega: cerrar cada cuadro con E hasta que se devuelve el control para la voltereta.
	var empezo := false
	for i in 4000:
		await get_tree().process_frame
		if j.estado == B:
			empezo = true
		if empezo and EstadoJuego.tiene_libro and escena._bloqueado == null and not Dialogos.abierto:
			break
		if Dialogos.abierto:
			await pulsar(&"interactuar")
	_muestreando = false
	ok("la escena empezó y dio el libro", empezo and EstadoJuego.tiene_libro)
	var primero := _muestras.find(B)
	var hueco := -1
	var n_entrega := 0
	for k in range(primero, _muestras.size()):
		if not _en_entrega[k]:
			continue
		n_entrega += 1
		if _muestras[k] != B:
			hueco = k
			break
	ok("BLOQUEADO en todos los fotogramas de la entrega (%d)" % n_entrega, primero >= 0 and hueco == -1, "hueco en %d de %d" % [hueco, _muestras.size()])
	await ticks(3)
	ok("control devuelto para la voltereta: NORMAL sin motivos", j.estado == N and not j.esta_bloqueado(), str(j.estado))
	ok("la E que cerró el último cuadro no hizo nada más", not Dialogos.abierto and not EstadoJuego.voltereta_aprendida)
	j.estamina.llenar()
	await pulsar(&"pirueta")
	ok("voltereta por evento → voltereta_aprendida", EstadoJuego.voltereta_aprendida)
	# Despedida
	for i in 600:
		await get_tree().process_frame
		if Dialogos.abierto:
			break
	ok("sale la despedida", Dialogos.abierto)
	ok("jugador BLOQUEADO en la despedida", j.estado == B, str(j.estado))
	for i in 600:
		if not Dialogos.abierto:
			break
		await pulsar(&"interactuar")
	for i in 600:
		await get_tree().process_frame
		if not is_instance_valid(escena):
			break
	await ticks(3)
	ok("escena liberada; jugador NORMAL con 0 motivos", not is_instance_valid(escena) and j.estado == N and not j.esta_bloqueado(), str(j.estado))

	# Liberada a mitad: Kathita ya está fuera de casa cuando se libera la escena entera
	# (p. ej. al cambiar de zona): no deben quedar nodos Kathita ni el jugador bloqueado.
	await liberar_game()
	EstadoJuego.reiniciar()
	await crear_game(false, false)
	var k := game.zona_actual.get_node(^"Objetos/Eventos/EntregaLibro") as EscenaKathitaLibro
	j.global_position = (k.get_node(^"Disparador") as Node2D).global_position
	var fuera := false
	for i in 4000:
		await get_tree().process_frame
		if k.kathita.get_parent() != k and k.kathita.visible:
			fuera = true
			break
		if Dialogos.abierto:
			await pulsar(&"interactuar")
	ok("liberada: Kathita ya está fuera de casa (reparentada al Y-sort)", fuera)
	ok("liberada: el jugador está bloqueado por la escena", j.esta_bloqueado())
	k.queue_free()
	await ticks(3)
	Dialogos.cerrar()
	await ticks(3)
	var huerfanas := game.zona_actual.find_children("Kathita", "", true, false)
	ok("liberada: ningún nodo Kathita huérfano (%d)" % huerfanas.size(), huerfanas.is_empty())
	ok("liberada: jugador NORMAL y sin motivos", not j.esta_bloqueado() and j.estado == Jugador.Estado.NORMAL,
		str(j._motivos_bloqueo))
