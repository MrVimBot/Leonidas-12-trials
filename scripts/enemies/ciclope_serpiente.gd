class_name CiclopeSerpiente
extends CharacterBody2D
## Cíclope serpiente del nivel 2 (Guión p. 36; arte pintado de una sola vista, mira a la
## izquierda). Enemigo A DISTANCIA: guarda las distancias, apunta y dispara un pequeño rayo
## (`RayoCiclope`) por el ojo, y luego tiene un tiempo de ENFRIAMIENTO en el que se le puede
## alcanzar. Solo vive en la cueva y como invocación de Medusa. La posición del nodo es el
## punto de apoyo (como los pies de Leonidas).
##
## Estados: VIGILAR (quieto o deambulando muy poco; si ve a Leonidas, apunta; si lo tiene
## MUY cerca retrocede un poco antes de disparar y, si no puede, dispara igual) → APUNTAR
## (anim `atacar`: se yergue y FIJA el punto al que dispara en el fotograma `frame_apuntar`,
## 11; en `frame_disparo`, 13, baja la cabeza y sale el rayo) → ENFRIAMIENTO (al acabar la
## animación, `enfriamiento` s quieto en `parado`) → VIGILAR. Un golpe mientras apunta
## cancela el disparo y le da un enfriamiento nuevo (para que pegarle sirva de algo).
##
## CONTRATO PARA MEDUSA (plan 06; no cambiar sin avisar):
## - Señal `derrotado` (sin argumentos): se emite en cuanto muere, al entrar en MUERTA (no
##   cuando se libera el nodo, que ocurre ~0,45 s después), sea invocado o no.
## - `@export var invocado := false`: con `true` empieza en APARECER (`duracion_aparicion`,
##   0,5 s: aparece con `modulate.a` de 0 a 1 y una nube de polvo PROVISIONAL), sin `Hurtbox`
##   ni `Contacto` activos mientras aparece, y suelta 0 monedas (`Muerte.monedas = 0`).
## - `aparecer()`: hace lo mismo, para quien lo instancia por código. Llamarlo DESPUÉS de
##   `add_child` (necesita sus nodos hijos) y de colocarlo; recentra su deambular en su
##   posición. Quien invoque debe esperar `derrotado` para saber cuándo han muerto todos.
##
## Sin `ComponenteAtaque` (no hay golpe cuerpo a cuerpo; solo el `Contacto` de la base).
## Todo número es PROVISIONAL hasta que Esteban lo pruebe.

## Al morir (ver el contrato de arriba).
signal derrotado

enum Estado { APARECER, VIGILAR, APUNTAR, ENFRIAMIENTO, DANO, MUERTA }

@export_group("Sonido")
## Al empezar a apuntar.
@export var sonido_apuntar: AudioStreamPlayer2D
## Cuando sale el rayo.
@export var sonido_disparo: AudioStreamPlayer2D
@export_group("Rayo")
## Se asigna en el Inspector (no `preload`: regla del proyecto). Su raíz es un `RayoCiclope`.
@export var escena_rayo: PackedScene
## Fotograma de `atacar` en el que fija hacia dónde dispara (último momento para corregir).
@export var frame_apuntar := 11
## Fotograma de `atacar` en el que sale el rayo (baja la cabeza hacia delante).
@export var frame_disparo := 13
## Segundos quieto tras acabar la animación de ataque.
@export var enfriamiento := 2.0
## Daño del rayo, en cuartos de corazón.
@export var danio_rayo := 2
## Apunta a esta altura sobre los pies de Leonidas (el centro de su Hurtbox).
@export var altura_objetivo := 11.0

@export_group("Movimiento")
@export var velocidad_deambular := 30.0
## Distancia máxima a su sitio mientras deambula (se pasa al componente Paseo).
@export var radio_deambular := 16.0
## Si Leonidas está más cerca que esto (px, pies a pies), retrocede en vez de disparar.
@export var distancia_cerca := 28.0
@export var velocidad_retroceso := 30.0
## Segundos máximos retrocediendo seguidos; luego dispara igual (o antes, si choca).
@export var tiempo_retroceso_max := 1.0

@export_group("Daño")
@export var empuje_dano := 80.0
@export var tiempo_aturdida := 0.3

@export_group("Invocación")
## true = la invoca otro (Medusa): empieza en APARECER y no suelta monedas. Ver el contrato.
@export var invocado := false
@export var duracion_aparicion := 0.5

var estado: Estado = Estado.VIGILAR

var _enfriamiento := 0.0
var _espera := 0.0
var _retroceso := 0.0
var _fijado := false
var _punto_apuntado := Vector2.ZERO
var _estado_tras_dano := Estado.VIGILAR

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var movimiento: ComponenteMovimiento = $Movimiento
@onready var animador: AnimadorDireccional = $Animador
@onready var vida: ComponenteVida = $Vida
@onready var deteccion: ComponenteDeteccion = $Deteccion
@onready var parpadeo: ComponenteParpadeo = $Parpadeo
@onready var muerte: ComponenteMuerte = $Muerte
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var contacto: Hitbox = $Contacto
@onready var paseo: ComponentePaseo = $Paseo
@onready var ojo: Marker2D = $Ojo
@onready var polvo: CPUParticles2D = $Polvo


func _ready() -> void:
	vida.danado.connect(_al_recibir_danio)
	vida.murio.connect(_al_morir)
	animador.termino.connect(_al_terminar_animacion)
	animador.frame_cambio.connect(_al_cambiar_frame)
	movimiento.choco.connect(_al_chocar)
	animador.direccion = Vector2.LEFT
	paseo.centro = global_position
	paseo.radio = radio_deambular
	paseo.velocidad = velocidad_deambular
	paseo.activar(Vector2(0.5, 2.0))
	animador.reproducir(&"parado")
	if invocado:
		aparecer()


func _physics_process(delta: float) -> void:
	match estado:
		Estado.VIGILAR:
			_vigilar(delta)
		Estado.APUNTAR:
			movimiento.frenar(delta)
			if not _fijado:
				_mirar_a_leonidas()
				animador.reproducir(&"atacar") # sin reiniciar: solo actualiza el espejo
		Estado.ENFRIAMIENTO:
			movimiento.frenar(delta)
			_mirar_a_leonidas()
			animador.reproducir(&"parado")
			_enfriamiento -= delta
			if _enfriamiento <= 0.0:
				estado = Estado.VIGILAR
		Estado.DANO:
			movimiento.frenar(delta, 0.6)
			_espera -= delta
			if _espera <= 0.0:
				estado = _estado_tras_dano
		_:
			movimiento.frenar(delta)


## Invocación (lo usa Medusa; ver el contrato en la cabecera).
func aparecer() -> void:
	invocado = true
	estado = Estado.APARECER
	muerte.monedas = 0
	hurtbox.activo = false
	contacto.activo = false
	paseo.centro = global_position
	sprite.modulate.a = 0.0
	polvo.restart()
	var t := create_tween()
	t.tween_property(sprite, ^"modulate:a", 1.0, duracion_aparicion)
	t.tween_callback(_terminar_aparicion)


func _terminar_aparicion() -> void:
	if estado != Estado.APARECER:
		return
	hurtbox.activo = true
	contacto.activo = true
	estado = Estado.VIGILAR


func _vigilar(delta: float) -> void:
	if not deteccion.viendo():
		_retroceso = 0.0
		paseo.actualizar(delta)
		if paseo.andando:
			_mirar_x(paseo.hacia.x)
			animador.reproducir(&"caminar")
		else:
			animador.reproducir(&"parado")
		return
	_mirar_a_leonidas()
	# Muy cerca: se aleja un poco (lento) antes de disparar. Si no hay sitio, dispara igual.
	if deteccion.distancia() < distancia_cerca and _retroceso < tiempo_retroceso_max:
		_retroceso += delta
		movimiento.mover(-deteccion.direccion(), delta, velocidad_retroceso)
		animador.reproducir(&"caminar")
		return
	_apuntar()


func _apuntar() -> void:
	if sonido_apuntar:
		sonido_apuntar.play()
	estado = Estado.APUNTAR
	_fijado = false
	_retroceso = 0.0
	movimiento.detener()
	_punto_apuntado = _punto_de_leonidas()
	animador.reproducir(&"atacar", true)


## Fotograma `frame_apuntar`: último momento en que corrige el tiro.
func _fijar_punto() -> void:
	_fijado = true
	_punto_apuntado = _punto_de_leonidas()


## Fotograma `frame_disparo`: sale el rayo del ojo hacia el punto fijado.
func _disparar() -> void:
	if sonido_disparo:
		sonido_disparo.play()
	if escena_rayo == null:
		return
	var origen := _posicion_ojo()
	var rayo := escena_rayo.instantiate() as Node2D
	var rayo_ciclope := rayo as RayoCiclope
	if rayo_ciclope:
		var hacia := _punto_apuntado - origen
		rayo_ciclope.direccion = hacia.normalized() if hacia.length() > 1.0 else animador.direccion
		rayo_ciclope.danio = danio_rayo
	# Al padre (el contenedor con orden por Y de la zona) y no al cíclope: el rayo debe
	# sobrevivir si lo matan (mismo motivo que la nube de la seta).
	get_parent().add_child(rayo)
	rayo.global_position = origen


func _punto_de_leonidas() -> Vector2:
	if deteccion.viendo():
		return deteccion.objetivo.global_position + Vector2(0, -altura_objetivo)
	# Sin verle: dispara hacia donde mira.
	return global_position + Vector2(animador.direccion.x * 100.0, -altura_objetivo)


## El `Ojo` de la escena está puesto para el dibujo que mira a la izquierda: se espeja en x
## cuando mira a la derecha.
func _posicion_ojo() -> Vector2:
	var lado := 1.0 if animador.direccion == Vector2.LEFT else -1.0
	return global_position + Vector2(ojo.position.x * lado, ojo.position.y)


## Solo mira a los lados: el arte tiene una sola vista.
func _mirar_a_leonidas() -> void:
	if deteccion.viendo():
		_mirar_x(deteccion.vector_hacia().x)


func _mirar_x(dx: float) -> void:
	if absf(dx) > 1.0:
		animador.mirar(Vector2(signf(dx), 0))


func _al_cambiar_frame(frame: int) -> void:
	# `frame_changed` también salta con las otras animaciones (parado, caminar): solo cuenta
	# `atacar` estando apuntando.
	if estado != Estado.APUNTAR or sprite.animation != &"atacar":
		return
	if frame == frame_apuntar:
		_fijar_punto()
	elif frame == frame_disparo:
		_disparar()


func _al_terminar_animacion(anim: StringName) -> void:
	if estado == Estado.APUNTAR and anim == &"atacar":
		estado = Estado.ENFRIAMIENTO
		_enfriamiento = enfriamiento
		animador.reproducir(&"parado", true)


func _al_chocar(_colision: KinematicCollision2D) -> void:
	if estado != Estado.VIGILAR:
		return
	if deteccion.viendo():
		_retroceso = tiempo_retroceso_max # contra una pared: ya no hay a dónde retroceder
	else:
		paseo.al_chocar()


func _al_recibir_danio(_cantidad: int, origen: Vector2) -> void:
	if vida.muerto:
		return
	parpadeo.parpadear(vida.tiempo_invulnerable())
	# Apuntando (o aún sin empezar a enfriar): el golpe cancela el disparo y empieza un
	# enfriamiento nuevo. En ENFRIAMIENTO sigue con el que le quedaba.
	if estado == Estado.APUNTAR:
		_estado_tras_dano = Estado.ENFRIAMIENTO
		_enfriamiento = enfriamiento
	elif estado in [Estado.VIGILAR, Estado.ENFRIAMIENTO]:
		_estado_tras_dano = estado
	elif estado != Estado.DANO:
		return # APARECER / MUERTA: no se le interrumpe
	estado = Estado.DANO
	_espera = tiempo_aturdida
	_fijado = false
	animador.reproducir(&"parado", true)
	movimiento.empujar_desde(origen, empuje_dano)


func _al_morir() -> void:
	estado = Estado.MUERTA
	parpadeo.detener()
	movimiento.detener()
	derrotado.emit()
