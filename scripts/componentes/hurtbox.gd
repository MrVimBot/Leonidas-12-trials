class_name Hurtbox
extends Area2D
## Zona que RECIBE daño: parte de la cabeza de una entidad (jugador, enemigo, barco).
## Un `Hitbox` que la toca llama a `recibir_golpe(danio, origen)` (contrato de daño del
## proyecto; lo implementan también las vasijas y los arbustos). Si está `activo`, lo
## reenvía por `golpeado`; el `ComponenteVida` de la entidad se conecta a esa señal
## (su export `hurtbox`) y es quien resta la vida. Va en la capa de la entidad que
## protege (jugador o enemigos).

## Al recibir un golpe estando `activo`: daño (en cuartos de corazón) y posición del origen.
signal golpeado(danio: int, origen: Vector2)

## Si es false ignora los golpes (no emite `golpeado`).
@export var activo: bool = true


func recibir_golpe(danio: int, origen: Vector2) -> void:
	if activo:
		golpeado.emit(danio, origen)
