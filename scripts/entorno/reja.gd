@tool
class_name Reja
extends StaticBody2D
## Reja que cierra un paso (salidas del laberinto del Minotauro): cae y bloquea con `cerrar()`,
## sube y deja pasar con `abrir()`. Empieza ABIERTA (sin colisión y sin dibujo), así el
## verificador de zonas recorre el paso libre.
##
## La posición del nodo es el centro de la base de los barrotes (orden por Y como los decorados).
## `ancho` es el hueco que tapa (px de mundo): escala el dibujo y la colisión. `@tool` para ver
## el tamaño en el editor; la forma es `local_to_scene`, así cada reja tiene la suya.
## Arte de la artista (assets/sprites/entorno/nivel3/rejas.png, 2026-11-22): 5 barrotes pintados.

## Lo dibujado en rejas.png (px de la textura): x 23–485, base de los barrotes en y 390.
const DIBUJO_X := Vector2(23, 485)
const DIBUJO_BASE := 390.0

## Ancho del hueco que cierra (px de mundo).
@export var ancho := 64.0:
	set(valor):
		ancho = maxf(valor, 4.0)
		_aplicar()
## Grosor de la colisión (px de mundo).
@export var grosor := 8.0:
	set(valor):
		grosor = maxf(valor, 2.0)
		_aplicar()
## Segundos que tarda en caer o subir.
@export var duracion := 0.35

var cerrada := false

var _tween: Tween

@onready var visual: Sprite2D = $Visual
@onready var forma: CollisionShape2D = $Forma


func _ready() -> void:
	_aplicar()
	if Engine.is_editor_hint():
		return
	_poner(false)


## Baja la reja (con `animado`, cae desde arriba). La colisión se activa al momento.
func cerrar(animado := true) -> void:
	cerrada = true
	forma.set_deferred(&"disabled", false)
	visual.visible = true
	_matar_tween()
	if not animado:
		visual.position.y = 0.0
		return
	visual.position.y = -_alto()
	_tween = create_tween()
	_tween.tween_property(visual, ^"position:y", 0.0, duracion).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Sube la reja (con `animado`, la deja subir antes de ocultarla). La colisión se quita al momento.
func abrir(animado := true) -> void:
	cerrada = false
	forma.set_deferred(&"disabled", true)
	_matar_tween()
	if not animado or not visual.visible:
		_poner(false)
		return
	_tween = create_tween()
	_tween.tween_property(visual, ^"position:y", -_alto(), duracion).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_poner.bind(false))


func _poner(cerrar_ya: bool) -> void:
	cerrada = cerrar_ya
	visual.visible = cerrar_ya
	visual.position.y = 0.0
	if forma:
		forma.disabled = not cerrar_ya


func _matar_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null


func _escala() -> float:
	return ancho / (DIBUJO_X.y - DIBUJO_X.x)


func _alto() -> float:
	return DIBUJO_BASE * _escala()


func _aplicar() -> void:
	var v := get_node_or_null(^"Visual") as Sprite2D
	var f := get_node_or_null(^"Forma") as CollisionShape2D
	if v:
		var s := _escala()
		v.scale = Vector2(s, s)
		v.centered = false
		v.offset = Vector2(-(DIBUJO_X.x + DIBUJO_X.y) / 2.0, -DIBUJO_BASE)
	if f and f.shape is RectangleShape2D:
		(f.shape as RectangleShape2D).size = Vector2(ancho, grosor)
		f.position = Vector2(0, -grosor / 2.0)
