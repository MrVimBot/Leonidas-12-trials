@tool
class_name SpriteFramesBuilder
extends RefCounted
## Construye un SpriteFrames a partir del JSON + tiras PNG que genera
## tools/export_strips.lua. Usado por tools/build_sprite_frames.gd (CLI) y
## reutilizable desde un EditorScript.

const STRIPS_DIR := "res://assets/sprites/strips"
const OUT_DIR := "res://resources/sprite_frames"


## Construye todos los manifiestos que haya en STRIPS_DIR. Devuelve las rutas guardadas.
static func build_all() -> PackedStringArray:
	var saved := PackedStringArray()
	for dir_name in DirAccess.get_directories_at(STRIPS_DIR):
		var json_path := "%s/%s/%s.json" % [STRIPS_DIR, dir_name, dir_name]
		if FileAccess.file_exists(json_path):
			var out := build(json_path)
			if out != "":
				saved.append(out)
	return saved


## Lee un manifiesto y guarda resources/sprite_frames/<name>.tres. Devuelve la ruta o "".
static func build(json_path: String) -> String:
	var text := FileAccess.get_file_as_string(json_path)
	var manifest = JSON.parse_string(text)
	if typeof(manifest) != TYPE_DICTIONARY:
		push_error("JSON inválido: %s" % json_path)
		return ""

	var base_dir := json_path.get_base_dir()
	var cell_w: int = manifest.cell.w
	var cell_h: int = manifest.cell.h
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")

	var names: Array = manifest.animations.keys()
	names.sort()
	for anim_name in names:
		var a: Dictionary = manifest.animations[anim_name]
		var tex := load("%s/%s" % [base_dir, a.file]) as Texture2D
		if tex == null:
			push_error("No se pudo cargar %s/%s (¿falta importar?)" % [base_dir, a.file])
			continue

		# Solo los frames reales: el ciclo se repite cada `period` frames.
		var count: int = int(a.get("period", a.frame_count))
		var durations: Array = a.durations_ms
		var base_ms := float(durations[0])

		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, a.loop)
		frames.set_animation_speed(anim_name, 1000.0 / base_ms)
		for i in count:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * cell_w, 0, cell_w, cell_h)
			frames.add_frame(anim_name, atlas, float(durations[i]) / base_ms)

	# Datos útiles para el código del jugador (offset del sprite y espejado).
	frames.set_meta(&"origin", Vector2(manifest.origin.x, manifest.origin.y))
	frames.set_meta(&"cell_size", Vector2i(cell_w, cell_h))
	frames.set_meta(&"side_faces", manifest.side_faces)
	frames.set_meta(&"source", manifest.source)

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var out_path := "%s/%s.tres" % [OUT_DIR, manifest.name]
	# Conservar el UID del archivo anterior para no romper las escenas que lo usan.
	var uid_anterior := ResourceLoader.get_resource_uid(out_path) if FileAccess.file_exists(out_path) else ResourceUID.INVALID_ID
	var err := ResourceSaver.save(frames, out_path)
	if err != OK:
		push_error("No se pudo guardar %s (error %d)" % [out_path, err])
		return ""
	if uid_anterior != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(out_path, uid_anterior)
	var warnings: Array = manifest.get("warnings", [])
	for w in warnings:
		push_warning("%s: %s" % [manifest.name, w])
	print("[sprite_frames] %s: %d animaciones -> %s" % [manifest.name, names.size(), out_path])
	return out_path
