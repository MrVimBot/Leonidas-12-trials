@tool
class_name ComponentePasos
extends Node
## Suena un paso cuando el `sprite` llega a un fotograma de apoyo de una animación de caminar.
## Escucha `frame_changed` (no pregunta cada fotograma) y solo reacciona mientras la animación
## empieza por `prefijo` (`caminar`, `caminar_objeto`…, con cualquier sufijo de dirección).
## El sonido (un `AudioStreamPlayer` con un `AudioStreamRandomizer`, para variar el paso) se
## asigna en `sonido`. `@tool` solo para avisar en el editor de lo que falta.

## Sprite del que se leen animación y fotograma.
@export var sprite: AnimatedSprite2D:
	set(valor):
		sprite = valor
		update_configuration_warnings()
## Reproductor del paso.
@export var sonido: AudioStreamPlayer:
	set(valor):
		sonido = valor
		update_configuration_warnings()
## Las animaciones que cuentan son las que empiezan por este texto.
@export var prefijo := "caminar"
## Fotogramas del ciclo en los que el pie toca el suelo. `caminar` tiene 8 fotogramas a 10 fps
## con la cabeza más baja en el 2 y el 6 (medido en las tiras): el apoyo es el anterior.
@export var fotogramas_de_paso := PackedInt32Array([1, 5])


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	assert(sprite != null and sonido != null, "ComponentePasos: asigna `sprite` y `sonido`")
	sprite.frame_changed.connect(_al_cambiar_fotograma)


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if sprite == null:
		avisos.append("Asigna en `sprite` el AnimatedSprite2D que camina.")
	if sonido == null:
		avisos.append("Asigna en `sonido` el AudioStreamPlayer del paso.")
	return avisos


func _al_cambiar_fotograma() -> void:
	if not sprite.is_playing() or not String(sprite.animation).begins_with(prefijo):
		return
	if sprite.frame in fotogramas_de_paso:
		sonido.play()
