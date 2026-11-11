extends SceneTree
## CLI: godot --headless --path . --script res://tools/build_arte_provisional.gd
## Genera el arte PROVISIONAL de las zonas nuevas (mientras la artista no entregue el
## definitivo):
##   - assets/tilesets/tiles_provisional.png: 9 tiles de 16×16 sin separación (cueva,
##     mar navegable, losa del jefe, muelle, arrecife). El TileSet lo hace build_tilesets.gd.
##   - assets/sprites/entorno/provisional/*.png: palmeras y rocas de mar reducidas desde
##     las ilustraciones grandes de assets/sprites/environment/, y la boca de la cueva.
## Después: godot --headless --path . --import

const TILES := "res://assets/tilesets/tiles_provisional.png"
const DIR_SPRITES := "res://assets/sprites/entorno/provisional/"
const DIR_ORIGEN := "res://assets/sprites/environment/"

# [archivo de origen, archivo final, ancho, alto]
const REDUCIR := [
	["palmera", "palmera", 56, 70],
	["mini_palmera", "mini_palmera", 40, 38],
	["roca_1", "roca_mar_1", 48, 32],
	["roca_2", "roca_mar_2", 56, 31],
	["roca_3", "roca_mar_3", 44, 31],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_SPRITES))
	var ok := _tiles()
	for r in REDUCIR:
		ok = _reducir(r[0], r[1], r[2], r[3]) and ok
	ok = _entrada_cueva() and ok
	ok = _recolorear("roca", "roca_cueva", PALETA_CUEVA) and ok
	quit(0 if ok else 1)


# --- Recoloreados ----------------------------------------------------------------

## Roca de la artista con la paleta de la cueva: sin la hierba ni la sombra verdosa del
## pasto (no pegan con el suelo #4a4458). Color original → color nuevo (exactos).
const PALETA_CUEVA := {
	"cbdbfc": "9a92a8", # luz
	"a7bbe5": "8a839c", # luz media
	"b0aeed": "7d7590", # medio
	"8467c6": "5e566e", # sombra de la roca
	"3d1695": "2a2438", # contorno
	"106165": "3b3648", # sombra en el suelo
	"5fb93b": "5e566e", # hierba clara → sombra de la roca
	"30914c": "3b3648", # hierba oscura → sombra en el suelo
}


func _recolorear(origen: String, destino: String, paleta: Dictionary) -> bool:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/entorno/" + origen + ".png"))
	if img == null or img.is_empty():
		push_error("No se pudo cargar %s" % origen)
		return false
	img.convert(Image.FORMAT_RGBA8)
	var mapa := {}
	for k in paleta:
		mapa[Color(k).to_html(false)] = Color(paleta[k])
	var sin_cambiar := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var clave := c.to_html(false)
			if mapa.has(clave):
				img.set_pixel(x, y, mapa[clave])
			else:
				sin_cambiar += 1
	if sin_cambiar > 0:
		push_warning("%s: %d píxeles con colores fuera de la paleta" % [origen, sin_cambiar])
	return _guardar(img, DIR_SPRITES + destino + ".png")


# --- Tiles ---------------------------------------------------------------------

func _tiles() -> bool:
	var img := Image.create_empty(16 * 9, 16, false, Image.FORMAT_RGBA8)
	# 0 SUELO_CUEVA
	_relleno(img, 0, Color("#4a4458"))
	# 1 SUELO_CUEVA_B: con píxeles sueltos más oscuros
	_relleno(img, 1, Color("#4a4458"))
	for p in [Vector2i(3, 2), Vector2i(11, 4), Vector2i(6, 9), Vector2i(13, 12), Vector2i(2, 13)]:
		_px(img, 1, p, Color("#3b3648"))
	# 2 PARED_CUEVA: con una línea superior más clara
	_relleno(img, 2, Color("#2a2438"))
	for y in 2:
		for x in 16:
			_px(img, 2, Vector2i(x, y), Color("#3d3550"))
	# 3 VACIO
	_relleno(img, 3, Color("#0b0a12"))
	# 4 MAR_NAV
	_relleno(img, 4, Color("#3f8fa8"))
	# 5 MAR_NAV_OLA: dos rayas cortas
	_relleno(img, 5, Color("#3f8fa8"))
	for x in range(2, 7):
		_px(img, 5, Vector2i(x, 4), Color("#7cc4d0"))
	for x in range(9, 14):
		_px(img, 5, Vector2i(x, 11), Color("#7cc4d0"))
	# 6 LOSA_JEFE: con borde
	_relleno(img, 6, Color("#6a5f78"))
	for i in 16:
		for p in [Vector2i(i, 0), Vector2i(i, 15), Vector2i(0, i), Vector2i(15, i)]:
			_px(img, 6, p, Color("#574d65"))
	# 7 MUELLE: tablas de madera
	_relleno(img, 7, Color("#8a5a32"))
	for y in range(3, 16, 4):
		for x in 16:
			_px(img, 7, Vector2i(x, y), Color("#6b4425"))
	# 8 ARRECIFE
	_relleno(img, 8, Color("#1f5f78"))
	for p in [Vector2i(4, 3), Vector2i(11, 7), Vector2i(6, 12)]:
		_px(img, 8, p, Color("#2f7f98"))
	return _guardar(img, TILES)


func _relleno(img: Image, col: int, color: Color) -> void:
	img.fill_rect(Rect2i(col * 16, 0, 16, 16), color)


func _px(img: Image, col: int, p: Vector2i, color: Color) -> void:
	img.set_pixel(col * 16 + p.x, p.y, color)


# --- Sprites reducidos --------------------------------------------------------

## Reduce una ilustración grande a pixel art: premultiplica el alfa (para que el color
## de los píxeles transparentes no deje halo), baja a la mitad hasta quedar cerca del
## tamaño final, termina con Lanczos y aplica un umbral de alfa (bordes duros).
func _reducir(origen: String, destino: String, ancho: int, alto: int) -> bool:
	var img := Image.load_from_file(ProjectSettings.globalize_path(DIR_ORIGEN + origen + ".png"))
	if img == null or img.is_empty():
		push_error("No se pudo cargar %s" % origen)
		return false
	img.convert(Image.FORMAT_RGBA8)
	img.premultiply_alpha()
	while img.get_width() >= ancho * 4 and img.get_height() >= alto * 4:
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	img.resize(ancho, alto, Image.INTERPOLATE_LANCZOS)
	for y in alto:
		for x in ancho:
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				img.set_pixel(x, y, Color(clampf(c.r / c.a, 0, 1), clampf(c.g / c.a, 0, 1), clampf(c.b / c.a, 0, 1), 1.0))
	return _guardar(img, DIR_SPRITES + destino + ".png")


## Boca de la cueva: montículo (media elipse apoyada abajo) con sombra en el tercio
## inferior y un arco negro de 24×30 centrado abajo.
func _entrada_cueva() -> bool:
	const W := 64
	const H := 56
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var cx := (W - 1) / 2.0
	for y in H:
		for x in W:
			var dx := (x - cx) / (W / 2.0)
			var dy := (H - 0.5 - y) / float(H)
			if dx * dx + dy * dy > 1.0:
				continue
			img.set_pixel(x, y, Color("#514a42") if y >= H * 2 / 3 else Color("#6b6257"))
	# Arco: rectángulo de 24 de ancho con la parte de arriba redondeada (radio 12).
	for y in range(H - 30, H):
		for x in range(W / 2 - 12, W / 2 + 12):
			var arriba := H - 30 + 12
			if y < arriba:
				var ddx := x + 0.5 - W / 2.0
				var ddy := y + 0.5 - arriba
				if ddx * ddx + ddy * ddy > 144.0:
					continue
			img.set_pixel(x, y, Color("#0b0a12"))
	return _guardar(img, DIR_SPRITES + "entrada_cueva.png")


func _guardar(img: Image, ruta: String) -> bool:
	var err := img.save_png(ProjectSettings.globalize_path(ruta))
	if err != OK:
		push_error("No se pudo guardar %s (error %d)" % [ruta, err])
		return false
	print("[arte provisional] %s (%d×%d)" % [ruta, img.get_width(), img.get_height()])
	return true
