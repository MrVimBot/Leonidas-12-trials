extends SceneTree
## Lanzador de pruebas: `godot --headless --path . --script res://tools/pruebas/lanzar.gd -- <prueba>`
##
## `<prueba>` es la ruta de la prueba (`res://tools/pruebas/prueba_estado.gd`) o solo su nombre
## (`prueba_estado` / `prueba_estado.gd`). Los argumentos que sigan a la prueba se los queda ella
## (`OS.get_cmdline_user_args()`, el primero es la propia prueba).
##
## Por qué la prueba va como nodo y no como `--script` directo: un script pasado con `--script`
## se compila antes de que existan los autoload (EstadoJuego, Dialogos, Libro…), y las pruebas
## los usan por nombre. Aquí solo se la añade al árbol, cuando ya están registrados.
## Código de salida: el de la prueba (0 = todo pasa); 2 si no se encuentra o no compila.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Uso: lanzar.gd -- <prueba>")
		quit(2)
		return
	var ruta := args[0]
	if not ruta.begins_with("res://"):
		ruta = "res://tools/pruebas/" + ruta
	if not ruta.ends_with(".gd"):
		ruta += ".gd"
	var script := load(ruta) as GDScript
	if script == null or not script.can_instantiate():
		printerr("RESULTADO: no se puede cargar la prueba %s" % ruta)
		quit(2)
		return
	var nodo := Node.new()
	nodo.set_script(script)
	root.add_child.call_deferred(nodo)
