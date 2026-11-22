class_name EscenaSabios
extends Node2D
## Escena jugable del pueblo: los sabios, delante del templo, dan a Leonidas la misión
## (derrotar a Medusa) y la espada; después le enseñan a atacar (segunda etapa del
## tutorial) y lo despiden. Plan: docs/design/plan_escena_sabios.md.
##
## Hijos:
##   Disparador     Area2D (máscara: jugador) en la explanada delante de los sabios: al
##                  pisarla empieza la escena. En el pueblo cubre solo el pasillo entre los
##                  dos canales (x 868–972, y 654–700): desde cualquier punto de dentro se
##                  llega a PuntoLeonidas en línea recta sin cruzar el agua. Durante el
##                  tutorial de ataque es también el perímetro: salir de él antes del
##                  primer espadazo hace volver a Leonidas (`dialogo_no_te_vayas`).
##   PuntoLeonidas  Marker2D: dónde se coloca Leonidas (sus pies), mirando a los sabios.
## Los sabios son NPC normales (scenes/npcs/npc.tscn, `paseo = false`) colocados en el
## nodo con y_sort de la zona (Objetos/NPCs) y asignados en `sabios`; así la escena se
## puede mover a otra zona (un templo con interior) sin tocar el script.
## Antes de la escena no tienen diálogo (ni burbuja). Al acabar, o si al cargar la zona
## ya se tiene la misión (`EstadoJuego.mision_recibida`), todos dicen `dialogo_recordatorio`.
##
## SEGUNDA FASE (regreso): con Medusa vencida (`EstadoJuego.medusa_derrotada`) y sin la
## misión del Minotauro, los sabios llevan la burbuja «!» y `dialogo_regreso`. Al terminar
## de hablar con cualquiera de ellos, Leonidas va a `PuntoLeonidas`, enseña la cabeza de
## piedra (pose de objeto obtenido; la conserva) y le dan la misión del Minotauro
## (`dialogo_minotauro`). Después dicen `recordatorios_minotauro`. Al cargar con esa misión
## ya recibida, empiezan así y la escena se libera.
## Textos PROVISIONALES (resources/dialogues/sabios_*.tres, los edita el guion).
## Regla de las escenas guiadas: todo lo que se guarda se concede antes de devolver el
## control (aquí, espada, misiones y `mision_recibida` de golpe, antes del tutorial de
## ataque); lo que queda después debe poder reanudarse o no ser necesario (al cargar con
## la misión, los sabios ya empiezan en su modo de recordatorio).

@export var sabios: Array[NPC] = []
## Índice en `sabios` del que da unos pasos al frente y entrega la espada.
@export var sabio_que_entrega := 0

@export_group("Diálogos")
@export var dialogo_bienvenida: Dialogo
@export var dialogo_mision: Dialogo
@export var dialogo_espada: Dialogo
## Aviso de objeto obtenido (sin nombre de quien habla).
@export var texto_obtenido := "¡Obtuviste la espada! Pulsa {atacar} para atacar."
@export var dialogo_ataque: Dialogo
## Si Leonidas sale del Disparador antes de su primer espadazo: se le devuelve a su sitio.
@export var dialogo_no_te_vayas: Dialogo
@export var dialogo_despedida: Dialogo
## Lo que dice cada sabio cuando ya han dado la misión (mismo orden que `sabios`).
## Si falta el de alguno, usa `dialogo_recordatorio`.
@export var recordatorios: Array[Dialogo] = []
@export var dialogo_recordatorio: Dialogo

@export_group("Regreso")
## Lo que dice cualquier sabio al volver Leonidas con Medusa vencida; al cerrarlo sigue
## la escena (la cabeza y la misión del Minotauro).
@export var dialogo_regreso: Dialogo
## Aviso mientras Leonidas levanta la cabeza de piedra (sin nombre de quien habla).
@export var texto_ensenar_cabeza := "Leonidas enseña la cabeza petrificada de Medusa."
@export var dialogo_minotauro: Dialogo
## Recordatorios con la misión del Minotauro (mismo orden que `sabios`).
@export var recordatorios_minotauro: Array[Dialogo] = []

@export_group("Movimiento")
## Píxeles por segundo al caminar (Leonidas hasta su sitio y el sabio).
@export var velocidad := 60.0
## Cuánto se adelanta el sabio para entregar la espada.
@export var pasos_sabio := 10.0
## Segundos que se espera tras el primer espadazo antes de la despedida.
@export var espera_tras_ataque := 0.6

var _en_curso := false
## Tutorial de ataque: Leonidas se mueve libre pero no puede salir del Disparador.
var _esperando_ataque := false
var _devolviendo := false
## Jugador al que esta escena tiene bloqueado (motivo &"escena"); null si no.
var _bloqueado: Jugador = null

@onready var disparador: Area2D = $Disparador
@onready var punto_leonidas: Marker2D = $PuntoLeonidas


func _ready() -> void:
	if EstadoJuego.mision_empezada(EstadoJuego.MISION_DERROTAR_MINOTAURO):
		_modo_despues(recordatorios_minotauro)
		queue_free()
		return
	if EstadoJuego.mision_recibida:
		if EstadoJuego.medusa_derrotada:
			_modo_regreso()
			return
		_modo_despues(recordatorios)
		queue_free()
		return
	disparador.body_entered.connect(_al_entrar)
	disparador.body_exited.connect(_al_salir)


func _exit_tree() -> void:
	# Liberada a mitad de la escena (p. ej. cambio de zona): soltar su motivo si el
	# jugador sigue vivo (al salir al menú se libera con todo Game).
	if is_instance_valid(_bloqueado):
		_bloqueado.desbloquear(&"escena")


func _al_entrar(cuerpo: Node2D) -> void:
	if _en_curso or EstadoJuego.mision_recibida or not cuerpo is Jugador:
		return
	_en_curso = true
	_reproducir(cuerpo as Jugador)


func _reproducir(jugador: Jugador) -> void:
	# El Disparador sigue vigilando: en el tutorial de ataque hace de perímetro.
	_bloquear(jugador)

	# Leonidas se coloca delante de los sabios.
	await jugador.caminar_hasta(punto_leonidas.global_position, velocidad)
	_mirar_a_los_sabios(jugador)
	await get_tree().create_timer(0.3, false).timeout

	await Dialogos.mostrar(dialogo_bienvenida)
	await Dialogos.mostrar(dialogo_mision)

	# Un sabio da unos pasos al frente con la espada.
	var sabio := _sabio_que_entrega()
	var sitio := sabio.global_position if sabio else Vector2.ZERO
	if sabio:
		await sabio.caminar_hasta(sitio + Vector2(0, pasos_sabio), velocidad)
	await Dialogos.mostrar(dialogo_espada)

	# Todo de golpe, antes de devolver el control: si se guarda a mitad (en el tutorial
	# de ataque ya se puede abrir el libro), al cargar los sabios ya habrán pasado.
	EstadoJuego.tiene_espada = true
	EstadoJuego.completar_mision(EstadoJuego.MISION_IR_AL_TEMPLO)
	EstadoJuego.empezar_mision(EstadoJuego.MISION_DERROTAR_MEDUSA)
	EstadoJuego.mision_recibida = true # abre las puertas del pueblo (Zeus)

	# Leonidas levanta la espada.
	var espada := EstadoJuego.objeto(EstadoJuego.OBJ_ESPADA)
	var icono: Texture2D = espada.icono if espada else null
	# El diálogo no repinta la pose: el jugador ya está bloqueado por la escena.
	jugador.mostrar_objeto_obtenido(icono, 0.0)
	await get_tree().create_timer(0.5, false).timeout
	await Dialogos.mostrar_texto(texto_obtenido)
	jugador.ocultar_objeto_obtenido()
	_mirar_a_los_sabios(jugador)

	# Tutorial: no sigue hasta el primer espadazo.
	# J también cierra el cuadro, pero esa pulsación la consume la caja: no es el espadazo.
	await Dialogos.mostrar(dialogo_ataque)
	_desbloquear(jugador)
	_esperando_ataque = true
	await jugador.ataque_empezado
	_esperando_ataque = false
	disparador.set_deferred(&"monitoring", false)
	await get_tree().create_timer(espera_tras_ataque, false).timeout
	await Dialogos.mostrar(dialogo_despedida)

	if sabio:
		await sabio.caminar_hasta(sitio, velocidad)
	_modo_despues(recordatorios)
	queue_free()


## Segunda fase: los sabios esperan la cabeza. El Disparador no se usa (empieza al hablar).
func _modo_regreso() -> void:
	# Partidas guardadas tras vencer a Medusa antes de que existiera esta misión.
	EstadoJuego.empezar_mision(EstadoJuego.MISION_REGRESAR_CON_SABIOS)
	disparador.monitoring = false
	for sabio in sabios:
		if sabio:
			sabio.dialogo = dialogo_regreso
			sabio.burbuja = ZonaDialogo.Tipo.MISION
			(sabio.get_node(^"%ZonaDialogo") as ZonaDialogo).hablado.connect(_al_hablar_regreso)


## `hablado` llega dentro del cierre del diálogo, antes de que la caja suelte su motivo:
## el bloqueo de la escena entra sin que el jugador pase por NORMAL.
func _al_hablar_regreso() -> void:
	var jugador := Jugador.actual(self)
	if _en_curso or jugador == null:
		return
	_en_curso = true
	_reproducir_regreso(jugador)


func _reproducir_regreso(jugador: Jugador) -> void:
	_bloquear(jugador)
	await jugador.caminar_hasta(punto_leonidas.global_position, velocidad)
	_mirar_a_los_sabios(jugador)

	# Leonidas levanta la cabeza de piedra (se la queda). El diálogo no repinta la pose.
	var cabeza := EstadoJuego.objeto(EstadoJuego.OBJ_CABEZA_PIEDRA)
	jugador.mostrar_objeto_obtenido(cabeza.icono if cabeza else null, 0.0)
	await get_tree().create_timer(0.5, false).timeout
	await Dialogos.mostrar_texto(texto_ensenar_cabeza)
	jugador.ocultar_objeto_obtenido()
	_mirar_a_los_sabios(jugador)

	await Dialogos.mostrar(dialogo_minotauro)
	# Entrega atómica, antes de devolver el control.
	EstadoJuego.completar_mision(EstadoJuego.MISION_DERROTAR_MEDUSA)
	EstadoJuego.completar_mision(EstadoJuego.MISION_REGRESAR_CON_SABIOS)
	EstadoJuego.empezar_mision(EstadoJuego.MISION_DERROTAR_MINOTAURO)
	SonidosUI.mision_nueva()

	_modo_despues(recordatorios_minotauro)
	_desbloquear(jugador)
	queue_free()


## Perímetro del tutorial de ataque (como las barreras de Kathita): si sale de la
## explanada sin haber atacado, un sabio lo llama y Leonidas vuelve a su sitio.
func _al_salir(cuerpo: Node2D) -> void:
	if not _esperando_ataque or _devolviendo or not cuerpo is Jugador:
		return
	_devolviendo = true
	var jugador := cuerpo as Jugador
	_bloquear(jugador)
	await Dialogos.mostrar(dialogo_no_te_vayas)
	await jugador.caminar_hasta(punto_leonidas.global_position, velocidad)
	_mirar_a_los_sabios(jugador)
	_desbloquear(jugador)
	_devolviendo = false


## Los sabios pasan a ser NPC normales que recuerdan la misión (`lista`, en el orden de
## `sabios`; si falta el de alguno, `dialogo_recordatorio`).
func _modo_despues(lista: Array[Dialogo]) -> void:
	for i in sabios.size():
		if sabios[i]:
			var d: Dialogo = lista[i] if i < lista.size() else null
			sabios[i].dialogo = d if d else dialogo_recordatorio
			sabios[i].burbuja = ZonaDialogo.Tipo.HABLAR


func _sabio_que_entrega() -> NPC:
	if sabio_que_entrega >= 0 and sabio_que_entrega < sabios.size():
		return sabios[sabio_que_entrega]
	return null


func _mirar_a_los_sabios(jugador: Jugador) -> void:
	jugador.mirar_hacia(Vector2.UP)


func _bloquear(jugador: Jugador) -> void:
	_bloqueado = jugador
	jugador.bloquear(&"escena")


func _desbloquear(jugador: Jugador) -> void:
	jugador.desbloquear(&"escena")
	_bloqueado = null
