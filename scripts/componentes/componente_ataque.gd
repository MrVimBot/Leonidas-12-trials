class_name ComponenteAtaque
extends Node
## Ataque cuerpo a cuerpo: `atacar()` coloca el `Hitbox` según la dirección del animador (un
## rectángulo por dirección en `formas`), reproduce la animación y lo activa solo mientras
## el frame está dentro de `frames_golpe`. Al acabar la animación emite `termino`.
## Necesita un `Hitbox` hijo con un CollisionShape2D rectangular (se le duplica la forma) y
## un `AnimadorDireccional`. Decidir cuándo atacar es cosa del cerebro.

## Al empezar un ataque.
signal empezo
## Al terminar la animación del ataque (no si se `cancelar()`).
signal termino

## Hitbox que se coloca y se activa; su `danio` se sustituye por el de este componente.
@export var hitbox: Hitbox
## Animador que da la dirección y reproduce la animación.
@export var animador: AnimadorDireccional
## Animación base que se reproduce (`ataque_frente/lado/espalda`).
@export var animacion: StringName = &"ataque"
## Primer y último frame (incluidos) en que el Hitbox hace daño.
@export var frames_golpe := Vector2i(1, 5)
## Daño del golpe, en cuartos de corazón.
@export var danio := 1
## Rectángulo del Hitbox (relativo a los pies) para cada dirección cardinal.
@export var formas := {
	Vector2.DOWN: Rect2(0, 2, 22, 14),
	Vector2.UP: Rect2(0, -24, 22, 14),
	Vector2.LEFT: Rect2(-15, -10, 16, 20),
	Vector2.RIGHT: Rect2(15, -10, 16, 20),
}

## True entre `atacar()` y el fin (o cancelación) del ataque.
var atacando := false

var _forma: CollisionShape2D


func _ready() -> void:
	assert(hitbox != null and animador != null, "ComponenteAtaque necesita hitbox y animador")
	for c in hitbox.get_children():
		if c is CollisionShape2D:
			_forma = c
			break
	assert(_forma != null and _forma.shape is RectangleShape2D, "El Hitbox necesita un CollisionShape2D rectangular")
	_forma.shape = _forma.shape.duplicate()
	hitbox.danio = danio
	hitbox.activo = false
	animador.frame_cambio.connect(_al_cambiar_frame)
	animador.termino.connect(_al_terminar)


func atacar() -> void:
	atacando = true
	var r: Rect2 = formas.get(animador.direccion, formas[Vector2.DOWN])
	_forma.position = r.position
	(_forma.shape as RectangleShape2D).size = r.size
	hitbox.danio = danio
	animador.reproducir(animacion, true)
	empezo.emit()


func cancelar() -> void:
	atacando = false
	hitbox.activo = false


func _al_cambiar_frame(frame: int) -> void:
	if atacando:
		hitbox.activo = frame >= frames_golpe.x and frame <= frames_golpe.y


func _al_terminar(_anim: StringName) -> void:
	if not atacando:
		return
	cancelar()
	termino.emit()
