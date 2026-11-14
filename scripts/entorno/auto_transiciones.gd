@tool
class_name AutoTransiciones
extends Node
## Herramienta del EDITOR: pone las transiciones de caminos y estanques (bordes, esquinas)
## en `capa` según las reglas de scripts/entorno/transiciones.gd.
##
## Uso: pinta el área del camino/estanque con CUALQUIER tile de su familia (lo más cómodo:
## el relleno; tierra = fuente 1, 0–1,4 · piedra = 1, 2,4 · estanque con bordillo = fuente 0,
## 16,0 · estanque natural = fuente 1, 0,2) y pulsa "Aplicar transiciones". Luego "Variar
## pasto" en el VariadorPasto. Se puede pulsar las veces que haga falta (da lo mismo).
## Mínimo 2 tiles de ancho; nada de tocarse solo por una esquina (sale aviso en la salida).
## El área pintada es la final: los bordes se dibujan hacia dentro.

## Capa de tiles (el "Suelo" de la zona).
@export var capa: TileMapLayer
## Para elegir entre las variantes de cada pieza.
@export var semilla := 1
## Familias a las que se aplica (vacío = todas: tierra, piedra, bordillo, natural).
## La arena de playa/isla es, de momento, la familia tierra (faltan las transiciones
## hierba↔arena de la artista); llega al mar sin franja de hierba (`une_con`).
@export var familias: Array[StringName] = []

@export_tool_button("Aplicar transiciones") var _boton_aplicar := aplicar


func aplicar() -> void:
	if capa == null or capa.tile_set == null:
		push_warning("AutoTransiciones: asigna la capa (TileMapLayer)")
		return
	var avisos := Transiciones.aplicar(capa, semilla, familias)
	for a in avisos:
		push_warning("AutoTransiciones: " + a)
