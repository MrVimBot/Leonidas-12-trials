class_name BarreraMision
extends Area2D
## Cierra una salida del pueblo hasta que los sabios del templo den la misión
## (`EstadoJuego.mision_recibida`). Se pone por DENTRO de la puerta, antes de su
## SalidaZona: al pisarla, un destello y la voz de Zeus le dicen a Leonidas que aún no
## puede irse, y él retrocede unos pasos hacia el pueblo.
## Necesita un CollisionShape2D hijo que tape todo el hueco de la puerta.
## La primera vez sale `dialogo`; después (en cualquier barrera) `dialogo_repetido`.
## Textos PROVISIONALES: resources/dialogues/zeus_salida_*.tres.

@export var dialogo: Dialogo
@export var dialogo_repetido: Dialogo
## Hacia dónde retrocede Leonidas (hacia dentro del pueblo).
@export var direccion_retroceso := Vector2.DOWN
@export var distancia_retroceso := 24.0
## Destello blanco (el "rayo" de Zeus) antes de hablar.
@export var destello := true

var _en_curso := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # jugador
	monitorable = false
	body_entered.connect(_al_entrar)


func _al_entrar(cuerpo: Node2D) -> void:
	if _en_curso or EstadoJuego.mision_recibida or not cuerpo is Jugador:
		return
	_en_curso = true
	await _detener(cuerpo as Jugador)
	_en_curso = false


func _detener(jugador: Jugador) -> void:
	var dir := direccion_retroceso.normalized()
	Dialogos.mantener_bloqueo = true
	jugador.set_bloqueado(true)

	if destello:
		await _destellar()

	var d := dialogo if EstadoJuego.avisos_zeus == 0 or dialogo_repetido == null else dialogo_repetido
	EstadoJuego.avisos_zeus += 1
	await Dialogos.mostrar(d)

	# Leonidas da media vuelta y vuelve unos pasos hacia el pueblo.
	jugador.animador.mirar(dir)
	jugador.animador.reproducir(&"caminar")
	var t := create_tween()
	t.tween_property(jugador, ^"global_position", jugador.global_position + dir * distancia_retroceso,
		distancia_retroceso / 80.0)
	await t.finished
	jugador.animador.reproducir(&"parado")
	Dialogos.desbloquear_jugador()


func _destellar() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 50
	var rect := ColorRect.new()
	rect.color = Color(1, 1, 1, 0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(rect)
	add_child(capa)
	var t := create_tween()
	t.tween_property(rect, ^"color:a", 0.8, 0.08)
	t.tween_property(rect, ^"color:a", 0.0, 0.35)
	await t.finished
	capa.queue_free()
