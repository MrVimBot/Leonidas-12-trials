class_name ComponenteMuerte
extends Node
## Muerte de un enemigo (u objeto con vida) sin animación propia: al recibir `murio`
## de su `vida`, apaga sus golpes y colisiones, suelta `monedas` (saltan al suelo
## y el jugador las recoge: `Moneda`), hace un destello,
## se aplasta y se desvanece, y elimina a `cuerpo`.

signal termino

@export var vida: ComponenteVida
@export var visual: CanvasItem
## Nodo que se elimina al terminar (por defecto, el padre).
@export var cuerpo: Node
## Hitbox y Hurtbox que dejan de funcionar al morir.
@export var desactivar: Array[Node] = []
@export var duracion := 0.45
## Monedas que suelta al morir (cada una vale 1; salen saltando para recogerlas).
@export var monedas := 0


func _ready() -> void:
	if cuerpo == null:
		cuerpo = get_parent()
	assert(vida != null, "ComponenteMuerte necesita un ComponenteVida")
	vida.murio.connect(morir)


func morir() -> void:
	for n in desactivar:
		if n is Hitbox or n is Hurtbox:
			n.set_deferred(&"activo", false)
		if n is Area2D:
			n.set_deferred(&"monitorable", false)
	if cuerpo is CollisionObject2D:
		cuerpo.set_deferred(&"collision_layer", 0)
		cuerpo.set_deferred(&"collision_mask", 0)
	if monedas > 0 and cuerpo is Node2D and cuerpo.get_parent():
		Moneda.soltar(cuerpo.get_parent(), cuerpo.global_position, monedas)
	if visual == null:
		_terminar()
		return
	var t := create_tween()
	t.tween_property(visual, ^"modulate", Color(3, 3, 3, 1), 0.06)
	t.tween_property(visual, ^"modulate", Color.WHITE, 0.08)
	if visual is Node2D:
		t.tween_property(visual, ^"scale", Vector2(1.3, 0.3), duracion).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(visual, ^"modulate:a", 0.0, duracion)
	t.tween_callback(_terminar)


func _terminar() -> void:
	termino.emit()
	cuerpo.queue_free()
