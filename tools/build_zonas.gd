extends SceneTree
## CLI:
##   godot --headless --path . --script res://tools/build_zonas.gd            # todas
##   godot --headless --path . --script res://tools/build_zonas.gd -- bosque  # solo esas
## Genera las zonas del mapa (salvo el pueblo, que tiene su propio generador y retoques a
## mano) con tools/zonas/constructor_zona.gd. Trazados PROVISIONALES a partir del boceto
## de flujo de niveles (docs/design/plan_mapa_mundo.md):
##
##   casa_arbol ↑ pueblo ↓ bosque ↓ playa ↓ mar ↓ isla_orilla ↓ isla → cueva_medusa → cueva_jefe
##
## ⚠ SOBRESCRIBE las escenas; si una zona se retoca a mano, quítala de aquí.
## Después: godot --headless --path . --script res://tools/verificar_zonas.gd

const Constructor := preload("res://tools/zonas/constructor_zona.gd")
const C := Constructor # para acortar los nombres de tiles

const DIR := "res://scenes/levels/"
const SETA := "res://scenes/enemies/seta_bomba.tscn"
const FLOR := "res://scenes/enemies/flor_falsa.tscn"
const ARBOLES := ["pino", "cipres", "pino", "arbol_naranja", "cipres_dorado"]
const PALMERA := "provisional/palmera"
const MINI_PALMERA := "provisional/mini_palmera"
const BASE_PALMERA := Vector2(12, 6)
const SIN_SOMBRA := {"sombra": false}

var _zonas := {
	"bosque": _bosque,
	"playa": _playa,
	"mar": _mar,
	"isla_orilla": _isla_orilla,
	"isla": _isla,
	"cueva_medusa": _cueva_medusa,
	"cueva_jefe": _cueva_jefe,
	"casa_arbol": _casa_arbol,
}


func _initialize() -> void:
	var pedidas := OS.get_cmdline_user_args()
	if pedidas.is_empty():
		pedidas = PackedStringArray(_zonas.keys())
	var ok := true
	for nombre in pedidas:
		if not _zonas.has(nombre):
			push_error("Zona desconocida: %s (hay: %s)" % [nombre, ", ".join(_zonas.keys())])
			ok = false
			continue
		var z: Constructor = _zonas[nombre].call()
		var ruta := DIR + nombre + ".tscn"
		var err := z.guardar(ruta)
		if err == OK:
			print("[zonas] %s guardada (%d×%d tiles)" % [ruta, z.ancho, z.alto])
		ok = ok and err == OK
	quit(0 if ok else 1)


## Centro del tile (columna, fila) en píxeles.
func _t(c: int, f: int) -> Vector2:
	return Vector2(c * 16 + 8, f * 16 + 8)


## Arena de camino con piedras al 12 %.
func _arena(z: Constructor, r: Array) -> void:
	z.rect(r, C.ARENA, false, C.ARENA_PIEDRAS, 0.12)


## Árboles sin colisión sobre los setos del borde: que parezca bosque y no un muro.
func _arboles_borde(z: Constructor, franjas: Array) -> void:
	for r in franjas:
		z.dispersar("ArbolesBorde", ARBOLES, r, Vector2(46, 34), {"solido": false})


## Rocas grandes (sólidas) cada 40 px en una columna, delante de un límite invisible.
func _rocas_columna(z: Constructor, x: float, y0: float, y1: float) -> void:
	var y := y0
	while y <= y1:
		z.deco("Rocas", "roca_grande", Vector2(x, y), SIN_SOMBRA)
		y += 40.0


# --- Bosque: al sur del pueblo; primer combate ------------------------------------

func _bosque() -> Constructor:
	var z := Constructor.new("Bosque", "Bosque", 64, 56, 21)
	z.rect([0, 0, 63, 55], C.PASTO)
	z.marco(2, C.SETO)
	_arena(z, [30, 0, 33, 1])
	_arena(z, [44, 54, 47, 55])
	for r in [[31, 0, 32, 12], [14, 11, 32, 12], [14, 11, 15, 30], [14, 29, 46, 30], [45, 29, 46, 55]]:
		_arena(z, r)
	z.rect([36, 14, 47, 21], C.AGUA)

	z.entrada("desde_pueblo", Vector2(512, 40))
	z.entrada("desde_playa", Vector2(736, 856))
	z.salida("SalidaPueblo", Vector2(512, 8), Vector2(64, 16), "pueblo", "desde_bosque")
	z.salida("SalidaPlaya", Vector2(736, 888), Vector2(64, 16), "playa", "desde_bosque")

	# Claro de combate.
	z.reservar_rect([18, 32, 42, 40])
	z.deco("Arboles", "manzano_1", _t(18, 33))
	z.deco("Arboles", "manzano_2", _t(41, 39))
	z.deco("Arboles", "manzano_3", _t(27, 41))
	z.deco("Claro", "roca", _t(22, 35), SIN_SOMBRA)
	z.deco("Claro", "tronco", _t(33, 38), SIN_SOMBRA)
	z.deco("Claro", "arbusto_verde", _t(25, 39))
	z.deco("Claro", "arbusto_verde", _t(38, 33))
	z.deco("Claro", "roca_grande", _t(30, 33), SIN_SOMBRA)
	for p in [Vector2i(24, 31), Vector2i(38, 36), Vector2i(30, 38)]:
		z.instancia("Enemigos", SETA, _t(p.x, p.y))
	for p in [Vector2i(20, 36), Vector2i(36, 33), Vector2i(42, 31)]:
		z.instancia("Enemigos", FLOR, _t(p.x, p.y))

	for r in [[4, 4, 26, 9], [36, 4, 59, 10], [20, 15, 32, 26], [4, 14, 10, 40], [50, 24, 59, 50], [4, 43, 40, 51]]:
		z.dispersar("Arboles", ARBOLES, r, Vector2(54, 36))
	_arboles_borde(z, [[0, 0, 63, 2], [0, 53, 63, 55], [0, 0, 2, 55], [61, 0, 63, 55]])
	return z


# --- Playa ("Orilla del mar"): árboles arriba, mar y muelle abajo ------------------

func _playa() -> Constructor:
	var z := Constructor.new("Playa", "Orilla del mar", 60, 34, 22)
	z.rect([0, 0, 59, 9], C.PASTO)
	z.rect([0, 10, 59, 27], C.ARENA)
	z.rect([0, 28, 59, 33], C.MAR)
	for r in [[0, 0, 59, 1], [0, 2, 1, 9], [58, 2, 59, 9]]:
		z.rect(r, C.SETO)
	_arena(z, [28, 0, 31, 1])
	_arena(z, [29, 0, 30, 9])
	z.rect([28, 26, 31, 33], C.MUELLE, true)

	z.entrada("desde_bosque", Vector2(480, 40))
	z.entrada("desde_mar", Vector2(480, 472))
	z.salida("SalidaBosque", Vector2(480, 8), Vector2(64, 16), "bosque", "desde_playa")
	z.salida("SalidaMar", Vector2(480, 536), Vector2(48, 16), "mar", "desde_playa")

	z.limite("Oeste", Rect2(-16, 160, 32, 290))
	z.limite("Este", Rect2(944, 160, 32, 290))
	_rocas_columna(z, 20, 180, 440)
	_rocas_columna(z, 940, 180, 440)

	var op := {"base": BASE_PALMERA}
	for p in [Vector2i(8, 13), Vector2i(20, 12), Vector2i(42, 13), Vector2i(53, 12), Vector2i(14, 20), Vector2i(48, 21)]:
		z.deco("Palmeras", PALMERA, _t(p.x, p.y), op)
	for p in [Vector2i(25, 15), Vector2i(37, 16), Vector2i(6, 24), Vector2i(55, 24)]:
		z.deco("Palmeras", MINI_PALMERA, _t(p.x, p.y), op)
	z.deco("Decorados", "roca", _t(17, 17), SIN_SOMBRA)
	z.deco("Decorados", "roca", _t(45, 23), SIN_SOMBRA)
	z.deco("Decorados", "tronco", _t(36, 22), SIN_SOMBRA)
	z.deco("Decorados", "troncos_apilados", _t(24, 24), SIN_SOMBRA)
	z.cartel(Vector2(432, 420), "res://resources/dialogues/cartel_muelle.tres")

	z.dispersar("Arboles", ARBOLES, [3, 3, 25, 8], Vector2(54, 36))
	z.dispersar("Arboles", ARBOLES, [35, 3, 56, 8], Vector2(54, 36))
	_arboles_borde(z, [[0, 0, 59, 1], [0, 0, 1, 9], [58, 0, 59, 9]])
	return z


# --- Mar ("Barquito"): travesía hacia el sur. Leonidas camina (el barco es otra tarea) --

func _mar() -> Constructor:
	var z := Constructor.new("Mar", "Mar", 48, 90, 23)
	z.rect([0, 0, 47, 89], C.MAR_NAV, true, C.MAR_NAV_OLA, 0.12)
	for r in [[0, 0, 2, 89], [45, 0, 47, 89], [0, 0, 47, 1], [0, 88, 47, 89]]:
		z.rect(r, C.ARRECIFE, true)
	z.rect([22, 0, 25, 3], C.MUELLE, true)
	z.rect([22, 86, 25, 89], C.MUELLE, true)

	z.entrada("desde_playa", Vector2(384, 56))
	z.entrada("desde_isla", Vector2(384, 1384))
	z.salida("SalidaPlaya", Vector2(384, 8), Vector2(64, 16), "playa", "desde_mar")
	z.salida("SalidaIsla", Vector2(384, 1432), Vector2(64, 16), "isla_orilla", "desde_mar")

	var rocas := [Vector2i(10, 10), Vector2i(30, 12), Vector2i(38, 18), Vector2i(18, 20),
		Vector2i(8, 28), Vector2i(26, 30), Vector2i(36, 34), Vector2i(14, 40), Vector2i(28, 44),
		Vector2i(40, 48), Vector2i(8, 52), Vector2i(22, 56), Vector2i(34, 60), Vector2i(12, 66),
		Vector2i(26, 70), Vector2i(38, 74), Vector2i(16, 80), Vector2i(30, 82)]
	for i in rocas.size():
		z.deco("Rocas", "provisional/roca_mar_%d" % (i % 3 + 1), _t(rocas[i].x, rocas[i].y), SIN_SOMBRA)
	z.marcador("PuntoBarco", Vector2(384, 100))
	return z


# --- Orilla de la isla: la playa al revés (se llega por mar desde el norte) ---------

func _isla_orilla() -> Constructor:
	var z := Constructor.new("IslaOrilla", "Orilla de la isla", 60, 34, 24)
	z.rect([0, 0, 59, 5], C.MAR)
	z.rect([0, 6, 59, 6], C.MAR_ORILLA)
	z.rect([0, 7, 59, 24], C.ARENA)
	z.rect([0, 25, 59, 33], C.PASTO)
	for r in [[0, 32, 59, 33], [0, 25, 1, 31], [58, 25, 59, 31]]:
		z.rect(r, C.SETO)
	_arena(z, [28, 32, 31, 33])
	_arena(z, [29, 25, 30, 33])
	z.rect([28, 0, 31, 8], C.MUELLE, true)

	z.entrada("desde_mar", Vector2(480, 56))
	z.entrada("desde_isla", Vector2(480, 504))
	z.salida("SalidaMar", Vector2(480, 8), Vector2(48, 16), "mar", "desde_isla")
	z.salida("SalidaIsla", Vector2(480, 536), Vector2(64, 16), "isla", "desde_orilla")

	z.limite("Oeste", Rect2(-16, 96, 32, 320))
	z.limite("Este", Rect2(944, 96, 32, 320))
	_rocas_columna(z, 20, 120, 390)
	_rocas_columna(z, 940, 120, 390)

	var op := {"base": BASE_PALMERA}
	for p in [Vector2i(6, 11), Vector2i(16, 10), Vector2i(24, 13), Vector2i(38, 12), Vector2i(46, 10),
			Vector2i(55, 12), Vector2i(10, 19), Vector2i(21, 21), Vector2i(40, 20), Vector2i(51, 21)]:
		z.deco("Palmeras", PALMERA, _t(p.x, p.y), op)
	for p in [Vector2i(13, 15), Vector2i(33, 17), Vector2i(44, 16), Vector2i(27, 22), Vector2i(5, 23), Vector2i(56, 22)]:
		z.deco("Palmeras", MINI_PALMERA, _t(p.x, p.y), op)
	# Primer aviso de ruinas.
	z.deco("Ruinas", "columna_rota_1", _t(19, 16))
	z.deco("Ruinas", "columna_rota_2", _t(43, 23))
	z.deco("Ruinas", "roca", _t(35, 22), SIN_SOMBRA)

	_arboles_borde(z, [[0, 32, 59, 33], [0, 25, 1, 33], [58, 25, 59, 33]])
	return z


# --- Isla de Medusa: ovalada, con un rastro de estatuas hasta la cueva --------------

func _isla() -> Constructor:
	var z := Constructor.new("Isla", "Isla de Medusa", 72, 56, 25)
	z.rect([0, 0, 71, 55], C.MAR)
	z.elipse(Vector2i(34, 30), Vector2(28, 20), C.ARENA)
	z.elipse(Vector2i(36, 8), Vector2(5, 9), C.ARENA)
	z.rect([34, 0, 37, 6], C.ARENA)
	z.elipse(Vector2i(32, 30), Vector2(22, 15), C.PASTO)
	for r in [[35, 6, 36, 20], [26, 19, 36, 20], [26, 19, 27, 37], [26, 36, 50, 37], [49, 30, 50, 37], [49, 30, 54, 31]]:
		_arena(z, r)

	z.entrada("desde_orilla", Vector2(576, 40))
	z.entrada("desde_cueva", Vector2(904, 512))
	z.salida("SalidaOrilla", Vector2(576, 8), Vector2(64, 16), "isla_orilla", "desde_isla")
	z.salida("SalidaCueva", Vector2(904, 474), Vector2(24, 12), "cueva_medusa", "desde_isla")

	# Rastro de estatuas (guion pp. 23 y 39): se siguen hasta la cueva.
	var rastro := [
		["estatua", Vector2i(33, 14), {}], ["estatua", Vector2i(24, 24), {}],
		["estatua", Vector2i(30, 39), {}], ["estatua", Vector2i(47, 34), {}],
		["pedestal", Vector2i(38, 18), {}], ["pedestal", Vector2i(29, 30), {}],
		["columna_rota_3", Vector2i(40, 39), {}],
		["arco_ruinas", Vector2i(32, 27), {"base": Vector2(110, 14)}],
	]
	for o in rastro:
		var op: Dictionary = (o[2] as Dictionary).merged(SIN_SOMBRA)
		var pos := _t(o[1].x, o[1].y)
		z.deco("Estatuas", o[0], pos, op)
		z.reservar(pos, 48.0)

	z.deco("Cueva", "provisional/entrada_cueva", Vector2(904, 480), {"solido": false, "sombra": false})
	z.deco("Cueva", "roca_grande", Vector2(866, 484), SIN_SOMBRA)
	z.deco("Cueva", "roca_grande", Vector2(942, 484), SIN_SOMBRA)
	z.reservar(Vector2(904, 480), 64.0)
	z.limite("TrasCueva", Rect2(872, 436, 64, 30))

	var rocas := [Vector2i(12, 30), Vector2i(20, 44), Vector2i(44, 46), Vector2i(58, 24), Vector2i(50, 14)]
	for i in rocas.size():
		var pos := _t(rocas[i].x, rocas[i].y)
		z.deco("Rocas", "roca" if i % 2 == 0 else "roca_grande", pos, SIN_SOMBRA)
		z.reservar(pos, 32.0)

	z.dispersar("Palmeras", [PALMERA, MINI_PALMERA, PALMERA], [12, 17, 52, 43], Vector2(80, 56), {"base": BASE_PALMERA})
	z.marcador("PuntoControlIsla", Vector2(576, 120))
	return z


# --- Cueva de Medusa ("Cueva N1"): pasillo horizontal en zigzag ---------------------

func _cueva_medusa() -> Constructor:
	var z := Constructor.new("CuevaMedusa", "Cueva de Medusa", 72, 30, 26)
	z.rect([0, 0, 71, 29], C.VACIO, true)
	z.rect([2, 5, 69, 24], C.PARED_CUEVA, true)
	z.rect([3, 6, 68, 23], C.SUELO_CUEVA, true, C.SUELO_CUEVA_B, 0.15)
	z.rect([0, 14, 2, 15], C.SUELO_CUEVA, true)
	z.rect([69, 14, 71, 15], C.SUELO_CUEVA, true)
	for r in [[14, 6, 16, 17], [26, 12, 28, 23], [38, 6, 40, 17], [50, 12, 52, 23], [60, 6, 61, 11]]:
		z.rect(r, C.PARED_CUEVA, true)

	z.entrada("desde_isla", Vector2(56, 240))
	z.entrada("desde_jefe", Vector2(1096, 240))
	z.salida("SalidaIsla", Vector2(8, 240), Vector2(16, 32), "isla", "desde_cueva")
	z.salida("SalidaJefe", Vector2(1144, 240), Vector2(16, 32), "cueva_jefe", "desde_cueva")

	var columnas := [Vector2i(8, 9), Vector2i(21, 20), Vector2i(33, 9), Vector2i(45, 20), Vector2i(57, 19)]
	for i in columnas.size():
		z.deco("Ruinas", "columna_rota_%d" % (i % 3 + 1), _t(columnas[i].x, columnas[i].y), SIN_SOMBRA)
	for p in [Vector2i(10, 21), Vector2i(44, 8), Vector2i(64, 21)]:
		z.deco("Ruinas", "provisional/roca_cueva", _t(p.x, p.y), SIN_SOMBRA)
	for p in [Vector2i(20, 9), Vector2i(56, 9)]:
		z.deco("Ruinas", "estatua", _t(p.x, p.y), SIN_SOMBRA)

	# El mecanismo que abre la puerta del jefe es tarea futura (guion p. 25).
	z.marcador("PuntoMecanismo", Vector2(1032, 152))
	z.marcador("PuntoPuerta", Vector2(1104, 240))
	return z


# --- Sala del jefe: Medusa en el centro y personas petrificadas alrededor -----------

func _cueva_jefe() -> Constructor:
	var z := Constructor.new("CuevaJefe", "Guarida de Medusa", 34, 26, 27)
	z.rect([0, 0, 33, 25], C.VACIO, true)
	z.elipse(Vector2i(17, 11), Vector2(14, 10), C.PARED_CUEVA, true)
	z.elipse(Vector2i(17, 11), Vector2(13, 9), C.LOSA_JEFE, true)
	z.rect([15, 19, 18, 25], C.PARED_CUEVA, true)
	z.rect([16, 19, 17, 25], C.SUELO_CUEVA, true)

	z.entrada("desde_cueva", Vector2(272, 376))
	z.salida("SalidaCueva", Vector2(272, 408), Vector2(32, 16), "cueva_medusa", "desde_jefe")

	for p in [Vector2i(8, 8), Vector2i(26, 8), Vector2i(6, 13), Vector2i(28, 13), Vector2i(10, 17), Vector2i(24, 17)]:
		z.deco("Petrificados", "estatua", _t(p.x, p.y), SIN_SOMBRA)
	z.deco("Ruinas", "columna_rota_2", _t(12, 5), SIN_SOMBRA)
	z.deco("Ruinas", "columna_rota_2", _t(22, 5), SIN_SOMBRA)
	z.marcador("PuntoJefe", Vector2(272, 150)) # aquí irá Medusa
	return z


# --- Casa del árbol: claro al norte del pueblo con la casa-tocón ---------------------

func _casa_arbol() -> Constructor:
	var z := Constructor.new("CasaArbol", "Casa del árbol", 40, 30, 28)
	z.rect([0, 0, 39, 29], C.PASTO)
	z.marco(2, C.SETO)
	_arena(z, [18, 28, 21, 29])
	_arena(z, [19, 18, 20, 29])

	z.entrada("desde_pueblo", Vector2(320, 440))
	z.salida("SalidaPueblo", Vector2(320, 472), Vector2(64, 16), "pueblo", "desde_casa_arbol")

	z.deco("Casa", "casa_tocon", Vector2(320, 272), {"sombra": false, "base": Vector2(200, 60)})
	z.reservar(Vector2(320, 240), 120.0)
	var manzanos := [Vector2i(7, 12), Vector2i(32, 11), Vector2i(9, 21), Vector2i(31, 22)]
	for i in manzanos.size():
		z.deco("Decorados", "manzano_%d" % (i + 1), _t(manzanos[i].x, manzanos[i].y))
	z.deco("Decorados", "macizo_flores_1", _t(14, 19), SIN_SOMBRA)
	z.deco("Decorados", "macizo_flores_2", _t(26, 19), SIN_SOMBRA)
	z.deco("Decorados", "tronco", _t(12, 24), SIN_SOMBRA)
	z.deco("Decorados", "arbusto_verde", _t(28, 25))
	z.cartel(Vector2(360, 300), "res://resources/dialogues/cartel_casa_arbol.tres")
	z.marcador("PuertaCasa", Vector2(320, 276)) # el interior es tarea futura

	z.dispersar("Arboles", ARBOLES, [3, 3, 36, 6], Vector2(54, 36))
	_arboles_borde(z, [[0, 0, 39, 1], [0, 28, 39, 29], [0, 0, 1, 29], [38, 0, 39, 29]])
	return z
