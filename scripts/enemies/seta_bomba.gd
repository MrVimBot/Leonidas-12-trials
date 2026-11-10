class_name SetaBomba
extends CharacterBody2D
## Seta bomba (Guión p. 15). Cerebro: deambula cerca de su sitio; al ver a Leonidas
## lo persigue y, si se acerca, se infla y EXPLOTA (suelta una NubeToxica: daño en
## área). Después se queda escondida e inofensiva un rato: es el momento de atacarla.
## La voltereta esquiva la explosión. La posición del nodo son los pies.

enum Estado { DEAMBULAR, PERSEGUIR, EXPLOTAR, ESCONDIDA, SALIR, DANO, MUERTA }

@export_group("Movimiento")
@export var velocidad_deambular := 30.0
@export var velocidad_perseguir := 60.0
## Distancia máxima a su punto de inicio mientras deambula.
@export var radio_deambular := 48.0

@export_group("Explosión")
## Explota cuando Leonidas está a esta distancia (px, pies a pies).
@export var distancia_explotar := 22.0
## Frame de la animación "explotar" en el que sale la nube (el destello blanco).
@export var frame_explosion := 3
@export var escena_nube: PackedScene
@export var danio_explosion := 4
## Segundos escondida (inofensiva) tras explotar.
@export var tiempo_escondida := 2.5
## Segundos tras salir antes de poder volver a explotar.
@export var recarga := 1.5

@export_group("Daño")
@export var empuje_dano := 140.0
@export var tiempo_aturdida := 0.35

var estado: Estado = Estado.DEAMBULAR

var _origen: Vector2
var _destino: Vector2
var _espera := 0.0
var _recarga := 0.0

@onready var movimiento: ComponenteMovimiento = $Movimiento
@onready var animador: AnimadorDireccional = $Animador
@onready var vida: ComponenteVida = $Vida
@onready var deteccion: ComponenteDeteccion = $Deteccion
@onready var parpadeo: ComponenteParpadeo = $Parpadeo
@onready var contacto: Hitbox = $Contacto


func _ready() -> void:
	_origen = global_position
	_destino = _origen
	_espera = randf_range(0.2, 1.5)
	vida.danado.connect(_al_recibir_danio)
	vida.murio.connect(_al_morir)
	animador.termino.connect(_al_terminar_animacion)
	animador.frame_cambio.connect(_al_cambiar_frame)
	movimiento.choco.connect(_al_chocar)
	animador.reproducir(&"parado")


func _physics_process(delta: float) -> void:
	_recarga = maxf(_recarga - delta, 0.0)
	match estado:
		Estado.DEAMBULAR:
			_deambular(delta)
		Estado.PERSEGUIR:
			_perseguir(delta)
		Estado.ESCONDIDA:
			movimiento.frenar(delta)
			_espera -= delta
			if _espera <= 0.0:
				_salir()
		Estado.DANO:
			movimiento.frenar(delta, 0.6)
			_espera -= delta
			if _espera <= 0.0:
				_volver_a_andar()
		_:
			movimiento.frenar(delta)


func _deambular(delta: float) -> void:
	if deteccion.viendo():
		estado = Estado.PERSEGUIR
		return
	if _espera > 0.0:
		_espera -= delta
		movimiento.frenar(delta)
		animador.reproducir(&"parado")
		return
	var hacia := _destino - global_position
	if hacia.length() < 2.0:
		_nuevo_destino()
		return
	_andar(hacia.normalized(), velocidad_deambular, delta)


func _perseguir(delta: float) -> void:
	if not deteccion.viendo():
		estado = Estado.DEAMBULAR
		_destino = _origen
		return
	animador.mirar(deteccion.direccion())
	if deteccion.distancia() <= distancia_explotar:
		if _recarga <= 0.0:
			_explotar()
		else: # recién salida: espera pegada a él
			movimiento.frenar(delta)
			animador.reproducir(&"parado")
		return
	_andar(deteccion.direccion(), velocidad_perseguir, delta)


func _andar(dir: Vector2, vel: float, delta: float) -> void:
	animador.orientar(dir)
	movimiento.mover(dir, delta, vel)
	animador.reproducir(&"caminar")


func _nuevo_destino() -> void:
	_espera = randf_range(0.8, 2.0)
	_destino = _origen + Vector2.from_angle(randf() * TAU) * randf_range(8.0, radio_deambular)


func _al_chocar(_colision: KinematicCollision2D) -> void:
	if estado == Estado.DEAMBULAR and _espera <= 0.0:
		_nuevo_destino() # contra un árbol: se para y elige otro sitio


func _explotar() -> void:
	estado = Estado.EXPLOTAR
	movimiento.detener()
	contacto.activo = false
	animador.reproducir(&"explotar", true)


func _soltar_nube() -> void:
	if escena_nube == null:
		return
	var nube := escena_nube.instantiate() as Node2D
	if &"danio" in nube:
		nube.danio = danio_explosion
	get_parent().add_child(nube)
	nube.global_position = global_position


func _salir() -> void:
	estado = Estado.SALIR
	animador.reproducir(&"salir", true)


func _volver_a_andar() -> void:
	estado = Estado.PERSEGUIR if deteccion.viendo() else Estado.DEAMBULAR
	contacto.activo = true


func _al_cambiar_frame(frame: int) -> void:
	if estado == Estado.EXPLOTAR and frame == frame_explosion:
		_soltar_nube()


func _al_terminar_animacion(_anim: StringName) -> void:
	match estado:
		Estado.EXPLOTAR:
			estado = Estado.ESCONDIDA
			_espera = tiempo_escondida
			animador.reproducir(&"esconderse", true)
		Estado.SALIR:
			_recarga = recarga
			_volver_a_andar()


func _al_recibir_danio(_cantidad: int, origen: Vector2) -> void:
	if vida.muerto:
		return
	parpadeo.parpadear(vida.tiempo_invulnerable())
	# Inflándose o escondida no se mueve del sitio: solo parpadea.
	if estado in [Estado.DEAMBULAR, Estado.PERSEGUIR, Estado.DANO]:
		estado = Estado.DANO
		_espera = tiempo_aturdida
		movimiento.empujar_desde(origen, empuje_dano)


func _al_morir() -> void:
	estado = Estado.MUERTA
	parpadeo.detener()
	movimiento.detener()
