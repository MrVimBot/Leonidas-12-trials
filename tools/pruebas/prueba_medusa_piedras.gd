extends "res://tools/pruebas/base_prueba.gd"
## Piedras de los trozos de estatua en `cueva_jefe`:
## 1) desde la mitad de vida, cada `TrozoEstatua` que cae deja una piedra (`ObjetoAgarrable`)
##    donde cae, con la misma escena que `piedra.tscn`;
## 2) Leonidas la levanta y, lanzada contra Medusa, le quita vida y se rompe (un solo uso);
## 3) nunca hay más de `max_piedras` en el suelo;
## 4) `reiniciar()` (Game Over a mitad) las quita.

const DENTRO := Vector2(272, 290)
const QUIETO := Vector2(300, 205)

var medusa: Medusa


func piedras() -> Array[Node]:
	return medusa.get_parent().get_children().filter(func(n: Node) -> bool:
		return n is ObjetoAgarrable and not n.is_queued_for_deletion())


func mucha_vida() -> void:
	j.vida.fijar_maximo(400, true)


func matar_ciclopes() -> void:
	for c in medusa.ciclopes_vivos():
		c.vida.recibir_danio(99)
	await ticks(2)


func ejecutar() -> void:
	tiempo_maximo = 180.0
	await crear_game(true, true)
	await ir("res://scenes/levels/cueva_jefe.tscn", "desde_cueva")
	medusa = game.zona_actual.get_node_or_null(^"Objetos/Jefe/Medusa") as Medusa
	ok("0) la zona trae a Medusa", medusa != null)
	if medusa == null:
		return
	j.global_position = DENTRO
	await esperar_hasta(func() -> bool: return Dialogos.abierto, 900)
	await cerrar_dialogos()
	mucha_vida()
	await esperar_hasta(func() -> bool: return medusa.ciclopes_vivos().size() == 2, 300)
	await matar_ciclopes()
	await esperar_hasta(func() -> bool: return not medusa.vida.es_invulnerable(), 120)
	medusa.vida.recibir_danio(medusa.vida.vida - 10)
	await esperar_hasta(func() -> bool: return medusa.ciclopes_vivos().size() == 2, 900)
	await matar_ciclopes()

	# 1) Un trozo cae y deja una piedra en su sitio.
	var caidas: Array[Vector2] = []
	var al_anadir := func(n: Node) -> void:
		if n is TrozoEstatua:
			(n as TrozoEstatua).cayo.connect(func(p: Vector2) -> void: caidas.append(p))
	get_tree().node_added.connect(al_anadir)
	var hay := await esperar_hasta(func() -> bool:
		j.global_position = QUIETO
		mucha_vida()
		return not piedras().is_empty(), 1500)
	get_tree().node_added.disconnect(al_anadir)
	# Medusa quieta desde aquí hasta el paso 3: no lanza más ni se mueve.
	medusa.set_physics_process(false)
	medusa.movimiento.detener()
	ok("1) el trozo deja una piedra", hay)
	if not hay:
		return
	var piedra := piedras()[0] as ObjetoAgarrable
	ok("1) es la piedra de siempre", piedra.scene_file_path == "res://scenes/items/piedra.tscn", piedra.scene_file_path)
	# Donde cayó o, si estaba ocupado (Medusa al lado), en el hueco libre más cercano.
	ok("1) donde cayó el trozo (o al lado)", not caidas.is_empty() and caidas.any(func(p: Vector2) -> bool: return p.distance_to(piedra.global_position) <= 32.5))
	ok("1) se rompe al lanzarla", piedra.rompible)

	# 2) Levantarla y lanzarla contra Medusa.
	await esperar_hasta(func() -> bool: return not j.esta_bloqueado() and j.estado == Jugador.Estado.NORMAL, 300)
	piedra = piedras()[-1] as ObjetoAgarrable
	# Un golpe con la piedra en brazos la suelta (y se rompe, como las vasijas): aquí no.
	j.vida.invulnerable_extra = true
	j.global_position = piedra.global_position + Vector2(-14, 0)
	j.velocity = Vector2.ZERO
	j.animador.mirar(Vector2.RIGHT)
	await ticks(2)
	await pulsar(&"interactuar")
	var en_brazos := await esperar_hasta(func() -> bool: return j.carga.cargando() and j.estado == Jugador.Estado.NORMAL, 240)
	ok("2) Leonidas la levanta", en_brazos and j.carga.objeto == piedra, "estado %s, carga %s, j %s, piedra %s" % [j.estado, j.carga.objeto, j.global_position, piedra.global_position])
	if not en_brazos:
		return
	await esperar_hasta(func() -> bool: return not medusa.vida.es_invulnerable(), 120)
	var vida_antes := medusa.vida.vida
	j.global_position = medusa.global_position + Vector2(-50, 0)
	j.velocity = Vector2.ZERO
	j.animador.mirar(Vector2.RIGHT)
	await ticks(2)
	var ref: WeakRef = weakref(piedra)
	await pulsar(&"interactuar")
	var rota := await esperar_hasta(func() -> bool: return ref.get_ref() == null or (ref.get_ref() as ObjetoAgarrable).is_queued_for_deletion() or not (ref.get_ref() as ObjetoAgarrable).golpe.activo, 240)
	await ticks(2)
	ok("2) le quita vida a Medusa", medusa.vida.vida < vida_antes, "%d → %d" % [vida_antes, medusa.vida.vida])
	await ticks(60)
	ok("2) la piedra se rompe (un solo uso)", rota and ref.get_ref() == null)
	medusa.set_physics_process(true)
	j.vida.invulnerable_extra = false

	# 3) Límite de piedras en el suelo.
	var maximo := [0]
	await esperar_hasta(func() -> bool:
		j.global_position = QUIETO + Vector2(randf_range(-60, 60), randf_range(-30, 30))
		mucha_vida()
		maximo[0] = maxi(maximo[0], piedras().size())
		return false, 1800)
	ok("3) como mucho max_piedras", maximo[0] > 0 and maximo[0] <= medusa.max_piedras, str(maximo[0]))

	# 4) reiniciar() las quita.
	medusa.reiniciar()
	await ticks(3)
	ok("4) sin piedras tras reiniciar", piedras().is_empty(), str(piedras().size()))
