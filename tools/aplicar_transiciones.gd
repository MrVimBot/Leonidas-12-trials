extends SceneTree
## CLI: godot --headless --path . --script res://tools/aplicar_transiciones.gd -- pueblo [otra...]
## Aplica las transiciones (scripts/entorno/transiciones.gd) al "Suelo" de zonas que NO se
## regeneran (pueblo, retocado a mano). Solo reescribe la línea `tile_map_data` del nodo
## Suelo en el .tscn: el resto de la escena (nodos, instancias con Editable Children,
## UID) queda tal cual. Es lo mismo que el botón "Aplicar transiciones" del nodo
## AutoTransiciones, pero con el editor CERRADO (si está abierto con la escena, al guardar
## la pisaría: recargarla sin guardar).
## Usa la `semilla` del nodo AutoTransiciones de la escena si lo tiene (si no, 1).

const Transiciones := preload("res://scripts/entorno/transiciones.gd")


func _initialize() -> void:
	var ok := true
	for nombre in OS.get_cmdline_user_args():
		ok = _aplicar("res://scenes/levels/%s.tscn" % nombre) and ok
	quit(0 if ok else 1)


func _aplicar(ruta: String) -> bool:
	var escena := load(ruta) as PackedScene
	if escena == null:
		push_error("No se pudo cargar %s" % ruta)
		return false
	var raiz := escena.instantiate()
	var suelo := raiz.get_node_or_null("Suelo") as TileMapLayer
	if suelo == null:
		push_error("%s no tiene nodo Suelo" % ruta)
		raiz.free()
		return false
	var semilla := 1
	var auto := raiz.get_node_or_null("AutoTransiciones")
	if auto:
		semilla = auto.get("semilla")
	for aviso in Transiciones.aplicar(suelo, semilla):
		push_warning("[%s] %s" % [ruta.get_file(), aviso])
	var datos := Marshalls.raw_to_base64(suelo.tile_map_data)
	raiz.free()

	var texto := FileAccess.get_file_as_string(ruta)
	var re := RegEx.new()
	# Bloque del nodo Suelo (hijo directo de la raíz) hasta el siguiente [node ...].
	re.compile('(\\[node name="Suelo" type="TileMapLayer" parent="\\."[^\\]]*\\]\\n(?:(?!\\[node).*\\n)*?tile_map_data = PackedByteArray\\(")[^"]*("\\))')
	var m := re.search(texto)
	if m == null:
		push_error("%s: no encuentro tile_map_data del Suelo" % ruta)
		return false
	texto = texto.substr(0, m.get_start()) + m.get_string(1) + datos + m.get_string(2) + texto.substr(m.get_end())
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	f.store_string(texto)
	f.close()
	print("[aplicar_transiciones] %s actualizado" % ruta)
	return true
