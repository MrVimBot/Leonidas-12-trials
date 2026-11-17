extends SceneTree
## Construye resources/sprite_frames/<personaje>.tres a partir de las hojas y el manifiesto que
## genera tools/pintados/normalizar.gd (assets/sprites/pintados/<personaje>/). Las hojas tienen
## que estar ya importadas (tools/pintados/normalizar.sh lo hace todo en orden).
##
##   godot --headless --path . --script res://tools/pintados/construir_sprite_frames.gd [-- medusa]
##
## Cada fotograma es un AtlasTexture: `region` = su celda en la hoja y `margin` = lo que falta
## hasta el lienzo común del personaje. Así todos los fotogramas miden lo mismo y el ancla cae
## siempre en el mismo punto (como hacen los empaquetadores de texturas con "trim").
##
## Metadatos del SpriteFrames (los usa quien monte la escena; ver docs/design/arte_pintado.md):
##   offset     -> AnimatedSprite2D.offset (centered = true) para que la posición del nodo sea el ancla
##   escala     -> AnimatedSprite2D.scale (1 / densidad)
##   densidad, lienzo, ancla, mira, alto_mundo

const SALIDA := "res://resources/sprite_frames"
const PINTADOS := "res://assets/sprites/pintados"


func _init() -> void:
	var pedidos := OS.get_cmdline_user_args()
	var nombres: Array = pedidos if not pedidos.is_empty() else Array(DirAccess.get_directories_at(PINTADOS))
	var ok := true
	for nombre in nombres:
		ok = _construir(nombre) and ok
	quit(0 if ok else 1)


func _construir(nombre: String) -> bool:
	var ruta_json := PINTADOS.path_join(nombre).path_join("%s.json" % nombre)
	var m = JSON.parse_string(FileAccess.get_file_as_string(ruta_json))
	if typeof(m) != TYPE_DICTIONARY:
		push_error("Manifiesto inválido o ausente: %s" % ruta_json)
		return false
	var lienzo := Vector2(m.lienzo.w, m.lienzo.h)
	var ancla := Vector2(m.ancla.x, m.ancla.y)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")

	var nombres_anim: Array = m.animaciones.keys()
	nombres_anim.sort()
	for anim in nombres_anim:
		var a: Dictionary = m.animaciones[anim]
		var hoja := load(PINTADOS.path_join(nombre).path_join(a.archivo)) as Texture2D
		if hoja == null:
			push_error("No se pudo cargar la hoja %s/%s (¿falta importar?)" % [nombre, a.archivo])
			return false
		var celda := Rect2(a.celda.x, a.celda.y, a.celda.w, a.celda.h)
		var paso := celda.size + Vector2(a.separacion, a.separacion)
		var columnas := int(a.columnas)
		frames.add_animation(anim)
		frames.set_animation_loop(anim, a.loop)
		frames.set_animation_speed(anim, float(a.fps))
		for i in int(a.cuadros):
			var t := AtlasTexture.new()
			t.atlas = hoja
			t.region = Rect2(Vector2(i % columnas, i / columnas) * paso, celda.size)
			t.margin = Rect2(celda.position, lienzo - celda.size)
			t.filter_clip = true
			frames.add_frame(anim, t)

	var densidad := float(m.densidad)
	frames.set_meta(&"offset", Vector2(0.0, lienzo.y / 2.0 - ancla.y))
	frames.set_meta(&"escala", Vector2.ONE / densidad)
	frames.set_meta(&"densidad", densidad)
	frames.set_meta(&"lienzo", lienzo)
	frames.set_meta(&"ancla", ancla)
	frames.set_meta(&"mira", m.mira)
	frames.set_meta(&"alto_mundo", m.alto_mundo)

	var salida := SALIDA.path_join("%s.tres" % nombre)
	var uid_anterior := ResourceLoader.get_resource_uid(salida) if FileAccess.file_exists(salida) else ResourceUID.INVALID_ID
	var err := ResourceSaver.save(frames, salida)
	if err != OK:
		push_error("No se pudo guardar %s (%d)" % [salida, err])
		return false
	if uid_anterior != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(salida, uid_anterior)
	print("[pintados] %s: %d animaciones -> %s (offset %s, escala %s)" % [
		nombre, nombres_anim.size(), salida, frames.get_meta(&"offset"), frames.get_meta(&"escala")])
	return true
