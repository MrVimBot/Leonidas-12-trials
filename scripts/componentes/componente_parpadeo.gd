@tool
class_name ComponenteParpadeo
extends Node
## Parpadeo de un CanvasItem (p. ej. el sprite, tras recibir daño): `parpadear(duracion)`
## alterna su transparencia durante ese tiempo y la deja en 1 al acabar; `detener()` lo corta.
## `@tool` solo para avisar en el editor de lo que falta; en el editor no hace nada más
## (sobre todo, no toca el `modulate` del objetivo: se guardaría en la escena).

## Nodo que parpadea (su `modulate.a`).
@export var objetivo: CanvasItem:
	set(valor):
		objetivo = valor
		update_configuration_warnings()
## Segundos que dura cada fase (visible / apagado).
@export var intervalo := 0.08
## Opacidad en la fase apagada.
@export var alfa_apagado := 0.35

var _restante := 0.0


func _ready() -> void:
	set_process(false) # solo corre mientras parpadea (y nunca en el editor)


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if objetivo == null:
		avisos.append("Asigna en `objetivo` el CanvasItem que parpadea (p. ej. el sprite).")
	return avisos


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _restante <= 0.0:
		return
	_restante -= delta
	if _restante <= 0.0:
		detener()
		return
	objetivo.modulate.a = alfa_apagado if int(_restante / intervalo) % 2 == 0 else 1.0


func parpadear(duracion: float) -> void:
	_restante = duracion
	set_process(duracion > 0.0)


func detener() -> void:
	_restante = 0.0
	set_process(false)
	objetivo.modulate.a = 1.0
