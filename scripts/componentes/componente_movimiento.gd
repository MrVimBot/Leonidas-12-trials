class_name ComponenteMovimiento
extends Node


signal choco(colision: KinematicCollision2D)

@export var cuerpo: CharacterBody2D
@export var velocidad := 80.0
@export var aceleracion := 900.0
@export var friccion := 1100.0
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
