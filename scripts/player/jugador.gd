class_name Jugador
extends CharacterBody2D
## Cerebro de Leonidas a pie: lee la entrada y decide qué hacer; el cómo lo hacen sus
## componentes hijos (Movimiento, Animador, Vida, Estamina, Ataque, Carga, Interaccion,
## Parpadeo y el Hurtbox). La posición del nodo son los pies.
## Máquina de estados (`Estado`): NORMAL (mover, y desde ahí voltereta, espadazo, hablar
## o agarrar/lanzar), PIRUETA, ATAQUE, AGARRAR, TIRAR, DANO, MUERTO, BLOQUEADO y COMER.
## BLOQUEADO (quieto e invulnerable) dura mientras quede algún motivo de bloqueo
## (`bloquear(motivo)` / `desbloquear(motivo)`): diálogos, tienda, cambios de zona,
## escenas guiadas. Vida en cuartos de corazón; al morir emite `murio` y, si
## `reaparecer_automatico`, reaparece en `punto_control` (`reaparecio`).
## El daño llega por `ComponenteVida.danado` (conectada al Hurtbox); contrato de daño
## compartido: un Hitbox llama a `recibir_golpe(danio, origen)`.

## Al morir, tras la animación (antes de reaparecer).
signal murio
## Al reaparecer en `punto_control` con la vida restaurada.
signal reaparecio
## Al empezar una voltereta (no si falta estamina).
signal pirueta_empezada
## Al empezar un espadazo (lo usa el tutorial de los sabios).
signal ataque_empezado
## Al terminar de comer (después de curarse).
signal comio(objeto: Objeto)

enum Estado { NORMAL, PIRUETA, ATAQUE, AGARRAR, TIRAR, DANO, MUERTO, BLOQUEADO, COMER }

## Animación de comer (fila "Layer 17" de leonidas_mini, de frente: ver su layout).
const ANIM_COMER := &"comer"

@export_group("Movimiento")
## Velocidad al caminar con un objeto en las manos (px/s).
@export var velocidad_cargando := 55.0

@export_group("Pirueta")
## Velocidad constante durante la voltereta (px/s).
@export var velocidad_pirueta := 150.0
## Estamina que gasta una voltereta.
@export var costo_pirueta := 35.0
## Si la voltereta atraviesa los obstáculos bajos (capa `Capas.OBSTACULO_BAJO`).
@export var atraviesa_obstaculos_bajos := true

@export_group("Combate")
## Velocidad del empujón al recibir daño (px/s).
@export var empuje_dano := 170.0

@export_group("Objetos")
## Segundos con la pose de comer (es un solo dibujo) antes de curarse.
@export var duracion_comer := 0.8
## Dónde se dibuja el objeto que come, respecto a los pies: la pose de la artista no trae
## la manzana (en la lámina, Jugabilidad p. 8, va aparte, arriba a la derecha de la mano).
@export var posicion_objeto_comer := Vector2(11, -18)
## Dónde va el icono (16×16) de un objeto recién obtenido, con la misma pose: la
## empuñadura de la espada queda en la mano levantada.
@export var posicion_objeto_obtenido := Vector2(12, -23)

@export_group("Muerte")
## Si reaparece solo en `punto_control` al acabar de morir (si no, lo hace quien escuche `murio`).
@export var reaparecer_automatico := true

## La espada vive en EstadoJuego (sobrevive a guardar/cargar); la dan los sabios.
var tiene_espada: bool:
	get:
		return EstadoJuego.tiene_espada

var estado: Estado = Estado.NORMAL
var punto_control: Vector2

var _dir_pirueta := Vector2.DOWN
## Acción pedida por evento (&"pirueta", &"atacar", &"interactuar" o &"tirar") que se
## ejecuta en el siguiente tick de física (ver `_unhandled_input`). Vacía = ninguna.
var _accion_pendiente: StringName = &""
var _comiendo: Objeto = null
var _turno_comer := 0
var _objeto_en_mano: Sprite2D
## Por qué está bloqueado (&"dialogo", &"tienda", &"zona", &"escena"...): cada sistema
## pone y quita solo el suyo, así ninguno deshace el bloqueo de otro. Solo se usan las
## claves (un conjunto). Vive en este nodo: se vacía solo al recrearse `game.tscn`.
var _motivos_bloqueo: Dictionary[StringName, bool] = {}

@onready var movimiento: ComponenteMovimiento = $Movimiento
@onready var animador: AnimadorDireccional = $Animador
@onready var vida: ComponenteVida = $Vida
@onready var estamina: ComponenteEstamina = $Estamina
@onready var ataque: ComponenteAtaque = $Ataque
@onready var carga: ComponenteCarga = $Carga
@onready var interaccion: ComponenteInteraccion = $Interaccion
@onready var parpadeo: ComponenteParpadeo = $Parpadeo
@onready var hurtbox: Hurtbox = $Hurtbox


## El Jugador de la partida en curso (grupo "jugador", asignado en jugador.tscn), o null.
static func actual(desde: Node) -> Jugador:
	if desde == null or not desde.is_inside_tree():
		return null
	return desde.get_tree().get_first_node_in_group(&"jugador") as Jugador


func _ready() -> void:
	punto_control = global_position
	vida.danado.connect(_al_recibir_danio)
	vida.murio.connect(_al_morir)
	ataque.termino.connect(_volver_a_normal)
	animador.termino.connect(_al_terminar_animacion)
	animador.reproducir(&"parado")
	_objeto_en_mano = Sprite2D.new()
	_objeto_en_mano.name = &"ObjetoEnMano"
	_objeto_en_mano.position = posicion_objeto_comer
	_objeto_en_mano.visible = false
	add_child(_objeto_en_mano) # el último hijo: se dibuja encima de Leonidas


## Las acciones llegan por eventos (no se sondean) para que la pulsación la consuma un
## solo receptor: la escena actual recibe `_unhandled_input` antes que los autoload, así
## que el Jugador la ve antes que la caja de diálogo, la tienda o el libro. Solo consume
## en NORMAL: bloqueado (diálogo, tienda...) la deja pasar a quien la necesita.
## La acción no se ejecuta aquí sino en el siguiente tick de física: `interactuar` hace una
## consulta directa al espacio físico (`Hitbox.consultar`), que la documentación solo da
## por segura dentro del tick (con física en hilos, fuera falla), y así las acciones
## empiezan en el mismo orden que antes: orientar → mover → acción. Retraso ≤ 1 tick.
func _unhandled_input(event: InputEvent) -> void:
	if estado != Estado.NORMAL:
		return
	var accion: StringName = &""
	if carga.cargando():
		if event.is_action_pressed(&"interactuar") or event.is_action_pressed(&"atacar"):
			accion = &"tirar"
	elif event.is_action_pressed(&"pirueta"):
		accion = &"pirueta"
	elif event.is_action_pressed(&"atacar") and tiene_espada:
		accion = &"atacar"
	elif event.is_action_pressed(&"interactuar"):
		accion = &"interactuar"
	if accion.is_empty():
		return
	get_viewport().set_input_as_handled()
	_accion_pendiente = accion


func _physics_process(delta: float) -> void:
	# La acción pendiente vale solo para este tick: si ya no está en NORMAL, se pierde.
	var accion := _accion_pendiente
	_accion_pendiente = &""
	match estado:
		Estado.NORMAL:
			_estado_normal(delta, accion)
		Estado.PIRUETA:
			movimiento.impulsar(_dir_pirueta * velocidad_pirueta)
		Estado.ATAQUE, Estado.AGARRAR, Estado.TIRAR, Estado.COMER:
			movimiento.frenar(delta)
		Estado.DANO:
			movimiento.frenar(delta, 0.6)
		Estado.MUERTO, Estado.BLOQUEADO:
			movimiento.detener()


## Movimiento (sondeado: es un estado continuo) y la `accion` que pidió un evento.
func _estado_normal(delta: float, accion: StringName) -> void:
	var entrada := Input.get_vector(&"mover_izquierda", &"mover_derecha", &"mover_arriba", &"mover_abajo")
	animador.orientar(entrada)
	movimiento.mover(entrada, delta, velocidad_cargando if carga.cargando() else -1.0)

	var base := "caminar" if entrada != Vector2.ZERO else "parado"
	if carga.cargando():
		animador.reproducir(StringName(base + "_objeto"))
		if accion == &"tirar":
			_tirar()
		return
	animador.reproducir(StringName(base))

	match accion:
		&"pirueta":
			_pirueta(entrada)
		&"atacar":
			if tiene_espada:
				_atacar()
		&"interactuar":
			_interactuar()


func _pirueta(entrada: Vector2) -> void:
	if not estamina.gastar(costo_pirueta):
		return # sin estamina suficiente no hay voltereta
	_dir_pirueta = entrada.normalized() if entrada != Vector2.ZERO else animador.direccion
	animador.orientar(_dir_pirueta)
	estado = Estado.PIRUETA
	vida.invulnerable_extra = true
	estamina.pausada = true
	if atraviesa_obstaculos_bajos:
		set_collision_mask_value(Capas.NUMERO_OBSTACULO_BAJO, false)
	# El giro dibujado de "pirueta_lado" va al revés del movimiento: se invierte el espejo.
	animador.reproducir(&"pirueta", true, true)
	pirueta_empezada.emit()


func _terminar_pirueta() -> void:
	vida.invulnerable_extra = false
	estamina.pausada = false
	set_collision_mask_value(Capas.NUMERO_OBSTACULO_BAJO, true)
	velocity *= 0.3


func _atacar() -> void:
	estado = Estado.ATAQUE
	velocity *= 0.2
	ataque.atacar()
	ataque_empezado.emit()


func _interactuar() -> void:
	var objetivo := interaccion.buscar()
	if objetivo == null:
		return
	if objetivo.has_method(&"interactuar"):
		# Duck typing a propósito: NPC, carteles, cofres... (cualquier nodo con `interactuar`).
		objetivo.call(&"interactuar", self)
		return
	var agarrable := objetivo as ObjetoAgarrable
	if agarrable:
		estado = Estado.AGARRAR
		movimiento.detener()
		carga.levantar(agarrable)
		animador.reproducir(&"agarrar", true)


func _tirar() -> void:
	estado = Estado.TIRAR
	animador.reproducir(&"tirar", true)
	carga.lanzar(animador.direccion)


## ¿Puede abrir el libro / usar un objeto ahora? (a pie, sin hacer nada más).
func puede_usar_objeto() -> bool:
	return estado == Estado.NORMAL and not carga.cargando() and not vida.muerto


## Come un consumible (lo llama el libro, que ya lo ha gastado): pose de comer durante
## `duracion_comer` y luego cura `objeto.cura` cuartos de corazón.
func comer(objeto: Objeto) -> void:
	if vida.muerto:
		return
	_comiendo = objeto
	estado = Estado.COMER
	movimiento.detener()
	animador.direccion = Vector2.DOWN # la pose es de frente; al acabar sigue mirando abajo
	animador.reproducir_fija(ANIM_COMER)
	_mostrar_objeto_en_mano(objeto.icono_pequeno if objeto.icono_pequeno else objeto.icono, posicion_objeto_comer, true)
	_turno_comer += 1
	var turno := _turno_comer
	await get_tree().create_timer(duracion_comer, false).timeout
	# Si mientras tanto le golpearon (o pasó otra cosa), no se cura.
	if turno == _turno_comer and estado == Estado.COMER:
		_terminar_de_comer()


## Pose de objeto obtenido (la de comer, de frente, con el icono en la mano levantada),
## sin curar ni cambiar de estado: sirve también estando BLOQUEADO (cinemáticas).
## Con `duracion` > 0 la quita sola al acabar; con 0 se queda hasta
## `ocultar_objeto_obtenido()` (p. ej. mientras sale el aviso «¡Obtuviste…!»).
func mostrar_objeto_obtenido(icono: Texture2D, duracion := 1.0) -> void:
	animador.direccion = Vector2.DOWN # la pose es de frente; al acabar sigue mirando abajo
	animador.reproducir_fija(ANIM_COMER)
	_mostrar_objeto_en_mano(icono, posicion_objeto_obtenido, false)
	if duracion > 0.0:
		await get_tree().create_timer(duracion, false).timeout
		ocultar_objeto_obtenido()


func ocultar_objeto_obtenido() -> void:
	_objeto_en_mano.visible = false
	if estado == Estado.NORMAL or estado == Estado.BLOQUEADO:
		animador.reproducir(&"parado", true)


func _mostrar_objeto_en_mano(icono: Texture2D, posicion: Vector2, saltito: bool) -> void:
	_objeto_en_mano.texture = icono
	_objeto_en_mano.visible = icono != null
	_objeto_en_mano.position = posicion
	# Un saltito de 1 px a mitad de la pose, como si lo levantara para morderlo.
	if icono and saltito:
		var t := create_tween()
		t.tween_interval(duracion_comer * 0.45)
		t.tween_property(_objeto_en_mano, ^"position:y", posicion.y - 1.0, 0.0)
		t.tween_interval(duracion_comer * 0.2)
		t.tween_property(_objeto_en_mano, ^"position:y", posicion.y, 0.0)


func _terminar_de_comer() -> void:
	_objeto_en_mano.visible = false
	var o := _comiendo
	_comiendo = null
	if o:
		vida.curar(o.cura)
	_volver_a_normal()
	comio.emit(o)


## Deja limpio lo que el estado actual tenía a medias (lo llaman `bloquear` y el
## daño), porque al cambiar de estado a la fuerza su animación se corta y nunca llega
## `_al_terminar_animacion`. Con `devolver_objeto`, si estaba comiendo, el objeto (que el
## libro ya gastó) vuelve al inventario.
func _salir_del_estado(devolver_objeto: bool) -> void:
	match estado:
		Estado.PIRUETA:
			_terminar_pirueta()
		Estado.ATAQUE:
			ataque.cancelar()
		Estado.COMER:
			if devolver_objeto and _comiendo:
				EstadoJuego.agregar_objeto(_comiendo.id)
			_comiendo = null
			_turno_comer += 1 # invalida el temporizador de comer() en curso
			_objeto_en_mano.visible = false


func _al_recibir_danio(_cantidad: int, origen: Vector2) -> void:
	# Si le golpean mientras come, se queda sin curar y pierde el objeto (es el riesgo de
	# comer en pleno combate); si lo interrumpe un bloqueo, se le devuelve (`bloquear`).
	_salir_del_estado(false)
	_objeto_en_mano.visible = false
	carga.soltar(animador.direccion)
	movimiento.empujar_desde(origen, empuje_dano, -animador.direccion)
	if vida.muerto:
		return
	estado = Estado.DANO
	parpadeo.parpadear(vida.tiempo_invulnerable())
	animador.reproducir(&"recibir_dano", true)


func _al_morir() -> void:
	estado = Estado.MUERTO
	parpadeo.detener()
	hurtbox.set_deferred(&"monitorable", false)
	animador.reproducir(&"morir", true)


func _al_terminar_animacion(_anim: StringName) -> void:
	match estado:
		Estado.PIRUETA:
			_terminar_pirueta()
			_volver_a_normal()
		Estado.AGARRAR, Estado.TIRAR, Estado.DANO:
			_volver_a_normal()
		Estado.MUERTO:
			await get_tree().create_timer(1.0, false).timeout # se para con la pausa
			murio.emit()
			if reaparecer_automatico:
				reaparecer()


func _volver_a_normal() -> void:
	if estado != Estado.MUERTO and estado != Estado.BLOQUEADO:
		estado = Estado.NORMAL


func reaparecer() -> void:
	global_position = punto_control
	movimiento.detener()
	vida.restaurar()
	estamina.llenar()
	animador.direccion = Vector2.DOWN
	hurtbox.set_deferred(&"monitorable", true)
	parpadeo.parpadear(vida.tiempo_invulnerable())
	# Los motivos se registran también estando muerto (una escena o un cambio de zona
	# pudo empezar mientras tanto): si queda alguno, reaparece ya bloqueado y lo libera
	# quien lo puso, como si se hubiera bloqueado en pie.
	estado = Estado.NORMAL
	if esta_bloqueado():
		_entrar_en_bloqueo()
	animador.reproducir(&"parado", true)
	reaparecio.emit()


## Bloquea a Leonidas por `motivo` (&"dialogo", &"tienda", &"zona", &"escena"...):
## quieto e invulnerable hasta que se quite el último motivo. Repetir un motivo no hace
## nada y, si ya estaba bloqueado por otro, tampoco: no corta ni repinta la pose que haya
## puesto una cinemática (p. ej. `mostrar_objeto_obtenido`). Muerto, solo se apunta el
## motivo (MUERTO tiene prioridad; ver `reaparecer`).
func bloquear(motivo: StringName) -> void:
	_motivos_bloqueo[motivo] = true
	if estado != Estado.BLOQUEADO and estado != Estado.MUERTO:
		_entrar_en_bloqueo()


## Quita `motivo`; al quitar el último vuelve a NORMAL. Quitar un motivo que no estaba no
## hace nada (p. ej. no corta una voltereta en curso).
func desbloquear(motivo: StringName) -> void:
	if not _motivos_bloqueo.erase(motivo):
		return
	if not esta_bloqueado() and estado == Estado.BLOQUEADO:
		estado = Estado.NORMAL
		vida.invulnerable_extra = false


func esta_bloqueado() -> bool:
	return not _motivos_bloqueo.is_empty()


## Para cinemáticas, estando bloqueado: mira hacia `hacia` en la pose de reposo.
func mirar_hacia(hacia: Vector2) -> void:
	animador.mirar(hacia)
	animador.reproducir(&"parado_objeto" if carga.cargando() else &"parado")


## Bloqueado = quieto e invulnerable: si le golpearan, el daño lo pasaría a DANO y al
## acabar la animación volvería a NORMAL con el diálogo abierto.
func _entrar_en_bloqueo() -> void:
	# Interrumpido sin culpa del jugador: si estaba comiendo, recupera el objeto.
	_salir_del_estado(true)
	estado = Estado.BLOQUEADO
	# Nada más usa invulnerable_extra estando BLOQUEADO: la voltereta, que también lo usa,
	# ya terminó en _salir_del_estado y no puede empezar hasta desbloquear.
	vida.invulnerable_extra = true
	animador.reproducir(&"parado_objeto" if carga.cargando() else &"parado")
