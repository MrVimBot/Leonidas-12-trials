extends "res://tools/pruebas/base_prueba.gd"
## Cerebro de Medusa (`scenes/enemies/medusa.tscn`, plan 06 M1–M3), instanciada junto al jugador
## en `cueva_jefe` (aún sin colocar allí: eso es M6):
## 0) INACTIVA no ataca; 1) `empezar_combate()` invoca 2 cíclopes y queda invulnerable y gris;
## un golpe no le quita vida; al morir los cíclopes deja de serlo; 2) el golpe al suelo cae donde
## estaba Leonidas (aviso incluido) y le quita 4; 3) a mitad de vida invoca 2 cíclopes nuevos y,
## muertos, lanza trozos de estatua que caen donde estaba Leonidas (2 a la vez con ≤ 25 %);
## 4) `reiniciar()` la deja como al principio; 5) a 0 de vida pasa a DERROTADA sin liberarse.

const ESCENA := preload("res://scenes/enemies/medusa.tscn")

var medusa: Medusa
var contenedor: Node2D
var cambios_invulnerable: Array[bool] = []


func nodos_de(clase: String) -> Array[Node]:
	return game.find_children("*", clase, true, false).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())


func matar_ciclopes() -> void:
	for c in medusa.ciclopes_vivos():
		c.vida.recibir_danio(99)
	await ticks(2)


## Leonidas no muere en la prueba: mucha vida.
func curar_jugador() -> void:
	j.vida.vida_max = 400
	j.vida.restaurar()


func ejecutar() -> void:
	await crear_game(true, true)
	await ir("res://scenes/levels/cueva_jefe.tscn", "desde_cueva")
	for e in get_tree().get_nodes_in_group(&"enemigos"):
		e.queue_free()
	await ticks(3)
	curar_jugador()
	contenedor = game.zona_actual.get_node(^"Objetos") as Node2D
	var inicio := Vector2(250, 140)
	medusa = ESCENA.instantiate() as Medusa
	medusa.position = contenedor.to_local(inicio)
	contenedor.add_child(medusa)
	medusa.invulnerable_cambio.connect(func(a: bool) -> void: cambios_invulnerable.append(a))
	j.global_position = Vector2(290, 200)
	await ticks(60)

	# 0) Inactiva: quieta, sin golpes.
	ok("0) empieza INACTIVA", medusa.estado == Medusa.Estado.INACTIVA, str(medusa.estado))
	ok("0) no se mueve", medusa.global_position.distance_to(inicio) < 0.5)
	ok("0) Hurtbox y contacto apagados", not medusa.hurtbox.activo and not medusa.contacto.activo)
	ok("0) vida 20", medusa.vida.vida == 20 and medusa.vida.vida_max == 20)

	# 1) Invocación inicial: 2 cíclopes, invulnerable y gris.
	medusa.empezar_combate()
	ok("1) INVOCAR al empezar", medusa.estado == Medusa.Estado.INVOCAR)
	var llegaron := await esperar_hasta(func() -> bool: return medusa.ciclopes_vivos().size() == 2, 300)
	ok("1) aparecen 2 cíclopes", llegaron and nodos_de("CiclopeSerpiente").size() == 2, str(medusa.ciclopes_vivos().size()))
	ok("1) invulnerable (señal true)", medusa.invulnerable and cambios_invulnerable == [true], str(cambios_invulnerable))
	ok("1) se ve gris", medusa.sprite.modulate.r < 0.7 and medusa.sprite.modulate.g < 0.7, str(medusa.sprite.modulate))
	ok("1) los cíclopes son invocados", medusa.ciclopes_vivos().all(func(c: CiclopeSerpiente) -> bool: return c.invocado))
	var lejos := medusa.ciclopes_vivos().all(func(c: CiclopeSerpiente) -> bool: return c.global_position.distance_to(j.global_position) > 60.0)
	ok("1) aparecen lejos de Leonidas", lejos)
	await ticks(40)
	medusa.hurtbox.recibir_golpe(1, j.global_position)
	await ticks(2)
	ok("1) un golpe no le quita vida", medusa.vida.vida == 20, str(medusa.vida.vida))
	await matar_ciclopes()
	ok("1) muertos los cíclopes deja de ser invulnerable", not medusa.invulnerable and cambios_invulnerable == [true, false], str(cambios_invulnerable))
	await ticks(60)
	ok("1) color normal", medusa.sprite.modulate.r > 0.99 and medusa.sprite.modulate.g > 0.99, str(medusa.sprite.modulate))
	medusa.hurtbox.recibir_golpe(1, j.global_position)
	await ticks(2)
	ok("1) ya recibe daño", medusa.vida.vida == 19, str(medusa.vida.vida))

	# 2) Golpe al suelo: Leonidas quieto; el aviso y la espada caen donde está.
	curar_jugador()
	var p := Vector2(300, 205)
	j.global_position = p
	medusa.global_position = p + Vector2(-60, -40)
	var aviso_en := [Vector2.INF]
	var impacto_en := [Vector2.INF]
	var danos: Array[int] = []
	var al_danar := func(c: int, _o: Vector2) -> void: danos.append(c)
	j.vida.danado.connect(al_danar)
	var golpeado := [false]
	var al_golpear := func(o: Node) -> void:
		if o == j.get_node(^"Hurtbox"):
			golpeado[0] = true
	medusa.golpe.golpeo.connect(al_golpear)
	medusa.golpe_suelo.connect(func(punto: Vector2) -> void: impacto_en[0] = punto)
	var vio_aviso := await esperar_hasta(func() -> bool:
		j.global_position = p # quieto (los empujones de daño no cuentan)
		if medusa.aviso.visible and aviso_en[0] == Vector2.INF:
			aviso_en[0] = medusa.aviso.global_position
		return golpeado[0], 1500)
	ok("2) el golpe al suelo alcanza a Leonidas", vio_aviso, "estado %d" % medusa.estado)
	ok("2) el aviso sale donde está Leonidas", aviso_en[0].distance_to(p) < 2.0, str(aviso_en[0]))
	await esperar_hasta(func() -> bool: return impacto_en[0] != Vector2.INF, 120)
	ok("2) la espada cae sobre el aviso", impacto_en[0].distance_to(aviso_en[0]) < 3.0, "%s / %s" % [impacto_en[0], aviso_en[0]])
	ok("2) quita 4 cuartos", 4 in danos, str(danos))
	var clavada := await esperar_hasta(func() -> bool: return medusa.estado == Medusa.Estado.CLAVADA, 120)
	ok("2) queda CLAVADA", clavada, str(medusa.estado))
	var pos_clavada := medusa.global_position
	await ticks(30)
	ok("2) clavada no se mueve", medusa.global_position.distance_to(pos_clavada) < 0.5)
	ok("2) aviso oculto y golpe apagado", not medusa.aviso.visible and not medusa.golpe.activo)
	j.vida.danado.disconnect(al_danar)
	var vuelve := await esperar_hasta(func() -> bool: return medusa.estado in [Medusa.Estado.ESPERA, Medusa.Estado.ACERCARSE], 400)
	ok("2) recupera y vuelve a ESPERA", vuelve, str(medusa.estado))

	# 3) A mitad de vida: 2 cíclopes nuevos; muertos, trozos de estatua.
	curar_jugador()
	j.global_position = Vector2(272, 220)
	medusa.vida.recibir_danio(medusa.vida.vida - 10) # 19 -> 10 (la mitad)
	var invoca := await esperar_hasta(func() -> bool: return medusa.estado == Medusa.Estado.INVOCAR, 700)
	ok("3) a mitad de vida invoca otra vez", invoca, str(medusa.estado))
	llegaron = await esperar_hasta(func() -> bool: return medusa.ciclopes_vivos().size() == 2, 300)
	ok("3) 2 cíclopes nuevos", llegaron and nodos_de("CiclopeSerpiente").size() == 2)
	ok("3) invulnerable otra vez", medusa.invulnerable)
	await ticks(150)
	ok("3) sin trozos mientras hay cíclopes", nodos_de("TrozoEstatua").is_empty())
	await matar_ciclopes()
	var caidas: Array[Vector2] = []
	var destinos: Array[Vector2] = []
	var al_anadir := func(n: Node) -> void:
		if n is TrozoEstatua:
			n.cayo.connect(func(punto: Vector2) -> void: caidas.append(punto))
			destinos.append(j.global_position)
	get_tree().node_added.connect(al_anadir)
	var hay_trozo := await esperar_hasta(func() -> bool:
		j.global_position = Vector2(272, 220)
		curar_jugador()
		return not caidas.is_empty(), 1200)
	ok("3) lanza un trozo de estatua", hay_trozo)
	if hay_trozo:
		ok("3) el trozo cae donde estaba Leonidas", caidas[0].distance_to(destinos[0]) < 1.5, "%s / %s" % [caidas[0], destinos[0]])
	# Con <= 25 % lanza dos a la vez.
	medusa.vida.recibir_danio(medusa.vida.vida - 4)
	await ticks(2)
	var maximo := [0]
	var dos := await esperar_hasta(func() -> bool:
		j.global_position = Vector2(272, 220)
		curar_jugador()
		maximo[0] = maxi(maximo[0], nodos_de("TrozoEstatua").size())
		return maximo[0] >= 2, 1500)
	ok("3) con <= 25 % lanza dos trozos", dos, str(maximo[0]))

	# 4) reiniciar(): con trozos o cíclopes vivos, todo vuelve a empezar.
	medusa.reiniciar()
	await ticks(3)
	ok("4) INACTIVA", medusa.estado == Medusa.Estado.INACTIVA)
	ok("4) vida llena", medusa.vida.vida == 20 and not medusa.vida.muerto)
	ok("4) en su posición inicial", medusa.global_position.distance_to(inicio) < 0.5, str(medusa.global_position))
	ok("4) sin trozos ni cíclopes", nodos_de("TrozoEstatua").is_empty() and nodos_de("CiclopeSerpiente").is_empty())
	ok("4) no invulnerable, sin golpes", not medusa.invulnerable and not medusa.hurtbox.activo and not medusa.golpe.activo and not medusa.aviso.visible)
	ok("4) banderas de invocación a cero", not medusa._invocado_inicio and not medusa._invocado_mitad and not medusa._invocacion_pendiente)
	get_tree().node_added.disconnect(al_anadir)
	medusa.empezar_combate()
	llegaron = await esperar_hasta(func() -> bool: return medusa.ciclopes_vivos().size() == 2, 300)
	ok("4) vuelve a invocar al empezar de nuevo", llegaron)

	# 5) Derrota: sin cíclopes, a 0 → DERROTADA; no se libera.
	await matar_ciclopes()
	var derrotada := [false]
	medusa.derrotada.connect(func() -> void: derrotada[0] = true)
	medusa.vida.recibir_danio(99)
	await ticks(2)
	ok("5) DERROTADA y señal", medusa.estado == Medusa.Estado.DERROTADA and derrotada[0])
	await ticks(120)
	ok("5) no se libera (sin ComponenteMuerte)", is_instance_valid(medusa) and medusa.is_inside_tree())
	ok("5) golpes y Hurtbox apagados", not medusa.hurtbox.activo and not medusa.contacto.activo and not medusa.golpe.activo)
	var pos := medusa.global_position
	await ticks(120)
	ok("5) quieta", medusa.global_position.distance_to(pos) < 0.5 and medusa.estado == Medusa.Estado.DERROTADA)
