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
## La `isla` ya NO sale de aquí: se montó con el arte pintado definitivo desde
## tools/zonas/isla/montar_isla.gd y se retoca a mano (metadato `editada_a_mano`).
##
## ⚠ SOBRESCRIBE las escenas; si una zona se retoca a mano, quítala de aquí.
## Después: godot --headless --path . --script res://tools/verificar_zonas.gd

const Constructor := preload("res://tools/zonas/constructor_zona.gd")
const Tiles := preload("res://tools/zonas/tiles.gd")
const C := Tiles # para acortar los nombres de tiles

const DIR := "res://scenes/levels/"
const MUSICA := "res://assets/audio/music/"
const ARBUSTO := "res://scenes/items/arbusto.tscn"
const VASIJA_AZUL := "res://scenes/items/vasija_azul.tscn"
const VASIJA_NARANJA := "res://scenes/items/vasija_naranja.tscn"
const PIEDRA := "res://scenes/items/piedra.tscn"
const SETA := "res://scenes/enemies/seta_bomba.tscn"
const FLOR := "res://scenes/enemies/flor_falsa.tscn"
const REMOLINO := "res://scenes/entorno/remolino.tscn"
const TIBURON := "res://scenes/enemies/tiburon.tscn"
const GAMBA := "res://scenes/enemies/gamba.tscn"
const CICLOPE := "res://scenes/enemies/ciclope_serpiente.tscn"
const ARBOLES := ["pino", "cipres", "pino", "arbol_naranja", "cipres_dorado"]
const PALMERA := "provisional/palmera"
const MINI_PALMERA := "provisional/mini_palmera"
const BASE_PALMERA := Vector2(12, 6)
## Palmeras pintadas de la artista (nivel 2): textura y escala para ~80 px de alto (la mini,
## ~30). Ver docs/design/arte_nivel2_mapa.md.
const PALMERAS_PINTADAS := [
	["nivel2/palmera_1", 0.036], ["nivel2/palmera_2", 0.041],
	["nivel2/palmera_3", 0.041], ["nivel2/palmera_4", 0.052],
]
const MINI_PALMERA_PINTADA := ["nivel2/mini_palmera", 0.049]
const SIN_SOMBRA := {"sombra": false}
## Rocas del mar de la artista (tools/recortes/piedras_barquito.lua): textura, colisión y
## su desplazamiento. Traen el agua y la sombra pintadas debajo (6–9 px): la colisión sube
## hasta la línea del agua para que el barco choque con la piedra y no con su sombra.
const ROCAS_BARCO := [
	["roca_barco_pequena", Vector2(30, 8), Vector2(0, -6)],
	["roca_barco_alta", Vector2(50, 10), Vector2(0, -7)],
	["roca_barco_grande", Vector2(62, 12), Vector2(0, -8)],
]

var _zonas := {
	"bosque": _bosque,
	"playa": _playa,
	"mar": _mar,
	"isla_orilla": _isla_orilla,
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


## Camino de tierra (o arena provisional): se pinta el relleno y Constructor.guardar() pone
## los bordes (scripts/entorno/transiciones.gd). Mínimo 2 tiles de ancho.
func _arena(z: Constructor, r: Array) -> void:
	z.rect(r, C.TIERRA, false, C.TIERRA_B, 0.5)


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
	z.musica = MUSICA + "bosque.mp3"
	z.rect([0, 0, 63, 55], C.PASTO)
	z.marco(2, C.SETO)
	_arena(z, [30, 0, 33, 1])
	_arena(z, [44, 54, 47, 55])
	for r in [[31, 0, 32, 12], [14, 11, 32, 12], [14, 11, 15, 30], [14, 29, 46, 30], [45, 29, 46, 55]]:
		_arena(z, r)
	z.rect([36, 14, 47, 21], C.AGUA_NATURAL) # estanque natural (orilla de hierba)

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
	# Objetos que se levantan y lanzan (lejos de los pasos obligatorios del claro).
	z.instancia("Claro", ARBUSTO, _t(21, 38))
	z.instancia("Claro", ARBUSTO, _t(34, 36))
	z.instancia("Claro", ARBUSTO, _t(40, 34))
	z.instancia("Claro", VASIJA_AZUL, _t(23, 33))
	z.instancia("Claro", VASIJA_NARANJA, _t(35, 40))
	z.instancia("Claro", PIEDRA, _t(28, 36))
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
	z.musica = MUSICA + "playa.mp3"
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


# --- Mar ("Barquito"): minijuego del barco hacia el sur (docs/design/plan_minijuego_barco.md)
# `modo_barco`: Game sustituye a Leonidas por el Barco. Muelles cortos pegados al borde;
# el barco no navega sobre ellos: la salida está justo delante.

func _mar() -> Constructor:
	var z := Constructor.new("Mar", "Mar", 48, 90, 23)
	z.musica = MUSICA + "barco.mp3"
	z.raiz.set("modo_barco", true)
	z.rect([0, 0, 47, 89], C.MAR_NAV, true) # liso: las olas las dibuja el shader del agua
	for r in [[0, 0, 2, 89], [45, 0, 47, 89], [0, 0, 47, 1], [0, 88, 47, 89]]:
		z.rect(r, C.ARRECIFE, true)
	z.rect([22, 0, 25, 1], C.MUELLE, true)
	z.rect([22, 88, 25, 89], C.MUELLE, true)

	z.entrada("desde_playa", Vector2(384, 96))
	z.entrada("desde_isla", Vector2(384, 1344))
	z.salida("SalidaPlaya", Vector2(384, 40), Vector2(64, 16), "playa", "desde_mar")
	z.salida("SalidaIsla", Vector2(384, 1400), Vector2(64, 16), "isla_orilla", "desde_mar")

	var rocas := [Vector2i(10, 10), Vector2i(30, 12), Vector2i(38, 18), Vector2i(18, 20),
		Vector2i(8, 28), Vector2i(26, 30), Vector2i(36, 34), Vector2i(14, 40), Vector2i(28, 44),
		Vector2i(40, 48), Vector2i(8, 52), Vector2i(22, 56), Vector2i(34, 60), Vector2i(12, 66),
		Vector2i(26, 70), Vector2i(38, 74), Vector2i(16, 80), Vector2i(31, 79)]
	for i in rocas.size():
		var roca: Array = ROCAS_BARCO[i % ROCAS_BARCO.size()]
		z.deco("Rocas", roca[0], _t(rocas[i].x, rocas[i].y),
			{"sombra": false, "base": roca[1], "desplazamiento_base": roca[2]})

	# Peligros: más juntos hacia el centro; nada en los primeros/últimos 200 px.
	for p in [Vector2(200, 340), Vector2(520, 470), Vector2(330, 640), Vector2(470, 820),
			Vector2(260, 1000), Vector2(500, 1150)]:
		z.instancia("Peligros", REMOLINO, p)
	for p in [Vector2(384, 560), Vector2(300, 760), Vector2(460, 930), Vector2(384, 1030)]:
		z.instancia("Peligros", TIBURON, p)
	return z


# --- Orilla de la isla: la playa al revés (se llega por mar desde el norte) ---------

func _isla_orilla() -> Constructor:
	var z := Constructor.new("IslaOrilla", "Orilla de la isla", 60, 34, 24)
	z.pintada = true # nivel 2: arte pintado, modo pintura
	z.musica = MUSICA + "playa.mp3" # la isla de Medusa usa la música de la playa
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

	var palmeras := [Vector2i(6, 11), Vector2i(16, 10), Vector2i(24, 13), Vector2i(38, 12), Vector2i(46, 10),
			Vector2i(55, 12), Vector2i(10, 19), Vector2i(21, 21), Vector2i(40, 20), Vector2i(51, 21)]
	for i in palmeras.size():
		var pp: Array = PALMERAS_PINTADAS[i % PALMERAS_PINTADAS.size()]
		z.deco("Palmeras", pp[0], _t(palmeras[i].x, palmeras[i].y), {"base": BASE_PALMERA, "escala": pp[1]})
	for p in [Vector2i(13, 15), Vector2i(33, 17), Vector2i(44, 16), Vector2i(27, 22), Vector2i(5, 23), Vector2i(56, 22)]:
		z.deco("Palmeras", MINI_PALMERA_PINTADA[0], _t(p.x, p.y),
				{"base": Vector2(10, 5), "escala": MINI_PALMERA_PINTADA[1]})
	# Primer aviso de ruinas.
	z.deco("Ruinas", "columna_rota_1", _t(19, 16))
	z.deco("Ruinas", "columna_rota_2", _t(43, 23))
	z.deco("Ruinas", "roca", _t(35, 22), SIN_SOMBRA)
	# Primer contacto con las gambas: lejos del muelle y de SalidaMar (su mordisco empuja y
	# podría echar a Leonidas al mar) y a más de 96 px de las dos entradas.
	_grupo_gambas(z, _t(48, 17), 3)

	_arboles_borde(z, [[0, 32, 59, 33], [0, 25, 1, 33], [58, 25, 59, 33]])
	return z


## Grupo de `n` gambas en un círculo de ~24 px alrededor de `centro` (plan 07, Z1).
func _grupo_gambas(z: Constructor, centro: Vector2, n: int) -> void:
	for i in n:
		var angulo := TAU * i / n + 0.4
		z.instancia("Enemigos", GAMBA, centro + Vector2.from_angle(angulo) * 24.0)


# --- Cueva de Medusa ("Cueva N1"): pasillo horizontal en zigzag ---------------------

func _cueva_medusa() -> Constructor:
	var z := Constructor.new("CuevaMedusa", "Cueva de Medusa", 72, 30, 26)
	z.pintada = true # nivel 2: arte pintado, modo pintura
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

	# Un cíclope serpiente por cámara del zigzag, apartado del paso para que dispare al
	# pasillo (guion p. 36: "solo en la cueva"), y un grupo de gambas en la tercera.
	for p in [Vector2i(23, 8), Vector2i(34, 21), Vector2i(47, 8), Vector2i(57, 22)]:
		z.instancia("Enemigos", CICLOPE, _t(p.x, p.y))
	_grupo_gambas(z, _t(44, 19), 4)

	# El mecanismo que abre la puerta del jefe es tarea futura (guion p. 25).
	z.marcador("PuntoMecanismo", Vector2(1032, 152))
	z.marcador("PuntoPuerta", Vector2(1104, 240))
	return z


# --- Sala del jefe: Medusa en el centro y personas petrificadas alrededor -----------

func _cueva_jefe() -> Constructor:
	var z := Constructor.new("CuevaJefe", "Guarida de Medusa", 34, 26, 27)
	z.pintada = true # nivel 2: arte pintado, modo pintura
	z.musica = MUSICA + "bossfight.mp3"
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
	z.marcador("PuntoJefe", Vector2(272, 150)) # donde está Medusa

	# Medusa (plan 06, M6) y la escena de su combate. La raíz de la escena va en la boca del
	# pasillo: su Disparador cubre la sala y su Cierre tapa el pasillo (y = 328) durante el
	# combate; empieza desactivado, así que el verificador recorre la sala sin él.
	var medusa := z.instancia("Jefe", "res://scenes/enemies/medusa.tscn", Vector2(272, 150))
	medusa.name = "Medusa"
	var escena := z.instancia("Eventos", "res://scenes/cinematics/escena_medusa.tscn", Vector2(272, 304))
	escena.name = "EscenaMedusa"
	escena.set("medusa", medusa)
	# Dónde aparecen los cíclopes que invoca (Medusa elige los más alejados de Leonidas): en
	# la losa, lejos de las estatuas y de la entrada.
	var puntos_nodo := Node2D.new()
	puntos_nodo.name = "PuntosInvocacion"
	z.raiz.add_child(puntos_nodo)
	puntos_nodo.owner = z.raiz
	var puntos: Array[Marker2D] = []
	for p in [Vector2(176, 176), Vector2(368, 176), Vector2(200, 248), Vector2(344, 248)]:
		var m := Marker2D.new()
		m.name = "Punto%d" % (puntos.size() + 1)
		m.position = p
		puntos_nodo.add_child(m)
		m.owner = z.raiz
		puntos.append(m)
	medusa.set("puntos_invocacion", puntos)
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
