extends SceneTree
## CLI (con laberinto.tscn cerrada en el editor):
##   python3 tools/zonas/laberinto/analizar_laberinto.py                                  # datos
##   godot --headless --path . --script res://tools/zonas/laberinto/montar_laberinto.gd   # escena
## Monta UNA VEZ scenes/levels/laberinto.tscn (nivel 3, PROVISIONAL: el laberinto del Minotauro,
## arte de la artista del 2026-11-22). Como la isla: queda con `editada_a_mano`, se retoca en el
## editor y ningún generador la sobrescribe; para volver a montarla hay que quitar antes ese
## metadato (y se pierden los retoques).
##
## Se entra por ARRIBA (desde la orilla sur de la isla de Medusa) y la salida es el hueco de ABAJO
## A LA IZQUIERDA (fin de la demo). Las dos llevan reja (se cierran al empezar el combate).

const Constructor := preload("res://tools/zonas/constructor_zona.gd")
const ZonaPintada := preload("res://tools/zonas/zona_pintada.gd")

const RUTA := "res://scenes/levels/laberinto.tscn"
const DATOS := "res://tools/zonas/laberinto/laberinto_datos.json"
const MAPA := "res://assets/backgrounds/nivel3/laberinto/mapa.png"
const MUSICA := "res://assets/audio/music/minotauro.mp3"
const COFRE := "res://scenes/entorno/cofre.tscn"
const CUERNO := "res://resources/objetos/cuerno.tres"
const MINOTAURO := "res://scenes/enemies/minotauro.tscn"
const REJA := "res://scenes/entorno/reja.tscn"
const ESCENA := "res://scenes/cinematics/escena_minotauro.tscn"
const BARRERA := "res://scenes/entorno/barrera_mision.tscn"
const DIALOGO_FIN := "res://resources/dialogues/leonidas_fin_demo.tres"
const LUZ := "res://scripts/entorno/luz_antorcha.gd"
const TEXTURA_LUZ := "res://resources/luces/luz_radial.tres"

## Entrada de arriba (pasillo oscuro, x 452–525): se llega aquí desde la isla. Por debajo de la
## reja y dentro del Disparador del encuentro (empieza al llegar).
const DESDE_ISLA := Vector2(489, 118)
## Salida de vuelta a la isla: el borde de arriba del pasillo (el suelo empieza en y 52).
const SALIDA_ISLA := Rect2(449, 51, 80, 18)
## Base de los barrotes: al pie de la cara del muro (y 100), donde acaba el pasillo oscuro. La reja
## (82 de ancho → 64 de alto) sube por la boca del pasillo; más arriba asomaba por encima del dibujo.
const REJA_NORTE := Vector2(489, 100) # tapa x 452–525
const ANCHO_REJA_NORTE := 88.0 # el hueco mide 448–529: un poco de más a cada lado
## Hueco de abajo a la izquierda (x 122–167 desde y 508 hasta el borde de abajo).
const REJA_SUR := Vector2(145, 512)
const ANCHO_REJA_SUR := 50.0
const FIN_DEMO := Rect2(127, 516, 38, 12)
## Raíz de la escena del encuentro (la boca de la entrada) y adónde mira la cámara en la salida.
const ESCENA_POS := Vector2(489, 100)
const PUNTO_SALIDA := Vector2(145, 500)
## Centro del laberinto (sitio libre más amplio cerca del centro) y esquina de abajo a la derecha.
const MINOTAURO_POS := Vector2(470, 285)
const COFRE_POS := Vector2(742, 492)

## Penumbra con las luces encendidas (el «filtro oscuro»); EscenaMinotauro la cambia.
const COLOR_PENUMBRA := Color(0.55, 0.55, 0.62)
const COLOR_ANTORCHA := Color(1.0, 0.72, 0.38)


## Un fotograma después: ver montar_isla.gd (autoload y scripts de las escenas).
func _initialize() -> void:
	_montar.call_deferred()


func _montar() -> void:
	var datos := ZonaPintada.leer_datos(DATOS)
	if datos.is_empty():
		push_error("No se pudo leer %s: ejecuta antes analizar_laberinto.py" % DATOS)
		quit(1)
		return
	var tam := Vector2i(int(datos.tam[0]), int(datos.tam[1]))
	var dibujo: Array = datos.dibujo
	var z := Constructor.new("Laberinto", "Laberinto del Minotauro", ceili(tam.x / 16.0), ceili(tam.y / 16.0), 31)
	z.pintada = true # arte pintado: modo pintura, como el nivel 2
	z.musica = MUSICA
	z.transiciones = false
	z.raiz.set("limites_camara", Rect2i(int(dibujo[0]), int(dibujo[1]), int(dibujo[2]), int(dibujo[3])))
	z.raiz.set_meta(&"editada_a_mano", true)
	z.suelo_prov.free()
	z.limites.free() # muros y borde van en `Colisiones`
	ZonaPintada.poner_mapa(z.raiz, [MAPA], float(datos.escala))
	# Negro detrás del dibujo: fuera de los muros el PNG es transparente y se veía el gris de fondo.
	var negro := Polygon2D.new()
	negro.name = "FondoNegro"
	negro.color = Color.BLACK
	negro.polygon = PackedVector2Array([Vector2.ZERO, Vector2(tam.x, 0), Vector2(tam), Vector2(0, tam.y)])
	var mapa := z.raiz.get_node(^"Mapa")
	mapa.add_child(negro)
	mapa.move_child(negro, 0)
	negro.owner = z.raiz
	ZonaPintada.poner_colisiones(z.raiz, {
		"Muros": (datos.solidos as Array).map(_rect_a_poligono),
		"Pedestales": (datos.pedestales as Array).map(_rect_a_poligono),
	})

	# Oscuridad y antorchas (los aros dorados).
	var oscuridad := CanvasModulate.new()
	oscuridad.name = "Oscuridad"
	oscuridad.color = COLOR_PENUMBRA
	z.raiz.add_child(oscuridad)
	oscuridad.owner = z.raiz
	var antorchas := Node2D.new()
	antorchas.name = "Antorchas"
	z.raiz.add_child(antorchas)
	antorchas.owner = z.raiz
	var textura_luz := load(TEXTURA_LUZ) as Texture2D
	var i := 0
	for aro: Array in datos.aros:
		i += 1
		var luz := PointLight2D.new()
		luz.name = "Antorcha%d" % i
		luz.set_script(load(LUZ))
		luz.position = Vector2(float(aro[0]), float(aro[1]))
		luz.texture = textura_luz
		luz.texture_scale = 0.9
		luz.color = COLOR_ANTORCHA
		luz.set("energia", 1.1)
		antorchas.add_child(luz)
		luz.owner = z.raiz

	z.entrada("desde_isla", DESDE_ISLA)
	z.salida("SalidaIsla", SALIDA_ISLA.get_center(), SALIDA_ISLA.size, "isla", "desde_laberinto")
	z.marcador("PuntoSalida", PUNTO_SALIDA)

	var cofre := z.instancia("Cofres", COFRE, COFRE_POS)
	cofre.name = "CofreCuerno"
	cofre.set("objeto", load(CUERNO))
	var minotauro := z.instancia("Jefe", MINOTAURO, MINOTAURO_POS)
	minotauro.name = "Minotauro"
	var reja_norte := z.instancia("Rejas", REJA, REJA_NORTE)
	reja_norte.name = "RejaNorte"
	reja_norte.set("ancho", ANCHO_REJA_NORTE)
	var reja_sur := z.instancia("Rejas", REJA, REJA_SUR)
	reja_sur.name = "RejaSur"
	reja_sur.set("ancho", ANCHO_REJA_SUR)

	var fin := z.instancia("Eventos", BARRERA, FIN_DEMO.get_center())
	fin.name = "BarreraFinDemo"
	fin.set("requisito", 3) # BarreraMision.Requisito.FIN_DEMO
	fin.set("dialogo", load(DIALOGO_FIN))
	fin.set("dialogo_repetido", null)
	fin.set("destello", false)
	fin.set("direccion_retroceso", Vector2.UP)
	# Hijos editables (como «Editable Children»): si no, la forma nueva no se guarda.
	z.raiz.set_editable_instance(fin, true)
	var forma_fin := fin.get_node(^"Forma") as CollisionShape2D
	var rect_fin := RectangleShape2D.new()
	rect_fin.size = FIN_DEMO.size
	forma_fin.shape = rect_fin

	var escena := z.instancia("Eventos", ESCENA, ESCENA_POS)
	escena.name = "EscenaMinotauro"
	escena.set("minotauro", minotauro)
	var lista_rejas: Array[Reja] = [reja_norte as Reja, reja_sur as Reja]
	escena.set("rejas", lista_rejas)
	escena.set("oscuridad", oscuridad)
	escena.set("antorchas", antorchas)
	escena.set("punto_salida", z.raiz.get_node(^"PuntoSalida"))
	escena.set("color_penumbra", COLOR_PENUMBRA)

	var err := z.guardar(RUTA)
	print("Laberinto montado: ", error_string(err))
	quit(err)


## [x, y, ancho, alto] → los 4 vértices ([[x, y], ...], como los polígonos de los JSON).
static func _rect_a_poligono(r: Array) -> Array:
	var x := float(r[0])
	var y := float(r[1])
	var w := float(r[2])
	var h := float(r[3])
	return [[x, y], [x + w, y], [x + w, y + h], [x, y + h]]
