class_name EscenaMedusa
extends Node2D
## Combate con Medusa en `cueva_jefe` (Guión pp. 26–28, 37–38; plan
## docs/plan/nivel2/06_medusa_jefe.md, M5–M6): encuentro, salida cerrada, barra de vida,
## derrota con súplica y trato, recompensa, y reinicio del combate tras el Game Over.
## Modelo: `EscenaSabios` (bloqueo con motivo &"escena", `caminar_hasta`, diálogos seguidos).
##
## Hijos (posiciones relativas a la raíz, que la zona pone en la boca del pasillo de entrada):
##   Disparador     Area2D (máscara: jugador) que cubre la sala por encima del pasillo. Al
##                  pisarla empieza el encuentro. Cubre toda la sala (no solo la entrada) para
##                  que también empiece al cargar una partida guardada dentro, o al reaparecer
##                  dentro tras un Game Over.
##   PuntoLeonidas  Marker2D: dónde se coloca Leonidas, mirando a Medusa. Debe poder llegarse en
##                  línea recta desde cualquier punto del Disparador (`caminar_hasta` atraviesa).
##                  Cerca de Medusa (38 px bajo ella en `cueva_jefe`): la cámara va centrada en
##                  Leonidas y, más lejos, la cabeza de Medusa (96 px de alto) queda fuera.
##   Cierre         StaticBody2D (capa mundo) que tapa el pasillo durante el combate. Su forma
##                  empieza desactivada (el verificador de zonas recorre la sala sin él) y su
##                  `Visual` (rocas PROVISIONALES) oculto.
## `medusa` (la jefa, en otro nodo de la zona con orden por Y) se asigna en el Inspector (en
## `cueva_jefe` lo hace `tools/build_zonas.gd`).
##
## Flujo:
##   1. Pisar el Disparador → bloqueo, Leonidas camina a PuntoLeonidas, se cierra la salida,
##      `dialogo_encuentro`, desbloqueo, barra de vida (`Game.empezar_jefe`) y
##      `medusa.empezar_combate()`.
##   2. Medusa a 0 (`Medusa.derrotada`) → bloqueo, se oculta la barra, `dialogo_suplica`,
##      `dialogo_trato` → ENTREGA ATÓMICA (cabeza de piedra, misión completada,
##      `jefes_derrotados`, `medusa_derrotada`, corazón extra que cura del todo) → pose con la
##      cabeza + `texto_obtenido` → `texto_corazon` → se abre la salida, Medusa se queda con
##      `dialogo_recordatorio` y la escena se libera.
##   3. Game Over a mitad (Continuar = `Jugador.reaparecio`, sin recargar la zona): Medusa
##      `reiniciar()`, sin barra, salida abierta y el Disparador vuelve a esperar.
## Con `EstadoJuego.medusa_derrotada` al cargar la zona: Medusa ya derrotada con su recordatorio,
## sin cierre ni barra, y la escena se libera.
## Textos PROVISIONALES (resources/dialogues/medusa_*.tres, los edita el guion).
## Regla de las escenas guiadas: lo que se guarda se concede de golpe antes de devolver el
## control (aquí, en la entrega).

@export var medusa: Medusa
## Nombre en la barra de vida.
@export var nombre_jefe := "Medusa"

@export_group("Diálogos")
@export var dialogo_encuentro: Dialogo
## Medusa vencida: maldita por los dioses, suplica; Leonidas se niega a matarla.
@export var dialogo_suplica: Dialogo
## Fingen su muerte: le da la réplica de piedra de su cabeza.
@export var dialogo_trato: Dialogo
## Lo que dice Medusa si se le vuelve a hablar después.
@export var dialogo_recordatorio: Dialogo
## Aviso de objeto obtenido (sin nombre de quien habla).
@export var texto_obtenido := "¡Obtuviste la cabeza de piedra de Medusa!"
## Aviso del corazón extra (Jugabilidad p. 12).
@export var texto_corazon := "¡Ganaste un corazón! Tu vida máxima aumenta."

@export_group("Movimiento")
## Píxeles por segundo al caminar Leonidas hasta su sitio.
@export var velocidad := 60.0

enum Fase { ESPERANDO, ENCUENTRO, COMBATE, DERROTA }

var fase := Fase.ESPERANDO
## Jugador al que esta escena tiene bloqueado (motivo &"escena"); null si no.
var _bloqueado: Jugador = null
## Jugador cuyo `reaparecio` se escucha (desde el primer encuentro).
var _jugador: Jugador = null

@onready var disparador: Area2D = $Disparador
@onready var forma_disparador: CollisionShape2D = $Disparador/Forma
@onready var punto_leonidas: Marker2D = $PuntoLeonidas
@onready var cierre: StaticBody2D = $Cierre
@onready var forma_cierre: CollisionShape2D = $Cierre/Forma
@onready var visual_cierre: CanvasItem = $Cierre/Visual


func _ready() -> void:
	_abrir_salida()
	if medusa == null:
		# P. ej. el verificador de zonas quita los CharacterBody2D antes de añadir la zona.
		push_warning("EscenaMedusa: falta `medusa`; no hay combate.")
		disparador.monitoring = false
		return
	if not medusa.is_node_ready():
		await medusa.ready # su `_ready` la reinicia: después se puede dejar derrotada
	if EstadoJuego.medusa_derrotada:
		_dejar_resuelta()
		queue_free()
		return
	medusa.derrotada.connect(_al_derrotar)
	disparador.body_entered.connect(_al_entrar)


func _exit_tree() -> void:
	# Liberada a mitad (cambio de zona o fin): soltar su motivo si el jugador sigue vivo.
	if is_instance_valid(_bloqueado):
		_bloqueado.desbloquear(&"escena")
		_bloqueado = null


func _al_entrar(cuerpo: Node2D) -> void:
	if fase != Fase.ESPERANDO or not cuerpo is Jugador or not is_instance_valid(medusa):
		return
	fase = Fase.ENCUENTRO
	_encuentro(cuerpo as Jugador)


# --- 1. Encuentro ---------------------------------------------------------------------------

func _encuentro(jugador: Jugador) -> void:
	_escuchar(jugador)
	_bloquear(jugador)
	await jugador.caminar_hasta(punto_leonidas.global_position, velocidad)
	_mirar_a_medusa(jugador)
	_cerrar_salida()
	await get_tree().create_timer(0.3, false).timeout
	await Dialogos.mostrar(dialogo_encuentro)
	_desbloquear(jugador)
	fase = Fase.COMBATE
	var game := Game.actual(self)
	if game:
		game.empezar_jefe(medusa, nombre_jefe)
	medusa.empezar_combate()


# --- 2. Derrota y recompensa ----------------------------------------------------------------

func _al_derrotar() -> void:
	if fase != Fase.COMBATE:
		return
	fase = Fase.DERROTA
	_derrota()


func _derrota() -> void:
	var game := Game.actual(self)
	if game:
		game.terminar_jefe()
	var jugador := _jugador if is_instance_valid(_jugador) else Jugador.actual(self)
	if jugador == null:
		return
	_bloquear(jugador)
	await get_tree().create_timer(0.8, false).timeout
	_mirar_a_medusa(jugador)
	await Dialogos.mostrar(dialogo_suplica)
	await Dialogos.mostrar(dialogo_trato)

	_entregar()

	# Leonidas levanta la cabeza de piedra. El diálogo no repinta la pose: ya está bloqueado.
	var cabeza := EstadoJuego.objeto(EstadoJuego.OBJ_CABEZA_PIEDRA)
	jugador.mostrar_objeto_obtenido(cabeza.icono if cabeza else null, 0.0)
	await get_tree().create_timer(0.5, false).timeout
	await Dialogos.mostrar_texto(texto_obtenido)
	jugador.ocultar_objeto_obtenido()
	_mirar_a_medusa(jugador)
	await Dialogos.mostrar_texto(texto_corazon)

	_dejar_resuelta()
	_desbloquear(jugador)
	queue_free()


## Todo de golpe, antes de devolver el control: si se guarda después, al cargar la sala ya
## está resuelta.
func _entregar() -> void:
	if EstadoJuego.medusa_derrotada:
		return
	EstadoJuego.agregar_objeto(EstadoJuego.OBJ_CABEZA_PIEDRA)
	EstadoJuego.completar_mision(EstadoJuego.MISION_DERROTAR_MEDUSA)
	EstadoJuego.jefes_derrotados += 1
	EstadoJuego.medusa_derrotada = true
	EstadoJuego.corazones_extra += 1
	var game := Game.actual(self)
	if game:
		game.aplicar_corazones_extra(true) # sube la vida máxima y cura del todo


## Medusa se queda en la sala, vencida y con su recordatorio; la salida, abierta.
func _dejar_resuelta() -> void:
	_abrir_salida()
	disparador.set_deferred(&"monitoring", false)
	medusa.quedarse_derrotada()
	medusa.charla.dialogo = dialogo_recordatorio


# --- 3. Game Over a mitad del combate -------------------------------------------------------

## `Jugador.reaparecio` (Continuar del Game Over): el combate vuelve a empezar desde cero.
func _al_reaparecer() -> void:
	if fase != Fase.COMBATE and fase != Fase.ENCUENTRO:
		return
	fase = Fase.ESPERANDO
	var game := Game.actual(self)
	if game:
		game.terminar_jefe()
	medusa.reiniciar()
	_abrir_salida()
	# Si reaparece dentro de la sala (partida guardada aquí) no habrá `body_entered`. No vale
	# `get_overlapping_bodies()`: va con retraso y aún tiene al jugador de antes de morir (y con
	# el árbol en pausa del Game Over ni se actualiza); se mira su posición (sus pies).
	_empezar_si_dentro.call_deferred()


func _empezar_si_dentro() -> void:
	if is_instance_valid(_jugador) and _dentro(_jugador.global_position):
		_al_entrar(_jugador)


## ¿`punto` (global) cae dentro de la forma del Disparador?
func _dentro(punto: Vector2) -> bool:
	return forma_disparador.shape.get_rect().has_point(forma_disparador.global_transform.affine_inverse() * punto)


# --- Ayudantes ------------------------------------------------------------------------------

func _escuchar(jugador: Jugador) -> void:
	if _jugador == jugador:
		return
	if is_instance_valid(_jugador) and _jugador.reaparecio.is_connected(_al_reaparecer):
		_jugador.reaparecio.disconnect(_al_reaparecer)
	_jugador = jugador
	jugador.reaparecio.connect(_al_reaparecer)


func _cerrar_salida() -> void:
	forma_cierre.set_deferred(&"disabled", false)
	visual_cierre.visible = true


func _abrir_salida() -> void:
	forma_cierre.set_deferred(&"disabled", true)
	visual_cierre.visible = false


func _mirar_a_medusa(jugador: Jugador) -> void:
	if is_instance_valid(medusa):
		jugador.mirar_hacia(medusa.global_position - jugador.global_position)


func _bloquear(jugador: Jugador) -> void:
	_bloqueado = jugador
	jugador.bloquear(&"escena")


func _desbloquear(jugador: Jugador) -> void:
	jugador.desbloquear(&"escena")
	_bloqueado = null
