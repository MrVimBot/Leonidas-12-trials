extends "res://tools/pruebas/base_prueba.gd"
## EstadoJuego (autoload): reiniciar y sus señales, objetos con máximos, monedas con límite,
## misiones, atajos (espada/libro) y formato del tiempo jugado. Sin escenas.


func ejecutar() -> void:
	var E := EstadoJuego
	var contador := {"rest": 0, "obj": [], "mon": 0, "mis": 0}
	E.estado_restablecido.connect(func() -> void: contador.rest += 1)
	E.objetos_cambio.connect(func(id: StringName, n: int) -> void: contador.obj.append([id, n]))
	E.monedas_cambio.connect(func(_m: int) -> void: contador.mon += 1)
	E.misiones_cambio.connect(func() -> void: contador.mis += 1)

	# reiniciar()
	E.mision_recibida = true
	E.avisos_zeus = 3
	E.tiempo_jugado = 99.0
	E.reiniciar()
	ok("reiniciar emite estado_restablecido", contador.rest == 1)
	ok("reiniciar emite monedas y misiones", contador.mon == 1 and contador.mis == 1)
	ok("banderas a cero", not E.mision_recibida and E.avisos_zeus == 0 and E.tiempo_jugado == 0.0)

	# Objetos con máximo (manzanas: 9)
	contador.obj.clear()
	ok("agregar manzanas", E.agregar_objeto(E.OBJ_MANZANA, 8))
	ok("objetos_cambio con id y cantidad", contador.obj == [[&"manzana", 8]], str(contador.obj))
	ok("cabe 1 más, no 2", E.cabe(E.OBJ_MANZANA, 1) and not E.cabe(E.OBJ_MANZANA, 2))
	ok("no se pasa del máximo", not E.agregar_objeto(E.OBJ_MANZANA, 2) and E.cantidad(E.OBJ_MANZANA) == 8)
	ok("máximo de manzanas = 9", E.maximo(E.OBJ_MANZANA) == 9)
	ok("gastar", E.gastar_objeto(E.OBJ_MANZANA, 3) and E.cantidad(E.OBJ_MANZANA) == 5)
	ok("gastar de más no hace nada", not E.gastar_objeto(E.OBJ_MANZANA, 6) and E.cantidad(E.OBJ_MANZANA) == 5)

	# Atajos sobre objetos
	ok("sin espada al empezar", not E.tiene_espada)
	E.tiene_espada = true
	ok("tiene_espada = objeto espada", E.tiene_espada and E.cantidad(E.OBJ_ESPADA) == 1)
	E.tiene_libro = true
	ok("tiene_libro = objeto libro", E.cantidad(E.OBJ_LIBRO) == 1)
	ok("los objetos existen como recurso", E.objeto(E.OBJ_CARTA) != null and E.objeto(E.OBJ_ESPADA) != null)

	# Monedas (límite 999)
	E.agregar_monedas(990)
	E.agregar_monedas(50)
	ok("monedas limitadas a 999", E.monedas == 999)
	ok("gastar monedas sin saldo falla", not E.gastar_monedas(1000) and E.monedas == 999)
	ok("gastar monedas", E.gastar_monedas(99) and E.monedas == 900)

	# Misiones
	E.empezar_mision(E.MISION_IR_AL_TEMPLO)
	ok("misión activa", E.misiones.get(E.MISION_IR_AL_TEMPLO) == E.EstadoMision.ACTIVA
		and not E.mision_completada(E.MISION_IR_AL_TEMPLO))
	E.completar_mision(E.MISION_IR_AL_TEMPLO)
	ok("misión completada", E.mision_completada(E.MISION_IR_AL_TEMPLO))
	ok("el recurso de la misión se cachea", E.mision(E.MISION_IR_AL_TEMPLO) != null
		and E.mision(E.MISION_IR_AL_TEMPLO) == E.mision(E.MISION_IR_AL_TEMPLO))
	ok("misión inexistente = null", E.mision(&"nada") == null)

	# Tiempo jugado
	E.tiempo_jugado = 3725.0
	ok("tiempo_texto con horas", E.tiempo_texto() == "1:02:05", E.tiempo_texto())
	E.tiempo_jugado = 125.0
	ok("tiempo_texto corto", E.tiempo_texto() == "02:05", E.tiempo_texto())

	# La partida de las pruebas es la temporal, no la real
	ok("ruta_partida es la de pruebas", E.ruta_partida == RUTA_PARTIDA_PRUEBA)
	E.reiniciar()
	ok("hay_partida mira la ruta de pruebas (vacía)", not E.hay_partida())
