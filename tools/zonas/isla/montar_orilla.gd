extends SceneTree
## CLI (con isla_orilla.tscn cerrada en el editor):
##   python3 tools/zonas/isla/analizar_orilla.py                                  # datos
##   godot --headless --path . --script res://tools/zonas/isla/montar_orilla.gd   # escena
## Monta UNA VEZ scenes/levels/isla_orilla.tscn (nivel 2: la playa donde se desembarca) con el
## fondo pintado de la artista (assets/backgrounds/nivel2/playa_entero_fondo.png) y sus objetos
## colocados como en la lámina de referencia
## (docs/reference/nivel2/playa_entero_como_se_debe_ver.jpeg). Como la isla (ver
## montar_isla.gd): queda con `editada_a_mano`, se retoca en el editor y ningún generador la
## sobrescribe; para volver a montarla hay que quitar antes ese metadato.
##
## Escala 0,125: el lienzo (4960×3508) ocupa 620×438 px de mundo. La playa está pintada con el
## pincel más grande que el mapa de la isla (los guijarros y remolinos de la arena miden más del
## doble), así que va a la mitad de escala que la isla para que la arena se vea igual de grande.

const Constructor := preload("res://tools/zonas/constructor_zona.gd")
const ZonaPintada := preload("res://tools/zonas/zona_pintada.gd")

const RUTA := "res://scenes/levels/isla_orilla.tscn"
const DATOS := "res://tools/zonas/isla/orilla_datos.json"
const FONDO := "res://assets/backgrounds/nivel2/playa_entero_fondo.png"
const MUSICA := "res://assets/audio/music/playa.mp3"
const GAMBA := "res://scenes/enemies/gamba.tscn"

## Muelle (llegada en barco, arriba) y camino de guijarros (salida a la isla, abajo).
const DESDE_MAR := Vector2(318, 52)
const DESDE_ISLA := Vector2(329, 400)

## Objetos de la lámina de referencia: [textura (entorno/nivel2/), base, escala, opciones]. Sin
## sombra: la lámina no la pinta y, a este tamaño, el óvalo de ComponenteSombra tapa media playa.
const DECORADOS := {
	"Palmeras": [
		["palmera_1", Vector2(84, 229), 0.103, {"sombra": false}],
		["palmera_2", Vector2(130, 430), 0.115, {"sombra": false}],
		["palmera_3", Vector2(558, 279), 0.14, {"sombra": false}],
		["palmera_4", Vector2(605, 320), 0.15, {"sombra": false}],
		["arbusto", Vector2(558, 372), 0.047, {"sombra": false}],
		["arbusto", Vector2(600, 430), 0.05, {"sombra": false}],
	],
	"Rocas": [
		["roca_3", Vector2(47, 406), 0.151, {"sombra": false}],
	],
}
## Franjas sólidas en los bordes oeste y este, donde las palmeras cierran la playa en la lámina:
## sin ellas, Leonidas se escondía entre los troncos y el borde del mapa.
const BORDES := {
	"BordeOeste": [Vector2(0, 120), Vector2(60, 120), Vector2(60, 438), Vector2(0, 438)],
	"BordeEste": [Vector2(596, 150), Vector2(620, 150), Vector2(620, 438), Vector2(596, 438)],
}
## Primer contacto con las gambas (como antes): lejos del muelle (su mordisco empuja y podría
## echar a Leonidas al agua) y a más de 96 px de las dos entradas.
const GAMBAS := Vector2(430, 230)


## Un fotograma después: ver montar_isla.gd (autoload y scripts de las escenas).
func _initialize() -> void:
	_montar.call_deferred()


func _montar() -> void:
	var datos := ZonaPintada.leer_datos(DATOS)
	if datos.is_empty():
		push_error("No se pudo leer %s: ejecuta antes analizar_orilla.py" % DATOS)
		quit(1)
		return
	var tam := Vector2i(int(datos.tamano[0]), int(datos.tamano[1]))
	var z := Constructor.new("IslaOrilla", "Orilla de la isla", ceili(tam.x / 16.0), ceili(tam.y / 16.0), 24)
	z.pintada = true # nivel 2: arte pintado, modo pintura
	z.musica = MUSICA # la isla de Medusa usa la música de la playa
	z.transiciones = false
	z.raiz.set("limites_camara", Rect2i(Vector2i.ZERO, tam))
	z.raiz.set_meta(&"editada_a_mano", true)
	z.suelo_prov.free()
	z.limites.free() # el agua y el borde del mapa van en `Colisiones`
	ZonaPintada.poner_mapa(z.raiz, [FONDO], float(datos.escala))
	ZonaPintada.poner_colisiones(z.raiz, {"Costa": datos.costa})
	for nombre: String in BORDES:
		var poli := CollisionPolygon2D.new()
		poli.name = nombre
		poli.polygon = PackedVector2Array(BORDES[nombre])
		z.raiz.get_node(^"Colisiones/Costa").add_child(poli)
		poli.owner = z.raiz

	z.entrada("desde_mar", DESDE_MAR)
	z.entrada("desde_isla", DESDE_ISLA)
	# Por debajo del borde del mapa (4 px sólidos): si no, los pies no llegan a pisarla.
	z.salida("SalidaMar", Vector2(DESDE_MAR.x, 12), Vector2(96, 16), "mar", "desde_isla")
	z.salida("SalidaIsla", Vector2(DESDE_ISLA.x, 432), Vector2(160, 12), "isla", "desde_orilla")

	# Posiciones = centro de la base de la imagen; ver `_deco` de montar_isla.gd.
	for grupo: String in DECORADOS:
		for d: Array in DECORADOS[grupo]:
			var op: Dictionary = (d[3] as Dictionary).merged({"escala": d[2]}).merged(ZonaPintada.opciones_pie(d[0], d[2]), true)
			z.deco(grupo, "nivel2/" + d[0], d[1] + ZonaPintada.correccion_pie(d[0], d[2]), op)
	for i in 3:
		var pos := GAMBAS + Vector2.from_angle(TAU * i / 3 + 0.4) * 24.0
		for e: Vector2 in [DESDE_MAR, DESDE_ISLA]:
			if pos.distance_to(e) < 96.0:
				push_error("Gamba a %.0f px de una entrada" % pos.distance_to(e))
		z.instancia("Enemigos", GAMBA, pos)

	var err := z.guardar(RUTA)
	print("Orilla montada: ", error_string(err))
	quit(err)
