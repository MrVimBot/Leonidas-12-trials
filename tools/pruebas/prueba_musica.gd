extends "res://tools/pruebas/base_prueba.gd"
## Música por zona (autoload Musica): pueblo en silencio, bosque/playa/mar/cueva_jefe con su pista
## en bucle, un solo reproductor a la vez, la misma pista no se reinicia al recargar la zona, varios
## cambios seguidos dejan un único reproductor y al liberar Game vuelve el silencio.
##
## Sobre el reloj: la posición de reproducción (`get_playback_position`) avanza con el reloj REAL
## del audio, no con el del juego, y con `--fixed-fps` el juego va mucho más rápido que el real.
## Por eso «la posición avanza» se espera con `Time.get_ticks_msec()` (hasta 3 s reales) en vez de
## con un temporizador del juego: la prueba vale con o sin `--fixed-fps`. El resto de las
## comprobaciones (qué pista suena, cuántos reproductores) no dependen del reloj.

const PUEBLO := "res://scenes/levels/pueblo.tscn"
const BOSQUE := "res://scenes/levels/bosque.tscn"
const PLAYA := "res://scenes/levels/playa.tscn"
const MAR := "res://scenes/levels/mar.tscn"
const JEFE := "res://scenes/levels/cueva_jefe.tscn"


func reproductores() -> Array:
	return Musica.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer)


func ir_y_esperar(ruta: String, entrada: String) -> void:
	await ir(ruta, entrada, ruta != MAR)
	await esperar(1.3) # fundidos de la música


func comprobar(nombre: String, pista: String) -> void:
	var r := reproductores()
	if pista == "":
		ok(nombre, r.is_empty(), "n=%d" % r.size())
		return
	var p := (r[0] as AudioStreamPlayer) if r.size() > 0 else null
	ok(nombre, r.size() == 1 and p.stream.resource_path == "res://assets/audio/music/%s.mp3" % pista,
		"n=%d %s" % [r.size(), p.stream.resource_path if p else ""])


## Espera (en tiempo real) a que la posición supere `desde`. Devuelve si lo hizo.
func _avanza_posicion(p: AudioStreamPlayer, desde: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		if p.get_playback_position() > desde:
			return true
		await get_tree().process_frame
	return p.get_playback_position() > desde


func ejecutar() -> void:
	EstadoJuego.tutorial_barco_visto = true
	Microfono.nivel_forzado = 0.0
	await crear_game(true, true)
	await esperar(1.3)
	comprobar("pueblo: silencio", "")
	await ir_y_esperar(BOSQUE, "desde_pueblo")
	comprobar("bosque", "bosque")
	ok("bosque en bucle", (reproductores()[0] as AudioStreamPlayer).stream.loop)
	await ir_y_esperar(PLAYA, "desde_bosque")
	comprobar("playa", "playa")
	await ir_y_esperar(MAR, "desde_playa")
	comprobar("mar", "barco")
	var p0 := reproductores()[0] as AudioStreamPlayer
	ok("la pista suena (posición > 0 en tiempo real)", await _avanza_posicion(p0, 0.0))
	var pos0 := p0.get_playback_position()
	await ir_y_esperar(MAR, "desde_playa")
	comprobar("mar recargada", "barco")
	ok("misma instancia: no se reinicia la pista", reproductores()[0] == p0)
	ok("la posición sigue avanzando (tiempo real)", await _avanza_posicion(p0, pos0))
	await ir_y_esperar(PLAYA, "desde_mar")
	comprobar("playa de vuelta", "playa")
	await ir_y_esperar(BOSQUE, "desde_playa")
	comprobar("bosque de vuelta", "bosque")
	await ir_y_esperar(PUEBLO, "desde_bosque")
	comprobar("pueblo: silencio otra vez", "")
	# Cambios rápidos de pista: queda un único reproductor
	for pista: String in ["playa", "bosque", "playa"]:
		Musica.reproducir(load("res://assets/audio/music/%s.mp3" % pista))
		await esperar(0.2)
	await esperar(1.5)
	ok("3 cambios seguidos → 1 reproductor", reproductores().size() == 1, "n=%d" % reproductores().size())
	await ir_y_esperar(JEFE, "inicio")
	comprobar("cueva_jefe", "bossfight")
	game.queue_free()
	await esperar(2.0)
	ok("al liberar Game, silencio", reproductores().is_empty(), "n=%d" % reproductores().size())
