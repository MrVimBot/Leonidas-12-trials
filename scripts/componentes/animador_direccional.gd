@tool
class_name AnimadorDireccional
extends Node
## Elige la animación según hacia dónde mira la entidad. Es el ÚNICO que toca su `sprite`
## (animación y espejo): los cerebros le piden animaciones, no manipulan el sprite.
##
## Sufijos: las animaciones del SpriteFrames se llaman `<base>_frente`, `<base>_lado` y
## `<base>_espalda` (abajo, izquierda/derecha, arriba). `reproducir(base)` escoge el sufijo y
## espeja el sprite para el lado que no está dibujado (`lado_mira` dice a cuál mira el dibujo).
## Respaldo: si falta la vista lateral o la de espalda (seta bomba, sabios, tendedera), usa la
## de frente sin espejo; si no hay direcciones (flor, tiburón, `comer`), la animación `base`
## tal cual (espejada solo con `espejar_sin_direccion`).
## `reproducir(base, reiniciar, invertir_lado = true)`: para animaciones laterales dibujadas al
## revés que el resto del SpriteFrames (pirueta del jugador, barco). `reproducir_fija(nombre)`
## reproduce una animación tal cual, sin sufijo ni espejo (pose de comer / objeto obtenido).
##
## Diagonales: `direccion` es siempre cardinal. `orientar(entrada)` aplica la regla tipo
## Zelda: al moverse en diagonal conserva la dirección actual si sigue siendo parte de la
## diagonal, y solo gira si no; `mirar(hacia)` gira sin esa regla.
##
## `@tool` solo para avisar en el editor (`_get_configuration_warnings`) si falta `sprite`;
## en el editor no hace nada más (`_ready` sale con `Engine.is_editor_hint()`).

## Hacia qué lado está dibujada la animación lateral.
enum Lado { IZQUIERDA, DERECHA }

## Al terminar una animación sin bucle.
signal termino(animacion: StringName)
## Al cambiar el frame del sprite.
signal frame_cambio(frame: int)
## Al cambiar la dirección cardinal.
signal direccion_cambio(direccion: Vector2)

## Sprite que se controla.
@export var sprite: AnimatedSprite2D:
	set(valor):
		sprite = valor
		update_configuration_warnings()
## Hacia qué lado está dibujada la animación lateral (se espeja para el otro). Si el
## SpriteFrames tiene el meta `side_faces`, manda ese valor.
@export var lado_mira := Lado.IZQUIERDA
## Para sprites sin direcciones (p. ej. la flor falsa): las animaciones sin sufijo
## también se espejan según hacia qué lado (izquierda/derecha) se mira por última vez.
@export var espejar_sin_direccion := false

var direccion := Vector2.DOWN:
	set(valor):
		if valor != direccion:
			direccion = valor
			direccion_cambio.emit(valor)


func _ready() -> void:
	# En el editor no conecta señales ni toca `lado_mira` (se guardaría en la escena).
	if Engine.is_editor_hint():
		return
	assert(sprite != null, "AnimadorDireccional necesita un AnimatedSprite2D")
	if sprite.sprite_frames and sprite.sprite_frames.has_meta(&"side_faces"):
		# El meta lo escribe tools/sprite_frames_builder.gd como texto ("izquierda"/"derecha").
		var meta := str(sprite.sprite_frames.get_meta(&"side_faces"))
		lado_mira = Lado.DERECHA if meta == "derecha" else Lado.IZQUIERDA
	sprite.animation_finished.connect(func() -> void: termino.emit(sprite.animation))
	sprite.frame_changed.connect(func() -> void: frame_cambio.emit(sprite.frame))


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if sprite == null:
		avisos.append("Asigna el AnimatedSprite2D en `sprite`.")
	return avisos


func orientar(entrada: Vector2) -> void:
	if entrada == Vector2.ZERO:
		return
	var en_diagonal := absf(entrada.x) > 0.2 and absf(entrada.y) > 0.2
	if en_diagonal and direccion.dot(entrada) > 0.0:
		return
	mirar(entrada)


func mirar(hacia: Vector2) -> void:
	if hacia == Vector2.ZERO:
		return
	if absf(hacia.x) >= absf(hacia.y):
		direccion = Vector2(signf(hacia.x), 0)
	else:
		direccion = Vector2(0, signf(hacia.y))


func sufijo() -> String:
	match direccion:
		Vector2.DOWN:
			return "frente"
		Vector2.UP:
			return "espalda"
	return "lado"


## Reproduce `base_frente/lado/espalda` según la dirección. Si el sprite no tiene vista
## lateral o de espalda, usa la de frente; si no tiene direcciones, `base`. Si no existe
## ninguna, no hace nada. `invertir_lado` invierte el espejo cuando sale la vista lateral.
func reproducir(base: StringName, reiniciar := false, invertir_lado := false) -> void:
	var frames := sprite.sprite_frames
	if frames == null:
		return
	var suf := sufijo()
	var nombre := StringName("%s_%s" % [base, suf])
	if suf != "frente" and not frames.has_animation(nombre):
		suf = "frente"
		nombre = StringName("%s_frente" % base)
	var direccional := frames.has_animation(nombre)
	if not direccional:
		nombre = base
		if not frames.has_animation(nombre):
			return
	var mira_derecha := direccion == Vector2.RIGHT
	if direccional:
		sprite.flip_h = suf == "lado" and (mira_derecha == _mira_a_la_izquierda())
		if suf == "lado" and invertir_lado:
			sprite.flip_h = not sprite.flip_h
	elif espejar_sin_direccion:
		if direccion.x != 0.0:
			sprite.flip_h = mira_derecha == _mira_a_la_izquierda()
	else:
		sprite.flip_h = false
	if reiniciar or sprite.animation != nombre:
		sprite.play(nombre)


## Reproduce `nombre` tal cual: sin sufijo de dirección ni espejo. No cambia `direccion`
## (si la pose es de frente, quien la pide decide si fijar `direccion` a abajo).
func reproducir_fija(nombre: StringName, reiniciar := true) -> void:
	sprite.flip_h = false
	if reiniciar or sprite.animation != nombre:
		sprite.play(nombre)


func animacion_actual() -> StringName:
	return sprite.animation


func frame_actual() -> int:
	return sprite.frame


func _mira_a_la_izquierda() -> bool:
	return lado_mira == Lado.IZQUIERDA
