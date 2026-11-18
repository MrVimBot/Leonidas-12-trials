extends Node
## Sonidos de interfaz (autoload `SonidosUI`): `mover()` al cambiar de opción, `aceptar()` al
## elegir y `volver()` al cancelar o cerrar. Lo llaman los menús (botones principal/pausa/Game
## Over, tienda, libro). Es un autoload porque todos los menús lo usan y así no hay que
## repetir los reproductores en cada escena. `PROCESS_MODE_ALWAYS`: suena con el juego en pausa.
## Los reproductores (hijos, con su `AudioStreamRandomizer` y el bus SFX) están en la escena.

@onready var _mover: AudioStreamPlayer = %Mover
@onready var _aceptar: AudioStreamPlayer = %Aceptar
@onready var _volver: AudioStreamPlayer = %Volver


func mover() -> void:
	_mover.play()


func aceptar() -> void:
	_aceptar.play()


func volver() -> void:
	_volver.play()
