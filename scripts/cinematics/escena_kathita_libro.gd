class_name EscenaKathitaLibro
extends Node2D
## Escena jugable del pueblo: cuando Leonidas se aleja unos pasos de su casa, Kathita
## lo llama, sale por la puerta y le regala el libro (inventario + mapa + guardar partida).
## Después le enseña la voltereta y, cuando la hace, se despide y vuelve a casa.
## Plan: docs/design/plan_entrega_libro_kathita.md.
##
## Hijos:
##   Puerta      Marker2D: de dónde sale y adónde vuelve Kathita (sus pies).
##   Disparador*  Area2D (máscara: jugador), uno por cada lado por el que Leonidas puede
##               alejarse de casa (Disparador al este, DisparadorOeste al oeste): al cruzar
##               cualquiera empieza la escena.
##   Kathita     Node2D (oculto) con Sombra y Sprite (cinematica_mama.tres, vista lateral).
## Se libera sola si ya se hizo la primera voltereta (`EstadoJuego.voltereta_aprendida`).
## Si hay libro pero aún no voltereta (se guardó la partida en mitad del tutorial), no repite
## la entrega ni saca a Kathita: solo espera la primera voltereta, pone la bandera (abre las
## barreras del cartel) y se libera. Si no, esas barreras quedarían cerradas para siempre.
## Los textos son PROVISIONALES (resources/dialogues/kathita_*.tres, los edita el guion).
## La escena bloquea al jugador con su propio motivo (&"escena") para que no se mueva
## entre un diálogo y otro; solo se le devuelve el control para probar la voltereta.
## Regla de las escenas guiadas: todo lo que se guarda se concede antes de devolver el
## control; lo que queda después debe poder reanudarse (`_reanudar_tutorial`) o no ser
## necesario. Si la escena se libera a mitad, `_exit_tree` suelta el bloqueo y a Kathita.

@export_group("Diálogos")
@export var dialogo_llamada: Dialogo
@export var dialogo_libro: Dialogo
## Aviso de objeto obtenido (sin nombre de quien habla).
@export var texto_obtenido := "¡Obtuviste el libro de Leonidas! Pulsa [I] para abrirlo."
@export var dialogo_voltereta: Dialogo
@export var dialogo_despedida: Dialogo

@export_group("Movimiento")
## Píxeles por segundo de Kathita.
@export var velocidad := 60.0
## A qué distancia de Leonidas se detiene Kathita.
@export var distancia_al_jugador := 20.0

var _en_curso := false
## Jugador al que esta escena tiene bloqueado (de la entrega al tutorial); null si no.
var _bloqueado: Jugador = null

@onready var puerta: Marker2D = $Puerta
@onready var kathita: Node2D = $Kathita
@onready var sprite: AnimatedSprite2D = $Kathita/Sprite


func _ready() -> void:
	if EstadoJuego.voltereta_aprendida:
		queue_free()
		return
	if EstadoJuego.tiene_libro:
		_reanudar_tutorial()
		return
	kathita.visible = false
	kathita.modulate.a = 0.0
	for h in get_children():
		var disparador := h as Area2D
		if disparador:
			disparador.body_entered.connect(_al_entrar)


func _exit_tree() -> void:
	# Liberada a mitad de la escena (p. ej. cambio de zona): soltar su motivo si el
	# jugador sigue vivo (al salir al menú se libera con todo Game).
	if is_instance_valid(_bloqueado):
		_bloqueado.desbloquear(&"escena")
	# Kathita se pasó (reparent) al nodo con orden por Y: si la escena muere antes de
	# devolverla, quedaría huérfana allí. Si sigue siendo hija nuestra, cae con nosotros.
	if is_instance_valid(kathita) and kathita.get_parent() != self:
		kathita.queue_free()


func _al_entrar(cuerpo: Node2D) -> void:
	if _en_curso or EstadoJuego.tiene_libro or not cuerpo is Jugador:
		return
	_en_curso = true
	_reproducir(cuerpo as Jugador)


## Partida cargada a mitad del tutorial: ya tiene el libro, solo falta la voltereta.
## Sin disparadores, sin Kathita y sin diálogos.
func _reanudar_tutorial() -> void:
	# La zona se instancia dentro de Game: el Jugador puede no estar listo aún en _ready.
	await get_tree().process_frame
	var jugador := Jugador.actual(self)
	if jugador == null:
		push_warning("EscenaKathitaLibro: no hay Jugador; no se puede reanudar el tutorial.")
		EstadoJuego.voltereta_aprendida = true # mejor abrir el paso que cerrarlo para siempre
		queue_free()
		return
	await jugador.pirueta_empezada
	EstadoJuego.voltereta_aprendida = true # abre la barrera del cartel
	queue_free()


func _reproducir(jugador: Jugador) -> void:
	await _entregar_libro(jugador)
	await _tutorial_voltereta(jugador)
	await _despedir_y_volver()


## Kathita sale de casa, habla con Leonidas y le da el libro. Al terminar ya hay libro.
func _entregar_libro(jugador: Jugador) -> void:
	for h in get_children():
		if h is Area2D:
			h.set_deferred(&"monitoring", false)
	_bloqueado = jugador
	jugador.bloquear(&"escena")
	jugador.mirar_hacia(puerta.global_position - jugador.global_position)

	await Dialogos.mostrar(dialogo_llamada)

	# Kathita sale de casa y va hacia Leonidas. Se pasa al nodo que ordena por Y
	# (Objetos) para que se dibuje delante o detrás de Leonidas y de la casa según su Y.
	var contenedor := get_parent() as CanvasItem
	while contenedor and not contenedor.y_sort_enabled:
		contenedor = contenedor.get_parent() as CanvasItem
	if contenedor:
		kathita.reparent(contenedor)
	kathita.global_position = puerta.global_position
	sprite.play(&"caminar_regalo")
	kathita.visible = true
	await _fundir(1.0)
	var desde := puerta.global_position
	var hacia := jugador.global_position
	var destino := hacia + (desde - hacia).normalized() * distancia_al_jugador
	await _mover(destino)
	sprite.play(&"parada_regalo")
	jugador.mirar_hacia(kathita.global_position - jugador.global_position)
	await get_tree().create_timer(0.3, false).timeout

	# El libro.
	await Dialogos.mostrar(dialogo_libro)
	sprite.play(&"dar_regalo")
	await sprite.animation_finished
	sprite.play(&"parada")
	EstadoJuego.tiene_libro = true # ya es suyo aunque luego se interrumpa la escena
	await Dialogos.mostrar_texto(texto_obtenido)


## Kathita enseña la voltereta; se devuelve el control y se espera la primera.
## Si se guarda aquí, `_reanudar_tutorial()` retoma solo la espera al cargar.
func _tutorial_voltereta(jugador: Jugador) -> void:
	await Dialogos.mostrar(dialogo_voltereta)
	# La pulsación que cerró el cuadro ya la consumió la caja: no hace falta esperar.
	jugador.desbloquear(&"escena")
	_bloqueado = null
	await jugador.pirueta_empezada
	EstadoJuego.voltereta_aprendida = true # abre la barrera del cartel
	await get_tree().create_timer(0.8, false).timeout # que termine la voltereta


## Despedida de Kathita, vuelve a casa y la escena se libera.
func _despedir_y_volver() -> void:
	await Dialogos.mostrar(dialogo_despedida)
	sprite.play(&"caminar")
	await _mover(puerta.global_position)
	await _fundir(0.0)
	kathita.queue_free() # puede haberse pasado a otro nodo (ver arriba)
	queue_free()


## Camina en línea recta; el sprite mira a la izquierda, así que se espeja al ir a la derecha.
func _mover(destino: Vector2) -> void:
	var dx := destino.x - kathita.global_position.x
	if absf(dx) > 1.0:
		sprite.flip_h = dx > 0.0
	var t := create_tween()
	t.tween_property(kathita, ^"global_position", destino, kathita.global_position.distance_to(destino) / velocidad)
	await t.finished


func _fundir(alfa: float) -> void:
	var t := create_tween()
	t.tween_property(kathita, ^"modulate:a", alfa, 0.3)
	await t.finished
