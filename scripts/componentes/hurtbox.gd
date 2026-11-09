class_name Hurtbox
extends Area2D

signal golpeado(danio: int, origen: Vector2)

@export var activo: bool = true


func recibir_golpe(danio: int, origen: Vector2) -> void:
	if activo:
		golpeado.emit(danio, origen)
