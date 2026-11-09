extends SceneTree
## CLI: godot --headless --path . --script res://tools/build_tilesets.gd
## Construye los TileSet (resources/tilesets/*.tres) a partir de las franjas de tiles
## que exporta tools/export_recortes.lua. Las colisiones se definen aquí como datos.
##
## Coordenadas de tile = (columna, fila) dentro de la franja.

const TILESETS := [
	{
		"textura": "res://assets/tilesets/tiles_naturaleza.png",
		"salida": "res://resources/tilesets/naturaleza.tres",
		"tamano": Vector2i(16, 16),
		"separacion": Vector2i(1, 1), # la artista dejó 1 px entre tiles
		# Tiles que existen: fila 0 completa (0–19); fila 1: 0–6 y 17–19.
		"tiles": [
			[0, 0, 19], # [fila, desde_columna, hasta_columna]
			[1, 0, 6],
			[1, 17, 19],
		],
		# Tiles con versiones volteadas (alternativas 1 = H, 2 = V, 3 = H+V) para que el
		# suelo no se vea repetido. Solo texturas sin dirección (hierba, tierra).
		"volteables": [
			Vector2i(0, 0), # hierba lisa
			Vector2i(1, 0), # hierba con hojas
			Vector2i(2, 0), # hierba con piedrita
			Vector2i(3, 0), # hierba con tierra y hojas
			Vector2i(4, 0), # parche de tierra
			Vector2i(5, 0), # tierra redonda
		],
		# Tiles que bloquean el paso (capa de física 1 = "mundo").
		"solidos": [
			Vector2i(12, 0), # seto
			Vector2i(16, 0), # agua de estanque
			Vector2i(17, 0), # orilla de estanque con bordillo
			Vector2i(18, 0), # esquina de bordillo
			Vector2i(19, 0), # mar
			Vector2i(0, 1),  # mar con orilla abajo
			Vector2i(17, 1), # mar con orilla
			Vector2i(18, 1), # mar con orilla
			Vector2i(19, 1), # mar con orilla
		],
	},
]

const CAPA_MUNDO := 1


func _init() -> void:
	var ok := true
	for cfg in TILESETS:
		ok = _construir(cfg) and ok
	quit(0 if ok else 1)


func _construir(cfg: Dictionary) -> bool:
	var textura := load(cfg.textura) as Texture2D
	if textura == null:
		push_error("No se pudo cargar %s (¿falta importar?)" % cfg.textura)
		return false

	var ts := TileSet.new()
	ts.tile_size = cfg.tamano
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, CAPA_MUNDO)
	ts.set_physics_layer_collision_mask(0, 0)

	var fuente := TileSetAtlasSource.new()
	fuente.texture = textura
	fuente.texture_region_size = cfg.tamano
	fuente.separation = cfg.separacion
	ts.add_source(fuente, 0)

	var n := 0
	for rango in cfg.tiles:
		for col in range(rango[1], rango[2] + 1):
			fuente.create_tile(Vector2i(col, rango[0]))
			n += 1

	for coords in cfg.get("volteables", []):
		for volteo in [[true, false], [false, true], [true, true]]:
			var alt := fuente.create_alternative_tile(coords)
			var datos_alt := fuente.get_tile_data(coords, alt)
			datos_alt.flip_h = volteo[0]
			datos_alt.flip_v = volteo[1]

	var m: Vector2 = Vector2(cfg.tamano) / 2.0
	var cuadrado := PackedVector2Array([Vector2(-m.x, -m.y), Vector2(m.x, -m.y), Vector2(m.x, m.y), Vector2(-m.x, m.y)])
	for coords in cfg.solidos:
		var datos := fuente.get_tile_data(coords, 0)
		datos.add_collision_polygon(0)
		datos.set_collision_polygon_points(0, 0, cuadrado)

	DirAccess.make_dir_recursive_absolute(cfg.salida.get_base_dir())
	if ResourceLoader.exists(cfg.salida):
		ts.take_over_path(cfg.salida) # conserva el UID: no rompe los mapas ya pintados
	var err := ResourceSaver.save(ts, cfg.salida)
	if err != OK:
		push_error("No se pudo guardar %s (error %d)" % [cfg.salida, err])
		return false
	print("[tilesets] %s: %d tiles, %d sólidos -> %s" % [cfg.textura.get_file(), n, cfg.solidos.size(), cfg.salida])
	return true
