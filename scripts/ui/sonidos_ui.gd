extends Node
## Sonidos de interfaz y de «avisos» globales (autoload `SonidosUI`). Menús: `mover()` al cambiar
## de opción, `aceptar()` al elegir, `volver()` al cancelar. Libro: `libro_abrir()`,
## `libro_cerrar()`, `libro_pagina()`, `guardar()`. Jingles: `mision_nueva()`, `objeto_importante()`
## (el «¡obtuviste!»: corta `mision_nueva` si suenan a la vez), `game_over()`, `zona_cambio()`.
## Es un autoload porque lo usan muchos sitios (menús, libro, Game, Jugador, cinemática) y así no se
## repiten los reproductores en cada escena. `PROCESS_MODE_ALWAYS`: suena con el juego en pausa.
## Los reproductores (hijos, con su `AudioStreamRandomizer` y el bus SFX) están en la escena.
## Los sonidos del mundo (pasos, golpes, objetos...) NO van aquí: cuelgan de su entidad.

@onready var _mover: AudioStreamPlayer = %Mover
@onready var _aceptar: AudioStreamPlayer = %Aceptar
@onready var _volver: AudioStreamPlayer = %Volver
@onready var _libro_abrir: AudioStreamPlayer = %LibroAbrir
@onready var _libro_cerrar: AudioStreamPlayer = %LibroCerrar
@onready var _libro_pagina: AudioStreamPlayer = %LibroPagina
@onready var _guardar: AudioStreamPlayer = %Guardar
@onready var _mision_nueva: AudioStreamPlayer = %MisionNueva
@onready var _objeto_importante: AudioStreamPlayer = %ObjetoImportante
@onready var _game_over: AudioStreamPlayer = %GameOver
@onready var _zona_cambio: AudioStreamPlayer = %ZonaCambio


func mover() -> void:
	_mover.play()


func aceptar() -> void:
	_aceptar.play()


func volver() -> void:
	_volver.play()


func libro_abrir() -> void:
	_libro_abrir.play()


func libro_cerrar() -> void:
	_libro_cerrar.play()


func libro_pagina() -> void:
	_libro_pagina.play()


func guardar() -> void:
	_guardar.play()


func mision_nueva() -> void:
	_mision_nueva.play()


func objeto_importante() -> void:
	_mision_nueva.stop() # dos jingles a la vez ensucian: manda el del objeto
	_objeto_importante.play()


func game_over() -> void:
	_game_over.play()


func zona_cambio() -> void:
	_zona_cambio.play()
