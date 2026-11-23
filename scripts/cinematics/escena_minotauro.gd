class_name EscenaMinotauro
extends Node2D
## Combate con el Minotauro en el laberinto (nivel 3, PROVISIONAL; idea de la artista del
## 2026-11-22). Modelo: `EscenaMedusa` (bloqueo con motivo &"escena", diálogos seguidos,
## reinicio tras el Game Over).
##
## Hijos (posiciones relativas a la raíz, que la zona pone en la entrada de arriba):
##   Disparador     Area2D (máscara: jugador) en la boca de la entrada: al pisarla empieza el
##                  encuentro. La entrada `desde_isla` cae dentro (empieza al llegar) y también el
##                  punto de control (al reaparecer tras el Game Over vuelve a empezar).
##   PuntoLeonidas  Marker2D: hasta dónde baja Leonidas antes de hablar (en línea recta).
##   LuzLeonidas    LuzAntorcha que sigue a Leonidas con las luces apagadas.
## En el Inspector (nodos de la zona): `minotauro`, `rejas` (las dos salidas), `oscuridad`
## (CanvasModulate de la zona), `antorchas` (padre de las LuzAntorcha de los aros dorados) y
## `punto_salida` (la salida de abajo, adonde mira la cámara).
##
## Flujo:
##   1. Pisar el Disparador → bloqueo, Leonidas baja a PuntoLeonidas, «¿por dónde salgo?», la
##      cámara enseña la salida de abajo, «por allí» y vuelve (solo la primera vez por visita).
##   2. Se apagan las luces (zona más oscura, antorchas casi apagadas, luz alrededor de Leonidas)
##      y caen las rejas de las dos salidas. La cámara va al centro: el Minotauro aparece y ruge;
##      sin cuerno se desvanece («es invisible»), con cuerno se queda. La cámara vuelve, barra de
##      vida (`Game.empezar_jefe`) y `minotauro.empezar_combate()`.
##   3. Minotauro a 0 (`derrotado`) → ENTREGA ATÓMICA (misión completada, `jefes_derrotados`,
##      `minotauro_derrotado`, corazón extra que cura del todo), vuelven las luces, se abren las
##      rejas y la escena se libera.
##   4. Game Over a mitad (`Jugador.reaparecio`): Minotauro `reiniciar()`, luces y rejas como
##      al principio y, si reaparece dentro del Disparador, vuelve a empezar (sin el paso 1).
## Con `EstadoJuego.minotauro_derrotado` al cargar la zona: sin Minotauro, luz normal, rejas
## abiertas y la escena se libera.
## Textos PROVISIONALES (resources/dialogues/minotauro_*.tres).

@export var minotauro: Minotauro
@export var rejas: Array[Reja] = []
@export var oscuridad: CanvasModulate
@export var antorchas: Node2D
@export var punto_salida: Marker2D
## Nombre en la barra de vida.
@export var nombre_jefe := "Minotauro"

@export_group("Diálogos")
@export var dialogo_salida: Dialogo
@export var dialogo_por_alli: Dialogo
@export var dialogo_aparece: Dialogo
## Sin cuerno: el Minotauro se ha vuelto invisible.
@export var dialogo_invisible: Dialogo
## Con el cuerno (al repetir el combate después de conseguirlo).
@export var dialogo_con_cuerno: Dialogo
@export var dialogo_derrota: Dialogo
## Aviso del corazón extra (Jugabilidad p. 12).
@export var texto_corazon := "¡Ganaste un corazón! Tu vida máxima aumenta."

@export_group("Luz")
## Color de la zona con las luces encendidas (penumbra) y apagadas.
@export var color_penumbra := Color(0.55, 0.55, 0.62)
@export var color_oscuro := Color(0.13, 0.13, 0.19)
## Intensidad (0–1) que les queda a las antorchas con las luces apagadas (brasas).
@export_range(0.0, 1.0) var antorchas_apagadas := 0.2
@export var duracion_apagar := 1.2

@export_group("Movimiento")
## Píxeles por segundo al caminar Leonidas hasta su sitio.
@export var velocidad := 60.0
## Segundos que tarda la cámara en ir a la salida o al Minotauro.
@export var duracion_camara := 1.4

enum Fase { ESPERANDO, ENCUENTRO, COMBATE, DERROTA }

var fase := Fase.ESPERANDO
## Ya se enseñó la salida en esta visita (al repetir tras el Game Over no se vuelve a enseñar).
var _salida_vista := false
## Jugador al que esta escena tiene bloqueado (motivo &"escena"); null si no.
var _bloqueado: Jugador = null
## Jugador cuyo `reaparecio` se escucha y al que sigue `LuzLeonidas`.
var _jugador: Jugador = null

@onready var disparador: Area2D = $Disparador
@onready var forma_disparador: CollisionShape2D = $Disparador/Forma
@onready var punto_leonidas: Marker2D = $PuntoLeonidas
@onready var luz_leonidas: LuzAntorcha = $LuzLeonidas


func _ready() -> void:
	_encender_luces(0.0)
	for r in rejas:
		if r:
			r.abrir(false)
	if minotauro == null:
		# P. ej. el verificador de zonas quita los CharacterBody2D antes de añadir la zona.
		push_warning("EscenaMinotauro: falta `minotauro`; no hay combate.")
		disparador.monitoring = false
		return
	if not minotauro.is_node_ready():
		await minotauro.ready
	if EstadoJuego.minotauro_derrotado:
		minotauro.queue_free()
		queue_free()
		return
	minotauro.derrotado.connect(_al_derrotar)
	disparador.body_entered.connect(_al_entrar)


func _exit_tree() -> void:
	# Liberada a mitad (cambio de zona o fin): soltar su motivo si el jugador sigue vivo.
	if is_instance_valid(_bloqueado):
		_bloqueado.desbloquear(&"escena")
		_bloqueado = null


func _physics_process(_delta: float) -> void:
	if is_instance_valid(_jugador):
		luz_leonidas.global_position = _jugador.global_position + Vector2(0, -12)


func _al_entrar(cuerpo: Node2D) -> void:
	if fase != Fase.ESPERANDO or not cuerpo is Jugador or not is_instance_valid(minotauro):
		return
	fase = Fase.ENCUENTRO
	_encuentro(cuerpo as Jugador)


# --- 1 y 2. Encuentro -----------------------------------------------------------------------

func _encuentro(jugador: Jugador) -> void:
	_escuchar(jugador)
	_bloquear(jugador)
	await jugador.caminar_hasta(punto_leonidas.global_position, velocidad)
	jugador.mirar_hacia(Vector2.DOWN)
	var camara := _camara()
	await get_tree().create_timer(0.3, false).timeout

	if not _salida_vista:
		_salida_vista = true
		await Dialogos.mostrar(dialogo_salida)
		if camara and punto_salida:
			await camara.enfocar(punto_salida.global_position, duracion_camara)
			await get_tree().create_timer(0.6, false).timeout
		await Dialogos.mostrar(dialogo_por_alli)
		if camara:
			await camara.soltar_foco(duracion_camara)

	# Se apagan las luces y caen las rejas.
	_apagar_luces(duracion_apagar)
	for r in rejas:
		if r:
			r.cerrar()
	await get_tree().create_timer(duracion_apagar, false).timeout

	# El Minotauro aparece en el centro.
	if camara:
		# Mira un poco por debajo de sus pies: así queda en la mitad de arriba de la pantalla y la
		# caja de diálogo (abajo) no lo tapa.
		await camara.enfocar(minotauro.global_position + Vector2(0, 20), duracion_camara)
	await minotauro.aparecer()
	if camara:
		camara.sacudir(3.0, 0.5)
	await Dialogos.mostrar(dialogo_aparece)
	if Minotauro.tiene_cuerno():
		await Dialogos.mostrar(dialogo_con_cuerno)
		await minotauro.desaparecer()
	else:
		await minotauro.desaparecer()
		await Dialogos.mostrar(dialogo_invisible)
	if camara:
		await camara.soltar_foco(duracion_camara)

	_desbloquear(jugador)
	fase = Fase.COMBATE
	var game := Game.actual(self)
	if game:
		game.empezar_jefe(minotauro, nombre_jefe)
	minotauro.empezar_combate()


# --- 3. Derrota -----------------------------------------------------------------------------

func _al_derrotar() -> void:
	if fase != Fase.COMBATE:
		return
	fase = Fase.DERROTA
	_derrota()


func _derrota() -> void:
	var game := Game.actual(self)
	if game:
		game.terminar_jefe()
	_entregar()
	var jugador := _jugador if is_instance_valid(_jugador) else Jugador.actual(self)
	if jugador == null:
		return
	_bloquear(jugador)
	await get_tree().create_timer(1.0, false).timeout
	_encender_luces(duracion_apagar)
	for r in rejas:
		if r:
			r.abrir()
	await get_tree().create_timer(0.6, false).timeout
	await Dialogos.mostrar(dialogo_derrota)
	await Dialogos.mostrar_texto(texto_corazon)
	_desbloquear(jugador)
	_jugador = null
	queue_free()


## Todo de golpe, antes de devolver el control: si se guarda después, al cargar el laberinto ya
## está resuelto.
func _entregar() -> void:
	if EstadoJuego.minotauro_derrotado:
		return
	EstadoJuego.completar_mision(EstadoJuego.MISION_DERROTAR_MINOTAURO)
	EstadoJuego.jefes_derrotados += 1
	EstadoJuego.minotauro_derrotado = true
	EstadoJuego.corazones_extra += 1
	var game := Game.actual(self)
	if game:
		game.aplicar_corazones_extra(true) # sube la vida máxima y cura del todo


# --- 4. Game Over a mitad del combate -------------------------------------------------------

## `Jugador.reaparecio` (Continuar del Game Over): el combate vuelve a empezar desde cero.
func _al_reaparecer() -> void:
	if fase != Fase.COMBATE and fase != Fase.ENCUENTRO:
		return
	fase = Fase.ESPERANDO
	var game := Game.actual(self)
	if game:
		game.terminar_jefe()
	if is_instance_valid(minotauro):
		minotauro.reiniciar()
	for r in rejas:
		if r:
			r.abrir(false)
	_encender_luces(0.0)
	# Si reaparece dentro del Disparador no habrá `body_entered` (ver EscenaMedusa).
	_empezar_si_dentro.call_deferred()


func _empezar_si_dentro() -> void:
	if is_instance_valid(_jugador) and _dentro(_jugador.global_position):
		_al_entrar(_jugador)


## ¿`punto` (global) cae dentro de la forma del Disparador?
func _dentro(punto: Vector2) -> bool:
	return forma_disparador.shape.get_rect().has_point(forma_disparador.global_transform.affine_inverse() * punto)


# --- Luz ------------------------------------------------------------------------------------

func _apagar_luces(duracion: float) -> void:
	_luz(color_oscuro, antorchas_apagadas, 1.0, duracion)


func _encender_luces(duracion: float) -> void:
	_luz(color_penumbra, 1.0, 0.0, duracion)


func _luz(color: Color, intensidad_antorchas: float, intensidad_leonidas: float, duracion: float) -> void:
	if oscuridad:
		if duracion > 0.0:
			# El tween va en la oscuridad, no en la escena: la escena se libera nada más
			# encender la luz tras la derrota y su tween se cortaría a medias.
			oscuridad.create_tween().tween_property(oscuridad, ^"color", color, duracion)
		else:
			oscuridad.color = color
	if antorchas:
		for a in antorchas.get_children():
			if a is LuzAntorcha:
				(a as LuzAntorcha).fijar_intensidad(intensidad_antorchas, duracion)
	luz_leonidas.fijar_intensidad(intensidad_leonidas, duracion)


# --- Ayudantes ------------------------------------------------------------------------------

func _camara() -> CamaraPixel:
	var game := Game.actual(self)
	return game.camara if game else null


func _escuchar(jugador: Jugador) -> void:
	if _jugador == jugador:
		return
	if is_instance_valid(_jugador) and _jugador.reaparecio.is_connected(_al_reaparecer):
		_jugador.reaparecio.disconnect(_al_reaparecer)
	_jugador = jugador
	jugador.reaparecio.connect(_al_reaparecer)


func _bloquear(jugador: Jugador) -> void:
	_bloqueado = jugador
	jugador.bloquear(&"escena")


func _desbloquear(jugador: Jugador) -> void:
	jugador.desbloquear(&"escena")
	_bloqueado = null
