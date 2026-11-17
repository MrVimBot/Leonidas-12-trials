extends "res://tools/pruebas/base_prueba.gd"
## Pez espada (plan 04 del nivel 2): escena sin avisos; ve a Leonidas → AVISO → CARRERA en línea
## recta a ≥ 200 px/s → frena y clava la espada (ESTOCADA, 3 de daño, sin atropello previo) →
## ENFRIAMIENTO de 1,5 s; si Leonidas se aparta durante el aviso pasa de largo y no le toca (rumbo
## fijo, Q5); corriendo es invulnerable y en el enfriamiento no (espadazo real); contra una pared se
## estrella y el enfriamiento dura más. Jugador y pez instanciados sueltos (sin game.tscn).

const POS_JUGADOR := Vector2(200, 200)
const DISTANCIA := 100.0

var raiz: Node2D
var pez: PezEspada


## Crea un escenario nuevo: Leonidas en `POS_JUGADOR` y un pez a `DISTANCIA` px a su derecha.
func _escenario() -> void:
	if is_instance_valid(raiz):
		raiz.free()
	EstadoJuego.reiniciar()
	EstadoJuego.tiene_espada = true
	raiz = Node2D.new()
	get_tree().root.add_child(raiz)
	j = (load("res://scenes/player/jugador.tscn") as PackedScene).instantiate() as Jugador
	j.position = POS_JUGADOR
	raiz.add_child(j)
	pez = (load("res://scenes/enemies/pez_espada.tscn") as PackedScene).instantiate() as PezEspada
	pez.position = POS_JUGADOR + Vector2(DISTANCIA, 0)
	raiz.add_child(pez)
	await ticks(2)


## Ticks que dura el estado `e` desde que se entra en él (máximo 600).
func _duracion(e: PezEspada.Estado) -> int:
	var n := 0
	while pez.estado == e and n < 600:
		await get_tree().physics_frame
		n += 1
	return n


func ejecutar() -> void:
	# ---- escena ----
	await _escenario()
	ok("sin avisos de configuración en el Ataque", pez.ataque._get_configuration_warnings().is_empty(), str(pez.ataque._get_configuration_warnings()))
	ok("empieza deambulando", pez.estado == PezEspada.Estado.ACECHO or pez.estado == PezEspada.Estado.AVISO)
	ok("en juego, antes de atacar, el Contacto y la Estocada están apagados", not pez.contacto.activo and not pez.ataque.hitbox.activo)

	# ---- 1) ve → AVISO → CARRERA rapidísima → ESTOCADA → ENFRIAMIENTO ----
	ok("1) ve a Leonidas y se para a avisar", await esperar_hasta(func() -> bool: return pez.estado == PezEspada.Estado.AVISO, 240))
	ok("1) el rumbo apunta a Leonidas (izquierda)", pez._rumbo.is_equal_approx(Vector2.LEFT), str(pez._rumbo))
	ok("1) en el aviso no se mueve", pez.velocity.length() < 1.0, str(pez.velocity))
	ok("1) pasa a CARRERA", await esperar_hasta(func() -> bool: return pez.estado == PezEspada.Estado.CARRERA, 120))
	ok("1) corriendo es invulnerable y atropella", pez.vida.invulnerable_extra and pez.contacto.activo)
	await ticks(2)
	var x0 := pez.global_position.x
	var n_ticks := 8
	await ticks(n_ticks)
	var dt := get_physics_process_delta_time()
	# `ticks()` espera además un fotograma de proceso: usa los ticks reales medidos con la posición.
	var vel := (x0 - pez.global_position.x) / (float(n_ticks + 1) * dt)
	ok("1) corre a ≥ 200 px/s hacia la izquierda", vel >= 200.0, "%.0f px/s" % vel)
	ok("1) en línea recta (no cambia de altura)", is_equal_approx(pez.global_position.y, POS_JUGADOR.y), str(pez.global_position.y))
	var vida_pez := pez.vida.vida
	pez.hurtbox.recibir_golpe(1, j.global_position)
	await ticks(2)
	ok("1) un golpe en plena carrera no le quita vida", pez.vida.vida == vida_pez and pez.estado == PezEspada.Estado.CARRERA, "vida %d estado %d" % [pez.vida.vida, pez.estado])
	ok("1) al llegar frena y clava la espada", await esperar_hasta(func() -> bool: return pez.estado == PezEspada.Estado.ESTOCADA, 120))
	var dx := pez.global_position.x - j.global_position.x
	ok("1) se queda a la distancia de la estocada", dx > 20.0 and dx <= pez.distancia_estocada + 4.0, "%.1f px" % dx)
	ok("1) en la estocada ya no atropella y es vulnerable", not pez.contacto.activo and not pez.vida.invulnerable_extra)
	ok("1) acaba en ENFRIAMIENTO", await esperar_hasta(func() -> bool: return pez.estado == PezEspada.Estado.ENFRIAMIENTO, 240))
	ok("1) la estocada quita 3 (y no hubo atropello antes)", j.vida.vida == j.vida.vida_max - 3, "vida %d/%d" % [j.vida.vida, j.vida.vida_max])
	ok("1) en el enfriamiento no atropella y es vulnerable", not pez.contacto.activo and not pez.vida.invulnerable_extra)
	var enfria := await _duracion(PezEspada.Estado.ENFRIAMIENTO)
	ok("1) el enfriamiento dura ~1,5 s", enfria >= 170 and enfria <= 200, "%d ticks" % enfria)

	# ---- 2) Leonidas se aparta durante el aviso: pasa de largo ----
	await _escenario()
	ok("2) AVISO", await esperar_hasta(func() -> bool: return pez.estado == PezEspada.Estado.AVISO, 240))
	var origen := pez.global_position
	j.global_position.y -= 40.0
	ok("2) CARRERA", await esperar_hasta(func() -> bool: return pez.estado == PezEspada.Estado.CARRERA, 120))
	ok("2) termina en ENFRIAMIENTO", await esperar_hasta(func() -> bool: return pez.estado == PezEspada.Estado.ENFRIAMIENTO, 240))
	var recorrido := origen.distance_to(pez.global_position)
	ok("2) recorrió la carrera entera en línea recta", recorrido >= pez.distancia_carrera_max - 3.0 and recorrido <= pez.distancia_carrera_max + 12.0, "%.1f px" % recorrido)
	ok("2) no corrigió el rumbo (misma altura)", is_equal_approx(pez.global_position.y, origen.y), str(pez.global_position.y))
	ok("2) no le quitó vida", j.vida.vida == j.vida.vida_max, str(j.vida.vida))
	ok("2) en el enfriamiento no está invulnerable", not pez.vida.invulnerable_extra)

	# ---- 3) un espadazo real en el enfriamiento sí le quita vida ----
	j.global_position = pez.global_position + Vector2(-14, 0)
	j.velocity = Vector2.ZERO
	j.animador.mirar(Vector2.RIGHT)
	await ticks(1)
	var vida_antes := pez.vida.vida
	await pulsar(&"atacar")
	await ticks(30)
	ok("3) el espadazo en el enfriamiento le quita vida", pez.vida.vida == vida_antes - 1, "%d -> %d" % [vida_antes, pez.vida.vida])
	ok("3) el retroceso no le saca del enfriamiento", pez.estado in [PezEspada.Estado.DANO, PezEspada.Estado.ENFRIAMIENTO, PezEspada.Estado.AVISO], str(pez.estado))

	# ---- 4) contra una pared se estrella: enfriamiento más largo ----
	await _escenario()
	var pared := StaticBody2D.new()
	pared.collision_layer = Capas.MUNDO
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 200)
	forma.shape = rect
	pared.add_child(forma)
	pared.position = POS_JUGADOR + Vector2(50, 0) # entre el pez y Leonidas
	raiz.add_child(pared)
	await ticks(2)
	ok("4) AVISO", await esperar_hasta(func() -> bool: return pez.estado == PezEspada.Estado.AVISO, 240))
	ok("4) CARRERA", await esperar_hasta(func() -> bool: return pez.estado == PezEspada.Estado.CARRERA, 120))
	ok("4) se estrella y queda en ENFRIAMIENTO", await esperar_hasta(func() -> bool: return pez.estado == PezEspada.Estado.ENFRIAMIENTO, 240))
	ok("4) frenó en la pared", pez.global_position.x > pared.position.x, str(pez.global_position))
	ok("4) no llegó a Leonidas", j.vida.vida == j.vida.vida_max)
	var aturdido := await _duracion(PezEspada.Estado.ENFRIAMIENTO)
	ok("4) enfriamiento largo (~2,2 s)", aturdido >= 255 and aturdido <= 280, "%d ticks" % aturdido)

	# ---- 5) muere: queda MUERTA, suelta 2 monedas y desaparece ----
	await _escenario()
	var monedas_antes := raiz.find_children("*", "ObjetoSuelto", true, false).size()
	pez.vida.recibir_danio(pez.vida.vida_max)
	await ticks(2)
	ok("5) muerta", pez.estado == PezEspada.Estado.MUERTA)
	await ticks(100)
	ok("5) se libera tras la animación de muerte", not is_instance_valid(pez))
	var monedas_despues := raiz.find_children("*", "ObjetoSuelto", true, false).size()
	ok("5) suelta 2 monedas", monedas_despues - monedas_antes == 2, "%d -> %d" % [monedas_antes, monedas_despues])

	raiz.queue_free()
	EstadoJuego.reiniciar()
	await ticks(2)
