@tool
class_name NPC
extends CharacterBody2D
## Cerebro de un NPC del pueblo: pasea alrededor de su casa o se queda quieto.
##
## Se usa instanciando scenes/npcs/npc.tscn y eligiendo en el Inspector `sprite_frames`
## (resources/sprite_frames/npc_*.tres), `dialogo` y `burbuja`. La posición del nodo
## son los pies (como el jugador y los decorados), así el orden por Y funciona solo.
##
## PASEO: el centro es la posición inicial del nodo (colócalo delante de su casa).
## Elige un punto al azar dentro de `radio_paseo`, camina hasta él, se para un rato y
## vuelve a empezar. Nunca se aleja más de `radio_paseo` del centro.
## Si choca (con una casa, el agua...) o tarda demasiado, se para y elige otro punto.
##
## Al hablar con él se para y mira al jugador; sigue paseando al cerrar el diálogo.
## `paseo = false` → NPC fijo (tendera, sabios...): no se mueve ni se gira.

enum Estado { QUIETO, CAMINANDO, HABLANDO }

## Animaciones del personaje: parado_* y caminar_* (frente / lado / espalda).
@export var sprite_frames: SpriteFrames:
	set(valor):
		sprite_frames = valor
		_aplicar_aspecto()
## Lo que dice al hablar con él (resources/dialogues/*.tres).
@export var dialogo: Dialogo
## Burbuja sobre la cabeza al acercarse: "…" hablar, "!" misión, "$" tienda.
@export var burbuja: ZonaDialogo.Tipo = ZonaDialogo.Tipo.HABLAR
## Punta de la burbuja respecto a los pies (encima de la cabeza).
@export var posicion_burbuja := Vector2(0, -46)

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

@onready var _movimiento: ComponenteMovimiento = $Movimiento
@onready var _animador: AnimadorDireccional = $Animador
@onready var _zona_dialogo: ZonaDialogo = $ZonaDialogo

var estado := Estado.QUIETO
var centro := Vector2.ZERO
var _destino := Vector2.ZERO
var _tiempo := 0.0
var _rng := RandomNumberGenerator.new()


func _enter_tree() -> void:
	# Antes del _ready de los hijos: ZonaDialogo crea su burbuja en su propio _ready.
	var zona := get_node_or_null(^"ZonaDialogo") as ZonaDialogo
	if zona and not Engine.is_editor_hint():
		zona.dialogo = dialogo
		zona.tipo = burbuja
		zona.posicion_burbuja = posicion_burbuja
	_aplicar_aspecto()


func _aplicar_aspecto() -> void:
	var sprite := get_node_or_null(^"Sprite") as AnimatedSprite2D
	if sprite == null:
		return
	sprite.sprite_frames = sprite_frames
	if sprite_frames:
		for nombre in [&"parado_frente", &"parado"]:
			if sprite_frames.has_animation(nombre):
				sprite.animation = nombre
				break


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	centro = position
	_rng.randomize()
	_movimiento.velocidad = velocidad
	_movimiento.choco.connect(_al_chocar)
	_zona_dialogo.empezo.connect(_al_empezar_dialogo)
	_zona_dialogo.hablado.connect(_al_terminar_dialogo)
	_animador.mirar(mirando)
	_quedarse_quieto()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	match estado:
		Estado.QUIETO:
			_movimiento.frenar(delta)
			_tiempo -= delta
			if paseo and _tiempo <= 0.0:
				_empezar_paseo()
		Estado.CAMINANDO:
			var hacia := _destino - position
			_tiempo -= delta
			if hacia.length() < 2.0 or _tiempo <= 0.0:
				_quedarse_quieto()
			else:
				_movimiento.mover(hacia.normalized(), delta)
				_animador.orientar(hacia)
				_reproducir(&"caminar")
		Estado.HABLANDO:
			_movimiento.frenar(delta, 4.0)


func _empezar_paseo() -> void:
	# Punto al azar dentro del círculo (sqrt → reparto uniforme, no amontonado en el centro).
	var angulo := _rng.randf() * TAU
	var distancia := sqrt(_rng.randf()) * radio_paseo
	_destino = centro + Vector2.from_angle(angulo) * distancia
	if _destino.distance_to(position) < 8.0:
		_tiempo = 0.5
		return
	# Margen por si algo lo frena: a la velocidad de paseo, el doble de lo necesario.
	_tiempo = _destino.distance_to(position) / maxf(velocidad, 1.0) * 2.0 + 0.5
	estado = Estado.CAMINANDO


func _quedarse_quieto() -> void:
	estado = Estado.QUIETO
	_tiempo = _rng.randf_range(espera.x, espera.y)
	_reproducir(&"parado")


func _al_chocar(_colision: KinematicCollision2D) -> void:
	if estado == Estado.CAMINANDO:
		_quedarse_quieto()


func _al_empezar_dialogo(quien: Node) -> void:
	estado = Estado.HABLANDO
	if mirar_al_hablar and quien is Node2D:
		_animador.mirar((quien as Node2D).global_position - global_position)
	_reproducir(&"parado")


func _al_terminar_dialogo() -> void:
	_quedarse_quieto()


## Reproduce `base_<dirección>`; si el sprite no tiene esa dirección, la de frente.
func _reproducir(base: StringName) -> void:
	var frames := _animador.sprite.sprite_frames
	if frames == null:
		return
	if frames.has_animation(StringName("%s_%s" % [base, _animador.sufijo()])):
		_animador.reproducir(base)
	elif frames.has_animation(StringName("%s_frente" % base)):
		_animador.sprite.flip_h = false
		if _animador.sprite.animation != StringName("%s_frente" % base):
			_animador.sprite.play(StringName("%s_frente" % base))
