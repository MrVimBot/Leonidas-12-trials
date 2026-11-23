extends SceneTree
## Normaliza los fotogramas pintados del nivel 2 (fuente/nivel2/, 1280×720 sueltos) para el juego:
## recorta, escala a la DENSIDAD de tools/pintados/personajes.gd y empaqueta cada animación en
## una hoja (rejilla) + un manifiesto JSON en assets/sprites/pintados/<personaje>/.
##
##   godot --headless --path . --script res://tools/pintados/normalizar.gd            # todos
##   godot --headless --path . --script res://tools/pintados/normalizar.gd -- medusa  # uno
##
## Mejor usar tools/pintados/normalizar.sh, que además importa y construye los SpriteFrames.
##
## Cómo se garantiza que no "salta" entre animaciones: todas las animaciones de un personaje se
## recortan con el MISMO lienzo (la unión de todos sus fotogramas, simétrica alrededor del ancla)
## y la misma escala. Después cada animación se recorta a lo que usa (`celda`) y el SpriteFrames
## devuelve el resto con `AtlasTexture.margin`, así cada fotograma vuelve a medir el lienzo entero.
##
## El escalado se hace con el alfa premultiplicado: los píxeles transparentes de los renders son
## negros y, sin premultiplicar, Lanczos oscurecería los bordes (halo negro).

const P := preload("res://tools/pintados/personajes.gd")

## Las entradas de personajes.gd dan la carpeta relativa a esta (nivel2/gamba, nivel3/minotauro…).
const FUENTE := "res://fuente"
const SALIDA := "res://assets/sprites/pintados"
## Margen (px de la fuente) alrededor de la unión de fotogramas.
const MARGEN := 4
## Separación transparente entre celdas de la hoja (texels): evita que el filtro lineal y los
## mipmaps mezclen un fotograma con el vecino.
const SEPARACION := 2
## Ancho máximo de una hoja (límite seguro de textura en la web).
const ANCHO_MAX := 4096


func _init() -> void:
	var pedidos := OS.get_cmdline_user_args()
	var nombres: Array = pedidos if not pedidos.is_empty() else P.PERSONAJES.keys()
	var ok := true
	for nombre in nombres:
		if not P.PERSONAJES.has(nombre):
			push_error("No existe '%s' en tools/pintados/personajes.gd" % nombre)
			ok = false
			continue
		ok = _normalizar(nombre, P.PERSONAJES[nombre]) and ok
	quit(0 if ok else 1)


func _fotogramas(carpeta: String) -> PackedStringArray:
	var archivos := PackedStringArray()
	for f in DirAccess.get_files_at(carpeta):
		if f.get_extension().to_lower() == "png":
			archivos.append(carpeta.path_join(f))
	archivos.sort()
	return archivos


func _normalizar(nombre: String, cfg: Dictionary) -> bool:
	var base := FUENTE.path_join(cfg.fuente)
	if not DirAccess.dir_exists_absolute(base):
		push_error("Falta %s: copiar la entrega con tools/pintados/copiar_fuente.sh" % base)
		return false

	# 1) Unión de lo dibujado (px de la fuente), total y de `parado`.
	var listas := {}
	var union := Rect2i()
	var union_parado := Rect2i()
	var tam_fuente := Vector2i.ZERO
	for anim in cfg.animaciones:
		var archivos := _fotogramas(base.path_join(cfg.animaciones[anim].carpeta))
		if archivos.is_empty():
			push_error("%s/%s: sin fotogramas" % [nombre, anim])
			return false
		listas[anim] = archivos
		for f in archivos:
			var img := Image.load_from_file(f)
			tam_fuente = img.get_size()
			var usado := img.get_used_rect()
			if usado.size == Vector2i.ZERO:
				push_warning("%s: fotograma vacío" % f)
				continue
			union = usado if union.size == Vector2i.ZERO else union.merge(usado)
			if anim == &"parado" or anim == "parado":
				union_parado = usado if union_parado.size == Vector2i.ZERO else union_parado.merge(usado)
	if union_parado.size == Vector2i.ZERO:
		push_error("%s: hace falta una animación 'parado' (fija la escala)" % nombre)
		return false

	# 2) Lienzo común simétrico alrededor del ancla (para que flip_h espeje sobre el ancla).
	var ancla: Vector2 = cfg.ancla
	var ax := int(round(ancla.x))
	var mitad := maxi(ax - union.position.x, union.end.x - ax) + MARGEN
	var arriba := mini(union.position.y, int(ancla.y)) - MARGEN
	var abajo := maxi(union.end.y, int(ancla.y)) + MARGEN
	var lienzo := Rect2i(ax - mitad, arriba, mitad * 2, abajo - arriba)

	var escala: float = float(cfg.alto * P.DENSIDAD) / union_parado.size.y
	var ancho_t := int(round(lienzo.size.x * escala / 2.0)) * 2  # par: el ancla queda en el centro
	var alto_t := int(round(lienzo.size.y * escala))
	var ancla_t := Vector2i(ancho_t / 2, int(round((ancla.y - lienzo.position.y) * escala)))

	var dir_salida := SALIDA.path_join(nombre)
	DirAccess.make_dir_recursive_absolute(dir_salida)
	var manifiesto := {
		"nombre": nombre,
		"fuente": base,
		"densidad": P.DENSIDAD,
		"alto_mundo": cfg.alto,
		"mira": cfg.mira,
		"lienzo": {"w": ancho_t, "h": alto_t},
		"ancla": {"x": ancla_t.x, "y": ancla_t.y},
		"animaciones": {},
	}
	var memoria := 0

	# 3) Cada animación: escalar con el mismo lienzo, recortar a lo usado y empaquetar.
	var origen_valido := Rect2i(Vector2i.ZERO, tam_fuente)
	for anim in cfg.animaciones:
		var a: Dictionary = cfg.animaciones[anim]
		var cuadros: Array[Image] = []
		var usado_anim := Rect2i()
		for f in listas[anim]:
			var src := Image.load_from_file(f)
			src.convert(Image.FORMAT_RGBA8)
			var img := Image.create_empty(lienzo.size.x, lienzo.size.y, false, Image.FORMAT_RGBA8)
			var trozo := lienzo.intersection(origen_valido)
			img.blit_rect(src, trozo, trozo.position - lienzo.position)
			img.premultiply_alpha()
			img.resize(ancho_t, alto_t, Image.INTERPOLATE_LANCZOS)
			_despremultiplicar(img)
			cuadros.append(img)
			var u := img.get_used_rect()
			if u.size != Vector2i.ZERO:
				usado_anim = u if usado_anim.size == Vector2i.ZERO else usado_anim.merge(u)

		var celda := usado_anim
		var paso := celda.size + Vector2i(SEPARACION, SEPARACION)
		var n := cuadros.size()
		var columnas := clampi(int(ceil(sqrt(float(n) * paso.y / paso.x))), 1, n)
		columnas = mini(columnas, maxi(1, ANCHO_MAX / paso.x))
		var filas := int(ceil(float(n) / columnas))
		var hoja := Image.create_empty(columnas * paso.x, filas * paso.y, false, Image.FORMAT_RGBA8)
		for i in n:
			hoja.blit_rect(cuadros[i], celda, Vector2i(i % columnas, i / columnas) * paso)
		var archivo := "%s.png" % anim
		var err := hoja.save_png(dir_salida.path_join(archivo))
		if err != OK:
			push_error("No se pudo guardar %s/%s (%d)" % [dir_salida, archivo, err])
			return false
		memoria += hoja.get_width() * hoja.get_height() * 4
		manifiesto.animaciones[anim] = {
			"archivo": archivo,
			"cuadros": n,
			"columnas": columnas,
			"separacion": SEPARACION,
			# Posición y tamaño de la celda dentro del lienzo (texels).
			"celda": {"x": celda.position.x, "y": celda.position.y, "w": celda.size.x, "h": celda.size.y},
			"fps": a.get("fps", P.FPS),
			"loop": a.loop,
		}

	var json := FileAccess.open(dir_salida.path_join("%s.json" % nombre), FileAccess.WRITE)
	json.store_string(JSON.stringify(manifiesto, "\t"))
	print("[pintados] %s: lienzo %d×%d texels (%d×%d px de mundo), ancla %s, %d animaciones, ~%.1f MB de VRAM (sin mipmaps)" % [
		nombre, ancho_t, alto_t, ancho_t / P.DENSIDAD, alto_t / P.DENSIDAD, ancla_t,
		cfg.animaciones.size(), memoria / 1048576.0])
	return true


## Inverso de `Image.premultiply_alpha()` (Godot no lo trae).
func _despremultiplicar(img: Image) -> void:
	var datos := img.get_data()
	for i in range(0, datos.size(), 4):
		var alfa := datos[i + 3]
		if alfa == 0:
			datos[i] = 0
			datos[i + 1] = 0
			datos[i + 2] = 0
		elif alfa < 255:
			datos[i] = mini(255, int(round(datos[i] * 255.0 / alfa)))
			datos[i + 1] = mini(255, int(round(datos[i + 1] * 255.0 / alfa)))
			datos[i + 2] = mini(255, int(round(datos[i + 2] * 255.0 / alfa)))
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, datos)
