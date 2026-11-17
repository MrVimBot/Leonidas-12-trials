extends "res://tools/pruebas/base_prueba.gd"
## Transiciones.aplicar (autotiler de caminos y estanques): idempotencia (aplicar dos veces da lo
## mismo, como promete el script) y la regla de erosión (un área de 2+ tiles de ancho se cierra
## con bordes, una franja de 1 tile vuelve a pasto con aviso). Capa pequeña propia, sin escenas.

const TILESET := "res://resources/tilesets/naturaleza.tres"


## Capa de `ancho`×`alto` de pasto (fuente 0, tile 0:0,0).
func _capa(ancho: int, alto: int) -> TileMapLayer:
	var capa := TileMapLayer.new()
	capa.tile_set = load(TILESET) as TileSet
	add_child(capa)
	for x in ancho:
		for y in alto:
			capa.set_cell(Vector2i(x, y), 0, Transiciones.PASTO)
	return capa


## Pinta `rect` con el relleno de la familia.
func _pintar(capa: TileMapLayer, familia: StringName, rect: Rect2i) -> void:
	var pieza: Array = (Transiciones.FAMILIAS[familia].piezas[15] as Array)[0]
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			capa.set_cell(Vector2i(x, y), pieza[0], pieza[1], pieza[2] if pieza.size() > 2 else 0)


## Foto comparable del contenido: celda → [fuente, coords, alternativa].
func _foto(capa: TileMapLayer) -> Dictionary:
	var f := {}
	for c: Vector2i in capa.get_used_cells():
		f[c] = [capa.get_cell_source_id(c), capa.get_cell_atlas_coords(c), capa.get_cell_alternative_tile(c)]
	return f


func ejecutar() -> void:
	for familia: StringName in [&"tierra", &"natural", &"bordillo"]:
		var capa := _capa(14, 12)
		# Un rectángulo y una "L" que se tocan por una esquina interior
		_pintar(capa, familia, Rect2i(2, 2, 5, 4))
		_pintar(capa, familia, Rect2i(7, 4, 3, 5))
		var inicial := _foto(capa)
		var avisos1 := Transiciones.aplicar(capa, 1)
		var tras1 := _foto(capa)
		var avisos2 := Transiciones.aplicar(capa, 1)
		var tras2 := _foto(capa)
		ok("%s: aplicar dos veces da lo mismo (idempotente)" % familia, tras1 == tras2)
		ok("%s: la segunda vez no avisa de nada nuevo" % familia, avisos1 == avisos2, str(avisos2))
		ok("%s: el autotiler cambió los bordes del área" % familia, tras1 != inicial)
		ok("%s: el interior queda de la familia" % familia, Transiciones.familia_de(capa, Vector2i(4, 3)) == familia)
		ok("%s: fuera del área sigue el pasto" % familia, capa.get_cell_atlas_coords(Vector2i(0, 0)) == Transiciones.PASTO
			and capa.get_cell_source_id(Vector2i(0, 0)) == 0)
		# Con otra semilla sigue siendo idempotente (puede variar la pieza, no la estructura)
		Transiciones.aplicar(capa, 7)
		var tras_s7 := _foto(capa)
		Transiciones.aplicar(capa, 7)
		ok("%s: con otra semilla también es idempotente" % familia, _foto(capa) == tras_s7)
		capa.queue_free()

	# Franja de 1 tile: no tiene dibujo, vuelve a pasto y avisa
	var capa := _capa(10, 8)
	_pintar(capa, &"tierra", Rect2i(1, 3, 8, 1))
	var avisos := Transiciones.aplicar(capa, 1)
	ok("franja de 1 tile → avisa", not avisos.is_empty(), str(avisos.size()))
	ok("franja de 1 tile → vuelve a pasto", capa.get_cell_source_id(Vector2i(4, 3)) == 0
		and capa.get_cell_atlas_coords(Vector2i(4, 3)) == Transiciones.PASTO)
	capa.queue_free()

	# Una capa vacía no falla
	var vacia := TileMapLayer.new()
	vacia.tile_set = load(TILESET) as TileSet
	add_child(vacia)
	ok("capa vacía: sin avisos ni errores", Transiciones.aplicar(vacia).is_empty())
	vacia.queue_free()
