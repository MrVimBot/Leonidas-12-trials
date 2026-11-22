@tool
class_name NPC
extends CharacterBody2D
## Cerebro de un NPC del pueblo: pasea alrededor de su casa o se queda quieto.
##
## Se usa instanciando scenes/npcs/npc.tscn y eligiendo en el Inspector `sprite_frames`
## (resources/sprite_frames/npc_*.tres), `dialogo` y `burbuja`. La posición del nodo
## son los pies (como el jugador y los decorados), así el orden por Y funciona solo.
##
## PASEO: lo hace su componente `Paseo` (ComponentePaseo); aquí se configura desde el
## Inspector. El centro es la posición inicial del nodo (colócalo delante de su casa).
## Elige un punto al azar dentro de `radio_paseo`, camina hasta él, se para un rato y
## vuelve a empezar. Nunca se aleja más de `radio_paseo` del centro.
## Si choca (con una casa, el agua...) o tarda demasiado, se para y elige otro punto.
##
## Al hablar con él se para y mira al jugador; sigue paseando al cerrar el diálogo.
## `paseo = false` → NPC fijo (tendera, sabios...): no se mueve ni se gira.
## `dialogo` y `burbuja` se pueden cambiar en juego (p. ej. la escena de los sabios): pasan a su ZonaDialogo.
##
## `dialogo`, `tienda`, `burbuja` y `posicion_burbuja` son una fachada para el Inspector: se
## copian a su hijo ZonaDialogo (instancia de scenes/entorno/zona_dialogo.tscn) en
## `_enter_tree` (único sitio; antes del `_ready` de los hijos, donde ZonaDialogo aplica su
## burbuja) y `dialogo` y `burbuja` además se reenvían al cambiarlos.

## QUIETO: fijo (`paseo = false`). PASEANDO: espera o camina, lo decide el componente.
enum Estado { QUIETO, PASEANDO, HABLANDO }

## Animaciones del personaje: parado_* y caminar_* (frente / lado / espalda).
@export var sprite_frames: SpriteFrames:
	set(valor):
		sprite_frames = valor
		_aplicar_aspecto()
## Lo que dice al hablar con él (resources/dialogues/*.tres). Sin diálogo ni tienda no
## sale burbuja ni se puede hablar con él.
@export var dialogo: Dialogo:
	set(valor):
		dialogo = valor
		var zona := get_node_or_null(^"%ZonaDialogo") as ZonaDialogo
		if zona and not Engine.is_editor_hint():
			zona.dialogo = valor
## Si vende algo: un ComponenteTienda hijo del NPC (entonces no usa `dialogo`).
@export var tienda: ComponenteTienda
## Burbuja sobre la cabeza al acercarse: "…" hablar, "!" misión, "$" tienda.
## Se puede cambiar en juego (los sabios ponen «!» cuando tienen una misión nueva).
@export var burbuja: ZonaDialogo.Tipo = ZonaDialogo.Tipo.HABLAR:
	set(valor):
		burbuja = valor
		var zona := get_node_or_null(^"%ZonaDialogo") as ZonaDialogo
		if zona and not Engine.is_editor_hint():
			zona.tipo = valor
## Punta de la burbuja respecto a los pies (encima de la cabeza).
@export var posicion_burbuja := Vector2(0, -46)
## `offset` del Sprite para que la posición del nodo sean los pies: (0, −24) para las
## celdas de 56×52 (burro, zorro...), (0, −28) para los sabios (48×60).
@export var desplazamiento_sprite := Vector2(0, -24):
	set(valor):
		desplazamiento_sprite = valor
		_aplicar_aspecto()

@export_group("Paseo")
## Si es false, el NPC se queda siempre en su sitio.
@export var paseo := true
## Distancia máxima (px) a la que se aleja de su posición inicial.
@export var radio_paseo := 48.0
## Velocidad al pasear (px/s). Múltiplos de 30 se ven más suaves (física a 120 Hz).
@export var velocidad := 30.0
## Segundos que espera parado entre paseo y paseo (mínimo, máximo).
@export var espera := Vector2(1.5, 4.0)
@export_group("")
## Si es true, al hablar se gira hacia el jugador (solo si tiene animaciones de lado/espalda).
@export var mirar_al_hablar := true
## Hacia dónde mira al empezar.
@export var mirando := Vector2.DOWN

var estado := Estado.QUIETO

@onready var _movimiento: ComponenteMovimiento = $Movimiento
@onready var _animador: AnimadorDireccional = $Animador
@onready var _paseo: ComponentePaseo = $Paseo
@onready var _zona_dialogo: ZonaDialogo = %ZonaDialogo


func _enter_tree() -> void:
	# Antes del _ready de los hijos: ZonaDialogo pone su burbuja en su propio _ready. Las
	# referencias a nodos (`tienda`) ya están resueltas: se asignan al instanciar la escena.
	var zona := get_node_or_null(^"%ZonaDialogo") as ZonaDialogo
	if zona and not Engine.is_editor_hint():
		zona.dialogo = dialogo
		zona.tienda = tienda
		zona.tipo = burbuja
		zona.posicion_burbuja = posicion_burbuja
	_aplicar_aspecto()


func _aplicar_aspecto() -> void:
	var sprite := get_node_or_null(^"%Sprite") as AnimatedSprite2D
	if sprite == null:
		return
	sprite.sprite_frames = sprite_frames
	sprite.offset = desplazamiento_sprite
	if sprite_frames:
		for nombre: StringName in [&"parado_frente", &"parado"]:
			if sprite_frames.has_animation(nombre):
				sprite.animation = nombre
				break


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_paseo.centro = global_position
	_paseo.radio = radio_paseo
	_paseo.velocidad = velocidad
	_paseo.espera = espera
	_movimiento.choco.connect(_al_chocar)
	_zona_dialogo.empezo.connect(_al_empezar_dialogo)
	_zona_dialogo.hablado.connect(_al_terminar_dialogo)
	_animador.mirar(mirando)
	_reposar()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	match estado:
		Estado.QUIETO:
			_movimiento.frenar(delta)
		Estado.PASEANDO:
			_paseo.actualizar(delta)
			if _paseo.andando:
				_animador.orientar(_paseo.hacia)
				_animador.reproducir(&"caminar")
			else:
				_animador.reproducir(&"parado")
		Estado.HABLANDO:
			_movimiento.frenar(delta, 4.0)


## Parado y mirando como estaba: empieza a pasear (o se queda fijo si `paseo` es false).
func _reposar() -> void:
	estado = Estado.PASEANDO if paseo else Estado.QUIETO
	if paseo:
		_paseo.activar()
	_animador.reproducir(&"parado")


func _al_chocar(colision: KinematicCollision2D) -> void:
	if estado == Estado.PASEANDO:
		_paseo.al_chocar(colision.get_normal())


func _al_empezar_dialogo(quien: Node) -> void:
	estado = Estado.HABLANDO
	if mirar_al_hablar and quien is Node2D:
		_animador.mirar((quien as Node2D).global_position - global_position)
	_animador.reproducir(&"parado")


func _al_terminar_dialogo() -> void:
	_reposar()


## Para cinemáticas que mueven al NPC por su cuenta (p. ej. la escena de los sabios):
## reproduce `base` (parado / caminar) en la dirección a la que mira. Si el sprite no tiene
## esa dirección, el animador usa la de frente (sabios, tendedera); si no tiene `base`
## (gallo y perro no caminan), no hace nada.
func animar(base: StringName) -> void:
	_animador.reproducir(base)


## Para cinemáticas: camina en línea recta hasta `destino` a `rapidez` px/s con la
## animación `caminar` y espera a llegar (`await`); al terminar queda en `parado`. Si ya
## está a menos de 1 px, no hace nada. Usar con el NPC quieto (`paseo = false` o hablando):
## mueve por tween, así que atraviesa colisiones y el destino debe ser alcanzable en línea
## recta. En NPC de una sola vista (sabios) camina de frente (ver `animar`).
func caminar_hasta(destino: Vector2, rapidez := 60.0) -> void:
	var distancia := global_position.distance_to(destino)
	if distancia < 1.0:
		return
	animar(&"caminar")
	var t := create_tween()
	t.tween_property(self, ^"global_position", destino, distancia / rapidez)
	await t.finished
	animar(&"parado")
