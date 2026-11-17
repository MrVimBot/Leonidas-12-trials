extends "res://tools/pruebas/base_prueba.gd"
## Estados propios del Jugador, instanciado SOLO (sin Game): comer una manzana (completo, con el
## árbol en pausa, interrumpido por un golpe o por un bloqueo), mostrar/ocultar el objeto
## obtenido, y morir + reaparecer en el punto de control.
## (Bloquear a mitad de acción: `prueba_jugador_bloqueo.gd`.)

var manzana: Objeto


func _nuevo() -> void:
	if j:
		j.free()
	j = (load("res://scenes/player/jugador.tscn") as PackedScene).instantiate() as Jugador
	get_tree().root.add_child(j)
	await get_tree().physics_frame


func _en_mano() -> Sprite2D:
	return j.get_node(^"Visual/ObjetoEnMano") as Sprite2D


func ejecutar() -> void:
	manzana = load("res://resources/objetos/manzana.tres") as Objeto
	var comidas := [0]
	await _nuevo()
	var visual := j.get_node(^"Visual")
	var ultimo := visual.get_child(visual.get_child_count() - 1)
	ok("ObjetoEnMano es el último hijo de Visual y está oculto", ultimo.name == &"ObjetoEnMano" and not (ultimo as Sprite2D).visible)

	# Comer completo
	j.comio.connect(func(_o: Objeto) -> void: comidas[0] += 1)
	j.vida.vida = 6
	j.comer(manzana)
	await get_tree().physics_frame
	ok("comer: estado COMER y objeto en la mano", j.estado == Jugador.Estado.COMER and _en_mano().visible
		and _en_mano().texture != null)
	await esperar(0.5)
	ok("comer: a los 0,5 s sigue comiendo", j.estado == Jugador.Estado.COMER)
	await esperar(0.5)
	ok("comer: termina, cura y vuelve a NORMAL", j.estado == Jugador.Estado.NORMAL
		and j.vida.vida == mini(6 + manzana.cura, j.vida.vida_max) and not _en_mano().visible and comidas[0] == 1,
		"vida %d" % j.vida.vida)

	# Comer con el árbol en pausa: el temporizador respeta la pausa
	await _nuevo()
	j.vida.vida = 4
	j.comer(manzana)
	await esperar(0.3)
	get_tree().paused = true
	await esperar(2.0)
	ok("comer en pausa: sigue comiendo y no cura", j.estado == Jugador.Estado.COMER and j.vida.vida == 4)
	get_tree().paused = false
	await esperar(0.9)
	ok("comer tras la pausa: termina y cura", j.estado == Jugador.Estado.NORMAL and j.vida.vida == 4 + manzana.cura)

	# Comer interrumpido por un golpe
	await _nuevo()
	j.vida.vida = 6
	var antes := EstadoJuego.cantidad(manzana.id)
	j.comer(manzana)
	await esperar(0.3)
	j.vida.recibir_danio(1)
	await esperar(1.2)
	ok("comer + golpe: no cura (vida 5), no devuelve el objeto, mano vacía",
		j.vida.vida == 5 and EstadoJuego.cantidad(manzana.id) == antes and not _en_mano().visible, str(j.vida.vida))

	# Comer interrumpido por un bloqueo: el objeto vuelve
	await _nuevo()
	j.vida.vida = 6
	antes = EstadoJuego.cantidad(manzana.id)
	j.comer(manzana)
	await esperar(0.3)
	j.bloquear(&"prueba")
	await esperar(1.0)
	ok("comer + bloqueo: no cura y devuelve el objeto", j.vida.vida == 6
		and EstadoJuego.cantidad(manzana.id) == antes + 1 and j.estado == Jugador.Estado.BLOQUEADO)
	j.desbloquear(&"prueba")
	EstadoJuego.gastar_objeto(manzana.id)

	# Objeto obtenido
	await _nuevo()
	j.mostrar_objeto_obtenido(manzana.icono, 0.5)
	await esperar(0.2)
	ok("objeto obtenido (0,5 s): visible", _en_mano().visible)
	await esperar(0.5)
	ok("objeto obtenido (0,5 s): se quita solo", not _en_mano().visible)
	j.mostrar_objeto_obtenido(manzana.icono, 0.0)
	await esperar(1.0)
	ok("objeto obtenido (duración 0): se queda", _en_mano().visible)
	j.ocultar_objeto_obtenido()
	ok("objeto obtenido (duración 0): se oculta a mano", not _en_mano().visible)

	# Morir y reaparecer
	await _nuevo()
	var murio := [0]
	j.murio.connect(func() -> void: murio[0] += 1)
	j.punto_control = Vector2(50, 60)
	j.global_position = Vector2(300, 300)
	j.vida.recibir_danio(99)
	await esperar(0.4)
	ok("morir: estado MUERTO", j.estado == Jugador.Estado.MUERTO)
	await esperar_hasta(func() -> bool: return murio[0] > 0, 600)
	ok("morir: emite murio y reaparece en el punto de control con la vida llena",
		murio[0] == 1 and j.global_position == Vector2(50, 60) and j.vida.vida == j.vida.vida_max
		and j.estado == Jugador.Estado.NORMAL)
	j.free()
	j = null
