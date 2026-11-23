class_name Minotauro
extends CharacterBody2D
## Jefe del laberinto (nivel 3, PROVISIONAL: diseño de los sabios y de la artista, 2026-11-22).
## Hereda de scenes/enemies/enemigo_pintado.tscn; arte pintado en resources/sprite_frames/
## minotauro.tres (parado, caminar, atacar).
##
## Es INVENCIBLE mientras Leonidas no tenga el cuerno (`EstadoJuego.OBJ_CUERNO`, en un cofre del
## laberinto): se le ve y la espada le da, pero no le quita vida (`vida.invulnerable_extra`). Al
## conseguir el cuerno se le puede herir al momento (`objetos_cambio`). `invulnerable` +
## `invulnerable_cambio` siguen ese estado (la barra del jefe se pone gris).
##
## Estados: INACTIVO (escondido hasta que la escena lo enseña, sin golpes) → `empezar_combate()`
## → PERSEGUIR (camina por el laberinto con `ComponenteRuta` hasta ponerse a un lado de
## Leonidas) → ATACAR (`Ataque`, un espadazo hacia el lado al que mira: `Golpe` en los
## fotogramas `frames_golpe` de `atacar`; después se queda con la espada clavada, el momento de
## atacarle) → ESPERA (`pausa`) → PERSEGUIR. A 0 de vida: DERROTADO y `derrotado`.
##
## Es un jefe, como Medusa: al vencerlo NO muere como un enemigo normal (sin `ComponenteMuerte`
## ni monedas): se queda quieto para la escena de la derrota, que después lo retira (`retirarse()`).
##
## Para la escena del encuentro: `aparecer()` (lo enseña con un fundido y ruge), `reiniciar()`
## (Game Over a mitad del combate) y `retirarse()`.

signal derrotado
## Cambia al quedar invencible (sin cuerno) o vulnerable: la barra del jefe se pone gris.
signal invulnerable_cambio(activa: bool)

enum Estado { INACTIVO, PERSEGUIR, ATACAR, ESPERA, DERROTADO }

@export_group("Combate")
## Píxeles por segundo (Leonidas camina a 80: puede huir, pero no dormirse).
@export var velocidad_caminar := 60.0
## Ataca si Leonidas está a ≤ x en horizontal (y a ≥ 6, para no golpear de frente) y ≤ y en
## vertical: el espadazo barre el suelo a su lado (ver la forma `Golpe/Derecha`).
@export var alcance := Vector2(50, 12)
## Distancia en horizontal a la que intenta colocarse de Leonidas antes de atacar.
@export var distancia_lado := 32.0
## Segundos quieto entre ataques.
@export var pausa := 0.8
## Segundos del fundido de `aparecer()` y `retirarse()`.
@export var duracion_fundido := 0.6
@export_group("Sonido")
## Rugido al aparecer.
@export var sonido_rugido: AudioStreamPlayer2D

var estado := Estado.INACTIVO
## True mientras es invencible en combate (Leonidas sin cuerno).
var invulnerable := false:
	set(valor):
		if valor == invulnerable:
			return
		invulnerable = valor
		vida.invulnerable_extra = valor
		invulnerable_cambio.emit(valor)

## Lo ha enseñado la escena (antes del combate está escondido).
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
@onready var golpe: Hitbox = $Golpe
@onready var ataque: ComponenteAtaque = $Ataque
@onready var ruta: ComponenteRuta = $Ruta
## Le alumbra mientras se le ve: el laberinto está a oscuras durante el combate.
@onready var luz: LuzAntorcha = $Luz


func _ready() -> void:
	# La base trae `Muerte` conectado a `vida.murio` y en una escena heredada no se puede quitar
	# el nodo: se desconecta aquí, porque el Minotauro es un jefe y no muere (DERROTADO), como Medusa.
	var muerte := $Muerte as ComponenteMuerte
	if vida.murio.is_connected(muerte.morir):
		vida.murio.disconnect(muerte.morir)
	vida.danado.connect(_al_recibir_danio)
	vida.murio.connect(_al_ser_derrotado)
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

## ¿Se le ve? (en cuanto la escena lo enseña y durante todo el combate)
func es_visible() -> bool:
	return _mostrado or estado != Estado.INACTIVO


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
	hurtbox.activo = true
	_actualizar()


## Como al principio: en su sitio, vida llena, INACTIVO y escondido.
func reiniciar() -> void:
	_matar_tween()
	estado = Estado.INACTIVO
	global_position = _posicion_inicial
	movimiento.detener()
	ataque.cancelar()
	contacto.activo = false
	hurtbox.activo = false
	vida.restaurar()
	parpadeo.detener()
	ruta.olvidar()
	_mostrado = false
	modulate.a = 1.0
	animador.direccion = Vector2.DOWN
	animador.reproducir(&"parado", true)
	_actualizar()


## Lo enseña con un fundido y ruge. Con `await`.
func aparecer() -> void:
	_mostrado = true
	_actualizar()
	modulate.a = 0.0
	if sonido_rugido:
		sonido_rugido.play()
	await _fundir(1.0)


## Tras la escena de la derrota: se desvanece en la oscuridad y se libera. Con `await`.
func retirarse() -> void:
	luz.fijar_intensidad(0.0, duracion_fundido)
	await _fundir(0.0)
	queue_free()


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


## A 0 de vida: quieto, sin golpes ni Hurtbox, de pie para la escena de la derrota.
func _al_ser_derrotado() -> void:
	estado = Estado.DERROTADO
	ataque.cancelar()
	golpe.set_deferred(&"activo", false)
	contacto.set_deferred(&"activo", false)
	hurtbox.set_deferred(&"activo", false)
	movimiento.detener()
	parpadeo.detener()
	invulnerable = false
	animador.reproducir(&"parado", true)
	derrotado.emit()


# --- Cuerno -----------------------------------------------------------------------------------

func _al_cambiar_objetos(id: StringName, _cantidad: int) -> void:
	if id == EstadoJuego.OBJ_CUERNO:
		_actualizar()


## Aplica si se ve y si se le puede herir (y, por la señal, si la barra va en gris).
func _actualizar() -> void:
	var en_combate := estado == Estado.PERSEGUIR or estado == Estado.ATACAR or estado == Estado.ESPERA
	var ve := es_visible()
	sprite.visible = ve
	sombra.visible = ve
	luz.fijar_intensidad(1.0 if ve else 0.0, duracion_fundido * 0.5)
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
