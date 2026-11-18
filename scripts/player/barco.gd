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
## Está en el grupo "barco" (asignado en barco.tscn): lo ven los tiburones
## (`ComponenteDeteccion.grupo`). Para el barco actual, `Game.actual(self).barco`.

signal hundido

enum Estado { NAVEGANDO, DANO, HUNDIDO, BLOQUEADO }

@export_group("Navegación")
## Velocidad solo con la dirección, sin soplar.
@export var velocidad_remo := 30.0
## Velocidad soplando al máximo.
@export var velocidad_viento := 120.0
## Por debajo de esto el soplido no cuenta (ruido).
@export var umbral_soplo := 0.08

@export_group("Sonido")
## Se oye con cada golpe que recibe el barco (choque, tiburón, remolino), también el que lo hunde.
@export var sonido_golpe: AudioStreamPlayer

@export_group("Animación")
## Por encima de esta rapidez (px/s) se anima el barco en marcha; por debajo, quieto.
@export var umbral_movimiento := 8.0
## Por encima de esta rapidez (px/s) la estela emite espuma.
@export var umbral_estela := 40.0
## Velocidad de la animación (`speed_scale`) en el umbral y a máxima velocidad.
@export var velocidad_anim_min := 0.6
@export var velocidad_anim_max := 1.6

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
## Motivos de bloqueo (&"zona", &"escena"...), como en `Jugador`: cada sistema quita solo
## el suyo. Solo se usan las claves (un conjunto).
var _motivos_bloqueo: Dictionary[StringName, bool] = {}

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var movimiento: ComponenteMovimiento = $Movimiento
@onready var animador: AnimadorDireccional = $Animador
@onready var vida: ComponenteVida = $Vida
@onready var parpadeo: ComponenteParpadeo = $Parpadeo
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var estela: CPUParticles2D = $Estela


func _ready() -> void:
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
				# Golpeado estando bloqueado (no es invulnerable): vuelve a quedarse quieto.
				estado = Estado.BLOQUEADO if esta_bloqueado() else Estado.NAVEGANDO
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
	if rapidez > umbral_movimiento and estado != Estado.BLOQUEADO:
		_reproducir(&"barco_moviendo")
		sprite.speed_scale = lerpf(velocidad_anim_min, velocidad_anim_max, clampf(rapidez / velocidad_viento, 0.0, 1.0))
	else:
		_reproducir(&"barco_quieto")
		sprite.speed_scale = 1.0
	estela.emitting = rapidez > umbral_estela and estado == Estado.NAVEGANDO


## Las vistas laterales del barco están dibujadas mirando a la DERECHA (el resto de
## `leonidas_mini` mira a la izquierda): se invierte el espejo del animador.
func _reproducir(base: StringName) -> void:
	animador.reproducir(base, false, true)


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
	if sonido_golpe:
		sonido_golpe.play()
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
	estela.emitting = false
	_reproducir(&"barco_quieto")
	var t := create_tween().set_parallel()
	t.tween_property(sprite, ^"position:y", sprite.position.y + 6.0, 0.8)
	t.tween_property(sprite, ^"modulate:a", 0.0, 0.8)
	await t.finished
	hundido.emit()


## Bloquea el barco por `motivo` (quieto) hasta que se quite el último motivo. Repetir
## un motivo no hace nada. Hundido, solo se apunta (HUNDIDO tiene prioridad).
func bloquear(motivo: StringName) -> void:
	_motivos_bloqueo[motivo] = true
	if estado == Estado.HUNDIDO or estado == Estado.BLOQUEADO:
		return
	estado = Estado.BLOQUEADO
	movimiento.detener()
	_reproducir(&"barco_quieto")


## Quita `motivo`; al quitar el último vuelve a navegar.
func desbloquear(motivo: StringName) -> void:
	if not _motivos_bloqueo.erase(motivo):
		return
	if not esta_bloqueado() and estado == Estado.BLOQUEADO:
		estado = Estado.NAVEGANDO


func esta_bloqueado() -> bool:
	return not _motivos_bloqueo.is_empty()


## Fija el rumbo y la orientación inicial (al aparecer en una entrada).
func mirar(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	rumbo = dir.normalized()
	if animador:
		animador.mirar(dir)
		_reproducir(&"barco_quieto")
