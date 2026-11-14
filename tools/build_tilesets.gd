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
		# Tiles que bloquean el paso (capa de física 1 = "mundo"). Los estanques (16–18,0 y la
		# fuente 1) NO van aquí: su colisión sale de scripts/entorno/transiciones.gd (solo los
		# cuadrantes con agua, para poder pisar la hierba de las orillas).
		"solidos": [
			Vector2i(12, 0), # seto
			Vector2i(19, 0), # mar
			Vector2i(0, 1),  # mar con orilla abajo
			Vector2i(17, 1), # mar con orilla
			Vector2i(18, 1), # mar con orilla
			Vector2i(19, 1), # mar con orilla
		],
		# Agua animada: material (shader resources/shaders/agua.gdshader) por tile.
		# Un material por color base de agua (el shader solo toca ese color).
		"materiales": {
			"res://resources/shaders/agua_estanque.tres": [Vector2i(16, 0), Vector2i(17, 0), Vector2i(18, 0)],
			"res://resources/shaders/agua_mar.tres": [Vector2i(19, 0), Vector2i(0, 1), Vector2i(17, 1), Vector2i(18, 1), Vector2i(19, 1)],
		},
		# Más fuentes (atlas) dentro del mismo TileSet: id de fuente = 1, 2... en orden.
		# Mismas claves que arriba. La fuente 0 (arriba) no cambia: las zonas ya pintadas
		# siguen igual.
		"fuentes_extra": [
			{
				# Fuente 1: transiciones de tiles_y_como_funcionan.aseprite
				# (tools/recortes/tiles_transiciones.lua explica cada tile).
				# Fila 0 suelo de piedra · 1 estanque con bordillo · 2 estanque natural ·
				# 3 camino de tierra · 4 rellenos PROVISIONALES de tierra y piedra.
				# Qué pieza va en cada combinación de esquinas: scripts/entorno/transiciones.gd.
				"textura": "res://assets/tilesets/tiles_transiciones.png",
				"separacion": Vector2i(1, 1),
				"tiles": [
					[0, 0, 11],
					[1, 0, 8],
					[2, 0, 12],
					[3, 0, 10],
					[4, 0, 2],
				],
				"volteables": [
					Vector2i(0, 2), # agua lisa del estanque natural
					Vector2i(0, 4), # relleno de tierra (provisional)
					Vector2i(1, 4), # relleno de tierra (provisional)
					Vector2i(2, 4), # relleno de piedra (provisional)
				],
				# Sin "solidos": las colisiones del agua las pone Transiciones (por cuadrantes).
				"materiales": {
					"res://resources/shaders/agua_estanque.tres": [
						Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
						Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 1),
					],
					"res://resources/shaders/agua_estanque_natural.tres": [
						Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
						Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2), Vector2i(9, 2),
						Vector2i(10, 2), Vector2i(11, 2), Vector2i(12, 2),
					],
				},
			},
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
		"materiales": {
			"res://resources/shaders/agua_provisional.tres": [Vector2i(4, 0), Vector2i(5, 0)],
		},
	},
]

const CAPA_MUNDO := 1
const Transiciones := preload("res://scripts/entorno/transiciones.gd")


func _init() -> void:
	var ok := true
	for cfg in TILESETS:
		ok = _construir(cfg) and ok
	quit(0 if ok else 1)


func _construir(cfg: Dictionary) -> bool:
	var ts := TileSet.new()
	ts.tile_size = cfg.tamano
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, CAPA_MUNDO)
	ts.set_physics_layer_collision_mask(0, 0)

	var n := 0
	var n_solidos := 0
	var fuentes: Array = [cfg]
	fuentes.append_array(cfg.get("fuentes_extra", []))
	for id in fuentes.size():
		var f: Dictionary = fuentes[id]
		var fuente := TileSetAtlasSource.new()
		var tex := load(f.textura) as Texture2D
		if tex == null:
			push_error("No se pudo cargar %s (¿falta importar?)" % f.textura)
			return false
		fuente.texture = tex
		fuente.texture_region_size = cfg.tamano
		fuente.separation = f.get("separacion", Vector2i.ZERO)
		ts.add_source(fuente, id)
		n += _rellenar(fuente, f, cfg.tamano)
		n_solidos += f.get("solidos", []).size()
		if not _materiales(fuente, f):
			return false
	if cfg.salida == "res://resources/tilesets/naturaleza.tres":
		n_solidos += _colisiones_transiciones(ts)

	DirAccess.make_dir_recursive_absolute(cfg.salida.get_base_dir())
	# Conservar el UID del archivo anterior: si cambia, las zonas ya pintadas que lo
	# referencian por UID dan avisos "invalid UID" hasta volver a guardarlas.
	var uid_anterior := ResourceLoader.get_resource_uid(cfg.salida) if FileAccess.file_exists(cfg.salida) else ResourceUID.INVALID_ID
	var err := ResourceSaver.save(ts, cfg.salida)
	if err != OK:
		push_error("No se pudo guardar %s (error %d)" % [cfg.salida, err])
		return false
	ResourceSaver.set_uid(cfg.salida, uid_anterior if uid_anterior != ResourceUID.INVALID_ID else ResourceUID.create_id())
	print("[tilesets] %s: %d tiles, %d sólidos, %d fuente(s) -> %s" % [cfg.textura.get_file(), n, n_solidos, fuentes.size(), cfg.salida])
	return true


## Crea los tiles, las alternativas y las colisiones de una fuente. Devuelve cuántos tiles.
func _rellenar(fuente: TileSetAtlasSource, cfg: Dictionary, tamano: Vector2i) -> int:
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

	var m: Vector2 = Vector2(tamano) / 2.0
	var cuadrado := PackedVector2Array([Vector2(-m.x, -m.y), Vector2(m.x, -m.y), Vector2(m.x, m.y), Vector2(-m.x, m.y)])
	for coords in cfg.get("solidos", []):
		# También a las alternativas (volteos), si las hay.
		for i in fuente.get_alternative_tiles_count(coords):
			var datos := fuente.get_tile_data(coords, fuente.get_alternative_tile_id(coords, i))
			datos.add_collision_polygon(0)
			datos.set_collision_polygon_points(0, 0, cuadrado)
	return n


## Colisión de los estanques (familias sólidas de Transiciones): solo los cuadrantes de
## las esquinas con agua. Las piezas giradas (banderas FH/FV) no necesitan nada: la
## bandera gira también la colisión. Devuelve cuántos tiles reciben colisión.
func _colisiones_transiciones(ts: TileSet) -> int:
	var n := 0
	var hechos := {}
	for familia in Transiciones.FAMILIAS:
		var def: Dictionary = Transiciones.FAMILIAS[familia]
		if not def.solido:
			continue
		for mascara in def.piezas:
			for p in def.piezas[mascara]:
				if p.size() > 2 and p[2] != 0:
					continue # girada: usa la colisión de su tile base
				var clave := Vector3i(p[0], p[1].x, p[1].y)
				if hechos.has(clave):
					push_error("Transiciones: %s aparece en dos máscaras sin girar" % clave)
					continue
				hechos[clave] = true
				var fuente := ts.get_source(p[0]) as TileSetAtlasSource
				var puntos := Transiciones.poligono(mascara, ts.tile_size.x, def.get("margen", 0))
				for i in fuente.get_alternative_tiles_count(p[1]):
					var datos := fuente.get_tile_data(p[1], fuente.get_alternative_tile_id(p[1], i))
					datos.add_collision_polygon(0)
					datos.set_collision_polygon_points(0, datos.get_collision_polygons_count(0) - 1, puntos)
				n += 1
	return n


## Asigna los materiales (agua animada) a los tiles y a sus alternativas.
func _materiales(fuente: TileSetAtlasSource, cfg: Dictionary) -> bool:
	var materiales: Dictionary = cfg.get("materiales", {})
	for ruta in materiales:
		var material := load(ruta) as Material
		if material == null:
			push_error("No se pudo cargar el material %s" % ruta)
			return false
		for coords in materiales[ruta]:
			for i in fuente.get_alternative_tiles_count(coords):
				fuente.get_tile_data(coords, fuente.get_alternative_tile_id(coords, i)).material = material
	return true
