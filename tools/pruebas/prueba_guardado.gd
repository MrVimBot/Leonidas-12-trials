extends "res://tools/pruebas/base_prueba.gd"
## Guardado y carga (EstadoJuego.guardar/cargar + Game + libro). Siempre sobre la partida
## temporal de las pruebas:
##  a) partida de ejemplo versionada (`datos/partida_ejemplo.cfg`, formato real) → cargar;
##  b) la misma sin `posicion` (partida antigua) → posición no finita;
##  c) ida y vuelta de TODO el progreso (`EstadoJuego.PROGRESO` + monedas, objetos, misiones, lugar);
##  d) Game arranca en la zona/posición/vida cargadas;
##  e) guardar desde el libro (página Guardar) escribe los datos.

const EJEMPLO := "res://tools/pruebas/datos/partida_ejemplo.cfg"


## Escribe en la partida temporal el ejemplo, opcionalmente sin la línea `posicion=`.
func _copiar_ejemplo(sin_posicion: bool = false) -> void:
	var lineas := FileAccess.get_file_as_string(EJEMPLO).split("\n")
	var salida: PackedStringArray = []
	for l in lineas:
		if not (sin_posicion and l.begins_with("posicion=")):
			salida.append(l)
	var f := FileAccess.open(RUTA_PARTIDA_PRUEBA, FileAccess.WRITE)
	f.store_string("\n".join(salida))
	f.close()


func ejecutar() -> void:
	var E := EstadoJuego
	var restablecidos := [0]
	E.estado_restablecido.connect(func() -> void: restablecidos[0] += 1)

	# a) partida de ejemplo
	_copiar_ejemplo()
	ok("a) hay_partida", E.hay_partida())
	ok("a) cargar", E.cargar())
	ok("a) cargar emite estado_restablecido una vez", restablecidos[0] == 1, str(restablecidos[0]))
	ok("a) monedas", E.monedas == 5)
	ok("a) objetos exactos", E.objetos == {&"espada": 1, &"libro": 1, &"manzana": 2}, str(E.objetos))
	ok("a) misiones", E.misiones.size() == 2
		and E.misiones.get(&"derrotar_medusa") == E.EstadoMision.ACTIVA
		and E.misiones.get(&"ir_al_templo") == E.EstadoMision.COMPLETADA, str(E.misiones))
	ok("a) banderas", E.mision_recibida and E.voltereta_aprendida and not E.tutorial_barco_visto
		and E.avisos_zeus == 0 and E.jefes_derrotados == 0
		and E.corazones_extra == 0 and not E.medusa_derrotada and not E.minotauro_derrotado) # banderas posteriores al archivo: su valor inicial
	ok("a) tiempo jugado", is_equal_approx(E.tiempo_jugado, 1.5057729595959584))
	var l := E.lugar_cargado
	ok("a) lugar", l != null and l.zona == "res://scenes/levels/bosque.tscn" and l.entrada == "desde_pueblo"
		and l.posicion == Vector2(512, 40) and l.vida == 12)

	# b) partida antigua sin posición
	_copiar_ejemplo(true)
	ok("b) cargar sin posición", E.cargar())
	ok("b) posición no finita y entrada conservada", E.lugar_cargado != null
		and not E.lugar_cargado.posicion.is_finite() and E.lugar_cargado.entrada == "desde_pueblo")

	# c) ida y vuelta: cada campo de PROGRESO con un valor distinto del inicial
	E.reiniciar()
	E.monedas = 77
	E.agregar_objeto(&"manzana", 4)
	E.tiene_libro = true
	E.empezar_mision(E.MISION_DERROTAR_MEDUSA)
	E.completar_mision(E.MISION_IR_AL_TEMPLO)
	E.tutorial_barco_visto = true
	E.mision_recibida = true
	E.voltereta_aprendida = true
	E.avisos_zeus = 7
	E.tiempo_jugado = 1234.5
	E.jefes_derrotados = 2
	E.corazones_extra = 1
	E.medusa_derrotada = true
	E.minotauro_derrotado = true
	var lg := DatosLugar.new()
	lg.zona = "res://scenes/levels/playa.tscn"
	lg.entrada = "desde_bosque"
	lg.posicion = Vector2(10, 20)
	lg.vida = 5
	ok("c) guardar", E.guardar(lg))
	var antes := {}
	for k: String in E.PROGRESO:
		antes[k] = E.get(k)
		ok("c) (precondición) %s distinto del inicial" % k, antes[k] != E.PROGRESO[k])
	var objetos_antes := E.objetos.duplicate()
	var misiones_antes := E.misiones.duplicate()
	E.reiniciar()
	ok("c) reiniciar limpia", E.monedas == 0 and E.objetos.is_empty() and E.misiones.is_empty() and E.lugar_cargado == null)
	for k: String in E.PROGRESO:
		ok("c) reiniciado %s" % k, E.get(k) == E.PROGRESO[k])
	ok("c) recargar", E.cargar())
	for k: String in E.PROGRESO:
		ok("c) vuelta %s" % k, E.get(k) == antes[k], str(E.get(k)))
	ok("c) monedas, objetos y misiones", E.monedas == 77 and E.objetos == objetos_antes and E.misiones == misiones_antes)
	ok("c) lugar", E.lugar_cargado.zona == lg.zona and E.lugar_cargado.entrada == lg.entrada
		and E.lugar_cargado.posicion == lg.posicion and E.lugar_cargado.vida == 5)

	# d) Game arranca donde dice la partida
	_copiar_ejemplo()
	E.cargar()
	await crear_game(false, false)
	ok("d) zona cargada", game.ruta_zona == "res://scenes/levels/bosque.tscn", game.ruta_zona)
	ok("d) posición cargada", j.global_position.distance_to(Vector2(512, 40)) < 1.0, str(j.global_position))
	ok("d) vida cargada", j.vida.vida == 12)
	ok("d) lugar_cargado consumido", E.lugar_cargado == null)

	# e) guardar desde el libro (pestañas: Inventario → R R R → Guardar)
	E.reiniciar()
	E.tiene_libro = true
	E.monedas = 31
	E.agregar_objeto(&"manzana", 3)
	borrar_partida_prueba()
	await ticks(5)
	await pulsar(&"inventario")
	ok("e) libro abierto", Libro.abierto)
	for i in 3:
		await pulsar(&"pagina_siguiente")
	await pulsar(&"interactuar")
	await ticks(3)
	ok("e) el archivo existe", FileAccess.file_exists(RUTA_PARTIDA_PRUEBA))
	var mensaje := (Libro.get_node(^"%MensajeGuardar") as Label).text
	ok("e) mensaje de confirmación", mensaje == "¡Partida guardada!", mensaje)
	var cfg := ConfigFile.new()
	cfg.load(RUTA_PARTIDA_PRUEBA)
	ok("e) datos guardados", cfg.get_value("jugador", "monedas") == 31
		and cfg.get_value("jugador", "objetos")["manzana"] == 3
		and cfg.get_value("lugar", "zona") == game.ruta_zona
		and cfg.get_value("lugar", "posicion") == game.jugador.global_position)
