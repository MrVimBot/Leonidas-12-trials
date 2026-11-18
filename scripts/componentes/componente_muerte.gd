@tool
class_name ComponenteMuerte
extends Node
## Muerte de un enemigo (u objeto con vida) sin animación propia: al recibir `murio`
## de su `vida`, apaga sus golpes y colisiones, suelta `monedas` (saltan al suelo
## y el jugador las recoge: `ObjetoSuelto`), se aplasta y se
## desvanece, y elimina a `cuerpo`.
## `@tool` solo para avisar en el editor de lo que falta; en el editor no hace nada más.

signal termino

## Respaldo de `escena_moneda` (ver `_escena_moneda()`).
const RUTA_MONEDA := "res://scenes/items/moneda.tscn"

@export var vida: ComponenteVida:
	set(valor):
		vida = valor
		update_configuration_warnings()
@export var visual: CanvasItem
## Nodo que se elimina al terminar (por defecto, el padre).
@export var cuerpo: Node
## Hitbox y Hurtbox que dejan de funcionar al morir.
@export var desactivar: Array[Node] = []
@export var duracion := 0.45
## Monedas que suelta al morir (cada una vale 1; salen saltando para recogerlas).
@export var monedas := 0
## Escena de la moneda suelta. Vacía = scenes/items/moneda.tscn (ver `_escena_moneda()`).
@export var escena_moneda: PackedScene
## Suena al morir (hijo del enemigo: dura menos que `duracion`, así acaba antes de liberarlo).
@export var sonido: AudioStreamPlayer


func _ready() -> void:
	# En el editor no rellena `cuerpo` (se guardaría en la escena) ni se conecta a la vida.
	if Engine.is_editor_hint():
		return
	if cuerpo == null:
		cuerpo = get_parent()
	assert(vida != null, "ComponenteMuerte necesita un ComponenteVida")
	vida.murio.connect(morir)


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if vida == null:
		avisos.append("Asigna el ComponenteVida en `vida` (muere cuando emite `murio`).")
	return avisos


func morir() -> void:
	if sonido:
		sonido.play()
	for n in desactivar:
		if n is Hitbox or n is Hurtbox:
			n.set_deferred(&"activo", false)
		if n is Area2D:
			n.set_deferred(&"monitorable", false)
	if cuerpo is CollisionObject2D:
		cuerpo.set_deferred(&"collision_layer", 0)
		cuerpo.set_deferred(&"collision_mask", 0)
	var cuerpo_2d := cuerpo as Node2D
	if monedas > 0 and cuerpo_2d and cuerpo_2d.get_parent():
		ObjetoSuelto.soltar(_escena_moneda(), cuerpo_2d.get_parent(), cuerpo_2d.global_position, monedas)
	if visual == null:
		_terminar()
		return
	var t := create_tween()
	# Sin destello blanco: Color(3, 3, 3) no se ve con GL Compatibility (los valores > 1
	# se recortan). Para tener destello haría falta un shader. Decidido el 2026-11-17.
	if visual is Node2D:
		# Relativo a la escala de partida: el arte pintado del nivel 2 va a 0,5 y un
		# (1.3, 0.3) absoluto lo haría crecer al morir.
		t.tween_property(visual, ^"scale", (visual as Node2D).scale * Vector2(1.3, 0.3), duracion).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(visual, ^"modulate:a", 0.0, duracion)
	t.tween_callback(_terminar)


## Respaldo mientras las escenas de los enemigos no tengan `escena_moneda` asignada en el
## Inspector: se carga con `load()` la primera vez que hace falta (no con `preload`, que
## ataría este script a la escena de la moneda al compilarse). Cuando todas la tengan
## asignada, se puede quitar.
func _escena_moneda() -> PackedScene:
	if escena_moneda == null:
		escena_moneda = load(RUTA_MONEDA) as PackedScene
	return escena_moneda


func _terminar() -> void:
	termino.emit()
	cuerpo.queue_free()
