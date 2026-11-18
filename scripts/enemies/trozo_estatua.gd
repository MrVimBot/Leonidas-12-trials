class_name TrozoEstatua
extends Node2D
## Trozo de estatua que lanza Medusa desde el 50 % de vida (Guión p. 38). Vuela en parábola
## hacia el punto donde estaba Leonidas al lanzarlo: la posición del nodo es el punto del SUELO
## bajo el trozo (va en línea recta del origen al destino, así se ordena por Y con los demás) y
## `Visual` sube y baja encima. La `Sombra` crece al acercarse al suelo: es el AVISO de dónde cae.
## No choca en el aire (vuela por encima de todo). Al caer, `Golpe` está activo `ticks_golpe`
## ticks, sale polvo y se libera.
## Quien lo crea: `add_child` (ya colocado en el origen) y después `lanzar(destino)`.
## Al caer deja en el suelo su `resto` (la piedra, `ObjetoAgarrable`) si hay hueco: Leonidas la
## puede levantar y lanzársela a Medusa.
## Arte PROVISIONAL (`Polygon2D` gris): falta el de la artista.

## Al tocar el suelo, con el punto de impacto.
signal cayo(punto: Vector2)
## Al dejar en el suelo su `resto` (ya añadido al árbol). Medusa lo usa para limitar cuántos hay.
signal resto_dejado(objeto: ObjetoAgarrable)

## Segundos de vuelo.
@export var duracion_vuelo := 0.9
## Altura máxima de la parábola sobre la recta (px).
@export var altura := 40.0
## Altura a la que sale (la mano de Medusa); baja en línea recta hasta 0 durante el vuelo.
@export var altura_inicial := 70.0
## Daño en cuartos de corazón.
@export var danio := 2:
	set(valor):
		danio = valor
		if is_node_ready():
			golpe.danio = valor
## Ticks de física con el golpe activo al caer.
@export var ticks_golpe := 2
## Tamaño de la sombra al salir y al tocar el suelo (crece: aviso).
@export var sombra_inicial := Vector2i(6, 2)
@export var sombra_final := Vector2i(16, 5)

@export_group("Resto")
## Lo que queda en el suelo al caer: un `ObjetoAgarrable` (= `piedra.tscn`). Vacío = nada.
@export var resto: PackedScene
## Si es true, el resto se rompe al lanzarlo (un solo uso; si no, se acumularían piedras).
@export var resto_rompible := true
## Hueco libre (px) que necesita el resto, centrado en x y apoyado en el punto (como la colisión
## de la piedra). Si cae sobre una pared, una estatua, otra piedra o un enemigo (Medusa suele
## estar al lado de Leonidas), se busca el hueco libre más cercano a saltos de `paso_hueco` px,
## hasta `radio_hueco`; sin hueco, no deja nada.
@export var hueco_resto := Vector2(12, 6)
@export var paso_hueco := 8.0
@export var radio_hueco := 32.0

var _origen := Vector2.ZERO
var _destino := Vector2.ZERO
var _t := 0.0
var _volando := false
var _ticks_restantes := 0

@onready var sombra: ComponenteSombra = $Sombra
@onready var visual: Node2D = $Visual
@onready var golpe: Hitbox = $Golpe
@onready var polvo: CPUParticles2D = $Polvo


func _ready() -> void:
	golpe.danio = danio
	golpe.activo = false
	_colocar(0.0)


func lanzar(destino: Vector2) -> void:
	_origen = global_position
	_destino = destino
	_t = 0.0
	_volando = true
	_colocar(0.0)


func _physics_process(delta: float) -> void:
	if _volando:
		_t = minf(_t + delta / maxf(duracion_vuelo, 0.01), 1.0)
		_colocar(_t)
		if _t >= 1.0:
			_caer()
	elif _ticks_restantes > 0:
		_ticks_restantes -= 1
		if _ticks_restantes == 0:
			golpe.activo = false
			# Espera a que acabe el polvo para liberarse.
			get_tree().create_timer(polvo.lifetime, false).timeout.connect(queue_free)


func _colocar(t: float) -> void:
	if _volando or t > 0.0:
		global_position = _origen.lerp(_destino, t)
	visual.position.y = -(altura_inicial * (1.0 - t) + altura * 4.0 * t * (1.0 - t))
	sombra.tamano = Vector2i(Vector2(sombra_inicial).lerp(Vector2(sombra_final), t).round())
	visual.rotation = t * TAU * 0.75


func _caer() -> void:
	_volando = false
	visual.visible = false
	sombra.visible = false
	golpe.activo = true
	_ticks_restantes = maxi(ticks_golpe, 1)
	polvo.restart()
	cayo.emit(global_position)
	_dejar_resto()


func _dejar_resto() -> void:
	if resto == null:
		return
	var punto := _buscar_hueco(global_position)
	if not punto.is_finite():
		return
	var objeto := resto.instantiate() as ObjetoAgarrable
	assert(objeto != null, "`resto` debe ser una escena de ObjetoAgarrable")
	objeto.rompible = resto_rompible
	objeto.position = position + (punto - global_position)
	# Al mismo padre que el trozo (el contenedor con orden por Y de la zona). Si cae encima de
	# Leonidas, su `move_and_slide()` lo saca del solape (recuperación de la física).
	get_parent().add_child(objeto)
	resto_dejado.emit(objeto)


## El punto libre más cercano a `centro` (anillos de 8 direcciones), o `Vector2.INF` si no hay.
func _buscar_hueco(centro: Vector2) -> Vector2:
	if _hueco_libre(centro):
		return centro
	var r := paso_hueco
	while r <= radio_hueco:
		for i in 8:
			var punto := centro + Vector2.from_angle(i * TAU / 8.0) * r
			if _hueco_libre(punto):
				return punto
		r += paso_hueco
	return Vector2.INF


func _hueco_libre(punto: Vector2) -> bool:
	var forma := RectangleShape2D.new()
	forma.size = hueco_resto
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.transform = Transform2D(0.0, punto + Vector2(0.0, -hueco_resto.y * 0.5))
	consulta.collision_mask = Capas.MUNDO | Capas.ENEMIGOS
	return get_world_2d().direct_space_state.intersect_shape(consulta, 1).is_empty()
