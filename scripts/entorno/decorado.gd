@tool
class_name Decorado
extends StaticBody2D
## Objeto fijo del escenario: casa, árbol, roca, estatua, columna...
## Se usa instanciando scenes/entorno/decorado.tscn y eligiendo la `textura` en el Inspector.
##
## La posición del nodo es el punto donde el objeto TOCA EL SUELO (centro de su base),
## igual que los pies del jugador. Así el orden de dibujado por Y funciona solo:
## si Leonidas está más arriba que la base, se dibuja detrás (pasa "por detrás" del tejado).
##
## La colisión es un rectángulo en la base: Leonidas choca con el tronco del árbol o la
## fachada de la casa, pero puede pasar por detrás de la copa o del tejado.

## Imagen del objeto (assets/sprites/entorno/*.png).
@export var textura: Texture2D:
	set(valor):
		textura = valor
		_actualizar()
## Tamaño de la colisión en la base, en píxeles. (0, 0) = automático según la imagen.
@export var base := Vector2.ZERO:
	set(valor):
		base = valor
		_actualizar()
## Mueve la colisión respecto a la base (p. ej. para una casa con porche).
@export var desplazamiento_base := Vector2.ZERO:
	set(valor):
		desplazamiento_base = valor
		_actualizar()
## Si es false, es solo decoración (flores, alfombras): no bloquea.
@export var solido := true:
	set(valor):
		solido = valor
		_actualizar()

@export_group("Sombra")
## Óvalo de sombra en la base (ComponenteSombra). Desactívalo en objetos que ya traen
## la sombra pintada (rocas, troncos, arbustos de la artista) o que no la necesitan (casas).
@export var sombra := true:
	set(valor):
		sombra = valor
		_actualizar()
## Tamaño en píxeles. (0, 0) = automático: 70 % del ancho con la proporción de la artista.
@export var tamano_sombra := Vector2i.ZERO:
	set(valor):
		tamano_sombra = valor
		_actualizar()
## Mueve la sombra respecto a la base.
@export var desplazamiento_sombra := Vector2.ZERO:
	set(valor):
		desplazamiento_sombra = valor
		_actualizar()

@export_group("Manzanas")
## Si es true, golpearlo con la espada varias veces suelta manzanas. Por defecto se activa
## solo en los manzanos (textura `manzano_*`), así que no hay que tocar las zonas.
@export var da_manzanas := false
## Golpes necesarios para que caigan: al azar entre estos dos valores (ambos incluidos).
@export var golpes_min := 3
@export var golpes_max := 5
## Manzanas que caen: al azar entre estos dos valores (ambos incluidos).
@export var manzanas_min := 1
@export var manzanas_max := 2

const ESCENA_MANZANA := preload("res://scenes/items/manzana_suelta.tscn")
const CAPA_INTERACTUABLE := 6 # la espada (Hitbox del jugador) detecta esta capa

var _golpes_restantes := 0
var _sin_manzanas := false

@onready var _sprite: Sprite2D = $Sprite
@onready var _colision: CollisionShape2D = $Colision
@onready var _sombra: ComponenteSombra = $Sombra


func _ready() -> void:
	_actualizar()
	if Engine.is_editor_hint():
		return
	if textura and textura.resource_path.get_file().begins_with("manzano_"):
		da_manzanas = true
	if da_manzanas:
		_golpes_restantes = randi_range(golpes_min, golpes_max)
		# Además de la capa del mundo, entra en "interactuable" para recibir los espadazos.
		set_collision_layer_value(CAPA_INTERACTUABLE, true)


## Contrato de daño (lo llama el Hitbox de la espada). Solo el daño del jugador importa:
## cada espadazo cuenta un golpe, sin mirar cuánto quita.
func recibir_golpe(_danio: int, _origen: Vector2) -> void:
	if not da_manzanas:
		return
	_sacudir()
	if _sin_manzanas:
		return
	_golpes_restantes -= 1
	if _golpes_restantes > 0:
		return
	_sin_manzanas = true
	var n := randi_range(manzanas_min, manzanas_max)
	# Caen delante del tronco (por debajo de la base) para que se puedan recoger.
	Moneda.soltar_escena(ESCENA_MANZANA, get_parent(), global_position + Vector2(0, 8), n)


func _sacudir() -> void:
	var t := create_tween()
	t.tween_property(_sprite, ^"position:x", 1.0, 0.04)
	t.tween_property(_sprite, ^"position:x", -1.0, 0.04)
	t.tween_property(_sprite, ^"position:x", 1.0, 0.04)
	t.tween_property(_sprite, ^"position:x", 0.0, 0.04)


func _actualizar() -> void:
	if not is_node_ready():
		return
	_sprite.texture = textura
	_colision.disabled = not solido or textura == null
	_sombra.visible = sombra and textura != null
	if textura == null:
		return
	_sombra.tamano = tamano_sombra if tamano_sombra != Vector2i.ZERO \
		else ComponenteSombra.tamano_para_ancho(textura.get_width() * 0.7)
	_sombra.position = desplazamiento_sombra
	var tam := textura.get_size()
	# La base de la imagen queda en el origen del nodo.
	_sprite.centered = false
	_sprite.offset = Vector2(-floorf(tam.x / 2.0), -tam.y)
	# Forma propia de cada instancia (si no, todas compartirían el mismo rectángulo).
	var forma := RectangleShape2D.new()
	forma.size = base if base != Vector2.ZERO else tamano_base_automatico()
	_colision.shape = forma
	_colision.position = Vector2(0, -forma.size.y / 2.0) + desplazamiento_base


## 80 % del ancho y una franja baja (entre 6 y 28 px) de alto.
func tamano_base_automatico() -> Vector2:
	var tam := textura.get_size()
	return Vector2(roundf(tam.x * 0.8), clampf(roundf(tam.y * 0.2), 6.0, 28.0))
