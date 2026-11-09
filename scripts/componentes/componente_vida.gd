class_name ComponenteVida
extends Node


signal cambio(vida: int, vida_max: int)
signal danado(cantidad: int, origen: Vector2)
signal curado(cantidad: int)
signal murio

@export var vida_max: int = 6
@export var invulnerabilidad: float = 1.0
@export var hurtbox: Hurtbox

var vida: int
var muerto := false
var invulnerable_extra := false

var _tiempo_invulnerable := 0.0


func _ready() -> void:
	vida = vida_max
	if hurtbox:
		hurtbox.golpeado.connect(recibir_danio)
	cambio.emit.call_deferred(vida, vida_max)


func _physics_process(delta: float) -> void:
	if _tiempo_invulnerable > 0.0:
		_tiempo_invulnerable -= delta


func recibir_danio(cantidad: int, origen: Vector2 = Vector2.ZERO) -> void:
	if muerto or cantidad <= 0 or es_invulnerable():
		return
	vida = maxi(vida - cantidad, 0)
	muerto = vida == 0
	if not muerto:
		_tiempo_invulnerable = invulnerabilidad
	cambio.emit(vida, vida_max)
	danado.emit(cantidad, origen)
	if muerto:
		murio.emit()


func curar(cantidad: int) -> void:
	if muerto or cantidad <= 0:
		return
	var antes := vida
	vida = mini(vida + cantidad, vida_max)
	if vida != antes:
		cambio.emit(vida, vida_max)
		curado.emit(vida - antes)


func restaurar() -> void:
	vida = vida_max
	muerto = false
	_tiempo_invulnerable = invulnerabilidad
	cambio.emit(vida, vida_max)


func es_invulnerable() -> bool:
	return _tiempo_invulnerable > 0.0 or invulnerable_extra


func tiempo_invulnerable() -> float:
	return maxf(_tiempo_invulnerable, 0.0)
