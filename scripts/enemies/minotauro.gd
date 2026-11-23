class_name Minotauro
extends CharacterBody2D
## Jefe del laberinto (nivel 3, PROVISIONAL: diseño de los sabios y de la artista, 2026-11-22).
## Hereda de scenes/enemies/enemigo_pintado.tscn; arte pintado en resources/sprite_frames/
## minotauro.tres (parado, caminar, atacar).
##
## Es INVISIBLE e invulnerable mientras Leonidas no tenga el cuerno (`EstadoJuego.OBJ_CUERNO`,
## en un cofre del laberinto): no se ve ni él ni su sombra, la espada lo atraviesa, pero él sí
## golpea. Al conseguir el cuerno se ve y se le puede herir al momento (`objetos_cambio`).
## `invulnerable` + `invulnerable_cambio` siguen ese estado (la barra del jefe se pone gris).
##
## Estados: INACTIVO (escondido, sin golpes) → `empezar_combate()` → PERSEGUIR (camina por el
## laberinto con `ComponenteRuta` hasta ponerse a un lado de Leonidas) → ATACAR (`Ataque`, un
## espadazo hacia el lado al que mira: `Golpe` en los fotogramas `frames_golpe` de `atacar`;
## después se queda con la espada clavada, el momento de atacarle) → ESPERA (`pausa`) →
## PERSEGUIR. A 0 de vida: MUERTO, `derrotado` y `Muerte` (heredado) lo aplasta y lo libera.
##
## Para la escena del encuentro: `aparecer()` / `desaparecer()` (lo enseñan y lo esconden con un
## fundido aunque no haya cuerno) y `reiniciar()` (Game Over a mitad del combate).

signal derrotado
## Cambia al volverse invisible (sin cuerno) o visible: la barra del jefe se pone gris.
signal invulnerable_cambio(activa: bool)

enum Estado { INACTIVO, PERSEGUIR, ATACAR, ESPERA, MUERTO }

@export_group("Combate")
@export var velocidad_caminar := 40.0
## Ataca si Leonidas está a ≤ x en horizontal (y a ≥ 6, para no golpear de frente) y ≤ y en
## vertical: el espadazo barre el suelo a su lado (ver la forma `Golpe/Derecha`).
@export var alcance := Vector2(50, 12)
## Distancia en horizontal a la que intenta colocarse de Leonidas antes de atacar.
@export var distancia_lado := 32.0
## Segundos quieto entre ataques.
@export var pausa := 0.8
## Segundos del fundido de `aparecer()` / `desaparecer()`.
@export var duracion_fundido := 0.6
@export_group("Sonido")
## Rugido al aparecer.
@export var sonido_rugido: AudioStreamPlayer2D

var estado := Estado.INACTIVO
## True mientras es invisible en combate (sin cuerno): no se le puede herir.
var invulnerable := false:
	set(valor):
		if valor == invulnerable:
			return
		invulnerable = valor
		invulnerable_cambio.emit(valor)

## Lo enseña la escena aunque no haya cuerno (al aparecer en el centro).
var _mostrado := false
var _espera := 0.0
var _posicion_inicial := Vector2.ZERO
var _tween: Tween

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var sombra: Node2D = $Sombra
@onready var movimiento: ComponenteMovimiento = $Movimiento
@onready var animador: AnimadorDireccional = $Animador
@onready var vida: ComponenteVida = $Vida
@onready var deteccion: ComponenteDeteccion = $Deteccion
@onready var parpadeo: ComponenteParpadeo = $Parpadeo
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var contacto: Hitbox = $Contacto
@onready var ataque: ComponenteAtaque = $Ataque
@onready var ruta: ComponenteRuta = $Ruta
## Le alumbra cuando se le ve: el laberinto está a oscuras durante el combate.
@onready var luz: LuzAntorcha = $Luz


func _ready() -> void:
	vida.danado.connect(_al_recibir_danio)
	vida.murio.connect(_al_morir) # `Muerte` (heredado) también: aplasta, suelta monedas y libera
	ataque.termino.connect(_al_terminar_ataque)
	EstadoJuego.objetos_cambio.connect(_al_cambiar_objetos)
	EstadoJuego.estado_restablecido.connect(_actualizar)
	movimiento.velocidad = velocidad_caminar
	_posicion_inicial = global_position
	reiniciar()


func _physics_process(delta: float) -> void:
	match estado:
		Estado.PERSEGUIR:
			_perseguir(delta)
		Estado.ESPERA:
			movimiento.frenar(delta)
			animador.reproducir(&"parado")
			_espera -= delta
			if _espera <= 0.0:
				estado = Estado.PERSEGUIR
		_:
			movimiento.detener()


# --- API --------------------------------------------------------------------------------------

## ¿Lo ve Leonidas? (tiene el cuerno, o la escena lo está enseñando)
func es_visible() -> bool:
	return _mostrado or (tiene_cuerno() and estado != Estado.INACTIVO)


static func tiene_cuerno() -> bool:
	return EstadoJuego.cantidad(EstadoJuego.OBJ_CUERNO) > 0


## Empieza a perseguir. Prepara la ruta del laberinto (las rejas ya deben estar cerradas).
func empezar_combate() -> void:
	if estado != Estado.INACTIVO:
		return
	var zona := Zona.de(self)
	if zona:
		ruta.preparar(Rect2(zona.obtener_limites()))
	estado = Estado.PERSEGUIR
	contacto.activo = true
	_actualizar()


## Como al principio: en su sitio, vida llena, INACTIVO y escondido.
func reiniciar() -> void:
	_matar_tween()
	estado = Estado.INACTIVO
	global_position = _posicion_inicial
	movimiento.detener()
	ataque.cancelar()
	contacto.activo = false
	vida.restaurar()
	parpadeo.detener()
	ruta.olvidar()
	_mostrado = false
	modulate.a = 1.0
	animador.direccion = Vector2.DOWN
	animador.reproducir(&"parado", true)
	_actualizar()


## Lo enseña con un fundido (aunque Leonidas no tenga el cuerno) y ruge. Con `await`.
func aparecer() -> void:
	_mostrado = true
	_actualizar()
	modulate.a = 0.0
	if sonido_rugido:
		sonido_rugido.play()
	await _fundir(1.0)


## Deja de enseñarlo: si no hay cuerno, se desvanece. Con `await`.
func desaparecer() -> void:
	if not tiene_cuerno():
		await _fundir(0.0)
	_mostrado = false
	modulate.a = 1.0
	_actualizar()


# --- Combate ----------------------------------------------------------------------------------

func _perseguir(delta: float) -> void:
	var j := deteccion.objetivo if deteccion.viendo() else null
	if j == null:
		movimiento.frenar(delta)
		animador.reproducir(&"parado")
		return
	var d := j.global_position - global_position
	if absf(d.x) <= alcance.x and absf(d.x) >= 6.0 and absf(d.y) <= alcance.y:
		movimiento.detener()
		_mirar(d.x)
		estado = Estado.ATACAR
		ataque.atacar()
		return
	# Se coloca a un lado de Leonidas (del lado en que ya está), o va a por él si ese sitio es pared.
	var lado := signf(-d.x) if absf(d.x) > 1.0 else 1.0
	var meta := j.global_position + Vector2(lado * distancia_lado, 0.0)
	if not ruta.es_libre(meta):
		meta = j.global_position
	var paso := ruta.siguiente_paso(global_position, meta, delta)
	var hacia := paso - global_position
	if hacia.length() > 1.0:
		movimiento.mover(hacia.normalized(), delta)
		_mirar(hacia.x)
		animador.reproducir(&"caminar")
	else:
		movimiento.frenar(delta)
		_mirar(d.x)
		animador.reproducir(&"parado")


func _al_terminar_ataque() -> void:
	if estado != Estado.ATACAR:
		return
	estado = Estado.ESPERA
	_espera = pausa


func _mirar(dx: float) -> void:
	if absf(dx) > 2.0:
		animador.mirar(Vector2(signf(dx), 0.0))


func _al_recibir_danio(_cantidad: int, _origen: Vector2) -> void:
	if not vida.muerto:
		parpadeo.parpadear(vida.tiempo_invulnerable())


func _al_morir() -> void:
	estado = Estado.MUERTO
	ataque.cancelar()
	contacto.set_deferred(&"activo", false)
	movimiento.detener()
	_mostrado = true # que se vea caer aunque no haya cuerno (no debería: sin él no se le hiere)
	_actualizar()
	derrotado.emit()


# --- Visibilidad ------------------------------------------------------------------------------

func _al_cambiar_objetos(id: StringName, _cantidad: int) -> void:
	if id == EstadoJuego.OBJ_CUERNO:
		_actualizar()


## Aplica si se ve, si se le puede herir y si la barra va en gris.
func _actualizar() -> void:
	var en_combate := estado == Estado.PERSEGUIR or estado == Estado.ATACAR or estado == Estado.ESPERA
	var ve := es_visible()
	sprite.visible = ve
	sombra.visible = ve
	luz.fijar_intensidad(1.0 if ve else 0.0, duracion_fundido * 0.5)
	hurtbox.activo = en_combate and tiene_cuerno()
	invulnerable = en_combate and not tiene_cuerno()


func _fundir(alfa: float) -> void:
	_matar_tween()
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", alfa, duracion_fundido)
	await _tween.finished


func _matar_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null
