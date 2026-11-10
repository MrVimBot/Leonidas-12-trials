class_name NubeToxica
extends Node2D
## Nube de la explosión de la seta bomba: daño en área una sola vez por objetivo
## mientras dura (si Leonidas la atraviesa rodando, la voltereta lo hace invulnerable
## y ya no le vuelve a dañar). Se desvanece y se elimina sola.

@export var duracion := 0.9
@export var duracion_danio := 0.45
@export var danio := 4

@onready var golpe: Hitbox = $Golpe
@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	golpe.danio = danio
	golpe.activo = true
	sprite.play(&"nube")
	var t := create_tween()
	t.tween_interval(duracion_danio)
	t.tween_callback(func() -> void: golpe.activo = false)
	t.tween_property(sprite, ^"modulate:a", 0.0, maxf(duracion - duracion_danio, 0.05))
	t.tween_callback(queue_free)
