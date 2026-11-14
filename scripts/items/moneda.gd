class_name Moneda
extends Area2D
## Moneda suelta en el suelo (la sueltan los enemigos al morir: `ComponenteMuerte`).
## Sale con un salto y rebota un par de veces; cuando ya está en el suelo, el jugador
## la recoge al pisarla. Si nadie la recoge, parpadea y desaparece a los `duracion` s.
##
## La posición del nodo es el punto del suelo bajo la moneda (como los pies del jugador):
## el sprite sube y baja con `_altura` y la sombra se queda en el suelo.
## Área: capa 0, máscara jugador (2).

const ESCENA := preload("res://scenes/items/moneda.tscn")
const CAPA_MUNDO := 1

## Monedas que da al recogerla.
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

@onready var sprite: AnimatedSprite2D = $Sprite


## Suelta `cantidad` monedas que saltan desde `posicion` (coordenadas globales).
## Se añaden diferidas: se puede llamar desde una señal de física.
static func soltar(padre: Node, posicion: Vector2, cantidad: int) -> void:
	var angulo_base := randf() * TAU
	for i in cantidad:
		var m := ESCENA.instantiate() as Moneda
		# Repartidas alrededor; una sola sale casi en vertical.
		var angulo := angulo_base + TAU * i / cantidad + randf_range(-0.4, 0.4)
		var rapidez := randf_range(8.0, 16.0) if cantidad == 1 else randf_range(22.0, 38.0)
		m.velocidad = Vector2.from_angle(angulo) * rapidez
		m._vel_altura = randf_range(120.0, 150.0)
		m.position = posicion
		padre.add_child.call_deferred(m)
		m.set_deferred(&"global_position", posicion)


func _ready() -> void:
	sprite.play(&"girar")
	sprite.frame = randi() % sprite.sprite_frames.get_frame_count(&"girar")
	_actualizar_sprite()


func _physics_process(delta: float) -> void:
	if _recogida:
		return
	if not _en_suelo:
		_volar(delta)
	else:
		_tiempo += delta
		if duracion > 0.0:
			var resta := duracion - _tiempo
			if resta <= 0.0:
				queue_free()
				return
			if resta < tiempo_parpadeo:
				sprite.visible = fmod(resta, 0.2) > 0.1
		for cuerpo in get_overlapping_bodies():
			if cuerpo is Jugador:
				_recoger()
				return


func _volar(delta: float) -> void:
	# Movimiento por el suelo: si algo sólido se interpone, rebota contra ello.
	var paso := velocidad * delta
	if paso != Vector2.ZERO:
		var consulta := PhysicsRayQueryParameters2D.create(global_position, global_position + paso, 1 << (CAPA_MUNDO - 1))
		var choque := get_world_2d().direct_space_state.intersect_ray(consulta)
		if choque:
			velocidad = velocidad.bounce(choque.normal) * 0.5
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
	# En píxeles enteros para que no se vea borrosa.
	sprite.position.y = -roundf(_altura)


func _recoger() -> void:
	_recogida = true
	set_deferred(&"monitoring", false)
	EstadoJuego.agregar_monedas(valor)
	# TODO: sonido de moneda cuando haya audio.
	sprite.visible = true
	$Sombra.visible = false
	var t := create_tween()
	t.tween_property(sprite, ^"position:y", sprite.position.y - 14.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(sprite, ^"modulate:a", 0.0, 0.25).set_delay(0.1)
	t.tween_callback(queue_free)
