extends "res://tools/pruebas/base_prueba.gd"
## Formas del golpe de `ComponenteAtaque` por dirección (tarea F5 de
## docs/plan/05_componentes_y_fisica.md): jugador en las 4 direcciones y falsa flor a izquierda y
## derecha (y abajo/arriba, que no usa: respaldo), cada uno instanciado suelto (sin game.tscn) en
## una posición fija. También: sin avisos de configuración y ninguna forma habilitada antes de atacar.
## Para cada ataque comprueba, en el primer fotograma en que el Hitbox está activo: el rectángulo
## global de la forma que golpea (centro y tamaño), que solo cuenta UNA forma, el daño y en qué
## ticks está activo. Después repite el ataque con sondas (StaticBody2D de 2×2 que registran
## `recibir_golpe`) justo dentro y justo fuera de cada borde del rectángulo y en el centro, y
## comprueba que solo golpea las de dentro.
## Las líneas `CARACT` son la caracterización: si cambian, cambió el combate.
## Valores esperados = los del antiguo diccionario `formas` (centro relativo a los pies, tamaño).

## Sonda: registra los golpes que recibe.
class Sonda extends StaticBody2D:
	var etiqueta := ""
	var golpes := 0

	func recibir_golpe(_danio: int, _origen: Vector2) -> void:
		golpes += 1


const POS_JUGADOR := Vector2(200, 200)
const POS_FLOR := Vector2(600, 200)

## Centro (relativo a los pies) y tamaño esperados por dirección.
const ESPERADO_JUGADOR := {
	Vector2.DOWN: Rect2(0, 2, 22, 14),
	Vector2.UP: Rect2(0, -24, 22, 14),
	Vector2.LEFT: Rect2(-15, -10, 16, 20),
	Vector2.RIGHT: Rect2(15, -10, 16, 20),
}
const ESPERADO_FLOR := {
	Vector2.LEFT: Rect2(-13, -10, 20, 16),
	Vector2.RIGHT: Rect2(13, -10, 20, 16),
	# La flor solo mira a los lados; abajo/arriba (no se usan) caen en el respaldo.
	Vector2.DOWN: Rect2(-13, -10, 20, 16),
	Vector2.UP: Rect2(-13, -10, 20, 16),
}

var raiz: Node2D
var flor: FlorFalsa
## Ticks de física desde el comienzo del ataque.
var _tick := 0


func ejecutar() -> void:
	raiz = Node2D.new()
	get_tree().root.add_child(raiz)
	EstadoJuego.reiniciar()
	EstadoJuego.tiene_espada = true
	j = (load("res://scenes/player/jugador.tscn") as PackedScene).instantiate() as Jugador
	j.position = POS_JUGADOR
	raiz.add_child(j)
	flor = (load("res://scenes/enemies/flor_falsa.tscn") as PackedScene).instantiate() as FlorFalsa
	flor.position = POS_FLOR
	raiz.add_child(flor)
	await ticks(10)
	ok("jugador: sin avisos de configuración en el Ataque", j.ataque._get_configuration_warnings().is_empty(), str(j.ataque._get_configuration_warnings()))
	ok("flor: sin avisos de configuración en el Ataque", flor.ataque._get_configuration_warnings().is_empty(), str(flor.ataque._get_configuration_warnings()))
	ok("jugador: en juego, antes de atacar, ninguna forma habilitada", _datos_formas(j.ataque.hitbox).begins_with("habilitadas=0 "))
	# La flor no decide nada durante la prueba: MORDER no hace nada en su `_physics_process`.
	flor.estado = FlorFalsa.Estado.MORDER

	for dir: Vector2 in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		await _probar("jugador", j, j.ataque, dir, ESPERADO_JUGADOR[dir], 32)
	for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN, Vector2.UP]:
		await _probar("flor", flor, flor.ataque, dir, ESPERADO_FLOR[dir], 2)
	raiz.queue_free()
	EstadoJuego.reiniciar()
	await ticks(2)


## Lanza un ataque de `quien` mirando a `dir`. Con el jugador, con la acción real `atacar`.
func _lanzar(quien: Node2D, ataque: ComponenteAtaque, dir: Vector2) -> void:
	ataque.animador.mirar(dir)
	if quien == j:
		await get_tree().process_frame
		accion(&"atacar", true)
		var n := 0
		while not ataque.atacando and n < 30:
			n += 1
			await get_tree().physics_frame
		accion(&"atacar", false)
	else:
		ataque.atacar()


## Espera al final del ataque registrando en qué ticks está activo el Hitbox. Devuelve
## [ticks activos, datos del primer tick activo].
func _seguir(ataque: ComponenteAtaque) -> Array:
	var activos: Array[int] = []
	var datos := ""
	_tick = 0
	while ataque.atacando and _tick < 600:
		await get_tree().physics_frame
		_tick += 1
		if ataque.hitbox.activo:
			activos.append(_tick)
			if datos.is_empty():
				datos = _datos_formas(ataque.hitbox)
	return [activos, datos]


## Formas habilitadas del Hitbox: cuántas, y de cada una centro global, tamaño y transform.
func _datos_formas(hb: Hitbox) -> String:
	var partes: Array[String] = []
	for c in hb.get_children():
		var f := c as CollisionShape2D
		if f == null or f.disabled or f.shape == null:
			continue
		var r := f.shape as RectangleShape2D
		partes.append("centro=%s tam=%s xform=%s" % [f.global_position, r.size, f.global_transform])
	return "habilitadas=%d danio=%d %s" % [partes.size(), hb.danio, " | ".join(partes)]


## Centro global de la única forma habilitada (o INF).
func _centro_activo(hb: Hitbox) -> Rect2:
	for c in hb.get_children():
		var f := c as CollisionShape2D
		if f and not f.disabled and f.shape:
			return Rect2(f.global_position, (f.shape as RectangleShape2D).size)
	return Rect2(Vector2.INF, Vector2.ZERO)


func _probar(nombre: String, quien: Node2D, ataque: ComponenteAtaque, dir: Vector2, esperado: Rect2, capa: int) -> void:
	var et := "%s %s" % [nombre, dir]
	# 1) Geometría y ticks activos.
	await _lanzar(quien, ataque, dir)
	var res := await _seguir(ataque)
	var activos: Array[int] = res[0]
	print("CARACT %s activo_ticks=%s %s" % [et, activos, res[1]])
	var r := _centro_activo(ataque.hitbox)
	ok("%s: centro y tamaño" % et, r.position == quien.global_position + esperado.position and r.size == esperado.size, str(r))
	ok("%s: una sola forma habilitada" % et, (res[1] as String).begins_with("habilitadas=1 "), res[1])
	await ticks(10)

	# 2) Sondas: centro, justo dentro (a 2 px del borde) y justo fuera (a 2 px) de cada borde.
	var c := quien.global_position + esperado.position
	var m := esperado.size / 2.0
	var puntos := {
		"centro": c,
		"dentro_izq": c + Vector2(-m.x + 2, 0), "fuera_izq": c + Vector2(-m.x - 2, 0),
		"dentro_der": c + Vector2(m.x - 2, 0), "fuera_der": c + Vector2(m.x + 2, 0),
		"dentro_arr": c + Vector2(0, -m.y + 2), "fuera_arr": c + Vector2(0, -m.y - 2),
		"dentro_aba": c + Vector2(0, m.y - 2), "fuera_aba": c + Vector2(0, m.y + 2),
	}
	var sondas: Array[Sonda] = []
	for k: String in puntos:
		var s := Sonda.new()
		s.etiqueta = k
		s.collision_layer = capa
		s.collision_mask = 0
		var forma := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(2, 2)
		forma.shape = rect
		s.add_child(forma)
		s.global_position = puntos[k]
		raiz.add_child(s)
		sondas.append(s)
	await ticks(2)
	await _lanzar(quien, ataque, dir)
	await _seguir(ataque)
	var golpeadas: Array[String] = []
	for s in sondas:
		if s.golpes > 0:
			golpeadas.append("%s×%d" % [s.etiqueta, s.golpes])
		s.queue_free()
	print("CARACT %s sondas_golpeadas=%s" % [et, golpeadas])
	var bien := golpeadas.size() == 5
	for g in golpeadas:
		if not (g.begins_with("centro×1") or g.begins_with("dentro_") and g.ends_with("×1")):
			bien = false
	ok("%s: golpea solo dentro (una vez cada sonda)" % et, bien, str(golpeadas))
	await ticks(10)
