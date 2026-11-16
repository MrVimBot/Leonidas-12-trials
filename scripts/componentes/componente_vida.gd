class_name ComponenteVida
extends Node
## Vida de una entidad, en cuartos de corazón (4 = un corazón). `recibir_danio()` resta,
## `curar()` suma, y tras un golpe que no mata da `invulnerabilidad` segundos de
## inmunidad. Si se asigna un `hurtbox`, se conecta solo a su señal `golpeado`.
## Emite `murio` al llegar a 0; `restaurar()` la deja llena otra vez (reaparecer).

## Cada vez que cambia la vida. No se emite al empezar: quien se conecte lee `vida` y `vida_max`.
signal cambio(vida: int, vida_max: int)
## Al recibir daño efectivo (no si era invulnerable): cantidad y posición de origen.
signal danado(cantidad: int, origen: Vector2)
## Al curarse algo: cuánto se curó de verdad.
signal curado(cantidad: int)
## Al llegar la vida a 0.
signal murio

## Vida máxima (y con la que empieza), en cuartos de corazón.
@export var vida_max: int = 6
## Segundos de invulnerabilidad tras recibir un golpe que no mata.
@export var invulnerabilidad: float = 1.0
## Hurtbox cuyos golpes restan vida (opcional: sin él, se llama a `recibir_danio()` a mano).
@export var hurtbox: Hurtbox

## Vida actual.
var vida: int
## True al llegar a 0 hasta `restaurar()`.
var muerto := false
## Invulnerabilidad añadida por quien la controle (voltereta, bloqueo); no caduca sola.
var invulnerable_extra := false

var _tiempo_invulnerable := 0.0


func _ready() -> void:
	vida = vida_max
	if hurtbox:
		hurtbox.golpeado.connect(recibir_danio)


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


## Fija la vida (p. ej. al cargar una partida): la limita a 0..`vida_max` y emite `cambio`.
## No emite `danado`, `curado` ni `murio`, ni da invulnerabilidad: está pensado para valores
## > 0; con 0 solo deja `muerto` en true, sin avisar.
func fijar(valor: int) -> void:
	vida = clampi(valor, 0, vida_max)
	muerto = vida == 0
	cambio.emit(vida, vida_max)


func restaurar() -> void:
	vida = vida_max
	muerto = false
	_tiempo_invulnerable = invulnerabilidad
	cambio.emit(vida, vida_max)


func es_invulnerable() -> bool:
	return _tiempo_invulnerable > 0.0 or invulnerable_extra


func tiempo_invulnerable() -> float:
	return maxf(_tiempo_invulnerable, 0.0)
