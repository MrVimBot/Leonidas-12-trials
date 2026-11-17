@tool
class_name ComponenteAtaque
extends Node
## Ataque cuerpo a cuerpo: `atacar()` habilita en el `Hitbox` solo la forma de la dirección del
## animador, reproduce la animación y activa el Hitbox solo mientras el frame está dentro de
## `frames_golpe`. Al acabar la animación emite `termino`.
## Formas: un CollisionShape2D hijo del Hitbox por dirección (`Abajo`, `Arriba`, `Izquierda`,
## `Derecha`), asignados en el grupo Formas; se ven y se ajustan en el editor 2D. En juego
## `_ready` las deshabilita todas y `atacar()` habilita solo la que toca (`Hitbox.consultar()`
## ignora las deshabilitadas). Una dirección sin forma usa la de Abajo (y si tampoco hay, la de
## Izquierda): así la falsa flor, que solo mira a los lados (`solo_lados`), lleva dos.
## Necesita además un `AnimadorDireccional`. Decidir cuándo atacar es cosa del cerebro.
## `@tool` solo para avisar en el editor de lo que falta; en el editor no hace nada más (no
## toca `disabled`: allí se ven las cuatro formas).

## Al empezar un ataque.
signal empezo
## Al terminar la animación del ataque (no si se `cancelar()`).
signal termino

## Hitbox que se activa (padre de las formas); su `danio` se sustituye por el de este componente.
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

@export_group("Formas")
## Forma del golpe al mirar abajo (CollisionShape2D hijo del `hitbox`). Respaldo de las
## direcciones sin forma.
@export var forma_abajo: CollisionShape2D:
	set(valor):
		forma_abajo = valor
		update_configuration_warnings()
## Forma del golpe al mirar arriba (hija del `hitbox`).
@export var forma_arriba: CollisionShape2D:
	set(valor):
		forma_arriba = valor
		update_configuration_warnings()
## Forma del golpe al mirar a la izquierda (hija del `hitbox`).
@export var forma_izquierda: CollisionShape2D:
	set(valor):
		forma_izquierda = valor
		update_configuration_warnings()
## Forma del golpe al mirar a la derecha (hija del `hitbox`).
@export var forma_derecha: CollisionShape2D:
	set(valor):
		forma_derecha = valor
		update_configuration_warnings()
## La entidad solo mira a izquierda/derecha (falsa flor): no necesita formas de Abajo ni de
## Arriba (si alguna vez mirara así, usaría la de Izquierda).
@export var solo_lados := false:
	set(valor):
		solo_lados = valor
		update_configuration_warnings()

## True entre `atacar()` y el fin (o cancelación) del ataque.
var atacando := false


func _ready() -> void:
	# En el editor no toca las formas ni el Hitbox (se guardaría en la escena).
	if Engine.is_editor_hint():
		return
	assert(hitbox != null and animador != null, "ComponenteAtaque necesita hitbox y animador")
	assert(_forma_respaldo() != null, "ComponenteAtaque necesita al menos la forma de Abajo o la de Izquierda")
	for forma in _formas():
		forma.disabled = true
	hitbox.danio = danio
	hitbox.activo = false
	animador.frame_cambio.connect(_al_cambiar_frame)
	animador.termino.connect(_al_terminar)


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if hitbox == null:
		avisos.append("Asigna el Hitbox en `hitbox`.")
	if animador == null:
		avisos.append("Asigna el AnimadorDireccional en `animador`.")
	var requeridas: Dictionary[String, CollisionShape2D] = {}
	if not solo_lados:
		requeridas["Abajo"] = forma_abajo
		requeridas["Arriba"] = forma_arriba
	requeridas["Izquierda"] = forma_izquierda
	requeridas["Derecha"] = forma_derecha
	for nombre in requeridas:
		var forma := requeridas[nombre]
		if forma == null:
			avisos.append("Falta la forma de %s (`forma_%s`)." % [nombre, nombre.to_lower()])
		elif forma.shape == null:
			avisos.append("La forma de %s no tiene `shape`." % nombre)
		elif hitbox != null and forma.get_parent() != hitbox:
			avisos.append("La forma de %s debe ser hija directa del Hitbox (`hitbox`)." % nombre)
	return avisos


## Formas asignadas (sin repetir), para deshabilitarlas.
func _formas() -> Array[CollisionShape2D]:
	var res: Array[CollisionShape2D] = []
	for forma: CollisionShape2D in [forma_abajo, forma_arriba, forma_izquierda, forma_derecha]:
		if forma != null and forma not in res:
			res.append(forma)
	return res


## Forma de las direcciones que no tienen la suya: Abajo o, si no hay, Izquierda.
func _forma_respaldo() -> CollisionShape2D:
	return forma_abajo if forma_abajo != null else forma_izquierda


## Forma que golpea mirando a `direccion` (cardinal); la de respaldo si no tiene.
func _forma_para(direccion: Vector2) -> CollisionShape2D:
	var forma: CollisionShape2D = null
	match direccion:
		Vector2.DOWN:
			forma = forma_abajo
		Vector2.UP:
			forma = forma_arriba
		Vector2.LEFT:
			forma = forma_izquierda
		Vector2.RIGHT:
			forma = forma_derecha
	return forma if forma != null else _forma_respaldo()


func atacar() -> void:
	atacando = true
	# Solo cuenta la forma de esta dirección; la del ataque anterior queda deshabilitada.
	var elegida := _forma_para(animador.direccion)
	for forma in _formas():
		forma.disabled = forma != elegida
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
