extends SceneTree
## CLI: godot --headless --path . --script res://tools/build_icono_coco.gd
## Genera los iconos PROVISIONALES del coco (objeto `coco`, nivel 2) reduciendo el dibujo pintado
## de la artista (assets/sprites/entorno/nivel2/coco.png, 1752×1469): uno de 16 px de ancho para
## el libro y otro de 10 px (`Objeto.icono_pequeno`: en la mano al comer). Borde duro (alfa 0 o 1)
## para que case con los demás iconos de pixel art. Sustituir por iconos de la artista.
## Después: godot --headless --path . --import

const ORIGEN := "res://assets/sprites/entorno/nivel2/coco.png"
const DESTINOS := {
	"res://assets/ui/provisional/icono_coco.png": 16,
	"res://assets/ui/provisional/icono_coco_pequeno.png": 10,
}


func _init() -> void:
	var original := Image.load_from_file(ProjectSettings.globalize_path(ORIGEN))
	if original == null:
		push_error("No se pudo leer %s" % ORIGEN)
		quit(1)
		return
	original.convert(Image.FORMAT_RGBA8)
	var err := OK
	for destino: String in DESTINOS:
		var ancho: int = DESTINOS[destino]
		var img := original.duplicate() as Image
		img.resize(ancho, maxi(roundi(ancho * float(img.get_height()) / img.get_width()), 1), Image.INTERPOLATE_LANCZOS)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				c.a = 1.0 if c.a >= 0.5 else 0.0
				img.set_pixel(x, y, c)
		err = img.save_png(ProjectSettings.globalize_path(destino))
		if err != OK:
			push_error("No se pudo guardar %s (%d)" % [destino, err])
			break
		print("Icono: ", destino, " ", img.get_size())
	quit(err)
