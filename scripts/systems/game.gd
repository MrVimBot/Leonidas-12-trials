class_name Game
extends Node2D
## Escena principal (game.tscn). Contiene lo que persiste entre zonas (jugador, cámara,
## y luego HUD y diálogos) y carga las zonas del mundo dentro de "Mundo".
##
##   Game (este script, y_sort_enabled)
##   ├─ Mundo (Node2D, y_sort)    aquí se instancia la zona actual
##   ├─ Jugador
##   ├─ Camara (CamaraPixel)      sigue al jugador; sus límites se ajustan a cada zona
##   └─ Transicion (CanvasLayer)  fundido a negro al cambiar de zona

signal zona_cambiada(zona: Zona)

@export_file("*.tscn") var zona_inicial := "res://scenes/levels/pueblo.tscn"
@export var entrada_inicial := "inicio"
@export var duracion_fundido := 0.25

var zona_actual: Zona = null
var _cambiando := false

@onready var mundo: Node2D = $Mundo
@onready var jugador: Jugador = $Jugador
@onready var camara: CamaraPixel = $Camara
@onready var fundido: ColorRect = $Transicion/Fundido


func _ready() -> void:
	add_to_group(&"game")
	fundido.color.a = 0.0
	jugador.reaparecio.connect(camara.saltar_a_objetivo)
	_cargar_zona(zona_inicial, entrada_inicial)


## Cambia de zona con fundido a negro. La llaman las SalidaZona.
func cambiar_zona(ruta: String, entrada: String = "inicio") -> void:
	if _cambiando:
		return
	_cambiando = true
	jugador.set_bloqueado(true)
	await _fundir(1.0)
	_cargar_zona(ruta, entrada)
	await _fundir(0.0)
	jugador.set_bloqueado(false)
	_cambiando = false


func _cargar_zona(ruta: String, entrada: String) -> void:
	var escena := load(ruta) as PackedScene
	if escena == null:
		push_error("Game: no se pudo cargar la zona %s" % ruta)
		return
	if zona_actual:
		mundo.remove_child(zona_actual)
		zona_actual.queue_free()
	zona_actual = escena.instantiate() as Zona
	mundo.add_child(zona_actual)

	jugador.global_position = zona_actual.punto_entrada(entrada)
	jugador.velocity = Vector2.ZERO
	jugador.punto_control = jugador.global_position # se reaparece al entrar a la zona

	_ajustar_camara()
	zona_cambiada.emit(zona_actual)


func _ajustar_camara() -> void:
	var r := zona_actual.obtener_limites()
	if r.has_area():
		camara.limit_left = r.position.x
		camara.limit_top = r.position.y
		camara.limit_right = r.end.x
		camara.limit_bottom = r.end.y
	# Coloca la cámara de golpe (sin el suavizado) sobre el jugador.
	camara.saltar_a_objetivo()


func _fundir(alfa: float) -> void:
	var t := create_tween()
	t.tween_property(fundido, ^"color:a", alfa, duracion_fundido)
	await t.finished
