class_name ComponenteEstamina
extends Node

signal cambio(estamina: float, estamina_max: float)
signal insuficiente
@export var estamina_max := 100.0
@export var regeneracion := 45.0 
@export var retraso_regeneracion := 0.6 

var estamina: float
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
