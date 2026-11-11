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
		# Tiles con las 7 transformaciones (giros y volteos) como alternativas:
		# id de la alternativa = H (1) + V (2) + transponer (4). Así 1 = H, 2 = V, 3 = H+V
		# igual que en "volteables", y 4–7 añaden la transposición (girar 90°).
		"transformables": [
			Vector2i(4, 1), # esquina de la greca (plaza)
			Vector2i(5, 1), # borde de la greca (plaza)
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
	{
		# PROVISIONAL (tools/build_arte_provisional.gd): cueva, mar navegable, muelle...
		# Sustituir por los tiles de la artista cuando los entregue.
		"textura": "res://assets/tilesets/tiles_provisional.png",
		"salida": "res://resources/tilesets/provisional.tres",
		"tamano": Vector2i(16, 16),
		"separacion": Vector2i(0, 0),
		# 0 suelo cueva · 1 suelo cueva B · 2 pared cueva · 3 vacío · 4 mar navegable ·
		# 5 mar navegable con ola · 6 losa del jefe · 7 muelle · 8 arrecife
		"tiles": [[0, 0, 8]],
		"solidos": [
			Vector2i(2, 0), # pared de cueva
			Vector2i(3, 0), # vacío
			Vector2i(8, 0), # arrecife
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

	for coords in cfg.get("transformables", []):
		for bits in range(1, 8):
			var alt := fuente.create_alternative_tile(coords)
			var datos_alt := fuente.get_tile_data(coords, alt)
			datos_alt.flip_h = bits & 1 != 0
			datos_alt.flip_v = bits & 2 != 0
			datos_alt.transpose = bits & 4 != 0

	var m: Vector2 = Vector2(cfg.tamano) / 2.0
	var cuadrado := PackedVector2Array([Vector2(-m.x, -m.y), Vector2(m.x, -m.y), Vector2(m.x, m.y), Vector2(-m.x, m.y)])
	for coords in cfg.solidos:
		var datos := fuente.get_tile_data(coords, 0)
		datos.add_collision_polygon(0)
		datos.set_collision_polygon_points(0, 0, cuadrado)

	DirAccess.make_dir_recursive_absolute(cfg.salida.get_base_dir())
	# Conservar el UID del archivo anterior: si cambia, las zonas ya pintadas que lo
	# referencian por UID dan avisos "invalid UID" hasta volver a guardarlas.
	var uid_anterior := ResourceLoader.get_resource_uid(cfg.salida) if FileAccess.file_exists(cfg.salida) else ResourceUID.INVALID_ID
	var err := ResourceSaver.save(ts, cfg.salida)
	if err != OK:
		push_error("No se pudo guardar %s (error %d)" % [cfg.salida, err])
		return false
	ResourceSaver.set_uid(cfg.salida, uid_anterior if uid_anterior != ResourceUID.INVALID_ID else ResourceUID.create_id())
	print("[tilesets] %s: %d tiles, %d sólidos -> %s" % [cfg.textura.get_file(), n, cfg.solidos.size(), cfg.salida])
	return true
