@tool
class_name ComponenteAtaque
extends Node
## Ataque cuerpo a cuerpo: `atacar()` coloca el `Hitbox` según la dirección del animador (un
## rectángulo por dirección en `formas`), reproduce la animación y lo activa solo mientras
## el frame está dentro de `frames_golpe`. Al acabar la animación emite `termino`.
## Necesita un `Hitbox` hijo con un CollisionShape2D rectangular (se le duplica la forma) y
## un `AnimadorDireccional`. Decidir cuándo atacar es cosa del cerebro.
## `@tool` solo para avisar en el editor de lo que falta; en el editor no hace nada más.

## Al empezar un ataque.
signal empezo
## Al terminar la animación del ataque (no si se `cancelar()`).
signal termino

## Hitbox que se coloca y se activa; su `danio` se sustituye por el de este componente.
@export var hitbox: Hitbox:
	set(valor):
		hitbox = valor
		update_configuration_warnings()
## Animador que da la dirección y reproduce la animación.
@export var animador: AnimadorDireccional:
	set(valor):
		animador = valor
		update_configuration_warnings()
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
	# En el editor no duplica la forma ni toca el Hitbox (se guardaría en la escena).
	if Engine.is_editor_hint():
		return
	assert(hitbox != null and animador != null, "ComponenteAtaque necesita hitbox y animador")
	_forma = _forma_del_hitbox()
	assert(_forma != null and _forma.shape is RectangleShape2D, "El Hitbox necesita un CollisionShape2D rectangular")
	_forma.shape = _forma.shape.duplicate()
	hitbox.danio = danio
	hitbox.activo = false
	animador.frame_cambio.connect(_al_cambiar_frame)
	animador.termino.connect(_al_terminar)


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if hitbox == null:
		avisos.append("Asigna el Hitbox en `hitbox`.")
	else:
		var forma := _forma_del_hitbox()
		if forma == null or not forma.shape is RectangleShape2D:
			avisos.append("El Hitbox de `hitbox` necesita un CollisionShape2D hijo con forma rectangular (RectangleShape2D).")
	if animador == null:
		avisos.append("Asigna el AnimadorDireccional en `animador`.")
	return avisos


## Primer CollisionShape2D hijo del Hitbox (la forma que se mueve y redimensiona), o null.
func _forma_del_hitbox() -> CollisionShape2D:
	for c in hitbox.get_children():
		var forma := c as CollisionShape2D
		if forma:
			return forma
	return null


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
