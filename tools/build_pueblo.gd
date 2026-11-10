extends SceneTree
## CLI: godot --headless --path . --script res://tools/build_pueblo.gd
## Genera scenes/levels/pueblo.tscn a partir del plano de la artista (pueblo amurallado
## ovalado con el templo arriba, la plaza de la estatua en el centro y dos puertas).
##
## ⚠ SOBRESCRIBE la escena. Úsalo para rehacer el trazado desde cero; si después se
## retoca el pueblo a mano en el editor, NO lo vuelvas a ejecutar (o pasa los retoques aquí).
##
## Coordenadas:
##   - Suelo: en tiles (columna, fila) de 16 px. Mapa de ANCHO × ALTO tiles.
##   - Objetos: en píxeles del PLANO de referencia (1600×1298); `_p()` los pasa al mundo
##     (1 tile = 14 px del plano). Es la base del objeto (donde toca el suelo).
##
## Salidas: la puerta de arriba de la muralla lleva al bosque (borde superior del mapa);
## la de abajo está cerrada (colisión invisible).

const RUTA := "res://scenes/levels/pueblo.tscn"
const ANCHO := 114
const ALTO := 92
const PX_PLANO := 14.0 # px del plano por tile
const ESCALA := 16.0 / PX_PLANO

# Muralla: elipse de la línea de la base de los muros (en píxeles del mundo).
const CENTRO := Vector2(920, 816)
const SEMIEJE := Vector2(857, 607)
const MEDIA_PUERTA := 36.0 # la puerta mide 72 px de ancho
const ANCHO_MURO := 32.0

# Tiles (columna, fila) del atlas naturaleza.
const PASTO := Vector2i(0, 0)
const AGUA := Vector2i(16, 0)
const MAR := Vector2i(19, 0)
const CAMINO := Vector2i(3, 1)
const CAMINO_PIEDRAS := Vector2i(1, 1)
const GRECA_ESQUINA := Vector2i(4, 1)
const GRECA_BORDE := Vector2i(5, 1)
const BALDOSA := Vector2i(6, 1)
# Alternativas de los tiles "transformables" (ver build_tilesets.gd): H 1 + V 2 + transponer 4.
const H := 1
const V := 2
const T := 4

# Rectángulos de suelo [col0, fila0, col1, fila1] (inclusivos). Se pintan en este orden:
# agua, luego caminos (un camino sobre el agua hace de vado/puente), luego la plaza.
const AGUA_RECTS := [
	# Canales de arriba, a los lados del camino, entre la muralla y el templo.
	[52, 14, 53, 18], [61, 14, 62, 18],
	# Canal izquierdo: baja del templo y se va al oeste por debajo del mercado.
	[52, 40, 53, 52], [41, 51, 53, 52], [41, 51, 42, 57], [32, 56, 42, 57],
	[32, 56, 33, 64], [13, 63, 33, 64],
	# Canal derecho: baja del templo y sale al este atravesando la muralla.
	[61, 40, 62, 52], [61, 51, 69, 52], [68, 51, 69, 61], [68, 60, 79, 61],
	[78, 60, 79, 67], [78, 66, 113, 67],
]
const CAMINO_RECTS := [
	[56, 0, 58, 91], # camino principal norte–sur (de puerta a puerta)
	[17, 44, 108, 45], # calle principal este–oeste
	[18, 39, 19, 43], [31, 39, 32, 43], [80, 39, 81, 43], [92, 39, 93, 43], # a las casas de arriba
	[33, 46, 34, 54], [22, 53, 34, 54], # al mercado
	[90, 46, 91, 59], [77, 58, 99, 59], [77, 55, 78, 57], [98, 55, 99, 57], # casas del este
	[36, 71, 73, 72], [36, 70, 37, 70], [71, 70, 72, 70], # calle de abajo (casa de Leonidas)
]
const PLAZA := [50, 55, 65, 69]
# Mar de abajo a la izquierda (fuera de la muralla): [fila, última columna de mar].
const MAR_ORILLA := [[54, 1], [62, 2], [63, 3], [68, 4], [72, 5], [78, 7], [82, 9], [85, 11], [88, 13], [91, 15]]

const DIR := "res://assets/sprites/entorno/"

# Casas: [nombre, textura, x, y (plano), base]
const CASAS := [
	["CasaAmarillaNO", "casa_amarilla_cerrada", 256, 540, Vector2(132, 80)],
	["CasaBalconNO", "casa_balcon_cerrada", 484, 540, Vector2(165, 90)],
	["CasaAmarillaNE", "casa_amarilla_cerrada", 1127, 540, Vector2(132, 80)],
	["CasaBalconNE", "casa_balcon_cerrada", 1350, 540, Vector2(165, 90)],
	["CasaBalconE", "casa_balcon_cerrada", 1137, 778, Vector2(165, 90)],
	["CasaAmarillaE", "casa_amarilla_cerrada", 1370, 778, Vector2(132, 80)],
	["CasaLeonidas", "casa_teja_cerrada", 550, 970, Vector2(150, 100)],
	["CasaAmarillaS", "casa_amarilla_cerrada", 1001, 983, Vector2(132, 80)],
]

# Objetos sueltos: [textura, x, y (plano), opciones]. Opciones: solido, sombra, base.
# Los que caen fuera de la muralla se descartan solos.
const OBJETOS := [
	["templo", 805, 548, {"sombra": false, "base": Vector2(330, 70)}],
	["columna_1", 703, 610, {}],
	["columna_1", 903, 610, {}],
	["estatua", 805, 895, {"sombra": false}],
	["puesto_mercado", 365, 732, {"sombra": false}],
	["pedestal", 155, 638, {}],
	["pedestal", 1455, 585, {}],
	# Árboles junto a las casas y el templo
	["cipres_dorado", 262, 378, {}],
	["pino", 236, 428, {}], ["pino", 300, 432, {}],
	["pino", 176, 522, {}], ["pino", 340, 518, {}],
	["cipres_dorado", 618, 498, {}], ["cipres_dorado", 652, 445, {}],
	["cipres", 988, 488, {}],
	["cipres_dorado", 995, 222, {}], ["cipres_dorado", 1135, 250, {}],
	["pino", 1178, 285, {}], ["pino", 1218, 282, {}],
	["pino", 605, 785, {}], ["pino", 650, 797, {}], ["pino", 692, 777, {}],
	# Zona "cositas" (arriba a la izquierda): manzanos y rocas
	["manzano_1", 405, 350, {}], ["manzano_2", 520, 330, {}], ["manzano_3", 470, 395, {}],
	["roca_grande", 450, 300, {"sombra": false}], ["roca", 585, 240, {"sombra": false}],
	["arbusto_1", 375, 365, {"sombra": false}],
	["tronco", 1020, 668, {"sombra": false}],
	["troncos_apilados", 205, 805, {"sombra": false}],
	# Setos
	["arbusto_2", 300, 597, {"sombra": false}], ["arbusto_2", 332, 597, {"sombra": false}],
	["arbusto_2", 364, 597, {"sombra": false}], ["arbusto_2", 396, 597, {"sombra": false}],
	["arbusto_2", 428, 597, {"sombra": false}],
	["arbusto_2", 180, 862, {"sombra": false}], ["arbusto_2", 212, 862, {"sombra": false}],
	["arbusto_2", 244, 862, {"sombra": false}], ["arbusto_2", 276, 862, {"sombra": false}],
	["arbusto_2", 308, 862, {"sombra": false}],
	# Maceteros de flores (con colisión en la base)
	["macizo_flores_1", 545, 548, {"sombra": false}],
	["macizo_flores_1", 882, 538, {"sombra": false}],
	["macizo_flores_1", 1200, 535, {"sombra": false}],
	["macizo_flores_1", 275, 905, {"sombra": false}],
	["macizo_flores_1", 322, 905, {"sombra": false}],
	["macizo_flores_1", 478, 968, {"sombra": false}],
	["macizo_flores_1", 618, 968, {"sombra": false}],
	["macizo_flores_1", 855, 200, {"sombra": false}],
	["macizo_flores_1", 1090, 225, {"sombra": false}],
	["macizo_flores_2", 180, 528, {"sombra": false}],
	["macizo_flores_2", 334, 528, {"sombra": false}],
	["macizo_flores_2", 720, 540, {"sombra": false}],
	["macizo_flores_2", 1210, 773, {"sombra": false}],
	["macizo_flores_2", 1015, 818, {"sombra": false}],
	["macizo_flores_2", 100, 590, {"sombra": false}],
]

# Bosquecillos dentro de la muralla ("Árboles" en el plano): [x0, y0, x1, y1] del plano.
const BOSQUECILLOS := [
	[270, 1092, 700, 1135], # abajo a la izquierda
	[930, 1092, 1290, 1125], # abajo a la derecha
	[560, 255, 610, 300], # junto al templo, arriba a la izquierda
]
const ARBOLES := ["pino", "cipres", "cipres_dorado", "arbol_naranja", "pino"]
# Dentro del pueblo, árboles bajos: los altos tapan la calle y las casas.
const ARBOLES_BAJOS := ["pino", "pino", "arbol_naranja"]

var _rng := RandomNumberGenerator.new()
var _decorado: PackedScene
var _raiz: Node2D
var _suelo: TileMapLayer


func _initialize() -> void:
	_rng.seed = 12
	_decorado = load("res://scenes/entorno/decorado.tscn")
	_raiz = Node2D.new()
	_raiz.name = "Pueblo"
	_raiz.y_sort_enabled = true
	_raiz.set_script(load("res://scripts/systems/zona.gd"))
	_raiz.set("nombre_zona", "Pueblo")

	_suelo = TileMapLayer.new()
	_suelo.name = "Suelo"
	_suelo.z_index = -1
	_suelo.tile_set = load("res://resources/tilesets/naturaleza.tres")
	_agregar(_raiz, _suelo)
	_raiz.set("suelo", _suelo)
	_pintar_suelo()

	var objetos := _grupo(_raiz, "Objetos")
	_poner_casas(_grupo(objetos, "Casas"))
	_poner_objetos(_grupo(objetos, "Decorados"))
	_poner_cartel(objetos)
	_poner_muralla(_grupo(objetos, "Muralla"))
	_poner_bosquecillos(_grupo(objetos, "Arboles"))
	_poner_bosque_exterior(_grupo(objetos, "BosqueExterior"))
	_poner_limites()
	_poner_entradas_y_salidas()

	var variador := Node.new()
	variador.name = "VariadorPasto"
	variador.set_script(load("res://scripts/entorno/variador_pasto.gd"))
	_agregar(_raiz, variador)
	variador.set("capa", _suelo)
	variador.set("semilla", 8)
	variador.call("variar")

	var escena := PackedScene.new()
	var err := escena.pack(_raiz)
	if err != OK:
		push_error("No se pudo empaquetar el pueblo (error %d)" % err)
		quit(1)
		return
	var uid_anterior := ResourceLoader.get_resource_uid(RUTA) if FileAccess.file_exists(RUTA) else ResourceUID.INVALID_ID
	err = ResourceSaver.save(escena, RUTA)
	if err != OK:
		push_error("No se pudo guardar %s (error %d)" % [RUTA, err])
		quit(1)
		return
	if uid_anterior != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(RUTA, uid_anterior)
	print("[pueblo] %s guardado (%d×%d tiles)" % [RUTA, ANCHO, ALTO])
	_raiz.free()
	quit(0)


# --- Suelo -------------------------------------------------------------------

func _pintar_suelo() -> void:
	for f in ALTO:
		for c in ANCHO:
			_suelo.set_cell(Vector2i(c, f), 0, PASTO)
	# Mar: la orilla se interpola entre los puntos de MAR_ORILLA.
	for i in MAR_ORILLA.size() - 1:
		var a: Array = MAR_ORILLA[i]
		var b: Array = MAR_ORILLA[i + 1]
		for f in range(a[0], b[0] + 1):
			var hasta := roundi(lerpf(a[1], b[1], inverse_lerp(a[0], b[0], f)))
			for c in hasta + 1:
				_suelo.set_cell(Vector2i(c, f), 0, MAR)
	for r in AGUA_RECTS:
		_rect(r, func(_c: Vector2i) -> void: _suelo.set_cell(_c, 0, AGUA))
	for r in CAMINO_RECTS:
		_rect(r, func(_c: Vector2i) -> void:
			_suelo.set_cell(_c, 0, CAMINO_PIEDRAS if _rng.randf() < 0.15 else CAMINO))
	# Plaza de la estatua: baldosas con un marco de greca.
	var c0: int = PLAZA[0]
	var f0: int = PLAZA[1]
	var c1: int = PLAZA[2]
	var f1: int = PLAZA[3]
	for f in range(f0, f1 + 1):
		for c in range(c0, c1 + 1):
			var tile := BALDOSA
			var alt := 0
			var izq := c == c0
			var der := c == c1
			var arr := f == f0
			var aba := f == f1
			if (izq or der) and (arr or aba):
				tile = GRECA_ESQUINA
				alt = (H if der else 0) + (V if aba else 0)
			elif arr or aba:
				tile = GRECA_BORDE
				alt = V if aba else 0
			elif izq or der:
				tile = GRECA_BORDE
				alt = T + (H if der else 0)
			_suelo.set_cell(Vector2i(c, f), 0, tile, alt)


func _rect(r: Array, pintar: Callable) -> void:
	for f in range(r[1], r[3] + 1):
		for c in range(r[0], r[2] + 1):
			if c >= 0 and c < ANCHO and f >= 0 and f < ALTO:
				pintar.call(Vector2i(c, f))


func _tile_en(pos: Vector2) -> Vector2i:
	return _suelo.get_cell_atlas_coords(Vector2i(floori(pos.x / 16.0), floori(pos.y / 16.0)))


## true si en `pos` (mundo) hay camino, agua, mar o plaza: ahí no se ponen árboles.
func _suelo_ocupado(pos: Vector2) -> bool:
	for d in [Vector2.ZERO, Vector2(-10, 0), Vector2(10, 0), Vector2(0, -8)]:
		var t := _tile_en(pos + d)
		if t in [AGUA, MAR, CAMINO, CAMINO_PIEDRAS, GRECA_ESQUINA, GRECA_BORDE, BALDOSA]:
			return true
	return false


# --- Objetos -------------------------------------------------------------------

## Píxel del plano -> píxel del mundo (entero).
func _p(x: float, y: float) -> Vector2:
	return Vector2(roundf(x * ESCALA), roundf(y * ESCALA))


## Distancia normalizada al centro de la muralla (1 = sobre la línea de los muros).
func _radio(pos: Vector2) -> float:
	return ((pos - CENTRO) / SEMIEJE).length()


func _grupo(padre: Node, nombre: String) -> Node2D:
	var n := Node2D.new()
	n.name = nombre
	n.y_sort_enabled = true
	_agregar(padre, n)
	return n


func _agregar(padre: Node, hijo: Node) -> void:
	padre.add_child(hijo, true)
	hijo.owner = _raiz


func _deco(padre: Node, nombre: String, textura: String, pos: Vector2, op: Dictionary = {}) -> Node2D:
	var d := _decorado.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	d.name = nombre
	d.position = pos
	_agregar(padre, d)
	d.set("textura", load(DIR + textura + ".png"))
	for clave in op:
		d.set(clave, op[clave])
	return d


func _nombre(textura: String) -> String:
	return textura.to_pascal_case()


func _poner_casas(padre: Node) -> void:
	for c in CASAS:
		_deco(padre, c[0], c[1], _p(c[2], c[3]), {"base": c[4], "sombra": false})


func _poner_objetos(padre: Node) -> void:
	for o in OBJETOS:
		var pos := _p(o[1], o[2])
		if _radio(pos) > 0.96:
			continue
		_deco(padre, _nombre(o[0]), o[0], pos, o[3])


func _poner_cartel(padre: Node) -> void:
	var cartel := _deco(padre, "Cartel", "cartel", _p(676, 958))
	var zona := Area2D.new()
	zona.name = "ZonaDialogo"
	zona.set_script(load("res://scripts/componentes/zona_dialogo.gd"))
	_agregar(cartel, zona)
	zona.set("dialogo", load("res://resources/dialogues/cartel_pueblo.tres"))
	zona.set("posicion_burbuja", Vector2(0, -42))
	var forma := CollisionShape2D.new()
	forma.name = "Forma"
	forma.position = Vector2(0, -18)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 36)
	forma.shape = rect
	_agregar(zona, forma)


## Muros colocados a lo largo de la elipse, en dos arcos (este y oeste) que van del
## borde de la puerta de arriba al de la puerta de abajo. Cada muro va 32 px a un lado
## o 16 px más abajo que el anterior (como en el plano: en los lados se escalonan).
## Colisión: arriba solo la base; abajo casi todo el alto del muro, para que Leonidas
## no se meta "detrás" del muro sur desde dentro del pueblo.
func _poner_muralla(padre: Node) -> void:
	var muros := ["muro_enredadera_2", "muro_enredadera_2", "muro_enredadera_1", "muro_enredadera_3"]
	var borde := asin((MEDIA_PUERTA + ANCHO_MURO / 2.0) / SEMIEJE.x)
	var n := 0
	for lado in [1.0, -1.0]:
		var puntos: Array[Vector2] = []
		var ultimo := Vector2.INF
		var phi := borde
		while phi <= PI - borde:
			var p := _punto_muralla(phi, lado)
			if ultimo == Vector2.INF or absf(p.x - ultimo.x) >= ANCHO_MURO or absf(p.y - ultimo.y) >= 16.0:
				puntos.append(p)
				ultimo = p
			phi += 0.0005
		var final := _punto_muralla(PI - borde, lado)
		if puntos[-1].distance_to(final) > 4.0:
			puntos.append(final)
		for p in puntos:
			var t := clampf((p.y - CENTRO.y) / SEMIEJE.y, 0.0, 1.0)
			var alto := roundf(16.0 + 88.0 * t)
			n += 1
			_deco(padre, "Muro%d" % n, muros[_rng.randi() % muros.size()], p,
				{"base": Vector2(ANCHO_MURO + 2.0, alto), "sombra": false})


## phi = 0 arriba, PI abajo; lado 1 = este, -1 = oeste.
func _punto_muralla(phi: float, lado: float) -> Vector2:
	return Vector2(roundf(CENTRO.x + lado * SEMIEJE.x * sin(phi)), roundf(CENTRO.y - SEMIEJE.y * cos(phi)))


func _poner_bosquecillos(padre: Node) -> void:
	var n := 0
	for r in BOSQUECILLOS:
		var a := _p(r[0], r[1])
		var b := _p(r[2], r[3])
		var y := a.y
		var fila := 0
		while y <= b.y:
			var x := a.x + (27.0 if fila % 2 else 0.0)
			while x <= b.x:
				var pos := (Vector2(x, y) + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-5, 5))).round()
				if _radio(pos) < 0.9 and not _suelo_ocupado(pos):
					n += 1
					_deco(padre, "Arbol%d" % n, ARBOLES_BAJOS[_rng.randi() % ARBOLES_BAJOS.size()], pos)
				x += 54.0
			y += 36.0
			fila += 1


## "Rellenar de árboles": todo lo de fuera de la muralla. Son solo decorado (sin
## colisión): fuera no se puede llegar salvo por el camino del norte, que tiene sus
## propios límites invisibles.
func _poner_bosque_exterior(padre: Node) -> void:
	var n := 0
	var y := 8.0
	var fila := 0
	while y <= ALTO * 16.0 + 40.0:
		var x := -10.0 + (23.0 if fila % 2 else 0.0)
		while x <= ANCHO * 16.0 + 10.0:
			var pos := (Vector2(x, y) + Vector2(_rng.randf_range(-9, 9), _rng.randf_range(-6, 6))).round()
			x += 46.0
			if _radio(pos) < 1.07:
				continue
			if absf(pos.x - CENTRO.x) < 64.0: # caminos de las puertas
				continue
			var t := _tile_en(pos)
			if t == MAR or _tile_en(pos + Vector2(0, -12)) == MAR:
				continue
			n += 1
			_deco(padre, "Arbol%d" % n, ARBOLES[_rng.randi() % ARBOLES.size()], pos, {"solido": false})
		y += 34.0
		fila += 1


# --- Límites, entradas y salidas ----------------------------------------------

## Paredes invisibles: los lados del camino que sale por la puerta norte hacia el
## bosque, y la puerta sur (cerrada: no lleva a ningún sitio).
func _poner_limites() -> void:
	var limites := StaticBody2D.new()
	limites.name = "Limites"
	limites.collision_layer = 1
	limites.collision_mask = 0
	_agregar(_raiz, limites)
	var base_norte := CENTRO.y - SEMIEJE.y
	var base_sur := CENTRO.y + SEMIEJE.y
	_forma(limites, "CaminoNorteOeste", Rect2(CENTRO.x - MEDIA_PUERTA - 300, -64, 300, base_norte + 72))
	_forma(limites, "CaminoNorteEste", Rect2(CENTRO.x + MEDIA_PUERTA, -64, 300, base_norte + 72))
	_forma(limites, "PuertaSurCerrada", Rect2(CENTRO.x - MEDIA_PUERTA - 4, base_sur - 104, MEDIA_PUERTA * 2 + 8, 104))


func _forma(padre: Node, nombre: String, r: Rect2) -> void:
	var forma := CollisionShape2D.new()
	forma.name = nombre
	forma.position = r.get_center()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	forma.shape = rect
	_agregar(padre, forma)


func _poner_entradas_y_salidas() -> void:
	var entradas := Node2D.new()
	entradas.name = "Entradas"
	_agregar(_raiz, entradas)
	# Delante de la puerta de la casa de Leonidas (la puerta está a la izquierda de la fachada).
	_marcador(entradas, "inicio", _p(550, 970) + Vector2(-43, 18))
	_marcador(entradas, "desde_bosque", Vector2(CENTRO.x, 40))

	var salida := Area2D.new()
	salida.name = "SalidaBosque"
	salida.set_script(load("res://scripts/systems/salida_zona.gd"))
	salida.position = Vector2(CENTRO.x, -4)
	_agregar(_raiz, salida)
	salida.set("zona_destino", "res://scenes/levels/bosque.tscn")
	salida.set("entrada_destino", "desde_pueblo")
	var forma := CollisionShape2D.new()
	forma.name = "Forma"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(MEDIA_PUERTA * 2, 24)
	forma.shape = rect
	_agregar(salida, forma)


func _marcador(padre: Node, nombre: String, pos: Vector2) -> void:
	var m := Marker2D.new()
	m.name = nombre
	m.position = pos
	_agregar(padre, m)
