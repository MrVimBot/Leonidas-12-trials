class_name AnimadorDireccional
extends Node

signal termino(animacion: StringName)
signal frame_cambio(frame: int)
signal direccion_cambio(direccion: Vector2)

@export var sprite: AnimatedSprite2D

@export_enum("izquierda", "derecha") var lado_mira := "izquierda"

var direccion := Vector2.DOWN:
	set(valor):
		if valor != direccion:
			direccion = valor
			direccion_cambio.emit(valor)


func _ready() -> void:
	assert(sprite != null, "AnimadorDireccional necesita un AnimatedSprite2D")
	if sprite.sprite_frames and sprite.sprite_frames.has_meta(&"side_faces"):
		lado_mira = sprite.sprite_frames.get_meta(&"side_faces")
	sprite.animation_finished.connect(func() -> void: termino.emit(sprite.animation))
	sprite.frame_changed.connect(func() -> void: frame_cambio.emit(sprite.frame))


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


func reproducir(base: StringName, reiniciar := false) -> void:
	var nombre := StringName("%s_%s" % [base, sufijo()])
	var direccional := sprite.sprite_frames.has_animation(nombre)
	if not direccional:
		nombre = base
	var mira_derecha := direccion == Vector2.RIGHT
	sprite.flip_h = direccional and sufijo() == "lado" and (mira_derecha == (lado_mira == "izquierda"))
	if reiniciar or sprite.animation != nombre:
		sprite.play(nombre)


func animacion_actual() -> StringName:
	return sprite.animation


func frame_actual() -> int:
	return sprite.frame
