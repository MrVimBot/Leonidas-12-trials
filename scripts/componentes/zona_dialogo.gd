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
## Justo antes de abrir el diálogo (p. ej. para que un NPC se pare y mire al jugador).
signal empezo(quien: Node)

enum Tipo { HABLAR, MISION, TIENDA }

## PROVISIONAL: arte provisional sacado de la lámina de NPC (Jugabilidad.pdf p. 10). Se
## deja como constante y no como `@export` porque los carteles de las zonas generadas son
## un Area2D con este script y sin escena: no tendrían las texturas asignadas. Cuando la
## artista entregue las burbujas, sustituir los PNG (mismo nombre) o pasarlas a un export.
const BURBUJAS := {
	Tipo.HABLAR: preload("res://assets/ui/provisional/burbuja_hablar.png"),
	Tipo.MISION: preload("res://assets/ui/provisional/burbuja_mision.png"),
	Tipo.TIENDA: preload("res://assets/ui/provisional/burbuja_tienda.png"),
}

## Recurso Dialogo (resources/dialogues/*.tres).
@export var dialogo: Dialogo:
	set(valor):
		dialogo = valor
		_actualizar_visibilidad()
## Si tiene tienda, al interactuar atiende la tienda en vez de mostrar `dialogo`.
@export var tienda: ComponenteTienda:
	set(valor):
		tienda = valor
		_actualizar_visibilidad()
## Qué burbuja aparece sobre la cabeza.
@export var tipo: Tipo = Tipo.HABLAR:
	set(valor):
		tipo = valor
		_poner_aspecto()
@export var mostrar_burbuja := true:
	set(valor):
		mostrar_burbuja = valor
		_actualizar_visibilidad()
## Dónde va la punta de la burbuja, respecto a la base del objeto (encima de la cabeza).
@export var posicion_burbuja := Vector2(0, -32):
	set(valor):
		posicion_burbuja = valor
		_poner_aspecto()

var _burbuja: Sprite2D
var _jugador_cerca := false
var _atendiendo := false


func _ready() -> void:
	_burbuja = get_node_or_null(^"Burbuja") as Sprite2D
	if _burbuja == null:
		# RESPALDO: los carteles de las zonas ya generadas son un Area2D con este script,
		# sin la escena zona_dialogo.tscn (regenerar las zonas pisaría los retoques a mano).
		# Sin esa escena no hay capas ni Burbuja: se crean aquí con lo mismo que trae la
		# escena. Lo que se genere de ahora en adelante instancia la escena.
		collision_layer = Capas.INTERACTUABLE # lo encuentra ComponenteInteraccion
		collision_mask = Capas.JUGADOR # para saber cuándo enseñar la burbuja
		monitoring = true
		_burbuja = Sprite2D.new()
		_burbuja.name = "Burbuja"
		_burbuja.centered = false
		_burbuja.z_index = 10 # por encima de todo el decorado
		_burbuja.visible = false
		add_child(_burbuja)
	_poner_aspecto()
	body_entered.connect(_al_entrar_cuerpo)
	body_exited.connect(_al_salir_cuerpo)
	# La burbuja se esconde mientras haya un diálogo o una tienda abiertos.
	Dialogos.empezo.connect(_actualizar_visibilidad)
	Dialogos.termino.connect(_actualizar_visibilidad)
	Tienda.se_abrio.connect(_actualizar_visibilidad)
	Tienda.cerrado.connect(_actualizar_visibilidad)
	_actualizar_visibilidad()


## Textura (según `tipo`) y posición de la burbuja. Antes de `_ready` no hay burbuja: los
## setters de los export se ejecutan al cargar la escena y `_ready` lo aplica todo.
func _poner_aspecto() -> void:
	if _burbuja == null:
		return
	var textura: Texture2D = BURBUJAS[tipo]
	_burbuja.texture = textura
	_burbuja.offset = Vector2(-floorf(textura.get_width() / 2.0), -textura.get_height())
	_burbuja.position = posicion_burbuja


## Se llama al cambiar algo de lo que depende (jugador cerca, diálogo o tienda abiertos,
## `dialogo`, `tienda`...), no cada fotograma. Sin diálogo ni tienda no hay nada que hablar
## (p. ej. los sabios antes de su escena).
func _actualizar_visibilidad() -> void:
	if _burbuja == null:
		return
	_burbuja.visible = mostrar_burbuja and _jugador_cerca and not _atendiendo \
		and (dialogo != null or tienda != null) \
		and not Dialogos.abierto and not Tienda.abierto


## Lo llama ComponenteInteraccion del jugador al pulsar interactuar.
func interactuar(quien: Node) -> void:
	if Dialogos.abierto or Tienda.abierto or _atendiendo:
		return
	if tienda == null and dialogo == null:
		return
	_atendiendo = true
	_actualizar_visibilidad()
	empezo.emit(quien)
	if tienda:
		await tienda.atender(quien)
	else:
		await Dialogos.mostrar(dialogo)
	_atendiendo = false
	_actualizar_visibilidad()
	hablado.emit()


func _al_entrar_cuerpo(cuerpo: Node2D) -> void:
	if cuerpo is Jugador:
		_jugador_cerca = true
		_actualizar_visibilidad()


func _al_salir_cuerpo(cuerpo: Node2D) -> void:
	if cuerpo is Jugador:
		_jugador_cerca = false
		_actualizar_visibilidad()
