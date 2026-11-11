class_name Tiburon
extends CharacterBody2D
## Tiburón del mar (minijuego del barco). No se le puede atacar (el barco no tiene
## ataque): hay que esquivarlo. Hace daño por contacto con su Hitbox.
##   PATRULLA  va y viene en horizontal ±`alcance_patrulla` desde donde empieza
##   EMBESTIR  al ver el barco, nada hacia él (boca abierta) y al final salta y muerde
##   CANSADO   un rato casi quieto: el momento de pasar
## Sprite sin direcciones que mira a la izquierda (espejar_sin_direccion).

enum Estado { PATRULLA, EMBESTIR, CANSADO }

@export var velocidad_patrulla := 60.0
@export var alcance_patrulla := 120.0
@export var velocidad_embestida := 120.0
@export var duracion_embestida := 0.8
@export var duracion_cansado := 1.5

var estado := Estado.PATRULLA

var _x_inicial := 0.0
var _sentido := -1.0
var _dir_embestida := Vector2.LEFT
var _tiempo := 0.0

@onready var movimiento: ComponenteMovimiento = $Movimiento
@onready var animador: AnimadorDireccional = $Animador
@onready var deteccion: ComponenteDeteccion = $Deteccion


func _ready() -> void:
	_x_inicial = global_position.x
	movimiento.choco.connect(_al_chocar)
	animador.mirar(Vector2(_sentido, 0))
	animador.reproducir(&"nadar")


func _physics_process(delta: float) -> void:
	match estado:
		Estado.PATRULLA:
			_patrullar(delta)
		Estado.EMBESTIR:
			movimiento.mover(_dir_embestida, delta, velocidad_embestida)
			_tiempo -= delta
			if _tiempo <= 0.0:
				_cansarse()
		Estado.CANSADO:
			movimiento.frenar(delta)
			_tiempo -= delta
			if _tiempo <= 0.0 and animador.animacion_actual() != &"morder":
				estado = Estado.PATRULLA
				animador.reproducir(&"nadar")


func _patrullar(delta: float) -> void:
	var dx := global_position.x - _x_inicial
	if dx <= -alcance_patrulla:
		_sentido = 1.0
	elif dx >= alcance_patrulla:
		_sentido = -1.0
	animador.mirar(Vector2(_sentido, 0))
	animador.reproducir(&"nadar")
	movimiento.mover(Vector2(_sentido, 0), delta, velocidad_patrulla)
	if deteccion.viendo():
		_embestir()


func _embestir() -> void:
	estado = Estado.EMBESTIR
	_tiempo = duracion_embestida
	_dir_embestida = deteccion.direccion()
	if _dir_embestida == Vector2.ZERO:
		_dir_embestida = Vector2(_sentido, 0)
	if absf(_dir_embestida.x) > 0.05:
		_sentido = signf(_dir_embestida.x)
	animador.mirar(Vector2(_sentido, 0))
	animador.reproducir(&"embestir", true)


func _cansarse() -> void:
	estado = Estado.CANSADO
	_tiempo = duracion_cansado
	animador.reproducir(&"morder", true) # salta, muerde y se sumerge
	await animador.termino
	if estado == Estado.CANSADO:
		animador.reproducir(&"nadar")


func _al_chocar(colision: KinematicCollision2D) -> void:
	var n := colision.get_normal()
	if estado == Estado.PATRULLA and absf(n.x) > 0.5:
		_sentido = signf(n.x) # da la vuelta
	elif estado == Estado.EMBESTIR:
		_cansarse()
