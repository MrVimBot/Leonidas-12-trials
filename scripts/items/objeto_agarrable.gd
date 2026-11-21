class_name ObjetoAgarrable
extends StaticBody2D
## Objeto que Leonidas puede levantar, cargar y lanzar (rocas, vasijas...).
## En el suelo bloquea el paso (capa mundo). Al lanzarlo vuela en línea recta con
## un pequeño arco, golpea con su Hitbox "Golpe" y se rompe al caer o chocar.
##
## Estructura de la escena (scenes/items/objeto_agarrable.tscn, de la que heredan vasijas,
## piedra y arbusto): StaticBody2D (capas mundo + interactuable) con este script, un hijo
## "Visual" (Sprite2D/Node2D), su CollisionShape2D, un hijo "Golpe" (Hitbox, capa
## golpe_jugador, máscara enemigos + interactuable) y, si se rompe con animación, un
## AnimatedSprite2D oculto ("Rotura", asignado en `sprite_rotura`).

## Al romperse.
signal roto

## Se rompe al aterrizar. Si es false, vuelve a quedar en el suelo.
@export var rompible := true
## Además se puede romper con la espada (vasijas). Las rocas no.
@export var se_rompe_con_espada := false
@export var velocidad_vuelo := 190.0
@export var altura_arco := 6.0
## Probabilidad (0–1) de soltar algo al romperse; la escena a soltar va en `botin`.
## Es una escena de ObjetoSuelto (la moneda), igual que la de los enemigos.
@export var botin: PackedScene
@export_range(0.0, 1.0) var probabilidad_botin := 0.0
## Cuántas unidades de `botin` salen cuando toca soltar.
@export var monedas_min := 1
@export var monedas_max := 2
@export_group("Sonido")
## Suena al romperse (vasijas). Vacío = en silencio.
@export var sonido_rotura: AudioStreamPlayer
## Suena al caer tras lanzarlo sin romperse (piedra). Vacío = en silencio.
@export var sonido_caida: AudioStreamPlayer
@export_group("Rotura")
## Animación de `sprite_rotura` al romperse. Vacía = se aplasta y desvanece (respaldo).
@export var animacion_rotura: StringName
## AnimatedSprite2D (oculto en la escena) con la animación de romperse; sus pies son los del objeto.
@export var sprite_rotura: AnimatedSprite2D
## Segundos que se quedan los trozos en el suelo antes de desvanecerse.
@export var duracion_restos := 1.0
## Lo que queda en el sitio al levantarlo o cortarlo (el tocón del arbusto). Se pone una
## sola vez, donde estaba el objeto.
@export var resto: PackedScene

var _capa_original: int
var _padre_original: Node
var _mascara_original: int
var _visual_y: float
var _volando := false
var _roto := false
var _resto_dejado := false
var _dir := Vector2.ZERO
var _distancia := 0.0
var _recorrido := 0.0
var _altura_inicial := 0.0

@onready var visual: Node2D = $Visual
@onready var golpe: Hitbox = $Golpe


func _ready() -> void:
	_capa_original = collision_layer
	_mascara_original = collision_mask
	_visual_y = visual.position.y
	golpe.activo = false


## Lo llama el jugador. Se engancha a `punto` (encima de la cabeza).
func levantar(punto: Node2D) -> void:
	collision_layer = 0
	collision_mask = 0
	_padre_original = get_parent() # la zona: al lanzarlo vuelve a ella (no a Game)
	_dejar_resto()
	# Sin z_index: en brazos se ordena por Y con su portador (hijo de Leonidas), así los árboles
	# y casas lo tapan cuando Leonidas está detrás de ellos.
	reparent(punto)
	var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, ^"position", Vector2.ZERO, 0.2)


## Sale volando desde encima de la cabeza. `pies` = posición de los pies del jugador.
## Con distancia 0 simplemente cae delante (p. ej. al recibir daño).
func lanzar(dir: Vector2, distancia: float, pies: Vector2) -> void:
	var altura := global_position.y - pies.y # negativo: está por encima
	# Vuelve al nodo de la zona del que se levantó: si fuera hijo de Game, un objeto no
	# rompible sobreviviría al cambio de zona.
	var destino := _padre_original if is_instance_valid(_padre_original) else get_tree().current_scene
	reparent(destino)
	# El nodo pasa a estar "en el suelo"; la altura se simula moviendo solo el Visual.
	global_position = pies + dir * 6.0
	_altura_inicial = altura
	visual.position.y = _visual_y + altura
	_dir = dir
	_distancia = maxf(distancia, 1.0)
	_recorrido = 0.0
	_volando = true
	collision_mask = Capas.MUNDO | Capas.ENEMIGOS
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
	if sonido_caida:
		sonido_caida.play()
	golpe.activo = false
	collision_layer = _capa_original
	collision_mask = _mascara_original


func romper() -> void:
	if _roto:
		return
	_roto = true
	_volando = false
	collision_layer = 0
	golpe.set_deferred(&"activo", false)
	roto.emit()
	if sonido_rotura:
		sonido_rotura.play()
	# Cortado en el sitio (con la espada): el resto aún no se dejó. Tras el vuelo ya está.
	_dejar_resto()
	if botin and randf() < probabilidad_botin:
		# Mismo padre que este objeto; `soltar` añade diferido (puede llamarse desde física).
		ObjetoSuelto.soltar(botin, get_parent(), global_position, randi_range(monedas_min, monedas_max))
	var sombra := get_node_or_null(^"Sombra") as CanvasItem
	if sombra:
		sombra.hide()
	if sprite_rotura and animacion_rotura != &"":
		visual.hide()
		sprite_rotura.show()
		sprite_rotura.play(animacion_rotura)
		await sprite_rotura.animation_finished
		await get_tree().create_timer(duracion_restos, false).timeout
		var t := create_tween()
		t.tween_property(sprite_rotura, ^"modulate:a", 0.0, 0.3)
		t.tween_callback(queue_free)
		return
	# Respaldo sin animación: se aplasta y se desvanece.
	var t2 := create_tween()
	t2.tween_property(visual, ^"scale", Vector2(1.4, 0.4), 0.08)
	t2.parallel().tween_property(visual, ^"modulate:a", 0.0, 0.12)
	t2.tween_callback(queue_free)


## Pone `resto` (el tocón) en el sitio original, una sola vez.
func _dejar_resto() -> void:
	if _resto_dejado or resto == null:
		return
	_resto_dejado = true
	var r := resto.instantiate() as Node2D
	r.position = position
	get_parent().add_child.call_deferred(r)


## Golpe de espada (u otro Hitbox).
func recibir_golpe(_danio: int, _origen: Vector2) -> void:
	if se_rompe_con_espada and not _volando:
		romper()
