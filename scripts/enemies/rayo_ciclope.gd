class_name RayoCiclope
extends Node2D
## Rayo del cíclope serpiente (Guión p. 36): proyectil pequeño que sale del ojo y avanza en
## LÍNEA RECTA (decisión Q6, 2026-11-17: no corrige el rumbo). Quien dispara fija `direccion`
## (y, si quiere, `danio`) ANTES de añadirlo al árbol y lo coloca con `global_position`.
##
## Se libera al pasar `alcance`, al chocar con el mundo (rayo contra la capa mundo, igual
## que se detecta lo sólido en el resto del juego: consulta directa al espacio físico) o al
## golpear al jugador. Su `Golpe` es un `Hitbox` normal (una sola vez por objetivo).
##
## La voltereta lo esquiva: un `Hitbox` golpea también a un objetivo invulnerable (llama a
## `recibir_golpe` igual y emite `golpeo`), pero `ComponenteVida` ignora el daño. Para que el
## rayo no se "gaste" contra alguien que rueda, `_al_golpear()` solo lo libera si el objetivo
## NO tiene `invulnerable_extra` (voltereta o bloqueo): si lo tiene, el rayo lo atraviesa y
## sigue su camino. Como el Hitbox no repite objetivo, un Leonidas que acabe de rodar justo
## encima del rayo ya no recibe ese rayo (margen a su favor, a propósito). Un jugador con la
## invulnerabilidad corta de después de un golpe sí lo detiene (sin daño).
##
## Altura: la partida es cenital, pero el rayo sale del ojo (alto) y apunta al cuerpo de
## Leonidas; tanto el choque con paredes como el golpe se miden en el plano del rayo.
##
## PROVISIONAL: sin arte de la artista (no entregó el rayo): dos `Line2D` y una estela de
## partículas. Sustituir `Visual` por su dibujo cuando llegue.

## Velocidad (px/s). Múltiplo de 60 (la física va a 120 ticks/s).
@export var velocidad := 180.0
## Distancia máxima que recorre antes de desaparecer (px).
@export var alcance := 220.0
## Daño en cuartos de corazón (2 = medio corazón).
@export var danio := 2

## Hacia dónde viaja (normalizada). La fija quien lo dispara antes de `add_child`.
var direccion := Vector2.LEFT

var _recorrido := 0.0

@onready var golpe: Hitbox = $Golpe


func _ready() -> void:
	direccion = direccion.normalized() if direccion != Vector2.ZERO else Vector2.LEFT
	rotation = direccion.angle()
	golpe.danio = danio
	golpe.activo = true


func _physics_process(delta: float) -> void:
	var paso := direccion * velocidad * delta
	var destino := global_position + paso
	var consulta := PhysicsRayQueryParameters2D.create(global_position, destino, Capas.MUNDO)
	if not get_world_2d().direct_space_state.intersect_ray(consulta).is_empty():
		queue_free() # choca con una pared, un árbol…
		return
	global_position = destino
	_recorrido += paso.length()
	if _recorrido >= alcance:
		queue_free()


## `Golpe.golpeo` (conectada en la escena). Ver la cabecera: la voltereta lo atraviesa.
func _al_golpear(objetivo: Node) -> void:
	var duenio := objetivo.get_parent()
	var vida_objetivo := duenio.get(&"vida") as ComponenteVida if duenio else null
	if vida_objetivo and vida_objetivo.invulnerable_extra:
		return
	queue_free()
