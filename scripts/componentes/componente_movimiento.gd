class_name ComponenteMovimiento
extends Node
## Mueve el CharacterBody2D padre (modo flotante, vista cenital): el cerebro de la entidad
## fija su intención con `mover()`, `frenar()`, `impulsar()`, `empujar_desde()` o `detener()` y
## este componente llama a `move_and_slide()` en su `_physics_process`. Funciona porque el
## padre se procesa antes que sus hijos, así que la intención y el movimiento ocurren en el
## mismo tick. Con `aplicar_movimiento` en false no mueve el cuerpo (lo hace otro).

## Tras `move_and_slide()`, una vez por cada colisión de ese tick.
signal choco(colision: KinematicCollision2D)

## Cuerpo que mueve. Si está vacío usa el nodo padre (debe ser un CharacterBody2D).
@export var cuerpo: CharacterBody2D
## Velocidad máxima por defecto (px/s). Conviene un múltiplo de 60 (la física va a 120 ticks/s).
@export var velocidad := 80.0
## Lo que acelera hacia la velocidad objetivo (px/s²).
@export var aceleracion := 900.0
## Lo que frena al soltar el movimiento (px/s²).
@export var friccion := 1100.0
## Si es false no llama a `move_and_slide()` (el cuerpo lo mueve otra cosa).
@export var aplicar_movimiento := true


func _ready() -> void:
	if cuerpo == null:
		cuerpo = get_parent() as CharacterBody2D
	assert(cuerpo != null, "ComponenteMovimiento necesita un CharacterBody2D")
	cuerpo.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _physics_process(_delta: float) -> void:
	if not aplicar_movimiento:
		return
	cuerpo.move_and_slide()
	for i in cuerpo.get_slide_collision_count():
		choco.emit(cuerpo.get_slide_collision(i))


func mover(direccion: Vector2, delta: float, vel := -1.0) -> void:
	if direccion == Vector2.ZERO:
		frenar(delta)
		return
	var objetivo := direccion.limit_length(1.0) * (vel if vel >= 0.0 else velocidad)
	cuerpo.velocity = cuerpo.velocity.move_toward(objetivo, aceleracion * delta)


func frenar(delta: float, factor := 1.0) -> void:
	cuerpo.velocity = cuerpo.velocity.move_toward(Vector2.ZERO, friccion * factor * delta)


func impulsar(nueva_velocidad: Vector2) -> void:
	cuerpo.velocity = nueva_velocidad


func empujar_desde(origen: Vector2, fuerza: float, por_defecto := Vector2.DOWN) -> void:
	var dir := cuerpo.global_position - origen
	cuerpo.velocity = (dir.normalized() if dir.length() > 0.1 else por_defecto) * fuerza


func detener() -> void:
	cuerpo.velocity = Vector2.ZERO
