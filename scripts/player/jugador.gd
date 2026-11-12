class_name Jugador
extends CharacterBody2D

signal murio
signal reaparecio

enum Estado { NORMAL, PIRUETA, ATAQUE, AGARRAR, TIRAR, DANO, MUERTO, BLOQUEADO }

@export_group("Movimiento")
@export var velocidad_cargando := 55.0

@export_group("Pirueta")
@export var velocidad_pirueta := 150.0
@export var costo_pirueta := 35.0
@export var atraviesa_obstaculos_bajos := true

@export_group("Combate")

@export var tiene_espada := true
@export var empuje_dano := 170.0

@export_group("Muerte")

@export var reaparecer_automatico := true

const CAPA_OBSTACULO_BAJO := 7

var estado: Estado = Estado.NORMAL
var punto_control: Vector2

var _dir_pirueta := Vector2.DOWN

@onready var movimiento: ComponenteMovimiento = $Movimiento
@onready var animador: AnimadorDireccional = $Animador
@onready var vida: ComponenteVida = $Vida
@onready var estamina: ComponenteEstamina = $Estamina
@onready var ataque: ComponenteAtaque = $Ataque
@onready var carga: ComponenteCarga = $Carga
@onready var interaccion: ComponenteInteraccion = $Interaccion
@onready var parpadeo: ComponenteParpadeo = $Parpadeo
@onready var hurtbox: Hurtbox = $Hurtbox


func _ready() -> void:
	punto_control = global_position
	vida.danado.connect(_al_recibir_danio)
	vida.murio.connect(_al_morir)
	ataque.termino.connect(_volver_a_normal)
	animador.termino.connect(_al_terminar_animacion)
	animador.reproducir(&"parado")


func _physics_process(delta: float) -> void:
	match estado:
		Estado.NORMAL:
			_estado_normal(delta)
		Estado.PIRUETA:
			movimiento.impulsar(_dir_pirueta * velocidad_pirueta)
		Estado.ATAQUE, Estado.AGARRAR, Estado.TIRAR:
			movimiento.frenar(delta)
		Estado.DANO:
			movimiento.frenar(delta, 0.6)
		Estado.MUERTO, Estado.BLOQUEADO:
			movimiento.detener()


func _estado_normal(delta: float) -> void:
	var entrada := Input.get_vector(&"mover_izquierda", &"mover_derecha", &"mover_arriba", &"mover_abajo")
	animador.orientar(entrada)
	movimiento.mover(entrada, delta, velocidad_cargando if carga.cargando() else -1.0)

	var base := "caminar" if entrada != Vector2.ZERO else "parado"
	if carga.cargando():
		animador.reproducir(StringName(base + "_objeto"))
		if Input.is_action_just_pressed(&"interactuar") or Input.is_action_just_pressed(&"atacar"):
			_tirar()
		return
	animador.reproducir(StringName(base))

	if Input.is_action_just_pressed(&"pirueta"):
		_pirueta(entrada)
	elif Input.is_action_just_pressed(&"atacar") and tiene_espada:
		_atacar()
	elif Input.is_action_just_pressed(&"interactuar"):
		_interactuar()



func _pirueta(entrada: Vector2) -> void:
	if not estamina.gastar(costo_pirueta):
		return # TODO:
	_dir_pirueta = entrada.normalized() if entrada != Vector2.ZERO else animador.direccion
	animador.orientar(_dir_pirueta)
	estado = Estado.PIRUETA
	vida.invulnerable_extra = true
	estamina.pausada = true
	if atraviesa_obstaculos_bajos:
		set_collision_mask_value(CAPA_OBSTACULO_BAJO, false)
	animador.reproducir(&"pirueta", true)
	# El giro dibujado de "pirueta_lado" va al revés del movimiento: se invierte el espejo.
	if animador.sufijo() == "lado":
		animador.sprite.flip_h = not animador.sprite.flip_h


func _terminar_pirueta() -> void:
	vida.invulnerable_extra = false
	estamina.pausada = false
	set_collision_mask_value(CAPA_OBSTACULO_BAJO, true)
	velocity *= 0.3


func _atacar() -> void:
	estado = Estado.ATAQUE
	velocity *= 0.2
	ataque.atacar()


func _interactuar() -> void:
	var objetivo := interaccion.buscar()
	if objetivo == null:
		return
	if objetivo.has_method(&"interactuar"):
		objetivo.interactuar(self) # NPC, carteles, cofres...
	elif objetivo is ObjetoAgarrable:
		estado = Estado.AGARRAR
		movimiento.detener()
		carga.levantar(objetivo)
		animador.reproducir(&"agarrar", true)


func _tirar() -> void:
	estado = Estado.TIRAR
	animador.reproducir(&"tirar", true)
	carga.lanzar(animador.direccion)



func _al_recibir_danio(_cantidad: int, origen: Vector2) -> void:
	if estado == Estado.PIRUETA:
		_terminar_pirueta()
	carga.soltar(animador.direccion)
	ataque.cancelar()
	movimiento.empujar_desde(origen, empuje_dano, -animador.direccion)
	if vida.muerto:
		return
	estado = Estado.DANO
	parpadeo.parpadear(vida.tiempo_invulnerable())
	animador.reproducir(&"recibir_dano", true)


func _al_morir() -> void:
	estado = Estado.MUERTO
	parpadeo.detener()
	hurtbox.set_deferred(&"monitorable", false)
	animador.reproducir(&"morir", true)


func _al_terminar_animacion(_anim: StringName) -> void:
	match estado:
		Estado.PIRUETA:
			_terminar_pirueta()
			_volver_a_normal()
		Estado.AGARRAR, Estado.TIRAR, Estado.DANO:
			_volver_a_normal()
		Estado.MUERTO:
			await get_tree().create_timer(1.0).timeout
			murio.emit()
			if reaparecer_automatico:
				reaparecer()


func _volver_a_normal() -> void:
	if estado != Estado.MUERTO and estado != Estado.BLOQUEADO:
		estado = Estado.NORMAL


func reaparecer() -> void:
	global_position = punto_control
	movimiento.detener()
	vida.restaurar()
	estamina.llenar()
	animador.direccion = Vector2.DOWN
	estado = Estado.NORMAL
	hurtbox.set_deferred(&"monitorable", true)
	parpadeo.parpadear(vida.tiempo_invulnerable())
	animador.reproducir(&"parado", true)
	reaparecio.emit()

func set_bloqueado(bloqueado: bool) -> void:
	if estado == Estado.MUERTO:
		return
	estado = Estado.BLOQUEADO if bloqueado else Estado.NORMAL
	if bloqueado:
		animador.reproducir(&"parado_objeto" if carga.cargando() else &"parado")
