class_name Jugador
extends CharacterBody2D

signal murio
signal reaparecio
## Al empezar una voltereta (no si falta estamina).
signal pirueta_empezada
## Al terminar de comer (después de curarse).
signal comio(objeto: Objeto)

enum Estado { NORMAL, PIRUETA, ATAQUE, AGARRAR, TIRAR, DANO, MUERTO, BLOQUEADO, COMER }

@export_group("Movimiento")
@export var velocidad_cargando := 55.0

@export_group("Pirueta")
@export var velocidad_pirueta := 150.0
@export var costo_pirueta := 35.0
@export var atraviesa_obstaculos_bajos := true

@export_group("Combate")

@export var empuje_dano := 170.0

@export_group("Objetos")
## Segundos con la pose de comer (es un solo dibujo) antes de curarse.
@export var duracion_comer := 0.8
## Dónde se dibuja el objeto que come, respecto a los pies: la pose de la artista no trae
## la manzana (en la lámina, Jugabilidad p. 8, va aparte, arriba a la derecha de la mano).
@export var posicion_objeto_comer := Vector2(11, -18)

@export_group("Muerte")

@export var reaparecer_automatico := true

const CAPA_OBSTACULO_BAJO := 7
## Animación de comer (fila "Layer 17" de leonidas_mini, de frente: ver su layout).
const ANIM_COMER := &"comer"

## La espada vive en EstadoJuego (sobrevive a guardar/cargar); la dan los sabios.
var tiene_espada: bool:
	get:
		return EstadoJuego.tiene_espada

var estado: Estado = Estado.NORMAL
var punto_control: Vector2

var _dir_pirueta := Vector2.DOWN
var _comiendo: Objeto = null
var _turno_comer := 0
var _objeto_en_mano: Sprite2D

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
	_objeto_en_mano = Sprite2D.new()
	_objeto_en_mano.name = &"ObjetoEnMano"
	_objeto_en_mano.position = posicion_objeto_comer
	_objeto_en_mano.visible = false
	add_child(_objeto_en_mano) # el último hijo: se dibuja encima de Leonidas


func _physics_process(delta: float) -> void:
	match estado:
		Estado.NORMAL:
			_estado_normal(delta)
		Estado.PIRUETA:
			movimiento.impulsar(_dir_pirueta * velocidad_pirueta)
		Estado.ATAQUE, Estado.AGARRAR, Estado.TIRAR, Estado.COMER:
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
	pirueta_empezada.emit()


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



## ¿Puede abrir el libro / usar un objeto ahora? (a pie, sin hacer nada más).
func puede_usar_objeto() -> bool:
	return estado == Estado.NORMAL and not carga.cargando() and not vida.muerto


## Come un consumible (lo llama el libro, que ya lo ha gastado): pose de comer durante
## `duracion_comer` y luego cura `objeto.cura` cuartos de corazón.
func comer(objeto: Objeto) -> void:
	if vida.muerto:
		return
	_comiendo = objeto
	estado = Estado.COMER
	movimiento.detener()
	animador.direccion = Vector2.DOWN
	animador.sprite.flip_h = false
	animador.sprite.play(ANIM_COMER)
	_mostrar_objeto_en_mano(objeto.icono)
	_turno_comer += 1
	var turno := _turno_comer
	await get_tree().create_timer(duracion_comer, false).timeout
	# Si mientras tanto le golpearon (o pasó otra cosa), no se cura.
	if turno == _turno_comer and estado == Estado.COMER:
		_terminar_de_comer()


func _mostrar_objeto_en_mano(icono: Texture2D) -> void:
	_objeto_en_mano.texture = icono
	_objeto_en_mano.visible = icono != null
	# Un saltito de 1 px a mitad de la pose, como si lo levantara para morderlo.
	_objeto_en_mano.position = posicion_objeto_comer
	if icono:
		var t := create_tween()
		t.tween_interval(duracion_comer * 0.45)
		t.tween_property(_objeto_en_mano, ^"position:y", posicion_objeto_comer.y - 1.0, 0.0)
		t.tween_interval(duracion_comer * 0.2)
		t.tween_property(_objeto_en_mano, ^"position:y", posicion_objeto_comer.y, 0.0)


func _terminar_de_comer() -> void:
	_objeto_en_mano.visible = false
	var o := _comiendo
	_comiendo = null
	if o:
		vida.curar(o.cura)
	_volver_a_normal()
	comio.emit(o)


func _al_recibir_danio(_cantidad: int, origen: Vector2) -> void:
	_comiendo = null # si le golpean mientras come, se queda sin curar
	_objeto_en_mano.visible = false
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
