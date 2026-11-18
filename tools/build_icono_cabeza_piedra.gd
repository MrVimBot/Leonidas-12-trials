extends SceneTree
## CLI: godot --headless --path . --script res://tools/build_icono_cabeza_piedra.gd
## Genera el icono PROVISIONAL de la cabeza de piedra de Medusa (objeto `cabeza_piedra`, plan
## docs/plan/nivel2/06_medusa_jefe.md, M5): la cabeza del primer fotograma de `parado` de
## Medusa, reducida a 16×16, en grises de piedra y con el borde duro (como el pixel art de los
## demás iconos). Sustituir por el icono de la artista cuando lo entregue.
## Después: godot --headless --path . --import

const ORIGEN := "res://assets/sprites/pintados/medusa/parado.png"
const DESTINO := "res://assets/ui/provisional/icono_cabeza_piedra.png"
## Recorte de la cabeza (con las serpientes) en el primer fotograma de la hoja (128×196).
const RECORTE := Rect2i(30, 0, 68, 68)
const TAMANO := 16
## Gris de piedra: oscuro → claro (se reparte la luminancia entre los dos).
const PIEDRA_OSCURA := Color(0.29, 0.29, 0.33)
const PIEDRA_CLARA := Color(0.82, 0.8, 0.76)


func _init() -> void:
	var hoja := Image.load_from_file(ProjectSettings.globalize_path(ORIGEN))
	if hoja == null:
		push_error("No se pudo leer %s" % ORIGEN)
		quit(1)
		return
	hoja.convert(Image.FORMAT_RGBA8)
	var cabeza := hoja.get_region(RECORTE)
	cabeza.resize(TAMANO, TAMANO, Image.INTERPOLATE_LANCZOS)
	for y in TAMANO:
		for x in TAMANO:
			var c := cabeza.get_pixel(x, y)
			if c.a < 0.5:
				cabeza.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# Luminancia con un poco de contraste, cuantizada a 4 tonos (aspecto pixel art).
			var l := clampf((c.get_luminance() - 0.5) * 1.4 + 0.55, 0.0, 1.0)
			l = roundf(l * 3.0) / 3.0
			cabeza.set_pixel(x, y, PIEDRA_OSCURA.lerp(PIEDRA_CLARA, l))
	var err := cabeza.save_png(ProjectSettings.globalize_path(DESTINO))
	if err != OK:
		push_error("No se pudo guardar %s (%d)" % [DESTINO, err])
	print("Icono: ", DESTINO)
	quit(err)
