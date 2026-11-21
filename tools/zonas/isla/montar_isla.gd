extends SceneTree
## CLI (con el editor CERRADO o sin isla.tscn abierta):
##   python3 tools/zonas/isla/analizar_isla.py                                   # datos
##   godot --headless --path . --script res://tools/zonas/isla/montar_isla.gd    # escena
## Monta UNA VEZ scenes/levels/isla.tscn (nivel 2) con el arte pintado definitivo de la artista
## (capas de assets/backgrounds/nivel2/ y objetos de assets/sprites/entorno/nivel2/) y los datos
## que `analizar_isla.py` saca del arte y de los layouts (docs/reference/nivel2/layout/):
## colisión de costa y de las elevaciones, bosques, enemigos y cofres.
##
## La escena queda con el metadato `editada_a_mano`: a partir de ahí se retoca en el editor y
## ni este script ni tools/build_zonas.gd la sobrescriben (`ConstructorZona.guardar()` se
## niega). Para volver a montarla desde cero hay que quitar antes ese metadato (y se pierden
## los retoques). Los polígonos de colisión no salen de ningún tile: se pueden mover punto a
## punto en el editor 2D.
##
## Escala: el lienzo (9828×5873) va a 0,25 → 2457×1468 px de mundo; en modo pintura 1 px del
## arte = 1 px de pantalla a 1920×1080. Los objetos pintados se reducen con `Decorado.escala`.

const Constructor := preload("res://tools/zonas/constructor_zona.gd")

const RUTA := "res://scenes/levels/isla.tscn"
const DATOS := "res://tools/zonas/isla/isla_datos.json"
const CAPAS := ["mar", "piso", "orilla", "monte_1", "monte_2"] # de abajo arriba
const DIR_CAPAS := "res://assets/backgrounds/nivel2/"
const MUSICA := "res://assets/audio/music/playa.mp3"
const GAMBA := "res://scenes/enemies/gamba.tscn"
const PEZ_ESPADA := "res://scenes/enemies/pez_espada.tscn"
const CICLOPE := "res://scenes/enemies/ciclope_serpiente.tscn"
const BOSQUE := "res://scenes/entorno/bosque_denso.tscn"
const COFRE := "res://scenes/entorno/cofre.tscn"
const COQUERA := "res://scenes/entorno/palmera_coquera.tscn"
const MANZANA := "res://resources/objetos/manzana.tres"
const COCO := "res://resources/objetos/coco.tres"

## Índices de `enemigos` (orden de isla_datos.json: de arriba abajo) que no son gambas. Los peces
## van en los puntos con más sitio para correr; los cíclopes, junto a la cueva y en el noreste.
const PECES := [4, 12, 22]
const CICLOPES := [1, 10, 18]
## Premio de cada cofre (orden de `cofres`: de arriba abajo). El del final de la «U» (callejón
## sin salida) es el mejor. PROVISIONAL: a falta de que guion lo decida.
const PREMIOS := [
	{"monedas": 10},
	{"objeto": MANZANA, "cantidad": 2},
	{"monedas": 20},
	{"monedas": 30, "objeto": COCO, "cantidad": 2},
	{"objeto": COCO, "cantidad": 3},
]

## Cueva: base del dibujo y boca (relativa a la base). La boca se mide en el dibujo
## (cueva.png: el hueco oscuro, a la izquierda del centro).
const CUEVA := Vector2(2280, 820)
const ESCALA_CUEVA := 0.197 # 350 px de ancho, como en el layout
const BOCA := Vector2(-35, -40)
## Contorno sólido de la cueva (relativo a la base), con una muesca hasta la boca.
const CONTORNO_CUEVA := [
	Vector2(-165, -8), Vector2(-150, -120), Vector2(-60, -200), Vector2(80, -215),
	Vector2(165, -130), Vector2(170, -8), Vector2(-15, -8), Vector2(-15, -60),
	Vector2(-55, -60), Vector2(-55, -8),
]

const BASE_PALMERA := Vector2(12, 6)
const BASE_ARBOL := Vector2(16, 8)

## Decorados: [textura (dentro de entorno/nivel2/), posición, escala, opciones de Decorado].
## Posiciones comprobadas contra la máscara transitable de analizar_isla.py (holgura ≥ 16 px).
const DECORADOS := {
	"Palmeras": [
		["palmera_1", Vector2(360, 168), 0.036, {"base": BASE_PALMERA}],
		["palmera_2", Vector2(600, 120), 0.041, {"base": BASE_PALMERA}],
		["palmera_3", Vector2(636, 264), 0.041, {"base": BASE_PALMERA}],
		["palmera_4", Vector2(564, 312), 0.052, {"base": BASE_PALMERA}],
		["palmera_1", Vector2(792, 360), 0.036, {"base": BASE_PALMERA}],
		["palmera_3", Vector2(828, 420), 0.041, {"base": BASE_PALMERA}],
		["mini_palmera", Vector2(120, 180), 0.049, {"base": Vector2(10, 5)}],
		["mini_palmera", Vector2(420, 150), 0.049, {"base": Vector2(10, 5)}],
		["mini_palmera", Vector2(2000, 450), 0.049, {"base": Vector2(10, 5)}],
		# Sobre la franja de costa del oeste (no se pisa): solo decoración.
		["palmera_2", Vector2(24, 120), 0.041, {"solido": false}],
		["palmera_4", Vector2(30, 264), 0.052, {"solido": false}],
		["palmera_1", Vector2(36, 420), 0.036, {"solido": false}],
		["palmera_3", Vector2(40, 560), 0.041, {"solido": false}],
	],
	"Arboles": [
		["arbol", Vector2(690, 200), 0.052, {"base": BASE_ARBOL}],
		["arbol", Vector2(720, 288), 0.052, {"base": BASE_ARBOL}],
	],
	"Rocas": [
		["roca_2", Vector2(552, 384), 0.076, {"sombra": false}],
		["roca_2", Vector2(228, 768), 0.076, {"sombra": false}],
		["roca_2", Vector2(300, 744), 0.076, {"sombra": false}],
		["roca_2", Vector2(240, 840), 0.07, {"sombra": false}],
		["roca_3", Vector2(144, 492), 0.055, {"sombra": false}],
	],
	"Estatuas": [
		["estatua_1", Vector2(300, 500), 0.053, {"sombra": false}],
		["estatua_2", Vector2(1380, 480), 0.05, {"sombra": false}],
		["estatua_3", Vector2(1150, 300), 0.042, {"sombra": false}],
		["estatua_4", Vector2(2050, 600), 0.046, {"sombra": false}],
	],
}
## Cristales de roca en el mar (layout base): solo decoración.
const CRISTALES := [
	Vector2(924, 108), Vector2(984, 96), Vector2(1032, 120), Vector2(1068, 29), Vector2(1392, 60),
	Vector2(1440, 48), Vector2(1476, 108), Vector2(2004, 96), Vector2(2100, 36), Vector2(2208, 96),
	Vector2(2316, 84), Vector2(2376, 96), Vector2(1968, 1116), Vector2(2040, 1176), Vector2(1944, 1224),
]
const COQUERAS := [Vector2(240, 300), Vector2(2000, 330), Vector2(520, 1180)]


## Se monta un fotograma después: un `--script` se compila antes de que existan los autoload,
## y los scripts de las escenas que se instancian (Cofre, ZonaDialogo…) los usan por nombre
## (si no compilan, la escena se guardaría con `script = null`). Ver tools/pruebas/lanzar.gd.
func _initialize() -> void:
	_montar.call_deferred()


func _montar() -> void:
	var texto := FileAccess.get_file_as_string(DATOS)
	var datos: Dictionary = JSON.parse_string(texto) if not texto.is_empty() else {}
	if datos.is_empty():
		push_error("No se pudo leer %s: ejecuta antes analizar_isla.py" % DATOS)
		quit(1)
		return
	var tam := Vector2i(int(datos.tamano[0]), int(datos.tamano[1]))
	var z := Constructor.new("Isla", "Isla de Medusa", ceili(tam.x / 16.0), ceili(tam.y / 16.0), 25)
	z.pintada = true # nivel 2: arte pintado, modo pintura
	z.musica = MUSICA # la isla de Medusa usa la música de la playa
	z.transiciones = false
	z.raiz.set("limites_camara", Rect2i(Vector2i.ZERO, tam))
	z.raiz.set_meta(&"editada_a_mano", true)
	# Sin tiles: el suelo es el mapa pintado. `Suelo` se queda vacío (Zona lo espera).
	z.suelo_prov.free()
	z.limites.free() # la costa y el borde del mapa van en `Colisiones`
	_mapa(z, float(datos.escala_mapa))
	_colisiones(z, datos)
	_bosques(z, datos.bosques)
	_cueva(z)

	z.entrada("desde_orilla", Vector2(125, 60))
	z.entrada("desde_cueva", CUEVA + Vector2(BOCA.x, 28))
	z.salida("SalidaOrilla", Vector2(125, 8), Vector2(200, 16), "isla_orilla", "desde_isla")
	z.salida("SalidaCueva", CUEVA + BOCA, Vector2(36, 30), "cueva_medusa", "desde_isla")
	z.marcador("PuntoControlIsla", Vector2(125, 110))

	for grupo: String in DECORADOS:
		for d: Array in DECORADOS[grupo]:
			var op: Dictionary = (d[3] as Dictionary).merged({"escala": d[2]})
			z.deco(grupo, "nivel2/" + d[0], d[1], op)
	for i in CRISTALES.size():
		z.deco("Rocas", "nivel2/roca_1", CRISTALES[i], {"escala": 0.06 + 0.01 * (i % 3), "solido": false, "sombra": false})
	for p: Vector2 in COQUERAS:
		z.instancia("Palmeras", COQUERA, p)

	for i in (datos.cofres as Array).size():
		var c := z.instancia("Cofres", COFRE, _v(datos.cofres[i].pos))
		var premio: Dictionary = PREMIOS[i]
		c.set("monedas", premio.get("monedas", 0))
		if premio.has("objeto"):
			c.set("objeto", load(premio.objeto))
			c.set("cantidad", premio.cantidad)
	# Puntos azules del layout: un enemigo cada uno (ninguno a < 96 px de una entrada).
	var entradas := [Vector2(125, 60), CUEVA + Vector2(BOCA.x, 28)]
	for i in (datos.enemigos as Array).size():
		var pos := _v(datos.enemigos[i].pos)
		for e: Vector2 in entradas:
			if pos.distance_to(e) < 96.0:
				push_error("Enemigo %d a %.0f px de una entrada" % [i, pos.distance_to(e)])
		var escena := PEZ_ESPADA if i in PECES else CICLOPE if i in CICLOPES else GAMBA
		z.instancia("Enemigos", escena, pos)

	var err := z.guardar(RUTA)
	print("Isla montada: ", error_string(err))
	quit(err)


func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


## Las cinco capas del mapa, todas en (0, 0) (comparten lienzo), debajo de todo.
func _mapa(z: Constructor, escala: float) -> void:
	var mapa := Node2D.new()
	mapa.name = "Mapa"
	mapa.z_index = -1
	mapa.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	z.raiz.add_child(mapa, true)
	z.raiz.move_child(mapa, 0)
	mapa.owner = z.raiz
	for nombre: String in CAPAS:
		var s := Sprite2D.new()
		s.name = nombre.to_pascal_case()
		s.texture = load(DIR_CAPAS + nombre + ".png")
		s.centered = false
		s.scale = Vector2(escala, escala)
		mapa.add_child(s, true)
		s.owner = z.raiz


## Costa (mar, acantilados, bordes del mapa) y paredes de las elevaciones: polígonos sólidos
## en la capa mundo, uno por trozo para que sean simples (sin agujeros) y editables.
func _colisiones(z: Constructor, datos: Dictionary) -> void:
	var colisiones := Node2D.new()
	colisiones.name = "Colisiones"
	z.raiz.add_child(colisiones, true)
	colisiones.owner = z.raiz
	for par: Array in [["Costa", datos.costa], ["BordesElevacion", datos.bordes_elevacion]]:
		var cuerpo := StaticBody2D.new()
		cuerpo.name = par[0]
		cuerpo.collision_layer = Capas.MUNDO
		cuerpo.collision_mask = 0
		colisiones.add_child(cuerpo, true)
		cuerpo.owner = z.raiz
		for i in (par[1] as Array).size():
			var poli := CollisionPolygon2D.new()
			poli.name = "%s%d" % [par[0], i + 1]
			var pts := PackedVector2Array()
			for p: Array in par[1][i]:
				pts.append(_v(p))
			poli.polygon = pts
			cuerpo.add_child(poli, true)
			poli.owner = z.raiz


func _bosques(z: Constructor, bosques: Array) -> void:
	for i in bosques.size():
		var pts := PackedVector2Array()
		for p: Array in bosques[i]:
			pts.append(_v(p))
		var centro := Vector2.ZERO
		for p in pts:
			centro += p
		centro = (centro / pts.size()).round()
		var b := z.instancia("Bosques", BOSQUE, centro)
		b.name = "Bosque%d" % (i + 1)
		var forma := b.get_node(^"Forma") as CollisionPolygon2D
		var local := PackedVector2Array()
		for p in pts:
			local.append(p - centro)
		forma.polygon = local
		# Editable Children: si no, no se guardarían el polígono ni los árboles de la instancia.
		z.raiz.set_editable_instance(b, true)
		b.set("semilla", i + 1)
		b.call("poblar")
		for arbol in b.get_node(^"Arboles").get_children():
			arbol.owner = z.raiz


## Boca de la cueva de Medusa (arte pintado) con su colisión: un contorno con una muesca que
## lleva hasta `SalidaCueva`.
func _cueva(z: Constructor) -> void:
	z.deco("Cueva", "nivel2/cueva", CUEVA, {"escala": ESCALA_CUEVA, "solido": false, "sombra": false})
	var cuerpo := StaticBody2D.new()
	cuerpo.name = "ColisionCueva"
	cuerpo.collision_layer = Capas.MUNDO
	cuerpo.collision_mask = 0
	cuerpo.position = CUEVA
	z.raiz.get_node(^"Colisiones").add_child(cuerpo, true)
	cuerpo.owner = z.raiz
	var poli := CollisionPolygon2D.new()
	poli.name = "Contorno"
	poli.polygon = PackedVector2Array(CONTORNO_CUEVA)
	cuerpo.add_child(poli, true)
	poli.owner = z.raiz
