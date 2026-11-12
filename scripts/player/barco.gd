class_name Barco
extends CharacterBody2D
## Leonidas en barco (minijuego del mar). Cerebro: decide QUÉ hacer; los componentes
## hijos hacen el CÓMO. Lo crea Game cuando la zona tiene `modo_barco = true`;
## mientras se navega el Jugador queda oculto y desactivado.
##
## Dirección: el movimiento normal (WASD / flechas / mando).
## Velocidad: soplar al micrófono (autoload Microfono) o mantener Espacio/K (`pirueta`).
## Sin soplar avanza despacio (`velocidad_remo`) para no quedarse nunca atascado.
## Sin ataque. Chocar fuerte con rocas, remolinos y tiburones quita vida AL BARCO.
## Posición del nodo = base del casco.

signal hundido

enum Estado { NAVEGANDO, DANO, HUNDIDO, BLOQUEADO }

@export_group("Navegación")
## Velocidad solo con la dirección, sin soplar.
@export var velocidad_remo := 30.0
## Velocidad soplando al máximo.
@export var velocidad_viento := 120.0
## Por debajo de esto el soplido no cuenta (ruido).
@export var umbral_soplo := 0.08

@export_group("Choques")
## Chocar más rápido que esto contra una roca o el arrecife quita vida.
@export var velocidad_choque := 70.0
## Cuartos de corazón.
@export var danio_choque := 1
@export var rebote := 60.0
@export var empuje_dano := 90.0
@export var duracion_dano := 0.3

var estado := Estado.NAVEGANDO
## Última dirección elegida: el soplido sin dirección empuja hacia aquí.
var rumbo := Vector2.DOWN

var _vel_previa := Vector2.ZERO
var _tiempo_dano := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var movimiento: ComponenteMovimiento = $Movimiento
@onready var animador: AnimadorDireccional = $Animador
@onready var vida: ComponenteVida = $Vida
@onready var parpadeo: ComponenteParpadeo = $Parpadeo
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var estela: CPUParticles2D = get_node_or_null(^"Estela") as CPUParticles2D


func _ready() -> void:
	add_to_group(&"barco")
	vida.danado.connect(_al_recibir_danio)
	vida.murio.connect(_al_hundirse)
	movimiento.choco.connect(_al_chocar)
	animador.mirar(rumbo)
	_reproducir(&"barco_quieto")


func _physics_process(delta: float) -> void:
	match estado:
		Estado.NAVEGANDO:
			_navegar(delta)
		Estado.DANO:
			movimiento.frenar(delta, 0.6)
			_tiempo_dano -= delta
			if _tiempo_dano <= 0.0:
				estado = Estado.NAVEGANDO
		Estado.HUNDIDO, Estado.BLOQUEADO:
			movimiento.detener()
	_animar()
	_vel_previa = velocity # el componente mueve después (los hijos se procesan tras el padre)


func _navegar(delta: float) -> void:
	var entrada := Input.get_vector(&"mover_izquierda", &"mover_derecha", &"mover_arriba", &"mover_abajo")
	if entrada != Vector2.ZERO:
		rumbo = entrada.normalized()
		animador.orientar(entrada)
	var soplo := soplido()
	if entrada != Vector2.ZERO:
		movimiento.mover(entrada, delta, lerpf(velocidad_remo, velocidad_viento, soplo))
	elif soplo > 0.0:
		movimiento.mover(rumbo, delta, velocidad_viento * soplo)
	else:
		movimiento.frenar(delta) # fricción baja: deriva


## Fuerza del soplido (0..1) que usa el barco; también la lee el HUD.
func soplido() -> float:
	var s := Microfono.nivel_efectivo()
	if Input.is_action_pressed(&"pirueta"):
		s = 1.0
	return s if s >= umbral_soplo else 0.0


func _animar() -> void:
	if estado == Estado.HUNDIDO:
		return
	var rapidez := velocity.length()
	if rapidez > 8.0 and estado != Estado.BLOQUEADO:
		_reproducir(&"barco_moviendo")
		sprite.speed_scale = lerpf(0.6, 1.6, clampf(rapidez / velocidad_viento, 0.0, 1.0))
	else:
		_reproducir(&"barco_quieto")
		sprite.speed_scale = 1.0
	if estela:
		estela.emitting = rapidez > 40.0 and estado == Estado.NAVEGANDO


## Las vistas laterales del barco están dibujadas mirando a la DERECHA (el resto de
## `leonidas_mini` mira a la izquierda): se invierte el espejo del animador.
func _reproducir(base: StringName) -> void:
	animador.reproducir(base)
	if animador.sufijo() == "lado":
		sprite.flip_h = not sprite.flip_h


func _al_chocar(colision: KinematicCollision2D) -> void:
	if estado != Estado.NAVEGANDO or colision.get_collider() is Barco:
		return
	if _vel_previa.length() <= velocidad_choque or vida.es_invulnerable():
		return
	var normal := colision.get_normal()
	vida.recibir_danio(danio_choque, colision.get_position())
	if not vida.muerto:
		velocity = normal * rebote


func _al_recibir_danio(_cantidad: int, origen: Vector2) -> void:
	if vida.muerto:
		return
	estado = Estado.DANO
	_tiempo_dano = duracion_dano
	parpadeo.parpadear(vida.tiempo_invulnerable())
	movimiento.empujar_desde(origen, empuje_dano, -rumbo)


func _al_hundirse() -> void:
	estado = Estado.HUNDIDO
	parpadeo.detener()
	movimiento.detener()
	hurtbox.set_deferred(&"monitorable", false)
	if estela:
		estela.emitting = false
	_reproducir(&"barco_quieto")
	var t := create_tween().set_parallel()
	t.tween_property(sprite, ^"position:y", sprite.position.y + 6.0, 0.8)
	t.tween_property(sprite, ^"modulate:a", 0.0, 0.8)
	await t.finished
	hundido.emit()


func set_bloqueado(bloqueado: bool) -> void:
	if estado == Estado.HUNDIDO:
		return
	estado = Estado.BLOQUEADO if bloqueado else Estado.NAVEGANDO
	if bloqueado:
		movimiento.detener()
		_reproducir(&"barco_quieto")


## Fija el rumbo y la orientación inicial (al aparecer en una entrada).
func mirar(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	rumbo = dir.normalized()
	if animador:
		animador.mirar(dir)
		_reproducir(&"barco_quieto")
