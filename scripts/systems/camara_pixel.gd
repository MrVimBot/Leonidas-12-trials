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
## - `sacudir()` la hace temblar unos instantes (al recibir daño), también en píxeles
##   enteros y cada vez más suave.

## Nodo a seguir (el jugador).
@export var objetivo: Node2D
## Punto del objetivo al que mira (el jugador tiene los pies en su origen: −12 = el cuerpo).
@export var desplazamiento := Vector2(0, -12)
## Rapidez del suavizado. 0 = pegada al objetivo (recomendado en pixel art: nítido).
## Con 6–10 la cámara se retrasa un poco, pero el jugador puede temblar 1 px.
@export var suavizado := 0.0

@export_group("Sacudida")
## Desplazamiento máximo (px) de `sacudir()` si no se indica otro.
@export var intensidad_sacudida := 3.0
@export var duracion_sacudida := 0.25
## Cada cuántos segundos cambia de posición (más bajo = vibra más rápido).
@export var intervalo_sacudida := 1.0 / 30.0

var _pos := Vector2.ZERO
var _sacudida_intensidad := 0.0
var _sacudida_duracion := 0.0
var _sacudida_resta := 0.0
var _sacudida_espera := 0.0
var _sacudida_offset := Vector2.ZERO


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
	global_position = _pos.round() + _calcular_sacudida(delta)


## Hace temblar la cámara `duracion` s con un desplazamiento de hasta `intensidad` px
## que se va apagando. Valores ≤ 0 = los del Inspector. Si ya temblaba, se queda con
## la sacudida más fuerte.
func sacudir(intensidad := -1.0, duracion := -1.0) -> void:
	if intensidad <= 0.0:
		intensidad = intensidad_sacudida
	if duracion <= 0.0:
		duracion = duracion_sacudida
	if _sacudida_resta > 0.0 and _sacudida_intensidad * _sacudida_resta / _sacudida_duracion > intensidad:
		return
	_sacudida_intensidad = intensidad
	_sacudida_duracion = duracion
	_sacudida_resta = duracion
	_sacudida_espera = 0.0


func _calcular_sacudida(delta: float) -> Vector2:
	if _sacudida_resta <= 0.0:
		return Vector2.ZERO
	_sacudida_resta -= delta
	if _sacudida_resta <= 0.0:
		_sacudida_offset = Vector2.ZERO
		return Vector2.ZERO
	_sacudida_espera -= delta
	if _sacudida_espera <= 0.0:
		_sacudida_espera = intervalo_sacudida
		var fuerza := _sacudida_intensidad * _sacudida_resta / _sacudida_duracion
		var nuevo := Vector2(randf_range(-fuerza, fuerza), randf_range(-fuerza, fuerza)).round()
		# Que no repita posición: si no, a veces parece que no tiembla.
		if nuevo == _sacudida_offset and fuerza >= 1.0:
			nuevo = -nuevo if nuevo != Vector2.ZERO else Vector2(signf(randf() - 0.5), 0)
		_sacudida_offset = nuevo
	return _sacudida_offset


## Coloca la cámara de golpe sobre el objetivo (al cambiar de zona, al reaparecer).
func saltar_a_objetivo() -> void:
	if objetivo == null:
		return
	_pos = objetivo.global_position + desplazamiento
	_sacudida_resta = 0.0
	_sacudida_offset = Vector2.ZERO
	global_position = _pos.round()
	reset_smoothing()
