class_name FlorFalsa
extends CharacterBody2D
## Falsa flor (Guión p. 16). Cerebro: camuflada como una flor más (no se le puede
## golpear); al acercarse Leonidas sale, se estira y muerde. Se queda fuera un rato
## y, si no la matan, se esconde y reaparece en otro sitio cercano.
## No se mueve: la posición del nodo es la base del tallo.

enum Estado { ESCONDIDA, SALIR, ALERTA, MORDER, MORDER_EXITO, DANO, ESCONDERSE, MUERTA }

@export_group("Mordisco")
## Alcance horizontal y vertical del mordisco (px desde la base del tallo).
@export var alcance := Vector2(24, 14)
@export var recarga_mordisco := 0.9

@export_group("Escondite")
## Segundos fuera antes de volver a esconderse (si no la matan).
@export var tiempo_fuera := 5.0
## Tras reaparecer, segundos en que no puede despertar aunque Leonidas esté cerca.
@export var espera_al_reaparecer := 1.5
## Distancia máxima a su punto de inicio a la que puede reaparecer.
@export var radio_reaparicion := 72.0
@export var intentos_reaparicion := 16

var estado: Estado = Estado.ESCONDIDA

var _origen: Vector2
var _fuera := 0.0
var _espera := 0.0
var _recarga := 0.0
var _mordio := false

@onready var animador: AnimadorDireccional = $Animador
@onready var vida: ComponenteVida = $Vida
@onready var deteccion: ComponenteDeteccion = $Deteccion
@onready var ataque: ComponenteAtaque = $Ataque
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var colision: CollisionShape2D = $Colision


func _ready() -> void:
	_origen = global_position
	animador.direccion = Vector2.LEFT
	vida.danado.connect(_al_recibir_danio)
	vida.murio.connect(_al_morir)
	animador.termino.connect(_al_terminar_animacion)
	ataque.termino.connect(_al_terminar_mordisco)
	ataque.hitbox.golpeo.connect(func(_o: Node) -> void: _mordio = true)
	_esconder_del_todo()


func _physics_process(delta: float) -> void:
	_recarga = maxf(_recarga - delta, 0.0)
	match estado:
		Estado.ESCONDIDA:
			_espera -= delta
			if _espera <= 0.0 and deteccion.viendo():
				estado = Estado.SALIR
				_fuera = tiempo_fuera
				hurtbox.activo = true
				_mirar_al_jugador()
				animador.reproducir(&"salir", true)
		Estado.ALERTA:
			_alerta(delta)
		Estado.MORDER_EXITO, Estado.DANO:
			_fuera -= delta


func _alerta(delta: float) -> void:
	_fuera -= delta
	if _fuera <= 0.0:
		estado = Estado.ESCONDERSE
		animador.reproducir(&"esconderse", true)
		return
	animador.reproducir(&"quieta")
	if not deteccion.viendo():
		return
	_mirar_al_jugador()
	var v := deteccion.vector_hacia()
	if _recarga <= 0.0 and absf(v.x) <= alcance.x and absf(v.y) <= alcance.y:
		estado = Estado.MORDER
		_mordio = false
		ataque.atacar()


func _mirar_al_jugador() -> void:
	var dx := deteccion.vector_hacia().x
	if absf(dx) > 1.0:
		animador.mirar(Vector2(signf(dx), 0))


func _al_terminar_mordisco() -> void:
	if estado != Estado.MORDER:
		return
	_recarga = recarga_mordisco
	if _mordio:
		estado = Estado.MORDER_EXITO
		animador.reproducir(&"morder_exito", true)
	else:
		estado = Estado.ALERTA


## Se mira también el nombre de la animación: al acabar "morder", ComponenteAtaque
## avisa antes (y ya se ha pasado a MORDER_EXITO con su propia animación).
func _al_terminar_animacion(anim: StringName) -> void:
	match [estado, anim]:
		[Estado.SALIR, &"salir"], [Estado.MORDER_EXITO, &"morder_exito"], [Estado.DANO, &"recibir_dano"]:
			estado = Estado.ALERTA
		[Estado.ESCONDERSE, &"esconderse"]:
			_reaparecer_en_otro_sitio()
			_esconder_del_todo()
			_espera = espera_al_reaparecer


func _esconder_del_todo() -> void:
	estado = Estado.ESCONDIDA
	hurtbox.activo = false # camuflada: la espada no le hace nada
	animador.reproducir(&"escondida", true)


func _reaparecer_en_otro_sitio() -> void:
	for i in intentos_reaparicion:
		var p := _origen + Vector2.from_angle(randf() * TAU) * randf_range(16.0, radio_reaparicion)
		if _sitio_libre(p):
			global_position = p.round()
			return


## ¿Cabe la flor en `p`? Sin chocar con el mundo ni con otros enemigos y sobre suelo de la zona.
func _sitio_libre(p: Vector2) -> bool:
	var zona := owner as Zona
	if zona and zona.suelo:
		var celda := zona.suelo.local_to_map(zona.suelo.to_local(p))
		if zona.suelo.get_cell_source_id(celda) == -1:
			return false
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = colision.shape
	q.transform = Transform2D(0.0, p + colision.position)
	q.collision_mask = collision_mask | collision_layer
	q.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func _al_recibir_danio(_cantidad: int, _origen_golpe: Vector2) -> void:
	if vida.muerto:
		return
	ataque.cancelar()
	estado = Estado.DANO
	animador.reproducir(&"recibir_dano", true)


func _al_morir() -> void:
	estado = Estado.MUERTA
	ataque.cancelar()
