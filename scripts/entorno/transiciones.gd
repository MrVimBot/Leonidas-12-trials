class_name Transiciones
extends RefCounted
## Transiciones terreno↔hierba de resources/tilesets/naturaleza.tres (caminos y estanques).
## Plan y explicación: docs/design/plan_tiles_transiciones.md.
##
## Los tiles de la artista son un juego de ESQUINAS: cada tile se define por cuáles de sus
## 4 esquinas son terreno (tierra, piedra, agua) y cuáles hierba. El borde se dibuja DENTRO
## del tile, así que un camino de 2 tiles de ancho son solo bordes. No hay piezas diagonales.
##
## Regla de "erosión": una esquina (compartida por 4 celdas) es del terreno F solo si las
## 4 celdas son de F. Así el área pintada es el área final, los bordes van hacia dentro y
## aplicar dos veces da lo mismo. Cualquier tile de la familia sirve para pintar el área.
## Anchura mínima: 2 tiles (una franja de 1 tile no tiene dibujo y se queda en pasto).
##
## Lo usan tools/build_tilesets.gd (colisiones), tools/zonas/constructor_zona.gd y la
## herramienta del editor AutoTransiciones.

# Banderas de transformación (TileSetAtlasSource.TRANSFORM_*), sumadas al id de alternativa.
# La colisión y el material se transforman solos.
const FH := 4096 # voltear horizontal
const FV := 8192 # voltear vertical

# Bits de la máscara de esquinas (1 = terreno).
const AI := 1 # arriba-izquierda
const AD := 2 # arriba-derecha
const BI := 4 # abajo-izquierda
const BD := 8 # abajo-derecha

const PASTO := Vector2i(0, 0)
const VACIA := [-1, Vector2i(-1, -1)]

## familia → {piezas: {máscara: [[fuente, coords, banderas], ...]}, solido, margen, une_con}
## `margen`: px que la colisión del agua se mete en la mitad de hierba de cada tile (para
## que cubra el bordillo / la orilla dibujada y el jugador no pise el agua).
## Máscaras: 15 relleno · 12/3/10/5 borde con hierba arriba/abajo/izquierda/derecha ·
## 8/4/2/1 esquina exterior sup-izq/sup-der/inf-izq/inf-der (la del área) ·
## 14/13/11/7 esquina interior con hierba arriba-izq/arriba-dcha/abajo-izq/abajo-dcha.
## Varias piezas para una máscara = variantes (se elige una por celda, determinista).
## `une_con`: tiles que cuentan como de la familia para las esquinas (no se reescriben):
## el camino entra en la plaza sin franja de hierba y la arena (tierra, provisional) llega
## al mar sin franja de hierba. VACIA = celda sin tile en esta capa (muelle provisional...).
const FAMILIAS := {
	&"tierra": {
		"solido": false,
		"une_con": [
			[0, Vector2i(4, 1)], [0, Vector2i(5, 1)], [0, Vector2i(6, 1)], # plaza (greca, baldosa)
			[0, Vector2i(19, 0)], [0, Vector2i(0, 1)], [0, Vector2i(17, 1)], [0, Vector2i(18, 1)], [0, Vector2i(19, 1)], # mar
			VACIA,
		],
		"piezas": {
			# Relleno PROVISIONAL (fila 4 fabricada con un parche, ver tiles_transiciones.lua).
			15: [[1, Vector2i(0, 4)], [1, Vector2i(1, 4)], [1, Vector2i(0, 4), FH], [1, Vector2i(1, 4), FH]],
			12: [[1, Vector2i(0, 3)], [1, Vector2i(1, 3)]],
			3: [[1, Vector2i(2, 3)], [0, Vector2i(1, 1)]],
			10: [[1, Vector2i(3, 3)]],
			5: [[1, Vector2i(4, 3)]],
			8: [[1, Vector2i(5, 3)]],
			4: [[1, Vector2i(6, 3)]],
			2: [[1, Vector2i(7, 3)]],
			1: [[1, Vector2i(8, 3)], [0, Vector2i(2, 1)]],
			14: [[1, Vector2i(9, 3), FV]],
			13: [[1, Vector2i(10, 3), FV]],
			11: [[1, Vector2i(9, 3)], [0, Vector2i(3, 1)]],
			7: [[1, Vector2i(10, 3)]],
		},
	},
	&"piedra": {
		"solido": false,
		"une_con": [[0, Vector2i(4, 1)], [0, Vector2i(5, 1)], [0, Vector2i(6, 1)]],
		"piezas": {
			15: [[1, Vector2i(2, 4)], [1, Vector2i(2, 4), FH], [1, Vector2i(2, 4), FV], [1, Vector2i(2, 4), FH | FV]],
			12: [[1, Vector2i(4, 0)], [1, Vector2i(5, 0)]],
			3: [[0, Vector2i(7, 0)], [0, Vector2i(8, 0)], [1, Vector2i(6, 0)], [1, Vector2i(7, 0)]],
			10: [[0, Vector2i(10, 0)], [0, Vector2i(11, 0)]],
			5: [[0, Vector2i(10, 0), FH], [0, Vector2i(11, 0), FH]],
			8: [[1, Vector2i(0, 0)]],
			4: [[1, Vector2i(1, 0)]],
			2: [[1, Vector2i(2, 0)], [0, Vector2i(6, 0)]],
			1: [[1, Vector2i(3, 0)]],
			14: [[1, Vector2i(8, 0)]],
			13: [[1, Vector2i(9, 0)], [0, Vector2i(9, 0)]],
			11: [[1, Vector2i(10, 0)]],
			7: [[1, Vector2i(11, 0)]],
		},
	},
	# Estanque con bordillo de piedra (canales del pueblo). El bordillo tiene sombra abajo:
	# no se gira salvo el borde vertical (17,0 volteado H+V, como en la hoja de la artista).
	&"bordillo": {
		"solido": true,
		"margen": 4, # el bordillo ocupa 4 px de la mitad de hierba (6 en el de abajo)
		"une_con": [],
		"piezas": {
			15: [[0, Vector2i(16, 0)]],
			12: [[1, Vector2i(0, 1)]],
			3: [[1, Vector2i(1, 1)]],
			10: [[0, Vector2i(17, 0)]],
			5: [[0, Vector2i(17, 0), FH | FV]],
			8: [[1, Vector2i(2, 1)]],
			4: [[1, Vector2i(3, 1)]],
			2: [[0, Vector2i(18, 0)]],
			1: [[1, Vector2i(6, 1)]],
			14: [[1, Vector2i(4, 1)]],
			13: [[1, Vector2i(5, 1)]],
			11: [[1, Vector2i(7, 1)]],
			7: [[1, Vector2i(8, 1)]],
		},
	},
	# Estanque natural: orilla de hierba, otro tono de agua (agua_estanque_natural.tres).
	&"natural": {
		"solido": true,
		"margen": 2,
		"une_con": [],
		"piezas": {
			15: [[1, Vector2i(0, 2)], [1, Vector2i(0, 2), FH], [1, Vector2i(0, 2), FV], [1, Vector2i(0, 2), FH | FV]],
			12: [[1, Vector2i(2, 2)]],
			3: [[1, Vector2i(1, 2)]],
			10: [[1, Vector2i(3, 2)]],
			5: [[1, Vector2i(4, 2)]],
			8: [[1, Vector2i(9, 2)]],
			4: [[1, Vector2i(10, 2)]],
			2: [[1, Vector2i(11, 2)]],
			1: [[1, Vector2i(12, 2)]],
			14: [[1, Vector2i(5, 2)]],
			13: [[1, Vector2i(6, 2)]],
			11: [[1, Vector2i(7, 2)]],
			7: [[1, Vector2i(8, 2)]],
		},
	},
}

# Celdas vecinas de cada esquina (las 4 celdas que la comparten), relativas a la celda.
const _ESQUINAS := {
	AI: [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)],
	AD: [Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, 0), Vector2i(1, 0)],
	BI: [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(-1, 1), Vector2i(0, 1)],
	BD: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
}

static var _miembros_cache := {}


## Vector3i(fuente, x, y) → familia, con todas las piezas de todas las familias.
static func miembros() -> Dictionary:
	if _miembros_cache.is_empty():
		for f in FAMILIAS:
			for mascara in FAMILIAS[f].piezas:
				for p in FAMILIAS[f].piezas[mascara]:
					_miembros_cache[Vector3i(p[0], p[1].x, p[1].y)] = f
	return _miembros_cache


## Familia de la celda (&"" si no es de ninguna). Mira fuente y coords: 1:0,0 es piedra,
## 0:0,0 es pasto.
static func familia_de(capa: TileMapLayer, celda: Vector2i) -> StringName:
	var fuente := capa.get_cell_source_id(celda)
	if fuente == -1:
		return &""
	var c := capa.get_cell_atlas_coords(celda)
	return miembros().get(Vector3i(fuente, c.x, c.y), &"")


## Polígono de colisión (tile centrado, `tamano` px) de una máscara: unión de los
## cuadrantes de sus esquinas de terreno, cada uno agrandado `margen` px hacia los
## cuadrantes de hierba vecinos (sin salirse del tile).
static func poligono(mascara: int, tamano := 16.0, margen := 0.0) -> PackedVector2Array:
	var m := tamano / 2.0
	# bit → [rect, vecino horizontal, vecino vertical, hacia dónde crece en x, en y]
	var cuadrantes := {
		AI: [Rect2(-m, -m, m, m), AD, BI, 1, 1],
		AD: [Rect2(0, -m, m, m), AI, BD, -1, 1],
		BI: [Rect2(-m, 0, m, m), BD, AI, 1, -1],
		BD: [Rect2(0, 0, m, m), BI, AD, -1, -1],
	}
	var union := PackedVector2Array()
	for bit in cuadrantes:
		if mascara & bit == 0:
			continue
		var q: Array = cuadrantes[bit]
		var r: Rect2 = q[0]
		if mascara & q[1] == 0: # hierba al lado: crecer en x
			if q[3] > 0:
				r.size.x += margen
			else:
				r.position.x -= margen
				r.size.x += margen
		if mascara & q[2] == 0: # hierba encima/debajo: crecer en y
			if q[4] > 0:
				r.size.y += margen
			else:
				r.position.y -= margen
				r.size.y += margen
		var pol := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		if union.is_empty():
			union = pol
		else:
			var res := Geometry2D.merge_polygons(union, pol)
			union = res[0] if res.size() > 0 else union
	return _sin_puntos_alineados(union)


static func _sin_puntos_alineados(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := p.size()
	for i in n:
		var a := p[(i - 1 + n) % n]
		var b := p[i]
		var c := p[(i + 1) % n]
		if absf((b - a).cross(c - b)) > 0.001:
			out.append(b)
	return out


## Aplica las transiciones a toda la capa. `familias` vacío = todas. Devuelve los avisos
## (franjas de 1 tile, diagonales). Determinista con `semilla`; idempotente.
static func aplicar(capa: TileMapLayer, semilla := 1, familias: Array = []) -> PackedStringArray:
	var avisos := PackedStringArray()
	var usado := capa.get_used_rect()
	if usado.size == Vector2i.ZERO:
		return avisos
	# Foto del estado inicial: celda → familia, y celdas que "unen".
	var fam := {}
	var une := {}
	for celda in capa.get_used_cells():
		var f := familia_de(capa, celda)
		if f != &"":
			fam[celda] = f
		var fuente := capa.get_cell_source_id(celda)
		var c := capa.get_cell_atlas_coords(celda)
		une[celda] = Vector3i(fuente, c.x, c.y)
	var cambiadas := 0
	for celda in fam:
		var f: StringName = fam[celda]
		if not familias.is_empty() and not f in familias:
			continue
		var def: Dictionary = FAMILIAS[f]
		var une_con := {}
		for u in def.une_con:
			une_con[Vector3i(u[0], u[1].x, u[1].y)] = true
		var mascara := 0
		for bit in _ESQUINAS:
			var todas := true
			for d in _ESQUINAS[bit]:
				var v := _dentro(celda + d, usado)
				if fam.get(v, &"") != f and not une_con.has(une.get(v, Vector3i(-1, -1, -1))):
					todas = false
					break
			if todas:
				mascara |= bit
		var piezas: Array = def.piezas.get(mascara, [])
		if mascara == 0:
			avisos.append("%s: celda %s suelta o franja de 1 tile → pasto" % [f, celda])
			capa.set_cell(celda, 0, PASTO)
			cambiadas += 1
			continue
		if piezas.is_empty():
			# Diagonal (6 o 9): no hay dibujo. Se deja relleno para no cambiar a los vecinos.
			avisos.append("%s: celda %s en diagonal (esquinas %d), no hay tile → relleno" % [f, celda, mascara])
			piezas = def.piezas[15]
		var p: Array = piezas[absi(hash(Vector3i(celda.x, celda.y, semilla))) % piezas.size()]
		var alt: int = p[2] if p.size() > 2 else 0
		if capa.get_cell_source_id(celda) != p[0] or capa.get_cell_atlas_coords(celda) != p[1] \
				or capa.get_cell_alternative_tile(celda) != alt:
			capa.set_cell(celda, p[0], p[1], alt)
			cambiadas += 1
	print("[Transiciones] %s: %d celdas cambiadas, %d avisos" % [capa.name, cambiadas, avisos.size()])
	return avisos


## Las celdas de fuera del mapa cuentan como la de dentro más cercana: un camino que sale
## por el borde no se cierra con un remate.
static func _dentro(c: Vector2i, r: Rect2i) -> Vector2i:
	return Vector2i(clampi(c.x, r.position.x, r.end.x - 1), clampi(c.y, r.position.y, r.end.y - 1))
