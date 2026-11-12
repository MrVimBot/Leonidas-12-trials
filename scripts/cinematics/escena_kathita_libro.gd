class_name EscenaKathitaLibro
extends Node2D
## Escena jugable del pueblo: cuando Leonidas se aleja unos pasos de su casa, Kathita
## lo llama, sale por la puerta y le regala el libro (inventario + mapa + guardar partida).
## Después le enseña la voltereta y, cuando la hace, se despide y vuelve a casa.
## Plan: docs/design/plan_entrega_libro_kathita.md.
##
## Hijos:
##   Puerta      Marker2D: de dónde sale y adónde vuelve Kathita (sus pies).
##   Disparador  Area2D (máscara: jugador): al cruzarlo empieza la escena.
##   Kathita     Node2D (oculto) con Sombra y Sprite (cinematica_mama.tres, vista lateral).
## No hace nada si ya se tiene el libro (`EstadoJuego.tiene_libro`): se libera sola.
## Los textos son PROVISIONALES (resources/dialogues/kathita_*.tres, los edita el guion).
## Los diálogos van bajo `Dialogos.mantener_bloqueo` para que el jugador no se mueva
## entre uno y otro; solo se le devuelve el control para probar la voltereta.

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

@onready var puerta: Marker2D = $Puerta
@onready var disparador: Area2D = $Disparador
@onready var kathita: Node2D = $Kathita
@onready var sprite: AnimatedSprite2D = $Kathita/Sprite


func _ready() -> void:
	if EstadoJuego.tiene_libro:
		queue_free()
		return
	kathita.visible = false
	kathita.modulate.a = 0.0
	disparador.body_entered.connect(_al_entrar)


func _al_entrar(cuerpo: Node2D) -> void:
	if _en_curso or EstadoJuego.tiene_libro or not cuerpo is Jugador:
		return
	_en_curso = true
	_reproducir(cuerpo as Jugador)


func _reproducir(jugador: Jugador) -> void:
	disparador.set_deferred(&"monitoring", false)
	Dialogos.mantener_bloqueo = true
	jugador.animador.mirar(puerta.global_position - jugador.global_position)
	jugador.set_bloqueado(true)

	await Dialogos.mostrar(dialogo_llamada)

	# Kathita sale de casa y va hacia Leonidas. Se pasa al nodo que ordena por Y
	# (Objetos) para que se dibuje delante o detrás de Leonidas y de la casa según su Y.
	var contenedor := get_parent()
	while contenedor and not contenedor.y_sort_enabled:
		contenedor = contenedor.get_parent()
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
	jugador.animador.mirar(kathita.global_position - jugador.global_position)
	jugador.set_bloqueado(true) # repinta a Leonidas mirando a su madre
	await get_tree().create_timer(0.3).timeout

	# El libro.
	await Dialogos.mostrar(dialogo_libro)
	sprite.play(&"dar_regalo")
	await sprite.animation_finished
	sprite.play(&"parada")
	EstadoJuego.tiene_libro = true # ya es suyo aunque luego se interrumpa la escena
	await Dialogos.mostrar_texto(texto_obtenido)

	# La voltereta.
	await Dialogos.mostrar(dialogo_voltereta)
	await get_tree().process_frame # que la pulsación que cerró el cuadro no cuente
	Dialogos.desbloquear_jugador()
	await jugador.pirueta_empezada
	await get_tree().create_timer(0.8).timeout # que termine la voltereta
	await Dialogos.mostrar(dialogo_despedida)

	# Vuelve a casa.
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
