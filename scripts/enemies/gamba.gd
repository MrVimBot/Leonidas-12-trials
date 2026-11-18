class_name Gamba
extends CharacterBody2D
## Gamba del nivel 2 (Guión p. 35). Enemigo básico que se encuentra EN GRUPO (3–5 instancias
## juntas): deambula, al ver a Leonidas lo persigue y lo muerde de cerca. Débil, pero molesta.
## Cerebro: decide QUÉ hacer; el CÓMO está en los componentes (Paseo, Movimiento, Ataque…).
## Es arte pintado de una sola vista (mira a la izquierda): solo se orienta a los lados.
## La posición del nodo son los pies.

enum Estado { DEAMBULAR, PERSEGUIR, ATACAR, RECARGA, DANO, MUERTA }

@export_group("Movimiento")
@export var velocidad_deambular := 30.0
@export var velocidad_perseguir := 60.0
## Distancia máxima a su punto de inicio mientras deambula (se pasa al componente Paseo).
@export var radio_deambular := 40.0

@export_group("Mordisco")
## Muerde si Leonidas está a menos de esto en horizontal y de `alcance_vertical` en vertical.
@export var distancia_morder := 20.0
@export var alcance_vertical := 10.0
## Segundos quieta tras morder.
@export var recarga := 0.8

@export_group("Grupo")
## Cada gamba persigue un punto desplazado como mucho esto (px) del jugador, para que no se
## amontonen. Cerca de Leonidas (`distancia_sin_desfase`) apuntan directamente a él.
@export var desfase_maximo := Vector2(12, 6)
@export var distancia_sin_desfase := 28.0
## Al perseguir se apartan de otras gambas más cercanas que esto (px; en vertical cuenta el
## doble porque el dibujo es más ancho que alto). Hace falta además del choque de los cuerpos:
## la colisión es solo la base (18×6) y el dibujo mide 47×30, así que sin esto se ven apiladas.
@export var distancia_separacion := 34.0
## Peso de la separación frente a la dirección hacia Leonidas.
@export var fuerza_separacion := 3.0

@export_group("Daño")
@export var empuje_dano := 120.0
@export var tiempo_aturdida := 0.3

## 0 = aleatoria. Con valor fijo, el desfase, el paseo y el fotograma inicial son repetibles.
@export var semilla := 0

var estado: Estado = Estado.DEAMBULAR

var _rng := RandomNumberGenerator.new()
var _desfase := Vector2.ZERO
var _espera := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var movimiento: ComponenteMovimiento = $Movimiento
@onready var animador: AnimadorDireccional = $Animador
@onready var vida: ComponenteVida = $Vida
@onready var deteccion: ComponenteDeteccion = $Deteccion
@onready var ataque: ComponenteAtaque = $Ataque
@onready var parpadeo: ComponenteParpadeo = $Parpadeo
@onready var paseo: ComponentePaseo = $Paseo
@onready var colision: CollisionShape2D = $Colision


func _ready() -> void:
	if semilla != 0:
		_rng.seed = semilla
		paseo.rng.seed = semilla + 1
	else:
		_rng.randomize()
	# Las gambas NO chocan entre sí (máscara solo mundo, como la base): si dos cuerpos empiezan
	# solapados, el choque las deja bloqueadas una contra otra. Se reparten con `_separacion()`,
	# una fuerza suave que nunca bloquea.
	paseo.centro = global_position
	paseo.radio = radio_deambular
	paseo.velocidad = velocidad_deambular
	# Que un grupo no se pare y arranque a la vez: primera espera y fotograma al azar.
	paseo.activar(Vector2(0.2, 1.5))
	animador.direccion = Vector2.LEFT
	animador.reproducir(&"parado")
	sprite.frame = _rng.randi() % sprite.sprite_frames.get_frame_count(sprite.animation)
	vida.danado.connect(_al_recibir_danio)
	vida.murio.connect(_al_morir)
	ataque.termino.connect(_al_terminar_mordisco)
	movimiento.choco.connect(_al_chocar)


func _physics_process(delta: float) -> void:
	match estado:
		Estado.DEAMBULAR:
			_deambular(delta)
		Estado.PERSEGUIR:
			_perseguir(delta)
		Estado.ATACAR:
			movimiento.frenar(delta)
		Estado.RECARGA:
			# Quieta tras morder, pero apartándose de las vecinas (si no, el grupo se queda
			# amontonado en el sitio del mordisco).
			var sep := _separacion()
			if sep.length() > 0.1:
				movimiento.mover(sep.normalized(), delta, velocidad_deambular)
			else:
				movimiento.frenar(delta)
			_espera -= delta
			if _espera <= 0.0:
				_volver_a_andar()
		Estado.DANO:
			movimiento.frenar(delta, 0.6)
			_espera -= delta
			if _espera <= 0.0:
				_volver_a_andar()
		_:
			movimiento.frenar(delta)


func _deambular(delta: float) -> void:
	if deteccion.viendo():
		_empezar_a_perseguir()
		return
	paseo.actualizar(delta)
	if paseo.andando:
		_mirar_x(paseo.hacia.x)
		animador.reproducir(&"caminar")
	else:
		animador.reproducir(&"parado")


func _empezar_a_perseguir() -> void:
	estado = Estado.PERSEGUIR
	_desfase = Vector2(
		_rng.randf_range(-desfase_maximo.x, desfase_maximo.x),
		_rng.randf_range(-desfase_maximo.y, desfase_maximo.y))


func _perseguir(delta: float) -> void:
	if not deteccion.viendo():
		estado = Estado.DEAMBULAR
		paseo.activar(Vector2(0.2, 1.0))
		return
	var v := deteccion.vector_hacia()
	_mirar_x(v.x)
	if absf(v.x) < distancia_morder and absf(v.y) < alcance_vertical:
		_morder()
		return
	# Lejos apunta a su punto desplazado; cerca, directo a Leonidas.
	var meta := v if v.length() < distancia_sin_desfase else v + _desfase
	if meta.length() < 2.0:
		movimiento.frenar(delta)
		animador.reproducir(&"parado")
		return
	var direccion := meta.normalized() + _separacion() * fuerza_separacion
	movimiento.mover(direccion.normalized(), delta, velocidad_perseguir)
	animador.reproducir(&"caminar")


## Empuje para alejarse de las gambas vecinas (0 si no hay ninguna cerca). Grupos de 3–5:
## recorrer el grupo `enemigos` cada tick es barato.
func _separacion() -> Vector2:
	var empuje := Vector2.ZERO
	for otro in get_tree().get_nodes_in_group(&"enemigos"):
		if otro == self or not otro is Gamba:
			continue
		var d: Vector2 = global_position - (otro as Gamba).global_position
		d.y *= 2.0
		var l := d.length()
		if l > 0.01 and l < distancia_separacion:
			empuje += d / l * (1.0 - l / distancia_separacion)
	return empuje


func _morder() -> void:
	estado = Estado.ATACAR
	movimiento.detener()
	_mirar_x(deteccion.vector_hacia().x) # el golpe usa la forma del lado al que mira
	ataque.atacar()


func _al_terminar_mordisco() -> void:
	if estado != Estado.ATACAR:
		return
	estado = Estado.RECARGA
	_espera = recarga
	animador.reproducir(&"parado", true)


func _volver_a_andar() -> void:
	if deteccion.viendo():
		_empezar_a_perseguir()
	else:
		estado = Estado.DEAMBULAR
		paseo.activar(Vector2(0.2, 1.0))


## Solo mira a los lados: el arte tiene una sola vista (izquierda) y el golpe solo tiene
## formas Izquierda/Derecha. Con una diferencia pequeña mantiene el lado.
func _mirar_x(dx: float) -> void:
	if absf(dx) > 1.0:
		animador.mirar(Vector2(signf(dx), 0))


func _al_chocar(_colision: KinematicCollision2D) -> void:
	if estado == Estado.DEAMBULAR:
		paseo.al_chocar()


func _al_recibir_danio(_cantidad: int, origen: Vector2) -> void:
	if vida.muerto:
		return
	parpadeo.parpadear(vida.tiempo_invulnerable())
	ataque.cancelar()
	estado = Estado.DANO
	_espera = tiempo_aturdida
	animador.reproducir(&"parado")
	movimiento.empujar_desde(origen, empuje_dano)


func _al_morir() -> void:
	estado = Estado.MUERTA
	ataque.cancelar()
	parpadeo.detener()
	movimiento.detener()
	colision.set_deferred(&"disabled", true) # muerta no empuja a las demás
