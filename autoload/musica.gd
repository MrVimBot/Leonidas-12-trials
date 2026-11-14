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
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func para_zona(ruta_zona: String) -> void:
	reproducir(POR_ZONA.get(ruta_zona, ""))


## `ruta` vacía = silencio.
func reproducir(ruta: String) -> void:
	if ruta == _actual:
		return
	_actual = ruta
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if _jugador and is_instance_valid(_jugador):
		var viejo := _jugador
		_tween.tween_property(viejo, "volume_db", DB_SILENCIO, duracion_fundido)
		_tween.tween_callback(viejo.queue_free)
		_jugador = null
	if ruta == "":
		return
	var flujo := load(ruta) as AudioStreamMP3
	if flujo == null:
		push_warning("Musica: no se pudo cargar %s" % ruta)
		return
	flujo.loop = true
	var nuevo := AudioStreamPlayer.new()
	nuevo.stream = flujo
	nuevo.volume_db = DB_SILENCIO
	add_child(nuevo)
	nuevo.play()
	_jugador = nuevo
	_tween.parallel().tween_property(nuevo, "volume_db", volumen_db, duracion_fundido)


func detener() -> void:
	reproducir("")
