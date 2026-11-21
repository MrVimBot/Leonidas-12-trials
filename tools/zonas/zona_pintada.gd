extends RefCounted
## Piezas comunes de los montadores de zonas dibujadas en una imagen (no con tiles):
## tools/zonas/isla/montar_isla.gd, montar_orilla.gd (arte pintado del nivel 2) y
## tools/zonas/playa/montar_playa.gd (pixel art): el fondo en capas y la colisión en polígonos
## que sacan los scripts de Python (analizar_*.py). Todo queda con `raiz` como dueño, para
## guardarse en la escena.


## Nodo `Mapa` (z −1) con un Sprite2D por textura, a `escala`, de abajo arriba en el orden de
## `rutas`. Va el primero de la zona. `esquinas`: px del lienzo donde empieza cada capa recortada
## (vacío = todas en (0, 0)). `pintado`: Linear Mipmap (arte pintado, reducido); si no, el filtro
## del proyecto (Nearest, pixel art).
static func poner_mapa(raiz: Node, rutas: Array, escala: float, pintado := true, esquinas: Array = []) -> void:
	var mapa := Node2D.new()
	mapa.name = "Mapa"
	mapa.z_index = -1
	if pintado:
		mapa.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	raiz.add_child(mapa, true)
	raiz.move_child(mapa, 0)
	mapa.owner = raiz
	for i in rutas.size():
		var ruta: String = rutas[i]
		var s := Sprite2D.new()
		s.name = ruta.get_file().get_basename().to_pascal_case()
		s.texture = load(ruta)
		s.centered = false
		s.scale = Vector2(escala, escala)
		if i < esquinas.size():
			s.position = (esquinas[i] as Vector2) * escala
		mapa.add_child(s, true)
		s.owner = raiz


## Nodo `Colisiones` con un StaticBody2D (capa mundo) por entrada de `cuerpos` (nombre →
## lista de polígonos [[x, y], ...] en px de mundo); un CollisionPolygon2D por polígono.
static func poner_colisiones(raiz: Node, cuerpos: Dictionary) -> Node2D:
	var colisiones := Node2D.new()
	colisiones.name = "Colisiones"
	raiz.add_child(colisiones, true)
	colisiones.owner = raiz
	for nombre: String in cuerpos:
		var cuerpo := StaticBody2D.new()
		cuerpo.name = nombre
		cuerpo.collision_layer = Capas.MUNDO
		cuerpo.collision_mask = 0
		colisiones.add_child(cuerpo, true)
		cuerpo.owner = raiz
		var polis: Array = cuerpos[nombre]
		for i in polis.size():
			var poli := CollisionPolygon2D.new()
			poli.name = "%s%d" % [nombre, i + 1]
			poli.polygon = a_puntos(polis[i])
			cuerpo.add_child(poli, true)
			poli.owner = raiz
	return colisiones


## [[x, y], ...] (JSON) → PackedVector2Array.
static func a_puntos(lista: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p: Array in lista:
		pts.append(Vector2(float(p[0]), float(p[1])))
	return pts


## Lee un JSON de datos; diccionario vacío si no existe.
static func leer_datos(ruta: String) -> Dictionary:
	var texto := FileAccess.get_file_as_string(ruta)
	var datos: Variant = JSON.parse_string(texto) if not texto.is_empty() else null
	return datos if datos is Dictionary else {}


## Medidas de los objetos pintados (tools/zonas/isla/medir_pies.py).
const PIES := "res://tools/zonas/isla/pies.json"


## Opciones de `Decorado` para que el pie del dibujo `nombre` (sin extensión, de
## assets/sprites/entorno/nivel2/) quede en el origen del nodo y la colisión lo cubra:
## `ancla` y `base`. Rocas: casi todo el ancho y el 40 % de su alto (son bloques: si la base es
## una franja, Leonidas se mete por detrás de media roca). Estatuas: el pedestal. Plantas: el
## tronco (70 % de su ancho) y 8 px de fondo. Vacío si no hay medidas.
static func opciones_pie(nombre: String, escala: float) -> Dictionary:
	var pies := leer_datos(PIES)
	if not pies.has(nombre):
		return {}
	var p: Dictionary = pies[nombre]
	var caja := Rect2(p.caja[0], p.caja[1], p.caja[2] - p.caja[0], p.caja[3] - p.caja[1])
	var ancla := Vector2(p.ancla[0], p.ancla[1])
	var base: Vector2
	if nombre.begins_with("roca_"):
		ancla.x = roundf(caja.get_center().x)
		base = Vector2(caja.size.x * escala * 0.85, maxf(caja.size.y * escala * 0.4, 8.0))
	elif nombre.begins_with("estatua_"):
		base = Vector2(maxf(float(p.ancho_pie) * escala * 0.8, 10.0), 10.0)
	else:
		base = Vector2(maxf(float(p.ancho_pie) * escala * 0.7, 8.0), 8.0)
	return {"ancla": ancla, "base": base.round()}


## Desplazamiento (px de mundo) del centro de la base de la imagen al pie, a `escala`: sumado a
## una posición pensada para el centro de la base, deja el dibujo donde estaba con `ancla`.
static func correccion_pie(nombre: String, escala: float) -> Vector2:
	var pies := leer_datos(PIES)
	if not pies.has(nombre):
		return Vector2.ZERO
	var p: Dictionary = pies[nombre]
	var ancla := opciones_pie(nombre, escala).ancla as Vector2
	return ((ancla - Vector2(float(p.tamano[0]) / 2.0, float(p.tamano[1]))) * escala).round()
