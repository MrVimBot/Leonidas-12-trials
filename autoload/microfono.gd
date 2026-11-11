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

# Valores medidos con el micrófono del MacBook Air (2026-11-10): silencio ≈ −58 dB,
# soplo suave −40…−46, soplo fuerte −14…−35 (continuo), voz con picos de −19 pero
# a golpes (cae a −58 entre sílabas). Para que hablar no mueva el barco se usa el
# nivel SOSTENIDO: el mínimo de los últimos `ventana_sostenido` segundos.

## dB a partir de los cuales empieza a contar el soplido (lo ajusta `calibrar()`).
@export var db_min := -48.0
## dB que equivalen a soplar al máximo.
@export var db_max := -26.0
## Margen sobre el ruido ambiente al calibrar.
@export var margen_db := 10.0
## Distancia mínima entre db_min y db_max tras calibrar.
@export var rango_min_db := 18.0
## Segundos que tiene que mantenerse el sonido para contar (filtra la voz).
@export var ventana_sostenido := 0.5
## Velocidad de subida/bajada del nivel suavizado (por segundo).
@export var subida := 8.0
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
## dB sostenido: mínimo de la ventana.
var db_sostenido := -80.0
var _historial: Array[Vector2] = [] # (tiempo, dB)
var _reloj := 0.0
var _sin_datos := 0.0


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
	_historial.clear()
	db_sostenido = -80.0
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
	if db_max < db_min + rango_min_db:
		db_max = db_min + rango_min_db


func _process(delta: float) -> void:
	if not _activo:
		return
	_tiempo_activo += delta
	_reloj += delta
	var frames := _captura.get_frames_available()
	if frames <= 0:
		# Hay fotogramas sin audio nuevo (el audio llega en bloques): se mantiene el
		# nivel; solo baja si deja de llegar audio un rato.
		_sin_datos += delta
		if _sin_datos > 0.2:
			_suavizar(0.0, delta)
		return
	_sin_datos = 0.0
	var buffer := _captura.get_buffer(frames)
	var suma := 0.0
	for muestra in buffer:
		suma += (muestra.x * muestra.x + muestra.y * muestra.y) * 0.5
	var rms := sqrt(suma / buffer.size())
	if rms > 0.0 and not disponible:
		disponible = true
		disponible_cambio.emit(true)
	_ultimo_db = linear_to_db(rms) if rms > 0.0 else -80.0
	db_sostenido = _sostenido(_ultimo_db)
	_suavizar(clampf(inverse_lerp(db_min, db_max, db_sostenido), 0.0, 1.0), delta)


## Mínimo de los dB de los últimos `ventana_sostenido` s (la voz va a golpes; soplar no).
func _sostenido(db: float) -> float:
	_historial.append(Vector2(_reloj, db))
	while _historial.size() > 1 and _reloj - _historial[0].x > ventana_sostenido:
		_historial.pop_front()
	var minimo := db
	for h in _historial:
		minimo = minf(minimo, h.y)
	return minimo


func _suavizar(crudo: float, delta: float) -> void:
	var vel := subida if crudo > nivel else bajada
	nivel = move_toward(nivel, crudo, vel * delta)
