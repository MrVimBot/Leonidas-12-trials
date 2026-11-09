class_name ObjetoAgarrable
extends StaticBody2D
## Objeto que Leonidas puede levantar, cargar y lanzar (rocas, vasijas...).
## En el suelo bloquea el paso (capa mundo). Al lanzarlo vuela en línea recta con
## un pequeño arco, golpea con su Hitbox "Golpe" y se rompe al caer o chocar.
##
## Estructura de la escena: StaticBody2D (capas mundo + interactuable) con este script,
## un hijo "Visual" (Sprite2D/Node2D), su CollisionShape2D y un hijo "Golpe" (Hitbox,
## capa golpe_jugador, máscara enemigos + interactuable).

signal roto

## Se rompe al aterrizar. Si es false, vuelve a quedar en el suelo.
@export var rompible := true
## Además se puede romper con la espada (vasijas). Las rocas no.
@export var se_rompe_con_espada := false
@export var velocidad_vuelo := 190.0
@export var altura_arco := 6.0
## Probabilidad (0–1) de soltar algo al romperse; la escena a soltar va en `botin`.
@export var botin: PackedScene
@export_range(0.0, 1.0) var probabilidad_botin := 0.0

@onready var visual: Node2D = $Visual
@onready var golpe: Hitbox = $Golpe

var _capa_original: int
var _mascara_original: int
var _visual_y: float
var _volando := false
var _dir := Vector2.ZERO
var _distancia := 0.0
var _recorrido := 0.0
var _altura_inicial := 0.0


func _ready() -> void:
	add_to_group(&"agarrable")
	_capa_original = collision_layer
	_mascara_original = collision_mask
	_visual_y = visual.position.y
	golpe.activo = false


## Lo llama el jugador. Se engancha a `punto` (encima de la cabeza).
func levantar(punto: Node2D) -> void:
	collision_layer = 0
	collision_mask = 0
	reparent(punto)
	z_index = 1
	var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, ^"position", Vector2.ZERO, 0.2)


## Sale volando desde encima de la cabeza. `pies` = posición de los pies del jugador.
## Con distancia 0 simplemente cae delante (p. ej. al recibir daño).
func lanzar(dir: Vector2, distancia: float, pies: Vector2) -> void:
	var altura := global_position.y - pies.y # negativo: está por encima
	var escena := get_tree().current_scene
	reparent(escena)
	z_index = 0
	# El nodo pasa a estar "en el suelo"; la altura se simula moviendo solo el Visual.
	global_position = pies + dir * 6.0
	_altura_inicial = altura
	visual.position.y = _visual_y + altura
	_dir = dir
	_distancia = maxf(distancia, 1.0)
	_recorrido = 0.0
	_volando = true
	collision_mask = 1 | 4 # mundo + enemigos
	golpe.activo = true


func _physics_process(delta: float) -> void:
	if not _volando:
		return
	var paso := _dir * velocidad_vuelo * delta
	var choque := move_and_collide(paso)
	_recorrido += paso.length()
	var t := clampf(_recorrido / _distancia, 0.0, 1.0)
	visual.position.y = _visual_y + lerpf(_altura_inicial, 0.0, t) - sin(t * PI) * altura_arco
	if choque or t >= 1.0:
		_aterrizar()


func _aterrizar() -> void:
	_volando = false
	visual.position.y = _visual_y
	if rompible:
		romper()
		return
	golpe.activo = false
	collision_layer = _capa_original
	collision_mask = _mascara_original


func romper() -> void:
	_volando = false
	collision_layer = 0
	golpe.set_deferred(&"activo", false)
	roto.emit()
	if botin and randf() < probabilidad_botin:
		var b := botin.instantiate() as Node2D
		get_parent().add_child.call_deferred(b)
		b.global_position = global_position
	# TODO: partículas / sonido de romperse cuando haya arte.
	var t := create_tween()
	t.tween_property(visual, ^"scale", Vector2(1.4, 0.4), 0.08)
	t.parallel().tween_property(visual, ^"modulate:a", 0.0, 0.12)
	t.tween_callback(queue_free)


## Golpe de espada (u otro Hitbox).
func recibir_golpe(_danio: int, _origen: Vector2) -> void:
	if se_rompe_con_espada and not _volando:
		romper()
