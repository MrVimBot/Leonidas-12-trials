class_name ObjetoSuelto
extends Area2D
## Algo suelto en el suelo que el jugador recoge al pisarlo: monedas (las sueltan los
## enemigos al morir, `ComponenteMuerte`) o un objeto del inventario (las manzanas del
## manzano, `ComponenteManzano`). Sale con un salto y rebota un par de veces; cuando ya
## está en el suelo, se recoge al pisarlo. Si nadie lo recoge, parpadea y desaparece a
## los `duracion` s.
##
## Una sola clase para los dos casos: lo único que cambia es lo que da (`objeto`), y eso
## es un dato, no un comportamiento distinto. Cada uno tiene su escena
## (scenes/items/moneda.tscn, manzana_suelta.tscn) con su sprite y su `objeto`.
##
## La posición del nodo es el punto del suelo bajo el objeto (como los pies del jugador):
## el sprite sube y baja con `_altura` y la sombra se queda en el suelo.
## Área: capa 0, máscara jugador (2).

## Qué da al recogerlo. Vacío = monedas.
@export var objeto: Objeto
## Cuántas monedas (o unidades de `objeto`) da.
@export var valor := 1
## Segundos en el suelo antes de desaparecer (0 = nunca).
@export var duracion := 10.0
## Los últimos segundos parpadea para avisar.
@export var tiempo_parpadeo := 3.0
@export var gravedad := 520.0
## Cuánto conserva la velocidad vertical en cada rebote.
@export var rebote := 0.45

var velocidad := Vector2.ZERO
var _altura := 0.0
var _vel_altura := 0.0
var _en_suelo := false
var _recogida := false
var _tiempo := 0.0

## Puede ser un AnimatedSprite2D (la moneda, gira) o un Sprite2D (la manzana).
@onready var sprite: Node2D = $Sprite
@onready var sombra: CanvasItem = $Sombra


## Suelta `cantidad` instancias de `escena` (una escena con ObjetoSuelto en la raíz) que
## saltan desde `posicion` (coordenadas globales). La escena la pasa quien suelta (un
## `@export` suyo) para que este script no dependa de sus propias escenas.
## Se añaden diferidas: se puede llamar desde una señal de física.
static func soltar(escena: PackedScene, padre: Node, posicion: Vector2, cantidad: int) -> void:
	var angulo_base := randf() * TAU
	for i in cantidad:
		var o := escena.instantiate() as ObjetoSuelto
		# Repartidos alrededor; uno solo sale casi en vertical.
		var angulo := angulo_base + TAU * i / cantidad + randf_range(-0.4, 0.4)
		var rapidez := randf_range(8.0, 16.0) if cantidad == 1 else randf_range(22.0, 38.0)
		o.velocidad = Vector2.from_angle(angulo) * rapidez
		o._vel_altura = randf_range(120.0, 150.0)
		o.position = posicion
		padre.add_child.call_deferred(o)
		o.set_deferred(&"global_position", posicion)


func _ready() -> void:
	var animado := sprite as AnimatedSprite2D
	if animado:
		animado.play(&"girar")
		animado.frame = randi() % animado.sprite_frames.get_frame_count(&"girar")
	_actualizar_sprite()


func _physics_process(delta: float) -> void:
	if _recogida:
		return
	if not _en_suelo:
		_volar(delta)
		return
	_tiempo += delta
	if duracion > 0.0:
		var resta := duracion - _tiempo
		if resta <= 0.0:
			queue_free()
			return
		if resta < tiempo_parpadeo:
			sprite.visible = fmod(resta, 0.2) > 0.1
	# Se consulta cada tick en vez de usar `body_entered` a propósito: el jugador puede
	# estar ya encima cuando el objeto aterriza (no habría entrada nueva), y si el premio no
	# cabe en el inventario hay que reintentarlo mientras siga encima.
	for cuerpo in get_overlapping_bodies():
		if cuerpo is Jugador:
			if _dar():
				_recoger()
			return


func _volar(delta: float) -> void:
	# Movimiento por el suelo: si algo sólido se interpone, rebota contra ello.
	var paso := velocidad * delta
	if paso != Vector2.ZERO:
		var consulta := PhysicsRayQueryParameters2D.create(global_position, global_position + paso, Capas.MUNDO)
		var choque := get_world_2d().direct_space_state.intersect_ray(consulta)
		if choque:
			var normal: Vector2 = choque.normal
			velocidad = velocidad.bounce(normal) * 0.5
			paso = Vector2.ZERO
	global_position += paso
	# Altura: salto con gravedad y rebotes cada vez más bajos.
	_vel_altura -= gravedad * delta
	_altura += _vel_altura * delta
	if _altura <= 0.0:
		_altura = 0.0
		_vel_altura = -_vel_altura * rebote
		velocidad *= 0.5
		if _vel_altura < 30.0:
			_en_suelo = true
			velocidad = Vector2.ZERO
			_vel_altura = 0.0
	_actualizar_sprite()


func _actualizar_sprite() -> void:
	# En píxeles enteros para que no se vea borroso.
	sprite.position.y = -roundf(_altura)


## Entrega el premio al jugador. Devuelve false si no puede llevarlo (se queda en el suelo).
func _dar() -> bool:
	if objeto == null:
		EstadoJuego.agregar_monedas(valor)
		return true
	return EstadoJuego.agregar_objeto(objeto.id, valor)


func _recoger() -> void:
	_recogida = true
	set_deferred(&"monitoring", false)
	# TODO: sonido al recoger cuando haya audio.
	sprite.visible = true
	sombra.visible = false
	var t := create_tween()
	t.tween_property(sprite, ^"position:y", sprite.position.y - 14.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(sprite, ^"modulate:a", 0.0, 0.25).set_delay(0.1)
	t.tween_callback(queue_free)
