class_name ComponenteAtaque
extends Node


signal empezo
signal termino

@export var hitbox: Hitbox
@export var animador: AnimadorDireccional
@export var animacion: StringName = &"ataque"
@export var frames_golpe := Vector2i(1, 5)
@export var danio := 1
@export var formas := {
	Vector2.DOWN: Rect2(0, 2, 22, 14),
	Vector2.UP: Rect2(0, -24, 22, 14),
	Vector2.LEFT: Rect2(-15, -10, 16, 20),
	Vector2.RIGHT: Rect2(15, -10, 16, 20),
}

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
