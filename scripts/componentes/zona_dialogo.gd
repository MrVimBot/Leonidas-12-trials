class_name ZonaDialogo
extends Area2D
## Hace que algo se pueda leer o con lo que se pueda hablar con el botón de interactuar
## (cartel, NPC, sabio, mercader...). Se añade como hijo del objeto, con un
## CollisionShape2D hijo que marca desde dónde se puede hablar.
##
## Según la lámina "NPCs" de Jugabilidad.pdf (p. 10), al acercarse aparece sobre la
## cabeza una burbuja: "…" diálogo normal, "!" misión, "$" tienda.
##
## El NPC puede escuchar `hablado` para, por ejemplo, dar un objeto al terminar.

signal hablado

enum Tipo { HABLAR, MISION, TIENDA }

const BURBUJAS := {
	Tipo.HABLAR: preload("res://assets/ui/provisional/burbuja_hablar.png"),
	Tipo.MISION: preload("res://assets/ui/provisional/burbuja_mision.png"),
	Tipo.TIENDA: preload("res://assets/ui/provisional/burbuja_tienda.png"),
}

## Recurso Dialogo (resources/dialogues/*.tres).
@export var dialogo: Dialogo
## Qué burbuja aparece sobre la cabeza.
@export var tipo: Tipo = Tipo.HABLAR
@export var mostrar_burbuja := true
## Dónde va la punta de la burbuja, respecto a la base del objeto (encima de la cabeza).
@export var posicion_burbuja := Vector2(0, -32)

var _burbuja: Sprite2D
var _jugador_cerca := false


func _ready() -> void:
	collision_layer = 32 # interactuable: lo encuentra ComponenteInteraccion
	collision_mask = 2 # jugador: para saber cuándo enseñar la burbuja
	monitoring = true
	body_entered.connect(func(b: Node2D) -> void: if b is Jugador: _jugador_cerca = true)
	body_exited.connect(func(b: Node2D) -> void: if b is Jugador: _jugador_cerca = false)
	_burbuja = Sprite2D.new()
	_burbuja.texture = BURBUJAS[tipo]
	_burbuja.centered = false
	_burbuja.offset = Vector2(-floorf(_burbuja.texture.get_width() / 2.0), -_burbuja.texture.get_height())
	_burbuja.position = posicion_burbuja
	_burbuja.z_index = 10 # por encima de todo el decorado
	_burbuja.visible = false
	add_child(_burbuja)


func _process(_delta: float) -> void:
	_burbuja.visible = mostrar_burbuja and _jugador_cerca and not Dialogos.abierto


## Lo llama ComponenteInteraccion del jugador al pulsar interactuar.
func interactuar(_quien: Node) -> void:
	if dialogo == null or Dialogos.abierto:
		return
	await Dialogos.mostrar(dialogo)
	hablado.emit()
