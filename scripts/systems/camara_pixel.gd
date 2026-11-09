class_name CamaraPixel
extends Camera2D
## Cámara que sigue a un objetivo sin temblores en pixel art.
##
## - Se actualiza en el ciclo de FÍSICA, igual que el jugador. (Con la cámara normal,
##   el suavizado iba a la frecuencia de la pantalla, 120 Hz en un Mac, y el jugador a
##   60 Hz: el personaje daba tirones respecto al fondo.)
## - Siempre se coloca en PÍXELES ENTEROS. (Con posiciones como 100.37, cada objeto
##   redondeaba por su cuenta y fondo y personaje temblaban 1 px entre sí: "borroso".)
## - Por defecto va PEGADA al objetivo (como en los Zelda de GBA). Con suavizado, la
##   cámara queda a una distancia fraccionaria del jugador y al redondear a píxel el
##   jugador tiembla 1 px respecto al fondo. El suavizado nativo de Camera2D queda
##   desactivado siempre.
## La física del proyecto va a 120 por segundo (igual que una pantalla de 120 Hz) para
## que el movimiento avance en todas las imágenes, no en una sí y otra no.

## Nodo a seguir (el jugador).
@export var objetivo: Node2D
## Punto del objetivo al que mira (el jugador tiene los pies en su origen: −12 = el cuerpo).
@export var desplazamiento := Vector2(0, -12)
## Rapidez del suavizado. 0 = pegada al objetivo (recomendado en pixel art: nítido).
## Con 6–10 la cámara se retrasa un poco, pero el jugador puede temblar 1 px.
@export var suavizado := 0.0

var _pos := Vector2.ZERO


func _ready() -> void:
	position_smoothing_enabled = false
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	if objetivo:
		saltar_a_objetivo()


func _physics_process(delta: float) -> void:
	if objetivo == null:
		return
	var meta := objetivo.global_position + desplazamiento
	if suavizado <= 0.0:
		_pos = meta
	else:
		# Suavizado exponencial: no depende de los FPS.
		_pos = _pos.lerp(meta, 1.0 - exp(-suavizado * delta))
	global_position = _pos.round()


## Coloca la cámara de golpe sobre el objetivo (al cambiar de zona, al reaparecer).
func saltar_a_objetivo() -> void:
	if objetivo == null:
		return
	_pos = objetivo.global_position + desplazamiento
	global_position = _pos.round()
	reset_smoothing()
