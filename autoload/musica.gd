extends Node
## Música de fondo (autoload `Musica`). Game llama a `reproducir(zona.musica)` al cambiar de zona:
## si la zona tiene canción se funde hacia ella; si es la misma que ya suena no se reinicia;
## si no tiene, se desvanece en silencio. Las canciones se repiten solas.

const DB_SILENCIO := -60.0
## Volumen de las canciones (dB).
@export var volumen_db := -6.0
@export var duracion_fundido := 1.0

var _actual: AudioStream
var _jugador: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## `flujo` null = silencio. Si es la canción que ya suena, no se reinicia.
func reproducir(flujo: AudioStream) -> void:
	if flujo == _actual:
		return
	_actual = flujo
	if _jugador and is_instance_valid(_jugador):
		_apagar(_jugador)
		_jugador = null
	if flujo == null:
		return
	# El bucle se activa en la importación (Loop en la pestaña Importar de cada mp3),
	# no en código: así no se modifica el recurso compartido.
	var nuevo := AudioStreamPlayer.new()
	nuevo.stream = flujo
	nuevo.volume_db = DB_SILENCIO
	add_child(nuevo)
	nuevo.play()
	_jugador = nuevo
	_fundir(nuevo, volumen_db)


## Funde `reproductor` hasta silencio y lo libera. Cada reproductor lleva su propio tween
## (creado desde él), así que otro cambio de canción no puede dejarlo sonando a medias.
func _apagar(reproductor: AudioStreamPlayer) -> void:
	var t := _fundir(reproductor, DB_SILENCIO)
	t.tween_callback(reproductor.queue_free)


## Lleva el volumen del reproductor a `destino_db`; sustituye el fundido anterior de ese
## mismo reproductor (p. ej. la entrada aún sin acabar cuando toca apagarlo).
func _fundir(reproductor: AudioStreamPlayer, destino_db: float) -> Tween:
	if reproductor.has_meta(&"fundido"):
		var previo: Tween = reproductor.get_meta(&"fundido")
		if previo and previo.is_valid():
			previo.kill()
	var t := reproductor.create_tween()
	t.tween_property(reproductor, "volume_db", destino_db, duracion_fundido)
	reproductor.set_meta(&"fundido", t)
	return t


func detener() -> void:
	reproducir(null)
