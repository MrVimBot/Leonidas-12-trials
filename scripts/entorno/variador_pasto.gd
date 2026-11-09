@tool
class_name VariadorPasto
extends Node
## Herramienta del EDITOR para que el pasto no se vea repetido.
## Recorre `capa` y cambia cada celda de pasto por una variante al azar (según `pesos`)
## y con un volteo al azar si el tile lo tiene. Usa una semilla fija: el resultado
## siempre es el mismo y queda guardado en la escena (no cambia al jugar).
##
## Uso: añade este nodo a una zona, asigna `capa` (su "Suelo") y pulsa "Variar pasto"
## en el Inspector. Cambia `semilla` para probar otra distribución.
## Solo toca celdas cuyo tile esté en `pesos`: caminos, agua, setos... no se tocan.

## Capa de tiles a variar.
@export var capa: TileMapLayer
## Cambiar la semilla vuelve a repartir el pasto.
@export var semilla := 1:
	set(valor):
		semilla = valor
		if Engine.is_editor_hint() and is_node_ready():
			variar()
## Tiles de pasto (columna, fila) y su peso: más peso = aparece más.
@export var pesos := {
	Vector2i(0, 0): 62, # hierba lisa
	Vector2i(1, 0): 26, # hierba con hojas
	Vector2i(2, 0): 8, # hierba con piedrita
	Vector2i(3, 0): 4, # hierba con tierra y hojas
}
## Voltear al azar las celdas (si el TileSet tiene las alternativas).
@export var voltear := true

@export_tool_button("Variar pasto") var _boton_variar := variar


func variar() -> void:
	if capa == null or capa.tile_set == null:
		push_warning("VariadorPasto: asigna la capa (TileMapLayer)")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var total := 0
	for p in pesos.values():
		total += p
	var cambiadas := 0
	for celda in capa.get_used_cells():
		var fuente_id := capa.get_cell_source_id(celda)
		if not pesos.has(capa.get_cell_atlas_coords(celda)):
			continue
		var fuente := capa.tile_set.get_source(fuente_id) as TileSetAtlasSource
		var elegido := _elegir(rng, total)
		var alt := 0
		if voltear and fuente:
			alt = rng.randi_range(0, fuente.get_alternative_tiles_count(elegido) - 1)
		capa.set_cell(celda, fuente_id, elegido, alt)
		cambiadas += 1
	print("[VariadorPasto] %d celdas de pasto variadas (semilla %d)" % [cambiadas, semilla])


func _elegir(rng: RandomNumberGenerator, total: int) -> Vector2i:
	var tirada := rng.randi_range(1, total)
	for coords in pesos:
		tirada -= pesos[coords]
		if tirada <= 0:
			return coords
	return pesos.keys()[0]
