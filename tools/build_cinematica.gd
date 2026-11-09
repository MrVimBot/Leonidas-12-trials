extends SceneTree
## CLI: godot --headless --path . --script res://tools/build_cinematica.gd
## Construye los SpriteFrames de la cinemática inicial a partir de las tiras PNG de
## assets/sprites/cinematica/ (las exporta tools/export_sprites.sh):
##   resources/sprite_frames/cinematica_cama.tres  (Leonidas en la cama, celda 38×47)
##   resources/sprite_frames/cinematica_mama.tres  (Kathita, celda 50×50)
## Cada cuadro se coloca en una celda común alineado ABAJO (los pies / la base de la
## cama), así la posición del nodo es la base: usar `offset = (0, -alto/2)`.

const DIR := "res://assets/sprites/cinematica"
const OUT := "res://resources/sprite_frames"

## nombre -> {celda, animaciones: {anim -> {tira, cuadros, paso, ancho, dx, fps, loop}}}
## dx = desplazamiento horizontal dentro de la celda (para que el cuerpo no salte al
## cambiar de animación).
const HOJAS := {
	"cinematica_cama": {
		"celda": Vector2i(38, 47),
		"animaciones": {
			"dormido": {"tira": "leonidas_dormido", "cuadros": 10, "paso": 38, "fps": 5, "loop": true},
			"despertar": {"tira": "leonidas_sorprendido_2", "cuadros": 10, "paso": 41, "ancho": 36, "dx": 1, "fps": 8, "loop": false},
			"despierto": {"tira": "leonidas_termina_de_leer", "cuadros": 10, "paso": 38, "fps": 5, "loop": true},
		},
	},
	"cinematica_mama": {
		"celda": Vector2i(50, 50),
		"animaciones": {
			"caminar_regalo": {"tira": "mama_caminando_con_regalo", "cuadros": 8, "paso": 50, "fps": 10, "loop": true},
			"parada_regalo": {"tira": "mama_parada", "cuadros": 1, "paso": 36, "dx": 6, "fps": 1, "loop": false},
			"dar_regalo": {"tira": "dar_regalo", "cuadros": 8, "paso": 50, "fps": 8, "loop": false},
			"parada": {"tira": "parada_sin_nada", "cuadros": 1, "paso": 31, "dx": 11, "fps": 1, "loop": false},
			"caminar": {"tira": "caminar_sin_nada", "cuadros": 8, "paso": 42, "dx": 4, "fps": 10, "loop": true},
		},
	},
}


func _init() -> void:
	var ok := true
	for nombre in HOJAS:
		ok = _construir(nombre, HOJAS[nombre]) and ok
	quit(0 if ok else 1)


func _construir(nombre: String, hoja: Dictionary) -> bool:
	var celda: Vector2i = hoja.celda
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in hoja.animaciones:
		var a: Dictionary = hoja.animaciones[anim]
		var tex := load("%s/%s.png" % [DIR, a.tira]) as Texture2D
		if tex == null:
			push_error("No se pudo cargar %s/%s.png (¿falta importar?)" % [DIR, a.tira])
			return false
		var ancho: int = a.get("ancho", a.paso)
		var alto := tex.get_height()
		var dx: int = a.get("dx", (celda.x - ancho) / 2)
		frames.add_animation(anim)
		frames.set_animation_loop(anim, a.loop)
		frames.set_animation_speed(anim, a.fps)
		for i in int(a.cuadros):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * int(a.paso), 0, ancho, alto)
			at.margin = Rect2(dx, celda.y - alto, celda.x - ancho, celda.y - alto)
			frames.add_frame(anim, at)
	frames.set_meta(&"cell_size", celda)

	DirAccess.make_dir_recursive_absolute(OUT)
	var ruta := "%s/%s.tres" % [OUT, nombre]
	var uid := ResourceLoader.get_resource_uid(ruta) if FileAccess.file_exists(ruta) else ResourceUID.INVALID_ID
	if ResourceSaver.save(frames, ruta) != OK:
		push_error("No se pudo guardar %s" % ruta)
		return false
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(ruta, uid)
	print("[cinematica] %s: %d animaciones -> %s" % [nombre, hoja.animaciones.size(), ruta])
	return true
