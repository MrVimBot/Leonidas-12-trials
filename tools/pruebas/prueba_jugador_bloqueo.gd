extends "res://tools/pruebas/base_prueba.gd"
## Bloqueo del Jugador por motivos (`bloquear(motivo)` / `desbloquear(motivo)`):
##  a) bloquear a mitad de voltereta, de ataque o de comer limpia lo que había (invulnerabilidad,
##     espada, objeto devuelto) y un `desbloquear` de más no corta una voltereta;
##  b) varios motivos a la vez: solo se libera al quitar el último; la pose no se repinta;
##  c) daño estando bloqueado: no hace nada;
##  d) morir con un motivo activo: reaparece BLOQUEADO si queda alguno;
##  e) el cambio de zona mantiene BLOQUEADO durante todo el fundido.

var _muestras: Array[int] = []
var _muestreando := false


func _physics_process(_delta: float) -> void:
	if _muestreando:
		_muestras.append(j.estado)


func ejecutar() -> void:
	await crear_game(true, true)
	var B := Jugador.Estado.BLOQUEADO
	var N := Jugador.Estado.NORMAL
	ok("arranque en NORMAL, sin motivos", j.estado == N and not j.esta_bloqueado(), str(j.estado))

	# a) voltereta + bloqueo
	j.estamina.llenar()
	await pulsar(&"pirueta")
	await esperar_hasta(func() -> bool: return j.estado == Jugador.Estado.PIRUETA, 10)
	ok("a) (precondición) en PIRUETA", j.estado == Jugador.Estado.PIRUETA)
	j.bloquear(&"prueba")
	ok("a) bloqueado: estado BLOQUEADO e invulnerable", j.estado == B and j.vida.invulnerable_extra)
	ok("a) bloqueado: estamina no pausada, máscara capa 7 repuesta", not j.estamina.pausada and j.get_collision_mask_value(7))
	j.bloquear(&"prueba")
	ok("a) bloquear dos veces con el mismo motivo es inofensivo", j.estado == B and j.vida.invulnerable_extra)
	j.desbloquear(&"prueba")
	ok("a) desbloquear: NORMAL y sin invulnerabilidad", j.estado == N and not j.vida.invulnerable_extra
		and not j.estamina.pausada and j.get_collision_mask_value(7))
	# Un desbloqueo de más a mitad de voltereta no la corta.
	await ticks(60)
	j.estamina.llenar()
	await pulsar(&"pirueta")
	await esperar_hasta(func() -> bool: return j.estado == Jugador.Estado.PIRUETA, 10)
	j.desbloquear(&"prueba")
	ok("a) desbloquear sin estar bloqueado no corta la voltereta", j.estado == Jugador.Estado.PIRUETA and j.vida.invulnerable_extra)
	ok("a) la voltereta termina sola y limpia", await esperar_hasta(func() -> bool: return j.estado == N, 240)
		and not j.vida.invulnerable_extra and not j.estamina.pausada)

	# a) ataque + bloqueo en los frames de golpe
	await ticks(10)
	var espada := j.get_node(^"Espada") as Hitbox
	accion(&"atacar", true)
	var activa := await esperar_hasta(func() -> bool: return espada.activo, 120)
	accion(&"atacar", false)
	ok("a) (precondición) la espada llega a estar activa", activa)
	j.bloquear(&"prueba")
	ok("a) bloqueado: sin ataque y espada apagada", not j.ataque.atacando and not espada.activo)
	await ticks(60)
	ok("a) sigue BLOQUEADO al acabar la animación", j.estado == B)

	# c) daño estando bloqueado
	var antes := j.vida.vida
	j.vida.recibir_danio(2, Vector2.ZERO)
	await ticks(5)
	ok("c) bloqueado: la vida no baja ni cambia el estado", j.vida.vida == antes and j.estado == B)
	j.desbloquear(&"prueba")
	j.vida.recibir_danio(2, Vector2.ZERO)
	ok("c) desbloqueado: la vida baja y pasa a DANO", j.vida.vida == antes - 2 and j.estado == Jugador.Estado.DANO)
	await esperar_hasta(func() -> bool: return j.estado == N, 300)

	# a) comer + bloqueo: el objeto vuelve al inventario una sola vez
	var manzana := load("res://resources/objetos/manzana.tres") as Objeto
	EstadoJuego.agregar_objeto(manzana.id)
	var cantidad := EstadoJuego.cantidad(manzana.id)
	EstadoJuego.gastar_objeto(manzana.id) # como hace el libro antes de comer
	var vida_antes := j.vida.vida
	j.comer(manzana)
	await ticks(20)
	var en_mano := j.get_node(^"ObjetoEnMano") as Sprite2D
	ok("a) (precondición) comiendo con el objeto en la mano", j.estado == Jugador.Estado.COMER and en_mano.visible)
	j.bloquear(&"prueba")
	j.bloquear(&"prueba")
	ok("a) comer + bloquear: el objeto se devuelve una vez", EstadoJuego.cantidad(manzana.id) == cantidad,
		"%d (esperado %d)" % [EstadoJuego.cantidad(manzana.id), cantidad])
	ok("a) comer + bloquear: se oculta el objeto en mano", not en_mano.visible)
	await esperar(1.2)
	ok("a) comer + bloquear: no cura al acabar el temporizador", j.vida.vida == vida_antes)
	ok("a) comer + bloquear: sigue BLOQUEADO", j.estado == B)
	j.desbloquear(&"prueba")
	EstadoJuego.gastar_objeto(manzana.id)

	# b) varios motivos
	await ticks(5)
	j.bloquear(&"a")
	j.bloquear(&"b")
	ok("b) a + b → BLOQUEADO", j.estado == B and j.esta_bloqueado() and j.vida.invulnerable_extra)
	j.desbloquear(&"a")
	await ticks(3)
	ok("b) quitar a: sigue BLOQUEADO", j.estado == B and j.esta_bloqueado() and j.vida.invulnerable_extra)
	j.desbloquear(&"b")
	ok("b) quitar b → NORMAL sin invulnerabilidad", j.estado == N and not j.esta_bloqueado() and not j.vida.invulnerable_extra)
	j.desbloquear(&"x")
	ok("b) desbloquear un motivo que no estaba: nada", j.estado == N and not j.esta_bloqueado())
	# Bloquear con otro motivo estando ya bloqueado no repinta la pose (la de objeto obtenido se mantiene).
	j.bloquear(&"escena")
	j.mostrar_objeto_obtenido(null, 0.0)
	j.bloquear(&"dialogo")
	ok("b) segundo motivo no repinta la pose", j.animador.animacion_actual() == &"comer", str(j.animador.animacion_actual()))
	j.desbloquear(&"dialogo")
	ok("b) quitar un motivo con otro activo no repinta", j.animador.animacion_actual() == &"comer")
	j.ocultar_objeto_obtenido()
	j.desbloquear(&"escena")
	ok("b) todo quitado → NORMAL", j.estado == N and not j.esta_bloqueado())

	# d) morir con un motivo activo
	await ticks(5)
	j.vida.recibir_danio(100, j.global_position + Vector2.UP)
	ok("d) muere", j.estado == Jugador.Estado.MUERTO, str(j.estado))
	j.bloquear(&"escena")
	ok("d) bloquear muerto: sigue MUERTO (prioridad)", j.estado == Jugador.Estado.MUERTO and j.esta_bloqueado())
	await j.reaparecio
	await ticks(2)
	ok("d) reaparece BLOQUEADO si queda un motivo", j.estado == B and j.vida.invulnerable_extra and j.vida.vida == j.vida.vida_max, str(j.estado))
	j.desbloquear(&"escena")
	ok("d) al quitarlo → NORMAL", j.estado == N and not j.vida.invulnerable_extra)
	await ticks(130) # que pase la invulnerabilidad del parpadeo
	j.vida.recibir_danio(100, j.global_position + Vector2.UP)
	j.bloquear(&"escena")
	j.desbloquear(&"escena")
	ok("d) motivo puesto y quitado estando muerto: sigue MUERTO", j.estado == Jugador.Estado.MUERTO)
	await j.reaparecio
	await ticks(2)
	ok("d) reaparece NORMAL si ya no quedan motivos", j.estado == N and not j.vida.invulnerable_extra, str(j.estado))

	# e) cambio de zona
	await ticks(130)
	_muestras.clear()
	_muestreando = true
	await game.cambiar_zona("res://scenes/levels/bosque.tscn", "desde_pueblo")
	_muestreando = false
	ok("e) BLOQUEADO durante todo el fundido (%d ticks)" % _muestras.size(),
		_muestras.size() > 5 and _muestras.all(func(e: int) -> bool: return e == B))
	ok("e) NORMAL al acabar, sin motivos", j.estado == N and not j.esta_bloqueado(), str(j.estado))
	ok("e) en el bosque", game.ruta_zona.ends_with("bosque.tscn"))
	await ticks(5)
	j.bloquear(&"escena")
	_muestras.clear()
	_muestreando = true
	await game.cambiar_zona("res://scenes/levels/pueblo.tscn", "desde_bosque")
	_muestreando = false
	ok("e) con un motivo ajeno: BLOQUEADO durante el cambio", _muestras.all(func(e: int) -> bool: return e == B))
	await ticks(5)
	ok("e) con un motivo ajeno: sigue BLOQUEADO al acabar", j.estado == B and j.esta_bloqueado(), str(j.estado))
	j.desbloquear(&"escena")
	ok("e) al quitar el motivo → NORMAL", j.estado == N)
