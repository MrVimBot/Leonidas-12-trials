extends "res://tools/pruebas/base_prueba.gd"
## Dialogo.parsear (formato "Nombre: texto"): quién habla, líneas sin nombre que siguen con el
## último, comentarios `#`, líneas vacías, nombre de más de 16 letras (no es un nombre) y dos
## diálogos seguidos en la caja (Dialogos.mostrar) sin que el jugador se desbloquee entre medias
## (la escena pone su propio motivo de bloqueo, &"escena", mientras encadena).


func ejecutar() -> void:
	# Quién habla y líneas sin nombre
	var r := Dialogo.parsear("Kathita: ¡Despierta!\nLeonidas: Cinco minutos más.\nOtra frase de Leonidas.")
	ok("3 cuadros", r.size() == 3, str(r.size()))
	ok("primer hablante", r[0].nombre == "Kathita" and r[0].texto == "¡Despierta!")
	ok("cambia de hablante", r[1].nombre == "Leonidas" and r[1].texto == "Cinco minutos más.")
	ok("sin nombre sigue el último", r[2].nombre == "Leonidas" and r[2].texto == "Otra frase de Leonidas.")

	# Texto sin nadie al principio (cartel)
	r = Dialogo.parsear("Solo un cartel.\nOtra línea.")
	ok("sin hablante: nombre vacío", r.size() == 2 and r[0].nombre == "" and r[1].nombre == "")

	# Comentarios y vacías
	r = Dialogo.parsear("# comentario\n\n   \nA: hola\n  # otro comentario con sangría\nB: adiós\n")
	ok("comentarios y vacías se ignoran", r.size() == 2 and r[0].nombre == "A" and r[1].nombre == "B", str(r))

	# Espacios alrededor
	r = Dialogo.parsear("  Zeus  :   Hola.  \n")
	ok("se recortan los espacios del nombre y del texto", r.size() == 1 and r[0].nombre == "Zeus" and r[0].texto == "Hola.", str(r))
	r = Dialogo.parsear("Zeus:Hola")
	ok("sin espacio tras «:» no es un nombre", r[0].nombre == "" and r[0].texto == "Zeus:Hola", str(r))

	# Nombre de exactamente 16 letras (vale) y de 17 (no es nombre)
	var n16 := "A".repeat(Dialogo.MAX_NOMBRE)
	var n17 := "A".repeat(Dialogo.MAX_NOMBRE + 1)
	r = Dialogo.parsear("%s: texto" % n16)
	ok("nombre de 16 letras vale", r[0].nombre == n16 and r[0].texto == "texto")
	r = Dialogo.parsear("%s: texto" % n17)
	ok("nombre de 17 letras no es nombre: toda la línea es texto", r[0].nombre == "" and r[0].texto == "%s: texto" % n17)

	# Dos puntos dentro del texto: solo cuenta el primero
	r = Dialogo.parsear("Kathita: Tienes dos cosas: la carta y el libro.")
	ok("solo el primer «: » separa el nombre", r[0].nombre == "Kathita" and r[0].texto == "Tienes dos cosas: la carta y el libro.")

	# Línea que empieza por «: » (posición 0): no es nombre
	r = Dialogo.parsear(": sin nombre")
	ok("«: » al inicio no es nombre", r[0].nombre == "")

	# Recurso Dialogo.lineas()
	var d := Dialogo.new()
	d.texto = "X: uno\ndos"
	ok("Dialogo.lineas() usa el texto", d.lineas().size() == 2 and d.lineas()[1].nombre == "X")

	# Encadenar dos diálogos en la caja: el jugador no se desbloquea entre uno y otro
	await crear_game(true, true)
	var d1 := Dialogo.new()
	d1.texto = "Uno: primero"
	var d2 := Dialogo.new()
	d2.texto = "Dos: segundo"
	j.bloquear(&"escena")
	var visto := {"d1": false, "d2": false, "libre_entre": false}
	var encadenado := func() -> void:
		await Dialogos.mostrar(d1)
		visto.d1 = true
		await Dialogos.mostrar(d2)
		visto.d2 = true
	encadenado.call()
	await esperar_hasta(func() -> bool: return Dialogos.abierto)
	ok("se abre el primero", Dialogos.abierto and j.estado == Jugador.Estado.BLOQUEADO)
	for i in 120:
		if visto.d2:
			break
		if Dialogos.abierto:
			await pulsar(&"interactuar")
			if j.estado != Jugador.Estado.BLOQUEADO:
				visto.libre_entre = true
		else:
			await ticks(1)
	ok("se muestran los dos, en orden", visto.d1 and visto.d2)
	ok("el jugador sigue bloqueado entre uno y otro", not visto.libre_entre)
	ok("con el motivo de la escena sigue bloqueado al acabar", j.estado == Jugador.Estado.BLOQUEADO)
	j.desbloquear(&"escena")
	await ticks(3)
	ok("al quitar el motivo de la escena queda libre", j.estado == Jugador.Estado.NORMAL and not j.esta_bloqueado(), str(j.estado))
