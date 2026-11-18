class_name Medusa
extends CharacterBody2D
## Medusa, jefa del nivel 2 (Guión pp. 26–28, 37–38; plan `docs/plan/nivel2/06_medusa_jefe.md`).
## Arte pintado: `parado` y `caminar` de frente, `atacar` de lado mirando a la izquierda (el
## AnimadorDireccional lo espeja). La posición del nodo es el punto de apoyo (la cola enroscada).
##
## Estados:
##   INACTIVA   quieta en `parado`, sin golpes ni Hurtbox, hasta `empezar_combate()`
##   INVOCAR    "canto" de `duracion_invocacion` (parpadeo verdoso PROVISIONAL) y aparecen
##              `ciclopes_por_invocacion` cíclopes serpiente. Al empezar el combate y la primera
##              vez que baja del 50 % de vida
##   ESPERA     `pausa_embestidas` quieta (× `factor_pausa_invulnerable` con cíclopes vivos)
##   ACERCARSE  camina hacia Leonidas hasta que el punto de impacto de la espada le quede a
##              menos de `distancia_embestir` (o pasan `tiempo_acercarse_max` s)
##   EMBESTIDA  anim `atacar`: hasta el fotograma `frame_fijar` (16) sigue a Leonidas; ahí FIJA
##              el objetivo y enseña `AvisoSuelo`; entre `frame_deslizar` (20) y el primer
##              fotograma de golpe se DESLIZA (como mucho `alcance_embestida` px, con
##              `move_and_slide`) para que la espada caiga en el objetivo; `GolpeSuelo` activo en
##              `frames_golpe` (24–27), sacudida de cámara en `frame_sacudida`. El `Contacto`
##              se apaga del deslizamiento al final del golpe (ver `_al_cambiar_frame`).
##              El punto de impacto es la forma de `GolpeSuelo` (6, 6): donde se clava la espada
##              en el dibujo (fotogramas 27–47, medido en el arte), justo delante de su cola
##   CLAVADA    espada clavada (fotogramas 28–47): no se mueve. Ventana para pegarle
##   RECUPERA   48–59 → ESPERA
##   LANZAR     desde el 50 %: cada `intervalo_trozos` s lanza `TrozoEstatua` (2 con ≤ 25 %)
##              desde `Mano`, en ESPERA o ACERCARSE. Sin pose propia: `parado` y un pequeño
##              "levantar" del Sprite (PROVISIONAL, falta arte)
##   DERROTADA  al llegar a 0 de vida. NO usa `ComponenteMuerte` (Medusa no muere: suplica,
##              plan M5): se para, apaga sus golpes y su Hurtbox, libera cíclopes y trozos y
##              emite `derrotada`
## Recibe daño en cualquier estado de combate salvo mientras sea invulnerable (INVOCAR y con
## cíclopes vivos, en gris); un golpe solo la hace parpadear: es una jefa, no se la empuja ni se
## la interrumpe.
##
## PARA M4–M8 (barra de vida, encuentro, recompensa, colocación, reinicio):
## - `empezar_combate()`: la saca de INACTIVA (lo llamará la escena del encuentro).
## - Señal `invulnerable_cambio(activa)`: para la barra (corazones en gris). `invulnerable` la lee.
## - Señal `derrotada` + estado DERROTADA: la escena del encuentro hace súplica, trato y premio.
## - Señal `golpe_suelo(punto)`: cuando la espada toca el suelo (además de la sacudida de cámara
##   propia si `sacudir_camara`).
## - `reiniciar()`: vida llena, INACTIVA, banderas de invocación a cero, posición inicial, sin
##   cíclopes ni trozos vivos (Game Over a mitad del combate, M6).
## - `vida` (ComponenteVida, 20 cuartos) para la barra: `vida.cambio(vida, vida_max)`.
## - `puntos_invocacion`: los pone la zona (`tools/build_zonas.gd`, `cueva_jefe`); sin ellos usa
##   `desplazamientos_invocacion`.
## - `quedarse_derrotada()`: DERROTADA sin emitir `derrotada` (al cargar `cueva_jefe` con
##   `EstadoJuego.medusa_derrotada`).
## - `charla` (ZonaDialogo, sin diálogo hasta que `EscenaMedusa` le pone el recordatorio): tras el
##   trato Medusa se queda en la sala y se puede hablar con ella.
## La escena del encuentro, la derrota y la recompensa son `EscenaMedusa`
## (scripts/cinematics/escena_medusa.gd).
## Todo número es PROVISIONAL hasta que Esteban lo pruebe.

## Al cambiar la invulnerabilidad por los cíclopes (para la barra de vida, M4).
signal invulnerable_cambio(activa: bool)
## Al llegar a 0 de vida (entra en DERROTADA). Solo una vez hasta `reiniciar()`.
signal derrotada
## Cuando la espada toca el suelo (`frame_sacudida`), con el punto de impacto global.
signal golpe_suelo(punto: Vector2)

enum Estado { INACTIVA, ESPERA, ACERCARSE, EMBESTIDA, CLAVADA, RECUPERA, INVOCAR, LANZAR, DERROTADA }

## Color de Medusa mientras es invulnerable (cíclopes vivos). PROVISIONAL: un shader de
## desaturar se vería mejor.
const COLOR_INVULNERABLE := Color(0.6, 0.6, 0.6)
## Tinte del "canto" al invocar. PROVISIONAL (no hay pose de invocar).
const COLOR_CANTO := Color(0.6, 1.0, 0.65)

@export_group("Sonido")
## Al empezar el canto de invocación.
@export var sonido_invocar: AudioStreamPlayer2D
## Cuando empieza a deslizarse en la embestida (el golpe al suelo y la derrota suenan por señal, en la escena).
@export var sonido_embestida: AudioStreamPlayer2D
## Al arrojar un trozo de estatua.
@export var sonido_lanzar: AudioStreamPlayer2D
@export_group("Embestida")
## Segundos quieta entre embestidas.
@export var pausa_embestidas := 1.2
## Empieza a embestir cuando el punto de impacto está a menos de esto de Leonidas (px).
@export var distancia_embestir := 32.0
## Si en este tiempo no se ha acercado lo bastante, embiste igual.
@export var tiempo_acercarse_max := 4.0
## Lo que se puede deslizar como mucho para que la espada caiga sobre el objetivo (px).
@export var alcance_embestida := 40.0
## Fotograma de `atacar` en el que fija el objetivo y aparece el aviso (espada arriba del todo).
@export var frame_fijar := 16
## Fotograma de `atacar` en el que empieza a deslizarse (acaba en el primero de `frames_golpe`).
@export var frame_deslizar := 20
## Fotogramas de `atacar` con `GolpeSuelo` activo (golpe al suelo).
@export var frames_golpe := Vector2i(24, 27)
## Fotograma en que la espada toca el suelo en el dibujo (sacudida y `golpe_suelo`).
@export var frame_sacudida := 27
## Último fotograma de CLAVADA (luego RECUPERA hasta el final de la animación).
@export var frame_fin_clavada := 47
## Sacude la cámara (`Game.camara`) al golpear el suelo.
@export var sacudir_camara := true

@export_group("Invocación")
## Se asigna en el Inspector (= `ciclope_serpiente.tscn`). Su raíz es un `CiclopeSerpiente`.
@export var escena_ciclope: PackedScene
## Cíclopes por invocación (Q7: 2 al empezar y 2 a mitad de vida).
@export var ciclopes_por_invocacion := 2
## Dónde pueden aparecer (los pone la zona, M6). Se usan los más alejados de Leonidas.
@export var puntos_invocacion: Array[Marker2D] = []
## Respaldo sin `puntos_invocacion`: desplazamientos desde la posición inicial de Medusa.
@export var desplazamientos_invocacion: Array[Vector2] = [Vector2(-80, 30), Vector2(80, 30), Vector2(-70, -40), Vector2(70, -40)]
## Segundos de "canto" antes de que aparezcan.
@export var duracion_invocacion := 1.0
## Con cíclopes vivos la pausa entre embestidas se multiplica por esto.
@export var factor_pausa_invulnerable := 1.5

@export_group("Trozos de estatua")
## Se asigna en el Inspector (= `trozo_estatua.tscn`). Su raíz es un `TrozoEstatua`.
@export var escena_trozo: PackedScene
## Segundos entre lanzamientos (desde el 50 % de vida).
@export var intervalo_trozos := 3.5
## Con la vida a esta fracción o menos lanza 2 trozos cada vez.
@export var fraccion_dos_trozos := 0.25
## El segundo trozo cae a esta distancia al azar del primero (px), para cerrar huidas.
@export var dispersion_segundo_trozo := 24.0
## Daño de cada trozo, en cuartos.
@export var danio_trozo := 2
## Duración de la pose de lanzar (el trozo sale a la mitad).
@export var duracion_lanzar := 0.4
## Si es false, no lanza trozos mientras haya cíclopes vivos (PROVISIONAL: preguntar).
@export var trozos_con_ciclopes := false

@export_group("Movimiento")
@export var velocidad_caminar := 30.0

var estado: Estado = Estado.INACTIVA
## True mientras la protegen los cíclopes (y durante el canto de invocar).
var invulnerable := false:
	set(valor):
		if valor == invulnerable:
			return
		invulnerable = valor
		vida.invulnerable_extra = valor
		_pintar()
		invulnerable_cambio.emit(valor)

var _espera := 0.0
var _objetivo := Vector2.ZERO
var _fijado := false
var _deslizado := false
var _sacudido := false
var _velocidad_deslizar := Vector2.ZERO
var _invocado_inicio := false
var _invocado_mitad := false
var _invocacion_pendiente := false
var _trozos_espera := 0.0
var _estado_tras_lanzar := Estado.ESPERA
var _espera_tras_lanzar := 0.0
var _lanzado := false
var _posicion_inicial := Vector2.ZERO
var _impacto_base := Vector2.ZERO
var _ciclopes: Array[CiclopeSerpiente] = []
var _trozos: Array[Node2D] = []
var _tween_canto: Tween
var _tween_lanzar: Tween

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var movimiento: ComponenteMovimiento = $Movimiento
@onready var animador: AnimadorDireccional = $Animador
@onready var vida: ComponenteVida = $Vida
@onready var deteccion: ComponenteDeteccion = $Deteccion
@onready var parpadeo: ComponenteParpadeo = $Parpadeo
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var contacto: Hitbox = $Contacto
@onready var golpe: Hitbox = $GolpeSuelo
@onready var forma_golpe: CollisionShape2D = $GolpeSuelo/Forma
@onready var aviso: Node2D = $AvisoSuelo
@onready var mano: Marker2D = $Mano
@onready var charla: ZonaDialogo = $Charla


func _ready() -> void:
	# La base trae `Muerte` conectado a `vida.murio` y en una escena heredada no se puede quitar
	# el nodo: se desconecta aquí, porque Medusa no muere (DERROTADA, plan M5).
	var muerte := $Muerte as ComponenteMuerte
	if vida.murio.is_connected(muerte.morir):
		vida.murio.disconnect(muerte.morir)
	vida.danado.connect(_al_recibir_danio)
	vida.cambio.connect(_al_cambiar_vida)
	vida.murio.connect(_al_ser_derrotada)
	animador.frame_cambio.connect(_al_cambiar_frame)
	animador.termino.connect(_al_terminar_animacion)
	movimiento.velocidad = velocidad_caminar
	# El punto de impacto se coloca en el editor (forma de `GolpeSuelo`) para el dibujo que mira
	# a la izquierda; se espeja al mirar a la derecha.
	_impacto_base = forma_golpe.position
	_posicion_inicial = global_position
	reiniciar()


func _physics_process(delta: float) -> void:
	match estado:
		Estado.ESPERA:
			movimiento.frenar(delta)
			_mirar_a_leonidas()
			animador.reproducir(&"parado")
			_contar_trozos(delta)
			if _siguiente_accion():
				return
			_espera -= delta
			if _espera <= 0.0:
				estado = Estado.ACERCARSE
				_espera = tiempo_acercarse_max
		Estado.ACERCARSE:
			_contar_trozos(delta)
			if _siguiente_accion():
				return
			_acercarse(delta)
		Estado.EMBESTIDA:
			_contar_trozos(delta)
			_seguir_embestida()
		Estado.CLAVADA, Estado.RECUPERA:
			_contar_trozos(delta)
			movimiento.detener()
		Estado.LANZAR:
			movimiento.frenar(delta)
			_espera -= delta
			if not _lanzado and _espera <= duracion_lanzar * 0.5:
				_lanzado = true
				_lanzar_trozos()
			if _espera <= 0.0:
				estado = _estado_tras_lanzar
				_espera = _espera_tras_lanzar
		_:
			movimiento.detener()


# --- API (M4–M8) ----------------------------------------------------------------------------

## Empieza el combate: primero invoca (Q7). Solo desde INACTIVA.
func empezar_combate() -> void:
	if estado != Estado.INACTIVA:
		return
	hurtbox.activo = true
	contacto.activo = true
	_invocado_inicio = true
	_invocar()


## Deja a Medusa como al principio: vida llena, INACTIVA, banderas de invocación a cero, en su
## posición inicial y sin cíclopes ni trozos vivos.
func reiniciar() -> void:
	_matar_tweens()
	for c in _ciclopes:
		if is_instance_valid(c):
			c.queue_free()
	_ciclopes.clear()
	_liberar_trozos()
	estado = Estado.INACTIVA
	_invocado_inicio = false
	_invocado_mitad = false
	_invocacion_pendiente = false
	_trozos_espera = intervalo_trozos
	_fijado = false
	global_position = _posicion_inicial
	movimiento.detener()
	vida.restaurar()
	invulnerable = false
	hurtbox.activo = false
	contacto.activo = false
	golpe.activo = false
	aviso.visible = false
	parpadeo.detener()
	sprite.position = Vector2.ZERO
	_pintar()
	animador.direccion = Vector2.LEFT
	animador.reproducir(&"parado", true)


## Cíclopes invocados que siguen vivos (para pruebas y la escena del encuentro).
func ciclopes_vivos() -> Array[CiclopeSerpiente]:
	return _ciclopes.duplicate()


## Punto global donde cae la espada ahora mismo (según hacia dónde mira).
func punto_impacto() -> Vector2:
	return global_position + _impacto_local()


# --- Embestida ------------------------------------------------------------------------------

func _acercarse(delta: float) -> void:
	var j := _leonidas()
	_espera -= delta
	if j == null:
		movimiento.frenar(delta)
		animador.reproducir(&"parado")
		return
	_mirar_a_leonidas()
	var hacia := j.global_position - punto_impacto()
	if hacia.length() <= distancia_embestir or _espera <= 0.0:
		_embestir()
		return
	movimiento.mover(hacia.normalized(), delta, velocidad_caminar)
	animador.reproducir(&"caminar")


func _embestir() -> void:
	estado = Estado.EMBESTIDA
	_fijado = false
	_deslizado = false
	_sacudido = false
	_velocidad_deslizar = Vector2.ZERO
	movimiento.detener()
	_mirar_a_leonidas()
	animador.reproducir(&"atacar", true)


func _seguir_embestida() -> void:
	var f := sprite.frame
	if _deslizado and f < frames_golpe.x:
		movimiento.impulsar(_velocidad_deslizar)
	else:
		movimiento.detener()
	if not _fijado:
		_mirar_a_leonidas()
		animador.reproducir(&"atacar") # sin reiniciar: solo actualiza el espejo


## Fotograma `frame_fijar`: fija el objetivo (limitado a lo que puede deslizarse) y enseña el aviso.
func _fijar_objetivo() -> void:
	_fijado = true
	var impacto := punto_impacto()
	var j := _leonidas()
	var destino := j.global_position if j else impacto
	_objetivo = impacto + (destino - impacto).limit_length(alcance_embestida)
	aviso.global_position = _objetivo
	aviso.visible = true


## Fotograma `frame_deslizar`: velocidad constante para recorrer lo que falta hasta el primer
## fotograma de golpe (el `move_and_slide` del Movimiento respeta las paredes).
func _empezar_deslizamiento() -> void:
	var fps := sprite.sprite_frames.get_animation_speed(&"atacar") * absf(sprite.speed_scale)
	var tiempo := maxf(float(frames_golpe.x - frame_deslizar) / maxf(fps, 1.0), 0.01)
	_velocidad_deslizar = (_objetivo - punto_impacto()) / tiempo


## Con comparaciones >= por si se salta algún fotograma (un tirón): cada paso ocurre una vez.
func _al_cambiar_frame(frame: int) -> void:
	if estado not in [Estado.EMBESTIDA, Estado.CLAVADA, Estado.RECUPERA] or sprite.animation != &"atacar":
		return
	if not _fijado and frame >= frame_fijar:
		_fijar_objetivo()
	if not _deslizado and frame >= frame_deslizar and frame < frames_golpe.x:
		_deslizado = true
		if sonido_embestida:
			sonido_embestida.play()
		# Sin contacto mientras se desliza y golpea: si no, su daño (2) llegaría antes y la
		# invulnerabilidad de Leonidas taparía el del espadazo (4). Vuelve en CLAVADA.
		contacto.activo = false
		_empezar_deslizamiento()
	var golpeando := frame >= frames_golpe.x and frame <= frames_golpe.y
	if golpeando != golpe.activo:
		golpe.activo = golpeando
	if golpeando:
		movimiento.detener()
	if not _sacudido and frame >= frame_sacudida:
		_sacudido = true
		golpe_suelo.emit(punto_impacto())
		if sacudir_camara:
			var game := Game.actual(self)
			if game:
				game.camara.sacudir()
	if frame > frames_golpe.y:
		aviso.visible = false
		if estado == Estado.EMBESTIDA:
			contacto.activo = true
		estado = Estado.CLAVADA if frame <= frame_fin_clavada else Estado.RECUPERA


func _al_terminar_animacion(anim: StringName) -> void:
	if anim != &"atacar" or estado not in [Estado.EMBESTIDA, Estado.CLAVADA, Estado.RECUPERA]:
		return
	golpe.activo = false
	aviso.visible = false
	contacto.activo = true
	_a_espera()


func _a_espera() -> void:
	estado = Estado.ESPERA
	_espera = pausa_embestidas * (factor_pausa_invulnerable if invulnerable else 1.0)
	animador.reproducir(&"parado", true)


func _impacto_local() -> Vector2:
	var lado := -1.0 if animador.direccion == Vector2.RIGHT else 1.0
	return Vector2(_impacto_base.x * lado, _impacto_base.y)


## Mira a un lado (el `atacar` solo tiene vista lateral; `parado`/`caminar` de frente se espejan).
func _mirar_a_leonidas() -> void:
	var j := _leonidas()
	if j == null:
		return
	var dx := j.global_position.x - global_position.x
	if absf(dx) > 2.0:
		animador.mirar(Vector2(signf(dx), 0))
		forma_golpe.position = _impacto_local()


func _leonidas() -> Node2D:
	return deteccion.objetivo if deteccion.viendo() else null


# --- Invocación -----------------------------------------------------------------------------

## Antes de acercarse o en la pausa: invocación pendiente (50 %) o trozo de estatua.
func _siguiente_accion() -> bool:
	if _invocacion_pendiente:
		_invocacion_pendiente = false
		_invocar()
		return true
	if _puede_lanzar() and _trozos_espera <= 0.0:
		_empezar_lanzar()
		return true
	return false


func _invocar() -> void:
	if sonido_invocar:
		sonido_invocar.play()
	estado = Estado.INVOCAR
	movimiento.detener()
	animador.reproducir(&"parado", true)
	invulnerable = true # durante el canto ya está protegida
	_matar_tweens()
	_tween_canto = create_tween()
	var medio := duracion_invocacion / 4.0
	for i in 2:
		_tween_canto.tween_property(sprite, ^"modulate", COLOR_CANTO, medio)
		_tween_canto.tween_property(sprite, ^"modulate", COLOR_INVULNERABLE, medio)
	_tween_canto.tween_callback(_terminar_invocacion)


func _terminar_invocacion() -> void:
	if estado != Estado.INVOCAR:
		return
	_crear_ciclopes()
	if _ciclopes.is_empty():
		invulnerable = false # sin escena o sin sitio: no se queda invulnerable para siempre
	_pintar()
	_a_espera()


func _crear_ciclopes() -> void:
	if escena_ciclope == null:
		push_warning("Medusa: falta `escena_ciclope`; no invoca.")
		return
	var padre := get_parent()
	for punto in _puntos_para_invocar():
		var c := escena_ciclope.instantiate() as CiclopeSerpiente
		c.position = (padre as Node2D).to_local(punto) if padre is Node2D else punto
		padre.add_child(c)
		c.aparecer() # contrato: tras add_child y ya colocado
		c.derrotado.connect(_al_morir_ciclope.bind(c))
		_ciclopes.append(c)


## Los `ciclopes_por_invocacion` puntos más alejados de Leonidas.
func _puntos_para_invocar() -> Array[Vector2]:
	var puntos: Array[Vector2] = []
	for m in puntos_invocacion:
		if m:
			puntos.append(m.global_position)
	if puntos.is_empty():
		for d in desplazamientos_invocacion:
			puntos.append(_posicion_inicial + d)
	var j := _leonidas()
	if j:
		var ref := j.global_position
		puntos.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(ref) > b.distance_squared_to(ref))
	return puntos.slice(0, ciclopes_por_invocacion)


func _al_morir_ciclope(c: CiclopeSerpiente) -> void:
	_ciclopes.erase(c)
	if _ciclopes.is_empty() and estado != Estado.INVOCAR:
		invulnerable = false


# --- Trozos de estatua ----------------------------------------------------------------------

func _puede_lanzar() -> bool:
	return _invocado_mitad and escena_trozo != null and (trozos_con_ciclopes or _ciclopes.is_empty())


func _contar_trozos(delta: float) -> void:
	if _puede_lanzar():
		_trozos_espera -= delta


func _empezar_lanzar() -> void:
	_estado_tras_lanzar = estado
	_espera_tras_lanzar = _espera # lo que le quedaba a la pausa o al acercamiento
	estado = Estado.LANZAR
	_espera = duracion_lanzar
	_lanzado = false
	_trozos_espera = intervalo_trozos
	movimiento.detener()
	animador.reproducir(&"parado")
	# "Levanta" el brazo: sin pose propia, un saltito del sprite (PROVISIONAL, falta arte).
	if _tween_lanzar:
		_tween_lanzar.kill()
	_tween_lanzar = create_tween()
	_tween_lanzar.tween_property(sprite, ^"position:y", -2.0, duracion_lanzar * 0.5)
	_tween_lanzar.tween_property(sprite, ^"position:y", 0.0, duracion_lanzar * 0.5)


func _lanzar_trozos() -> void:
	var j := _leonidas()
	if j == null:
		return
	if sonido_lanzar:
		sonido_lanzar.play()
	var n := 2 if vida.vida <= vida.vida_max * fraccion_dos_trozos else 1
	for i in n:
		var destino := j.global_position
		if i > 0:
			destino += Vector2.from_angle(randf() * TAU) * dispersion_segundo_trozo
		_lanzar_trozo(destino)


func _lanzar_trozo(destino: Vector2) -> void:
	var trozo := escena_trozo.instantiate() as TrozoEstatua
	var origen := global_position + Vector2(mano.position.x * (-1.0 if animador.direccion == Vector2.RIGHT else 1.0), 0)
	trozo.danio = danio_trozo
	trozo.altura_inicial = -mano.position.y
	# Al padre (el contenedor con orden por Y de la zona): vuela por su cuenta.
	var padre := get_parent()
	trozo.position = (padre as Node2D).to_local(origen) if padre is Node2D else origen
	padre.add_child(trozo)
	trozo.lanzar(destino)
	_trozos.append(trozo)
	trozo.tree_exited.connect(_al_salir_trozo.bind(trozo))


func _al_salir_trozo(trozo: Node2D) -> void:
	_trozos.erase(trozo)


func _liberar_trozos() -> void:
	for t in _trozos:
		if is_instance_valid(t):
			t.queue_free()
	_trozos.clear()


# --- Vida -----------------------------------------------------------------------------------

func _al_recibir_danio(_cantidad: int, _origen: Vector2) -> void:
	if not vida.muerto:
		parpadeo.parpadear(vida.tiempo_invulnerable())


func _al_cambiar_vida(actual: int, maximo: int) -> void:
	if estado == Estado.INACTIVA or estado == Estado.DERROTADA:
		return
	if not _invocado_mitad and actual > 0 and actual * 2 <= maximo:
		_invocado_mitad = true
		_invocacion_pendiente = true
		_trozos_espera = intervalo_trozos


func _al_ser_derrotada() -> void:
	quedarse_derrotada()
	derrotada.emit()


## Deja a Medusa en DERROTADA (quieta, sin golpes ni Hurtbox, sin cíclopes ni trozos) sin emitir
## `derrotada`. La usa `_al_ser_derrotada` y la escena del encuentro al cargar la sala con
## Medusa ya vencida. Se puede llamar más de una vez.
func quedarse_derrotada() -> void:
	_matar_tweens()
	estado = Estado.DERROTADA
	movimiento.detener()
	golpe.set_deferred(&"activo", false)
	contacto.set_deferred(&"activo", false)
	hurtbox.set_deferred(&"activo", false)
	aviso.visible = false
	for c in _ciclopes:
		if is_instance_valid(c):
			c.queue_free()
	_ciclopes.clear()
	_liberar_trozos()
	invulnerable = false
	parpadeo.detener()
	sprite.position = Vector2.ZERO
	_pintar()
	animador.reproducir(&"parado", true)


func _pintar() -> void:
	var c := COLOR_INVULNERABLE if invulnerable else Color.WHITE
	sprite.modulate = Color(c, sprite.modulate.a)


func _matar_tweens() -> void:
	for t in [_tween_canto, _tween_lanzar]:
		if t:
			(t as Tween).kill()
	_tween_canto = null
	_tween_lanzar = null
