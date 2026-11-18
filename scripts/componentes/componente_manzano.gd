@tool
class_name ComponenteManzano
extends Node
## Hace que un `Decorado` (un manzano) suelte manzanas al golpearlo con la espada:
## cada espadazo lo sacude y, tras unos cuantos, caen unas manzanas (`ObjetoSuelto`)
## delante del tronco. Después ya no da más; al volver a cargar la zona se reinicia.
##
## Va como hijo del árbol (scenes/entorno/manzano.tscn). Mete a su `cuerpo` en la capa
## interactuable para que lo detecte la espada (el Hitbox del jugador) y escucha su
## señal `golpeado`.
## `@tool` solo para avisar en el editor de lo que falta; en el editor no hace nada más
## (sobre todo, no cambia la capa del árbol: se guardaría en la escena).

## Árbol que golpean (por defecto, el padre).
@export var cuerpo: Decorado:
	set(valor):
		cuerpo = valor
		update_configuration_warnings()
## Escena de la manzana que cae (scenes/items/manzana_suelta.tscn).
@export var escena_manzana: PackedScene:
	set(valor):
		escena_manzana = valor
		update_configuration_warnings()
## Golpes necesarios para que caigan: al azar entre estos dos valores (ambos incluidos).
@export var golpes_min := 3
@export var golpes_max := 5
## Manzanas que caen: al azar entre estos dos valores (ambos incluidos).
@export var manzanas_min := 1
@export var manzanas_max := 2
## Dónde caen respecto a la base del árbol: delante del tronco, para poder recogerlas.
@export var desplazamiento_caida := Vector2(0, 8)
## Suena con cada espadazo al tronco (también cuando ya no da más manzanas).
@export var sonido_golpe: AudioStreamPlayer
## Suena cuando caen las manzanas.
@export var sonido_manzanas: AudioStreamPlayer

var _golpes_restantes := 0
var _sin_manzanas := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if cuerpo == null:
		cuerpo = get_parent() as Decorado
	assert(cuerpo != null, "ComponenteManzano debe ser hijo de un Decorado (o tener `cuerpo`)")
	assert(escena_manzana != null, "ComponenteManzano necesita `escena_manzana`")
	_golpes_restantes = randi_range(golpes_min, golpes_max)
	# Además de la capa del mundo, entra en "interactuable": es la que mira la espada.
	cuerpo.set_collision_layer_value(Capas.NUMERO_INTERACTUABLE, true)
	cuerpo.golpeado.connect(_al_golpear)


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if cuerpo == null and not get_parent() is Decorado:
		avisos.append("Ponlo como hijo de un Decorado (el manzano) o asígnalo en `cuerpo`.")
	if escena_manzana == null:
		avisos.append("Asigna en `escena_manzana` la escena de la manzana que cae (scenes/items/manzana_suelta.tscn).")
	return avisos


## Cada espadazo cuenta un golpe, sin mirar cuánto daño quita.
func _al_golpear() -> void:
	cuerpo.sacudir()
	if sonido_golpe:
		sonido_golpe.play()
	if _sin_manzanas:
		return
	_golpes_restantes -= 1
	if _golpes_restantes > 0:
		return
	_sin_manzanas = true
	if sonido_manzanas:
		sonido_manzanas.play()
	var n := randi_range(manzanas_min, manzanas_max)
	ObjetoSuelto.soltar(escena_manzana, cuerpo.get_parent(), cuerpo.global_position + desplazamiento_caida, n)
