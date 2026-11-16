class_name ComponenteEstamina
extends Node
## Estamina de una entidad (el jugador la gasta en la voltereta). `gastar()` resta si hay
## suficiente; tras `retraso_regeneracion` segundos sin gastar se regenera sola, salvo
## mientras `pausada` esté activa (el jugador la pone durante la voltereta).

## Cada vez que cambia la estamina (también una vez al empezar, para que la barra se pinte).
signal cambio(estamina: float, estamina_max: float)
## Al intentar `gastar()` más de lo que hay.
signal insuficiente

## Estamina máxima (y con la que empieza).
@export var estamina_max := 100.0
## Estamina que recupera por segundo.
@export var regeneracion := 45.0
## Segundos sin gastar antes de empezar a regenerar.
@export var retraso_regeneracion := 0.6

## Estamina actual.
var estamina: float
## Si es true no se regenera.
var pausada := false

var _tiempo_sin_gastar := 0.0


func _ready() -> void:
	estamina = estamina_max
	cambio.emit.call_deferred(estamina, estamina_max)


func _physics_process(delta: float) -> void:
	_tiempo_sin_gastar += delta
	if pausada or estamina >= estamina_max or _tiempo_sin_gastar < retraso_regeneracion:
		return
	estamina = minf(estamina + regeneracion * delta, estamina_max)
	cambio.emit(estamina, estamina_max)


func puede_gastar(cantidad: float) -> bool:
	return estamina >= cantidad


func gastar(cantidad: float) -> bool:
	if not puede_gastar(cantidad):
		insuficiente.emit()
		return false
	estamina -= cantidad
	_tiempo_sin_gastar = 0.0
	cambio.emit(estamina, estamina_max)
	return true


func llenar() -> void:
	estamina = estamina_max
	cambio.emit(estamina, estamina_max)
