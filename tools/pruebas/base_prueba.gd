extends Node
## Base de las pruebas de jugabilidad (`tools/pruebas/prueba_*.gd`). Léela antes de escribir una.
##
## CÓMO SE ESCRIBE UNA PRUEBA
##
##     extends "res://tools/pruebas/base_prueba.gd"
##     ## Qué cubre esta prueba (cabecera obligatoria).
##
##     func ejecutar() -> void:
##         await crear_game(true, true)   # game.tscn en el pueblo, sin Kathita y con misión
##         ok("arranca en NORMAL", j.estado == Jugador.Estado.NORMAL)
##
## - Se hereda por ruta (no hay `class_name`: no contamina las clases globales del juego).
## - NO se define `_ready()`: la base lo usa para preparar el entorno y llama a `ejecutar()`
##   (que puede usar `await`). Al volver de `ejecutar()` termina sola con `terminar()`.
## - Se lanza con `lanzar.gd` (ver su cabecera) o con `tools/verificar_todo.sh <patrón>`.
##
## CONVENCIÓN DE SALIDA
## - Una línea por comprobación: `PASA  nombre detalle` o `FALLA  nombre detalle`.
## - Al final, `COMPROBACIONES: N` y `RESULTADO: TODO PASA` o `RESULTADO: N FALLOS`.
## - Código de salida 0 si todo pasa, 1 si hay algún fallo o se agota el tiempo.
##
## PROTECCIONES (no se pueden quitar desde una prueba)
## - Partida real: al arrancar, `EstadoJuego.ruta_partida` apunta a `RUTA_PARTIDA_PRUEBA`
##   (`user://prueba_partida.cfg`), que se borra al empezar y al terminar. Además, al terminar se
##   comprueba que `user://partida.cfg` no ha cambiado de fecha: si cambió, FALLA.
## - Tiempo máximo: `tiempo_maximo` segundos REALES (por defecto 120). Si se agota, la prueba
##   FALLA y sale con error en vez de quedarse colgada. Una prueba más larga lo sube en `ejecutar()`.
##
## NOTAS DE ENTORNO
## - Se ejecuta con `--headless --fixed-fps 120` (como el juego, 120 ticks de física/s): los
##   segundos de juego pasan más rápido que los reales. Esperar con `ticks()`/`esperar_hasta()`
##   y no con `create_timer` salvo que haga falta el reloj del juego.
## - Un `ERROR: Parameter "t" is null` al abrir el libro es inofensivo (captura de pantalla con el
##   renderizador vacío); `verificar_todo.sh` lo ignora.

const RUTA_PARTIDA_PRUEBA := "user://prueba_partida.cfg"
const PARTIDA_REAL := "user://partida.cfg"

## Segundos reales máximos de la prueba (ver cabecera).
var tiempo_maximo := 120.0

var fallos := 0
var comprobaciones := 0
## Se rellenan con `crear_game()`.
var game: Game
var j: Jugador

var _inicio_ms := 0
var _fecha_partida_real := 0
var _terminada := false


func _ready() -> void:
	# Las pruebas siguen corriendo con el árbol en pausa (libro, pausa, escenas con pausa).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_inicio_ms = Time.get_ticks_msec()
	_fecha_partida_real = FileAccess.get_modified_time(PARTIDA_REAL)
	EstadoJuego.ruta_partida = RUTA_PARTIDA_PRUEBA
	borrar_partida_prueba()
	get_tree().process_frame.connect(_vigilar)
	_correr.call_deferred()


func _correr() -> void:
	await ejecutar()
	terminar()


## La prueba. Se sobrescribe en cada archivo.
func ejecutar() -> void:
	ok("la prueba sobrescribe ejecutar()", false)


## Vigilante del tiempo máximo. Va por la señal `process_frame` (y no en `_process`) para que una
## prueba pueda definir su propio `_process`/`_physics_process` sin anularlo.
func _vigilar() -> void:
	if not _terminada and (Time.get_ticks_msec() - _inicio_ms) / 1000.0 > tiempo_maximo:
		ok("tiempo máximo (%.0f s reales) agotado: la prueba se colgó" % tiempo_maximo, false)
		terminar()


# --- Comprobaciones y salida ----------------------------------------------------------------

func ok(nombre: String, cond: bool, detalle: String = "") -> void:
	comprobaciones += 1
	print("%s  %s %s" % ["PASA " if cond else "FALLA", nombre, detalle])
	if not cond:
		fallos += 1


## Imprime el resultado, limpia y sale. Se llama sola al acabar `ejecutar()`.
func terminar() -> void:
	if _terminada:
		return
	_terminada = true
	borrar_partida_prueba()
	if FileAccess.get_modified_time(PARTIDA_REAL) != _fecha_partida_real:
		fallos += 1
		print("FALLA  la prueba ha modificado la partida real (%s)" % PARTIDA_REAL)
	print("COMPROBACIONES: ", comprobaciones)
	print("RESULTADO: ", "TODO PASA" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(1 if fallos else 0)


func borrar_partida_prueba() -> void:
	if FileAccess.file_exists(RUTA_PARTIDA_PRUEBA):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA_PARTIDA_PRUEBA))


# --- Tiempo ---------------------------------------------------------------------------------

## Espera `n` ticks de física y un fotograma de proceso.
func ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame


## Espera (tick a tick) hasta que `condicion` sea true o pasen `max_ticks`. Devuelve si se cumplió.
func esperar_hasta(condicion: Callable, max_ticks: int = 600) -> bool:
	for i in max_ticks:
		if condicion.call():
			return true
		await get_tree().physics_frame
	return condicion.call()


## Espera `segundos` de JUEGO (con `--fixed-fps` pasan más rápido que los reales).
func esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


# --- Entrada --------------------------------------------------------------------------------

## Envía una acción del mapa de entradas como evento real (no `Input.action_press`).
func accion(nombre: StringName, pulsado: bool) -> void:
	var e := InputEventAction.new()
	e.action = nombre
	e.pressed = pulsado
	Input.parse_input_event(e)


## Pulsa y suelta `nombre`, esperando un par de ticks en cada paso.
func pulsar(nombre: StringName) -> void:
	accion(nombre, true)
	await ticks(2)
	accion(nombre, false)
	await ticks(2)


func tecla(codigo: Key, pulsado: bool, eco: bool = false) -> void:
	var e := InputEventKey.new()
	e.keycode = codigo
	e.physical_keycode = codigo
	e.pressed = pulsado
	e.echo = eco
	Input.parse_input_event(e)


func pulsar_tecla(codigo: Key) -> void:
	tecla(codigo, true)
	await ticks(2)
	tecla(codigo, false)
	await ticks(2)


## Pulsa `nombre` hasta que se cierre el diálogo (como avanzar todos los cuadros).
func cerrar_dialogos(nombre: StringName = &"interactuar", maximo: int = 60) -> void:
	var n := 0
	while Dialogos.abierto and n < maximo:
		n += 1
		await pulsar(nombre)


# --- Escenas --------------------------------------------------------------------------------

## Instancia `game.tscn` (pueblo) y espera a que acabe el fundido inicial.
## `saltar_kathita` y `mision` son los `depurar_*` de Game: true = sin escena de Kathita y con
## misión/espada recibidas (la prueba arranca "ya jugada"); false = flujo natural.
func crear_game(saltar_kathita: bool, mision: bool) -> void:
	game = (load("res://game.tscn") as PackedScene).instantiate() as Game
	game.depurar_saltar_kathita = saltar_kathita
	game.depurar_mision_recibida = mision
	get_tree().root.add_child(game)
	j = game.get_node(^"Jugador") as Jugador
	await esperar_normal()
	await ticks(5)


## Espera a que Game termine el cambio de zona y el jugador esté libre.
func esperar_normal() -> void:
	await esperar_hasta(func() -> bool: return j.estado == Jugador.Estado.NORMAL and not game.cambiando)


## Cambia de zona y espera a que acabe el fundido. En zonas con barco (`mar`) el jugador queda
## desactivado: pasar `a_pie = false` para no esperar a su estado NORMAL.
func ir(ruta: String, entrada: String, a_pie: bool = true) -> void:
	game.cambiar_zona(ruta, entrada)
	await get_tree().process_frame
	if a_pie:
		await esperar_normal()
	else:
		await esperar_hasta(func() -> bool: return not game.cambiando)
	await ticks(10)


## Libera el Game actual (por si la prueba necesita crear otro).
func liberar_game() -> void:
	if is_instance_valid(game):
		game.queue_free()
	await ticks(5)
