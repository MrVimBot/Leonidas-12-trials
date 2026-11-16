class_name ComponenteManzano
extends Node
## Hace que un `Decorado` (un manzano) suelte manzanas al golpearlo con la espada:
## cada espadazo lo sacude y, tras unos cuantos, caen unas manzanas (`ObjetoSuelto`)
## delante del tronco. Después ya no da más; al volver a cargar la zona se reinicia.
##
## Va como hijo del árbol (scenes/entorno/manzano.tscn). Mete a su `cuerpo` en la capa
## interactuable para que lo detecte la espada (el Hitbox del jugador) y escucha su
## señal `golpeado`.

## Árbol que golpean (por defecto, el padre).
@export var cuerpo: Decorado
## Escena de la manzana que cae (scenes/items/manzana_suelta.tscn).
@export var escena_manzana: PackedScene
## Golpes necesarios para que caigan: al azar entre estos dos valores (ambos incluidos).
@export var golpes_min := 3
@export var golpes_max := 5
## Manzanas que caen: al azar entre estos dos valores (ambos incluidos).
@export var manzanas_min := 1
@export var manzanas_max := 2
## Dónde caen respecto a la base del árbol: delante del tronco, para poder recogerlas.
@export var desplazamiento_caida := Vector2(0, 8)

var _golpes_restantes := 0
var _sin_manzanas := false


func _ready() -> void:
	if cuerpo == null:
		cuerpo = get_parent() as Decorado
	assert(cuerpo != null, "ComponenteManzano debe ser hijo de un Decorado (o tener `cuerpo`)")
	assert(escena_manzana != null, "ComponenteManzano necesita `escena_manzana`")
	_golpes_restantes = randi_range(golpes_min, golpes_max)
	# Además de la capa del mundo, entra en "interactuable": es la que mira la espada.
	cuerpo.set_collision_layer_value(Capas.NUMERO_INTERACTUABLE, true)
	cuerpo.golpeado.connect(_al_golpear)


## Cada espadazo cuenta un golpe, sin mirar cuánto daño quita.
func _al_golpear() -> void:
	cuerpo.sacudir()
	if _sin_manzanas:
		return
	_golpes_restantes -= 1
	if _golpes_restantes > 0:
		return
	_sin_manzanas = true
	var n := randi_range(manzanas_min, manzanas_max)
	ObjetoSuelto.soltar(escena_manzana, cuerpo.get_parent(), cuerpo.global_position + desplazamiento_caida, n)
