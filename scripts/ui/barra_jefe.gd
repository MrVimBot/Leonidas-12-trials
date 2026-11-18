class_name BarraJefe
extends MarginContainer
## Vida de un jefe, arriba en el centro de la pantalla (guía de interfaz, «Vida del jefe
## (Medusa)»; Guión p. 38). Va dentro de scenes/ui/hud.tscn, oculta hasta `seguir()`.
## Nombre + `FilaCorazones` (4 cuartos por corazón, como los de Leonidas: Medusa, 20 = 5).
## Arte PROVISIONAL: los corazones del jugador teñidos con `modulate` (pedir a la artista los
## de Medusa, rojos con detalles dorados). Mientras el jefe es invulnerable, en gris
## (`material_gris` en la fila).
##
## Contrato del jefe (duck typing, para no atar la barra a una clase):
##   `vida: ComponenteVida`                      obligatorio (se escucha `vida.cambio`)
##   `invulnerable: bool` + señal `invulnerable_cambio(activa: bool)`   opcionales
## Si el jefe sale del árbol, la barra se oculta sola.

## Material de la fila mientras el jefe es invulnerable (desaturar).
@export var material_gris: Material

var _jefe: Node = null
var _vida: ComponenteVida = null

@onready var nombre: Label = %Nombre
@onready var corazones: FilaCorazones = %Corazones


func _ready() -> void:
	visible = false


## Enseña la barra con la vida de `jefe` (ver contrato arriba) y su `texto_nombre`.
func seguir(jefe: Node, texto_nombre: String) -> void:
	dejar()
	_vida = jefe.get(&"vida") as ComponenteVida if jefe else null
	if _vida == null:
		push_error("BarraJefe: %s no tiene `vida` (ComponenteVida)" % jefe)
		return
	_jefe = jefe
	nombre.text = texto_nombre
	_vida.cambio.connect(_al_cambiar_vida)
	_al_cambiar_vida(_vida.vida, _vida.vida_max)
	if jefe.has_signal(&"invulnerable_cambio"):
		jefe.connect(&"invulnerable_cambio", poner_gris)
	poner_gris(jefe.get(&"invulnerable") == true)
	jefe.tree_exiting.connect(dejar)
	visible = true


## Oculta la barra y deja de escuchar al jefe.
func dejar() -> void:
	if is_instance_valid(_jefe):
		if _vida and _vida.cambio.is_connected(_al_cambiar_vida):
			_vida.cambio.disconnect(_al_cambiar_vida)
		if _jefe.has_signal(&"invulnerable_cambio") and _jefe.is_connected(&"invulnerable_cambio", poner_gris):
			_jefe.disconnect(&"invulnerable_cambio", poner_gris)
		if _jefe.tree_exiting.is_connected(dejar):
			_jefe.tree_exiting.disconnect(dejar)
	_jefe = null
	_vida = null
	poner_gris(false)
	visible = false


## Corazones en gris (jefe invulnerable) o normales.
func poner_gris(activa: bool) -> void:
	corazones.material = material_gris if activa else null


## El jefe que se está mostrando (null si la barra está oculta).
func jefe() -> Node:
	return _jefe


func esta_gris() -> bool:
	return corazones.material != null


func _al_cambiar_vida(vida: int, vida_max: int) -> void:
	corazones.mostrar(vida, vida_max)
