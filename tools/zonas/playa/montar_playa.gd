extends SceneTree
## CLI (con playa.tscn cerrada en el editor):
##   python3 tools/zonas/playa/analizar_playa.py                                  # PNG + datos
##   godot --headless --path . --import                                           # importar los PNG
##   godot --headless --path . --script res://tools/zonas/playa/montar_playa.gd   # escena
## Monta UNA VEZ scenes/levels/playa.tscn (nivel 1, la orilla del mar) con el dibujo de la artista
## assets/backgrounds/playa/playa.aseprite (500×400 pixel art, escala 1): fondo, objetos sueltos
## ordenados por Y y colisión, todo sacado por analizar_playa.py. Como la isla: queda con
## `editada_a_mano`, se retoca en el editor y ningún generador la sobrescribe; para volver a
## montarla hay que quitar antes ese metadato.

const Constructor := preload("res://tools/zonas/constructor_zona.gd")
const ZonaPintada := preload("res://tools/zonas/zona_pintada.gd")

const RUTA := "res://scenes/levels/playa.tscn"
const DATOS := "res://tools/zonas/playa/playa_datos.json"
const FONDO := "res://assets/backgrounds/playa/playa_fondo.png"
const MUSICA := "res://assets/audio/music/playa.mp3"

## Camino de tierra de arriba (al bosque) y muelle de abajo (al mar).
const DESDE_BOSQUE := Vector2(240, 46)
const DESDE_MAR := Vector2(251, 350)
const CARTEL := Vector2(186, 318) # junto al muelle (explica la barca)
## Franjas sólidas en las esquinas de arriba: detrás de las copas de los bordes Leonidas se
## escondía entre los árboles y el borde del mapa.
const BORDES := {
	"BordeOeste": [Vector2(0, 0), Vector2(50, 0), Vector2(50, 240), Vector2(0, 240)],
	"BordeEste": [Vector2(450, 0), Vector2(500, 0), Vector2(500, 190), Vector2(450, 190)],
}


## Un fotograma después: ver tools/zonas/isla/montar_isla.gd (autoload y scripts de escenas).
func _initialize() -> void:
	_montar.call_deferred()


func _montar() -> void:
	var datos := ZonaPintada.leer_datos(DATOS)
	if datos.is_empty():
		push_error("No se pudo leer %s: ejecuta antes analizar_playa.py" % DATOS)
		quit(1)
		return
	var tam := Vector2i(int(datos.tamano[0]), int(datos.tamano[1]))
	var z := Constructor.new("Playa", "Orilla del mar", ceili(tam.x / 16.0), ceili(tam.y / 16.0), 22)
	z.musica = MUSICA
	z.transiciones = false
	z.raiz.set("limites_camara", Rect2i(Vector2i.ZERO, tam))
	z.raiz.set_meta(&"editada_a_mano", true)
	z.suelo_prov.free()
	z.limites.free() # el agua, los objetos y el borde del mapa van en `Colisiones`
	ZonaPintada.poner_mapa(z.raiz, [FONDO], 1.0, false)
	ZonaPintada.poner_colisiones(z.raiz, {"Costa": datos.costa})
	for nombre: String in BORDES:
		var poli := CollisionPolygon2D.new()
		poli.name = nombre
		poli.polygon = PackedVector2Array(BORDES[nombre])
		z.raiz.get_node(^"Colisiones/Costa").add_child(poli)
		poli.owner = z.raiz

	z.entrada("desde_bosque", DESDE_BOSQUE)
	z.entrada("desde_mar", DESDE_MAR)
	# Salidas por dentro del borde del mapa (2 px sólidos): si no, los pies no llegan a pisarlas.
	z.salida("SalidaBosque", Vector2(DESDE_BOSQUE.x, 10), Vector2(48, 16), "bosque", "desde_playa")
	z.salida("SalidaMar", Vector2(DESDE_MAR.x, 392), Vector2(80, 16), "mar", "desde_playa")

	# Objetos del dibujo: sin colisión propia (su pie ya está en `Costa`) ni sombra (la traen).
	for o: Dictionary in datos.objetos:
		var grupo := "Palmeras" if o.tipo == "palmera" else "Decorados"
		z.deco(grupo, "playa/" + (o.textura as String).get_basename(), ZonaPintada.a_puntos([o.pos])[0],
				{"ancla": ZonaPintada.a_puntos([o.ancla])[0], "solido": false, "sombra": false})
	z.cartel(CARTEL, "res://resources/dialogues/cartel_muelle.tres")

	var err := z.guardar(RUTA)
	print("Playa montada: ", error_string(err))
	quit(err)
