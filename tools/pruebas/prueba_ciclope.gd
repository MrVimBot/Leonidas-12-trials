extends "res://tools/pruebas/base_prueba.gd"
## Cíclope serpiente del nivel 2 (`scenes/enemies/ciclope_serpiente.tscn` + `rayo_ciclope.tscn`),
## instanciado a 120 px del jugador en el bosque: apunta y dispara un `RayoCiclope` que avanza
## hacia Leonidas; con el jugador quieto le quita 2 cuartos y rodando no; durante el
## enfriamiento no hay otro rayo y después sí; un golpe mientras apunta cancela el disparo; el
## rayo se acaba contra una pared o al pasar su alcance (en una arena vacía lejos del mapa);
## y la invocación (`invocado`/`aparecer()`): invulnerable los primeros 0,5 s, emite
## `derrotado` al morir y no suelta monedas (uno normal suelta 1).

const ESCENA := preload("res://scenes/enemies/ciclope_serpiente.tscn")
const ESCENA_RAYO := preload("res://scenes/enemies/rayo_ciclope.tscn")
## Zona vacía, lejos de todo el mapa, para probar el rayo sin árboles ni tiles.
const ARENA := Vector2(100000, 100000)

var rayos_creados := 0
## Cuentas de `derrotado` (una lambda captura los enteros por valor: va en un Array).
var derrotados: Array[int] = [0, 0]


func nuevo_ciclope(pos: Vector2, invocado := false) -> CiclopeSerpiente:
	var c := ESCENA.instantiate() as CiclopeSerpiente
	c.invocado = invocado
	c.position = pos # antes de entrar al árbol: el deambular se centra en su sitio
	game.get_node(^"Mundo").add_child(c)
	return c


func rayo_actual() -> RayoCiclope:
	var rayos := game.find_children("*", "RayoCiclope", true, false)
	return rayos[0] as RayoCiclope if rayos.size() > 0 else null


func quitar_rayos() -> void:
	for r in game.find_children("*", "RayoCiclope", true, false):
		r.queue_free()
	await ticks(2)


func monedas_en_suelo() -> int:
	return game.find_children("*", "ObjetoSuelto", true, false).size()


func ejecutar() -> void:
	await crear_game(true, true)
	game.cambiar_zona("res://scenes/levels/bosque.tscn", "desde_pueblo")
	await ticks(5)
	await esperar_normal()
	await ticks(20)
	for e in get_tree().get_nodes_in_group(&"enemigos"):
		e.queue_free()
	await ticks(3)
	assert((game.get_node(^"Mundo") as Node2D).position == Vector2.ZERO)
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is RayoCiclope:
			rayos_creados += 1)
	j.vida.restaurar()
	var base := j.global_position
	j.animador.mirar(Vector2.RIGHT)

	# 1) Ve al jugador, apunta con la animación y dispara un rayo que avanza hacia él.
	var c := nuevo_ciclope(base + Vector2(-120, 0))
	await ticks(5)
	ok("1) ve al jugador y apunta", c.estado == CiclopeSerpiente.Estado.APUNTAR, str(c.estado))
	ok("1) anima `atacar`", c.sprite.animation == &"atacar", str(c.sprite.animation))
	ok("1) aún no hay rayo antes del fotograma de disparo", rayos_creados == 0)
	var salio := await esperar_hasta(func() -> bool: return rayos_creados > 0, 400)
	ok("1) dispara un RayoCiclope", salio)
	var rayo := rayo_actual()
	ok("1) el rayo está en el árbol y mira al jugador",
		rayo != null and rayo.direccion.x > 0.9, str(rayo.direccion) if rayo else "sin rayo")
	if rayo:
		var x0 := rayo.global_position.x
		await ticks(10)
		ok("1) avanza hacia el jugador", is_instance_valid(rayo) and rayo.global_position.x > x0 + 8.0,
			"%.1f -> %.1f" % [x0, rayo.global_position.x if is_instance_valid(rayo) else -1.0])

	# 2) Jugador quieto: pierde 2 cuartos.
	var vida_antes := j.vida.vida
	var golpeo := await esperar_hasta(func() -> bool: return j.vida.vida < vida_antes, 400)
	ok("2) el rayo quita 2 cuartos al jugador quieto", golpeo and vida_antes - j.vida.vida == 2,
		"%d -> %d" % [vida_antes, j.vida.vida])
	await ticks(2)
	ok("2) el rayo desaparece al golpear", rayo_actual() == null)

	# 3) Enfriamiento: tras acabar la animación espera ~2 s sin disparar y después vuelve a disparar.
	var acabo := await esperar_hasta(func() -> bool: return c.estado == CiclopeSerpiente.Estado.ENFRIAMIENTO, 600)
	ok("3) acaba la animación y entra en ENFRIAMIENTO", acabo, str(c.estado))
	ok("3) en `parado` mientras se enfría", c.sprite.animation == &"parado", str(c.sprite.animation))
	await ticks(200) # 1,7 s de los 2,0 s
	ok("3) durante el enfriamiento no hay otro rayo", rayos_creados == 1 and c.estado == CiclopeSerpiente.Estado.ENFRIAMIENTO,
		"rayos=%d estado=%d" % [rayos_creados, c.estado])
	j.vida.restaurar()
	var otra := await esperar_hasta(func() -> bool: return rayos_creados == 2, 600)
	ok("3) pasado el enfriamiento vuelve a disparar", otra, "rayos=%d" % rayos_creados)
	c.queue_free()
	await quitar_rayos()

	# 4) Rodando: el rayo lo atraviesa sin hacerle daño y sigue su camino.
	j.vida.restaurar()
	j.global_position = base
	j.velocity = Vector2.ZERO
	await ticks(130) # que se acabe la invulnerabilidad de después del golpe
	var c2 := nuevo_ciclope(base + Vector2(-120, 0))
	var centro := func() -> Vector2: return j.global_position + Vector2(0, -11)
	var cerca := await esperar_hasta(func() -> bool:
		var r := rayo_actual()
		return r != null and r.global_position.distance_to(centro.call()) < 26.0, 600)
	ok("4) el rayo se acerca al jugador", cerca)
	j.animador.mirar(Vector2.LEFT) # rueda hacia el rayo: se cruzan seguro
	await pulsar(&"pirueta")
	var vivo_al_cruzar := false
	var r2 := rayo_actual()
	for i in 80:
		await get_tree().physics_frame
		if is_instance_valid(r2) and r2.global_position.x > (centro.call() as Vector2).x + 1.0:
			vivo_al_cruzar = true
			break
	ok("4) rodando no pierde vida", j.vida.vida == j.vida.vida_max, "%d/%d" % [j.vida.vida, j.vida.vida_max])
	ok("4) el rayo lo atraviesa y sigue vivo", vivo_al_cruzar)
	c2.queue_free()
	await quitar_rayos()
	j.vida.restaurar()
	await ticks(200) # acaba la voltereta

	# 5) Un golpe mientras apunta cancela el disparo.
	rayos_creados = 0
	var c3 := nuevo_ciclope(base + Vector2(-120, 0))
	await esperar_hasta(func() -> bool: return c3.estado == CiclopeSerpiente.Estado.APUNTAR and c3.sprite.frame >= 3, 300)
	ok("5) está apuntando", c3.estado == CiclopeSerpiente.Estado.APUNTAR and c3.sprite.frame < c3.frame_disparo,
		"estado=%d frame=%d" % [c3.estado, c3.sprite.frame])
	c3.vida.recibir_danio(1, c3.global_position + Vector2(10, 0))
	await ticks(2)
	ok("5) el golpe lo aturde (DANO)", c3.estado == CiclopeSerpiente.Estado.DANO, str(c3.estado))
	await ticks(60) # pasa el frame 13 de lo que habría sido su ataque
	ok("5) no dispara", rayos_creados == 0, "rayos=%d" % rayos_creados)
	ok("5) queda en ENFRIAMIENTO", c3.estado == CiclopeSerpiente.Estado.ENFRIAMIENTO, str(c3.estado))
	c3.queue_free()
	await quitar_rayos()

	# 6) Rayo contra una pared, y alcance. En una arena vacía.
	rayos_creados = 0
	var muro := StaticBody2D.new()
	muro.collision_layer = Capas.MUNDO
	muro.collision_mask = 0
	var forma := CollisionShape2D.new()
	var caja := RectangleShape2D.new()
	caja.size = Vector2(6, 60)
	forma.shape = caja
	muro.add_child(forma)
	game.add_child(muro)
	muro.global_position = ARENA + Vector2(30, 0)
	var libre := ESCENA_RAYO.instantiate() as RayoCiclope
	libre.direccion = Vector2.LEFT
	game.add_child(libre)
	libre.global_position = ARENA + Vector2(0, 100) # lejos del muro
	var contra := ESCENA_RAYO.instantiate() as RayoCiclope
	contra.direccion = Vector2.RIGHT
	game.add_child(contra)
	contra.global_position = ARENA
	await ticks(10)
	ok("6) sin obstáculos el rayo sigue (control)", is_instance_valid(libre), "")
	await ticks(30) # 45 px a 1,5 px/tick: el muro (x 27–33) está a 27 px
	ok("6) contra una pared desaparece", not is_instance_valid(contra))
	await ticks(150) # alcance 220 px = 147 ticks
	ok("6) pasado su alcance desaparece", not is_instance_valid(libre))
	muro.queue_free()

	# 7) Invocado: invulnerable los primeros 0,5 s, derrotado al morir y sin monedas.
	var c4 := nuevo_ciclope(base + Vector2(-120, 0), true)
	c4.derrotado.connect(func() -> void: derrotados[0] += 1)
	await ticks(2)
	ok("7) invocado empieza en APARECER", c4.estado == CiclopeSerpiente.Estado.APARECER, str(c4.estado))
	ok("7) transparente al empezar", c4.sprite.modulate.a < 0.5, str(c4.sprite.modulate.a))
	ok("7) sin Hurtbox ni Contacto mientras aparece", not c4.hurtbox.activo and not c4.contacto.activo)
	c4.hurtbox.recibir_golpe(1, c4.global_position)
	await ticks(2)
	ok("7) un golpe al aparecer no le hace daño", c4.vida.vida == c4.vida.vida_max, "%d/%d" % [c4.vida.vida, c4.vida.vida_max])
	await esperar_hasta(func() -> bool: return c4.estado != CiclopeSerpiente.Estado.APARECER, 200)
	ok("7) tras aparecer ya es vulnerable", c4.hurtbox.activo and c4.contacto.activo and is_equal_approx(c4.sprite.modulate.a, 1.0))
	ok("7) y no suelta monedas (Muerte.monedas = 0)", c4.muerte.monedas == 0)
	var sueltas := monedas_en_suelo()
	c4.vida.recibir_danio(c4.vida.vida_max, c4.global_position + Vector2(10, 0))
	await ticks(2)
	ok("7) emite `derrotado` al morir (y una sola vez)", derrotados[0] == 1 and c4.estado == CiclopeSerpiente.Estado.MUERTA, "derrotados=%d" % derrotados[0])
	await ticks(90)
	ok("7) invocado: 0 monedas", monedas_en_suelo() == sueltas, "%d -> %d" % [sueltas, monedas_en_suelo()])
	await quitar_rayos()

	# 8) Uno normal suelta 1 moneda y también emite `derrotado`; `aparecer()` por código.
	var c5 := nuevo_ciclope(base + Vector2(-120, 0))
	c5.set_physics_process(false)
	c5.derrotado.connect(func() -> void: derrotados[1] += 1)
	sueltas = monedas_en_suelo()
	c5.vida.recibir_danio(c5.vida.vida_max, c5.global_position + Vector2(10, 0))
	await ticks(90)
	ok("8) normal: `derrotado` y 1 moneda", derrotados[1] == 1 and monedas_en_suelo() == sueltas + 1, "d=%d monedas=%d" % [derrotados[1], monedas_en_suelo() - sueltas])
	var c6 := nuevo_ciclope(base + Vector2(-120, 0))
	c6.aparecer()
	await ticks(2)
	ok("8) aparecer() por código: APARECER, invocado y sin monedas",
		c6.estado == CiclopeSerpiente.Estado.APARECER and c6.invocado and c6.muerte.monedas == 0)
	c6.queue_free()
	await quitar_rayos()
