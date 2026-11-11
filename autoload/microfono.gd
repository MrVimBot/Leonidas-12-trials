extends Node
## Nivel del soplido en el micrófono (minijuego del barco). Autoload: `Microfono`.
##   Microfono.activar()          # abre el micro (solo durante el minijuego)
##   var fuerza := Microfono.nivel  # 0..1, ya suavizado
##   await Microfono.calibrar()   # mide el ruido ambiente y ajusta el umbral
##   Microfono.desactivar()
##
## Crea por código un bus "Microfono" silenciado con un AudioEffectCapture, y un
## AudioStreamPlayer con AudioStreamMicrophone que suena en ese bus: el audio se
## analiza pero no sale por los altavoces.
## Necesita `audio/driver/enable_input = true` en el proyecto.
## Si no llega audio (sin permiso, sin dispositivo, web sin gesto), `disponible`
## queda en false y el juego se sigue pudiendo jugar con el teclado (Espacio).

signal disponible_cambio(disponible: bool)

const NOMBRE_BUS := &"Microfono"

## dB a partir de los cuales empieza a contar el soplido (lo ajusta `calibrar()`).
@export var db_min := -40.0
## dB que equivalen a soplar al máximo.
@export var db_max := -12.0
## Margen sobre el ruido ambiente al calibrar.
@export var margen_db := 12.0
## Velocidad de subida/bajada del nivel suavizado (por segundo).
@export var subida := 20.0
@export var bajada := 4.0
## Duración del buffer de captura (menor = menos retraso).
@export var buffer_captura := 0.1

var nivel := 0.0
var disponible := false
## ≥ 0 sustituye al micrófono (pruebas automáticas).
var nivel_forzado := -1.0

var _captura: AudioEffectCapture
var _reproductor: AudioStreamPlayer
var _activo := false
var _tiempo_activo := 0.0
var _ultimo_db := -80.0


func _ready() -> void:
	var idx := AudioServer.get_bus_index(NOMBRE_BUS)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, NOMBRE_BUS)
	# Mute del bus: el audio no llega a "Master" pero los efectos del bus sí lo reciben.
	AudioServer.set_bus_mute(idx, true)
	_captura = AudioEffectCapture.new()
	_captura.buffer_length = buffer_captura
	AudioServer.add_bus_effect(idx, _captura)

	_reproductor = AudioStreamPlayer.new()
	_reproductor.name = "Entrada"
	_reproductor.stream = AudioStreamMicrophone.new()
	_reproductor.bus = NOMBRE_BUS
	add_child(_reproductor)


func activar() -> void:
	if _activo:
		return
	_activo = true
	_tiempo_activo = 0.0
	_captura.clear_buffer()
	_reproductor.play()


func desactivar() -> void:
	_activo = false
	_reproductor.stop()
	nivel = 0.0


func esta_activo() -> bool:
	return _activo


## Nivel que debe usar el juego: el forzado (pruebas) o el del micrófono.
func nivel_efectivo() -> float:
	return nivel_forzado if nivel_forzado >= 0.0 else nivel


## Mide el ruido ambiente durante `duracion` s y fija `db_min` por encima de él.
func calibrar(duracion := 0.5) -> void:
	if not _activo:
		return
	var suma := 0.0
	var n := 0
	var t := 0.0
	while t < duracion:
		await get_tree().process_frame
		t += get_process_delta_time()
		suma += _ultimo_db
		n += 1
	if n == 0 or not disponible:
		return
	db_min = clampf(suma / n + margen_db, -50.0, -20.0)
	if db_max <= db_min + 6.0:
		db_max = db_min + 6.0


func _process(delta: float) -> void:
	if not _activo:
		return
	_tiempo_activo += delta
	var frames := _captura.get_frames_available()
	if frames <= 0:
		_suavizar(0.0, delta)
		return
	var buffer := _captura.get_buffer(frames)
	var suma := 0.0
	for muestra in buffer:
		suma += (muestra.x * muestra.x + muestra.y * muestra.y) * 0.5
	var rms := sqrt(suma / buffer.size())
	if rms > 0.0 and not disponible:
		disponible = true
		disponible_cambio.emit(true)
	_ultimo_db = linear_to_db(rms) if rms > 0.0 else -80.0
	_suavizar(clampf(inverse_lerp(db_min, db_max, _ultimo_db), 0.0, 1.0), delta)


func _suavizar(crudo: float, delta: float) -> void:
	var vel := subida if crudo > nivel else bajada
	nivel = move_toward(nivel, crudo, vel * delta)
