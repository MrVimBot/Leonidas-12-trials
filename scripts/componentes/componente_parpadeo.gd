class_name ComponenteParpadeo
extends Node

@export var objetivo: CanvasItem
@export var intervalo := 0.08
@export var alfa_apagado := 0.35

var _restante := 0.0


func _process(delta: float) -> void:
	if _restante <= 0.0:
		return
	_restante -= delta
	if _restante <= 0.0:
		detener()
		return
	objetivo.modulate.a = alfa_apagado if int(_restante / intervalo) % 2 == 0 else 1.0


func parpadear(duracion: float) -> void:
	_restante = duracion


func detener() -> void:
	_restante = 0.0
	objetivo.modulate.a = 1.0
