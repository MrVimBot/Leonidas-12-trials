class_name DatosLugar
extends RefCounted
## Dónde está la partida: lo que se guarda del mundo (lo da `Game.datos_guardado()`) y lo
## que se lee al cargar (`EstadoJuego.lugar_cargado`).

## Ruta de la zona (res://scenes/levels/<nombre>.tscn).
var zona := ""
## Entrada por la que se llegó a la zona (se usa si no hay posición).
var entrada := "inicio"
## Posición exacta del jugador. Vector2.INF = no hay (partidas antiguas o en el barco).
var posicion := Vector2.INF
## Vida en cuartos de corazón; -1 = no se sabe (no se cambia).
var vida := -1
