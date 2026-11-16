extends Node
## Música de fondo (autoload `Musica`). Game llama a `para_zona(ruta)` al cambiar de zona:
## si la zona tiene canción se funde hacia ella; si es la misma que ya suena no se reinicia;
## si no tiene, se desvanece en silencio. Las canciones se repiten solas.

## Ruta de la escena de la zona → canción. Zonas que no salgan aquí quedan en silencio.
const POR_ZONA := {
	"res://scenes/levels/bosque.tscn": "res://assets/audio/music/bosque.mp3",
	"res://scenes/levels/playa.tscn": "res://assets/audio/music/playa.mp3",
	"res://scenes/levels/mar.tscn": "res://assets/audio/music/barco.mp3",
	"res://scenes/levels/cueva_jefe.tscn": "res://assets/audio/music/bossfight.mp3",
}
const DB_SILENCIO := -60.0
## Volumen de las canciones (dB).
@export var volumen_db := -6.0
@export var duracion_fundido := 1.0

var _actual := ""
var _jugador: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func para_zona(ruta_zona: String) -> void:
	var ruta: String = POR_ZONA.get(ruta_zona, "")
	reproducir(ruta)


## `ruta` vacía = silencio.
func reproducir(ruta: String) -> void:
	if ruta == _actual:
		return
	_actual = ruta
	if _jugador and is_instance_valid(_jugador):
		_apagar(_jugador)
		_jugador = null
	if ruta == "":
		return
	# El bucle se activa en la importación (Loop en la pestaña Importar de cada mp3),
	# no en código: así no se modifica el recurso compartido.
	var flujo := load(ruta) as AudioStream
	if flujo == null:
		push_warning("Musica: no se pudo cargar %s" % ruta)
		return
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
	reproducir("")
