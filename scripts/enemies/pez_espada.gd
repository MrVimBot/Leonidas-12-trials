class_name PezEspada
extends CharacterBody2D
## Pez espada del nivel 2 (Guión p. 34). Cerebro: deambula despacio; al ver a Leonidas se
## para un instante (AVISO, fija el rumbo), corre hacia donde estaba a toda velocidad EN LÍNEA
## RECTA (no corrige el rumbo: hay que apartarse) y, si lo alcanza, frena en seco y le clava
## la espada. Luego queda cansado (ENFRIAMIENTO): es el momento de pegarle.
##   ACECHO        deambula (ComponentePaseo) hasta ver a Leonidas
##   AVISO         parado, mirando; aquí se fija el rumbo
##   CARRERA       `velocidad_carrera` en línea recta; INVULNERABLE; atropella (Contacto)
##   ESTOCADA      frena y clava la espada (ComponenteAtaque; dos estocadas en una animación)
##   ENFRIAMIENTO  quieto y jadeando, vulnerable (más largo si se estrelló contra una pared)
##   DANO          retroceso corto; devuelve al estado que tenía sin gastar su tiempo
## La posición del nodo es el punto de apoyo. El dibujo mira a la izquierda (el AnimadorDireccional
## lo espeja) y no tiene vista de frente ni de espalda: corriendo hacia arriba o abajo se ve de lado.
## PROVISIONAL: «ataque más débil» del Guión (p. 34) sin implementar a propósito (pregunta abierta).

enum Estado { ACECHO, AVISO, CARRERA, ESTOCADA, ENFRIAMIENTO, DANO, MUERTA }

@export_group("Movimiento")
@export var velocidad_acecho := 30.0
## 240 px/s = 2 px por tick de física (casi 3 veces lo que corre Leonidas).
@export var velocidad_carrera := 240.0
## Distancia máxima a su punto de inicio mientras deambula (se pasa al componente Paseo).
@export var radio_deambular := 48.0

@export_group("Carrera")
## Segundos parado antes de salir corriendo: el tiempo para reaccionar.
@export var tiempo_aviso := 0.4
## Si no alcanza a Leonidas, la carrera acaba al recorrer esta distancia (px).
@export var distancia_carrera_max := 180.0
## Multiplica la velocidad de la animación `correr` mientras corre (a 24 fps patinaba).
@export var velocidad_animacion_carrera := 1.25

@export_group("Estocada")
## Clava la espada si Leonidas está delante a esta distancia horizontal (px, pies a pies)...
@export var distancia_estocada := 34.0
## ...y a menos de esta distancia en vertical.
@export var alcance_vertical := 10.0
## Cuánto frena al empezar la estocada (múltiplo de la fricción del Movimiento).
@export var frenada := 10.0

@export_group("Enfriamiento")
@export var tiempo_enfriamiento := 1.5
## Si choca de frente contra una pared corriendo: queda aturdido más rato.
@export var tiempo_enfriamiento_choque := 2.2

@export_group("Daño")
@export var empuje_dano := 140.0
@export var tiempo_dano := 0.2

var estado: Estado = Estado.ACECHO

## Segundos que le quedan al estado actual (AVISO, ENFRIAMIENTO).
var _espera := 0.0
var _rumbo := Vector2.LEFT
var _origen_carrera := Vector2.ZERO
## Al salir de DANO: estado al que vuelve y el tiempo que le quedaba.
var _estado_tras_dano := Estado.ACECHO
var _espera_tras_dano := 0.0
var _tiempo_dano_restante := 0.0

@onready var movimiento: ComponenteMovimiento = $Movimiento
@onready var animador: AnimadorDireccional = $Animador
@onready var vida: ComponenteVida = $Vida
@onready var deteccion: ComponenteDeteccion = $Deteccion
@onready var parpadeo: ComponenteParpadeo = $Parpadeo
@onready var contacto: Hitbox = $Contacto
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var ataque: ComponenteAtaque = $Ataque
@onready var paseo: ComponentePaseo = $Paseo


func _ready() -> void:
	paseo.centro = global_position
	paseo.radio = radio_deambular
	paseo.velocidad = velocidad_acecho
	paseo.activar(Vector2(0.3, 1.2))
	contacto.activo = false # solo atropella corriendo
	animador.direccion = Vector2.LEFT # el dibujo mira a la izquierda
	vida.danado.connect(_al_recibir_danio)
	vida.murio.connect(_al_morir)
	movimiento.choco.connect(_al_chocar)
	ataque.termino.connect(_al_terminar_estocada)
	animador.reproducir(&"parado")


func _physics_process(delta: float) -> void:
	match estado:
		Estado.ACECHO:
			_acechar(delta)
		Estado.AVISO:
			movimiento.frenar(delta)
			_espera -= delta
			if _espera <= 0.0:
				_correr()
		Estado.CARRERA:
			_seguir_corriendo(delta)
		Estado.ESTOCADA:
			movimiento.frenar(delta, frenada)
		Estado.ENFRIAMIENTO:
			movimiento.frenar(delta)
			_espera -= delta
			if _espera <= 0.0:
				_terminar_enfriamiento()
		Estado.DANO:
			movimiento.frenar(delta, 0.6)
			_tiempo_dano_restante -= delta
			if _tiempo_dano_restante <= 0.0:
				_salir_de_dano()
		_:
			movimiento.frenar(delta)


func _acechar(delta: float) -> void:
	if deteccion.viendo():
		_avisar()
		return
	paseo.actualizar(delta)
	if paseo.andando:
		_mirar_lado(paseo.hacia.x)
		animador.reproducir(&"caminar")
	else:
		animador.reproducir(&"parado")


## Se para, mira a Leonidas y FIJA el rumbo de la carrera (Q5: no lo corrige después).
func _avisar() -> void:
	estado = Estado.AVISO
	_espera = tiempo_aviso
	_rumbo = deteccion.direccion()
	if _rumbo == Vector2.ZERO:
		_rumbo = Vector2(animador.direccion.x, 0)
	_mirar_lado(_rumbo.x)
	animador.reproducir(&"parado")


func _correr() -> void:
	estado = Estado.CARRERA
	_origen_carrera = global_position
	vida.invulnerable_extra = true
	contacto.activo = true
	_velocidad_animacion(velocidad_animacion_carrera)
	movimiento.impulsar(_rumbo * velocidad_carrera) # arranca de golpe
	animador.reproducir(&"correr", true)


func _seguir_corriendo(delta: float) -> void:
	movimiento.mover(_rumbo, delta, velocidad_carrera)
	if global_position.distance_to(_origen_carrera) >= distancia_carrera_max:
		_enfriar(tiempo_enfriamiento)
		return
	# Solo clava la espada si Leonidas está justo delante, al alcance de la punta.
	if not deteccion.viendo():
		return
	var v := deteccion.vector_hacia()
	var delante := signf(animador.direccion.x)
	if v.x * delante > 0.0 and absf(v.x) <= distancia_estocada and absf(v.y) <= alcance_vertical:
		_estocar()


func _estocar() -> void:
	estado = Estado.ESTOCADA
	vida.invulnerable_extra = false
	contacto.activo = false
	_velocidad_animacion(1.0)
	ataque.atacar() # frena en `_physics_process` (estado ESTOCADA)


func _al_terminar_estocada() -> void:
	if estado == Estado.ESTOCADA:
		_enfriar(tiempo_enfriamiento)


func _enfriar(segundos: float) -> void:
	estado = Estado.ENFRIAMIENTO
	_espera = segundos
	vida.invulnerable_extra = false
	contacto.activo = false
	_velocidad_animacion(1.0)
	animador.reproducir(&"parado")


func _terminar_enfriamiento() -> void:
	if deteccion.viendo():
		_avisar()
	else:
		_volver_a_acechar()


func _volver_a_acechar() -> void:
	estado = Estado.ACECHO
	paseo.activar(Vector2(0.3, 1.2)) # vuelve a pasear alrededor de su sitio
	animador.reproducir(&"parado")


func _al_chocar(colision: KinematicCollision2D) -> void:
	match estado:
		Estado.ACECHO:
			paseo.al_chocar() # contra una roca: se para y elige otro sitio
		Estado.CARRERA:
			# De frente contra el mundo = se estrella (rozar una pared no cuenta).
			if colision.get_normal().dot(_rumbo) < -0.5:
				movimiento.detener()
				_enfriar(tiempo_enfriamiento_choque)


func _al_recibir_danio(_cantidad: int, origen: Vector2) -> void:
	if vida.muerto:
		return
	parpadeo.parpadear(vida.tiempo_invulnerable())
	# La estocada no se interrumpe (solo parpadea); corriendo es invulnerable (no llega aquí).
	match estado:
		Estado.ENFRIAMIENTO:
			_entrar_en_dano(Estado.ENFRIAMIENTO, _espera, origen) # no le «salva» de la ventana
		Estado.ACECHO:
			_entrar_en_dano(Estado.ACECHO, 0.0, origen)
		Estado.AVISO:
			_entrar_en_dano(Estado.AVISO, tiempo_aviso, origen)


func _entrar_en_dano(vuelve_a: Estado, espera: float, origen: Vector2) -> void:
	_estado_tras_dano = vuelve_a
	_espera_tras_dano = espera
	_tiempo_dano_restante = tiempo_dano
	estado = Estado.DANO
	movimiento.empujar_desde(origen, empuje_dano)


func _salir_de_dano() -> void:
	estado = _estado_tras_dano
	_espera = _espera_tras_dano
	if estado == Estado.ACECHO:
		paseo.activar(Vector2(0.3, 1.2))
	animador.reproducir(&"parado")


func _al_morir() -> void:
	estado = Estado.MUERTA
	ataque.cancelar()
	contacto.activo = false
	parpadeo.detener()
	movimiento.detener()


## Gira el dibujo hacia el lado de `dx` (no tiene vista de frente ni de espalda).
func _mirar_lado(dx: float) -> void:
	if absf(dx) > 0.05:
		animador.mirar(Vector2(signf(dx), 0))


## Velocidad de reproducción del sprite (solo cambia la rapidez, no la animación).
func _velocidad_animacion(escala: float) -> void:
	animador.sprite.speed_scale = escala
