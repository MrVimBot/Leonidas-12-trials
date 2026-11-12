class_name Game
extends Node2D
## Escena principal (game.tscn). Contiene lo que persiste entre zonas (jugador, cámara,
## y luego HUD y diálogos) y carga las zonas del mundo dentro de "Mundo".
##
##   Game (este script, y_sort_enabled)
##   ├─ Mundo (Node2D, y_sort)    aquí se instancia la zona actual
##   ├─ Jugador
##   ├─ (Barco)                   solo en zonas con `modo_barco`: lo crea este script
##   ├─ Camara (CamaraPixel)      sigue al jugador o al barco; límites según la zona
##   └─ Transicion (CanvasLayer)  fundido a negro al cambiar de zona
##
## En una zona con `modo_barco` (el mar) Leonidas viaja en barco: se oculta y desactiva
## el Jugador, se crea el Barco en la entrada, la cámara lo sigue y se abre el micrófono.

signal zona_cambiada(zona: Zona)
## Cambia entre ir a pie y en barco; `vida` es la que debe mostrar el HUD.
signal modo_cambio(en_barco: bool, vida: ComponenteVida)

@export_file("*.tscn") var zona_inicial := "res://scenes/levels/pueblo.tscn"
@export var entrada_inicial := "inicio"
@export var duracion_fundido := 0.25
@export var escena_barco: PackedScene = preload("res://scenes/player/barco.tscn")
@export var dialogo_tutorial_barco: Dialogo = preload("res://resources/dialogues/tutorial_barco.tres")

@export_group("Depuración")
## Empieza como si los sabios ya hubieran dado la misión (las puertas del pueblo dejan
## pasar). Para probar el bosque y la playa mientras no exista la escena de los sabios.
@export var depurar_mision_recibida := false

var zona_actual: Zona = null
var barco: Barco = null
var _cambiando := false
var _ruta_actual := ""
var _entrada_actual := ""
## Zona desde la que se subió al barco: al bajar en la orilla contraria hay premio.
var _origen_travesia := ""

@onready var mundo: Node2D = $Mundo
@onready var jugador: Jugador = $Jugador
@onready var camara: CamaraPixel = $Camara
@onready var fundido: ColorRect = $Transicion/Fundido


func _ready() -> void:
	add_to_group(&"game")
	if depurar_mision_recibida:
		EstadoJuego.mision_recibida = true
	fundido.color.a = 0.0
	jugador.reaparecio.connect(camara.saltar_a_objetivo)
	_cargar_zona(zona_inicial, entrada_inicial)
	if barco:
		_tutorial_barco()


## Cambia de zona con fundido a negro. La llaman las SalidaZona.
func cambiar_zona(ruta: String, entrada: String = "inicio") -> void:
	if _cambiando:
		return
	_cambiando = true
	_bloquear(true)
	if barco and ruta != _origen_travesia:
		EstadoJuego.agregar_monedas(floori(barco.vida.vida / 4.0)) # una moneda por corazón entero conservado
	await _fundir(1.0)
	_cargar_zona(ruta, entrada)
	_bloquear(true) # el barco puede ser nuevo
	await _fundir(0.0)
	_bloquear(false)
	_cambiando = false
	if barco:
		_tutorial_barco()


func _bloquear(b: bool) -> void:
	jugador.set_bloqueado(b)
	if barco:
		barco.set_bloqueado(b)


## Al hundirse: fundido y se vuelve a empezar la travesía por la misma entrada.
func _al_hundirse() -> void:
	if _cambiando:
		return
	_cambiando = true
	await _fundir(1.0)
	_cargar_zona(_ruta_actual, _entrada_actual)
	_bloquear(true)
	await _fundir(0.0)
	_bloquear(false)
	_cambiando = false


## La primera vez que se sube al barco: explica los controles y calibra el micrófono.
func _tutorial_barco() -> void:
	if EstadoJuego.tutorial_barco_visto or barco == null:
		return
	EstadoJuego.tutorial_barco_visto = true
	var este_barco := barco
	este_barco.set_bloqueado(true)
	await Dialogos.mostrar(dialogo_tutorial_barco)
	await Microfono.calibrar()
	if is_instance_valid(este_barco):
		este_barco.set_bloqueado(false)


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
	if zona_actual.modo_barco and ruta != _ruta_actual:
		_origen_travesia = _ruta_actual
	_ruta_actual = ruta
	_entrada_actual = entrada

	if barco:
		remove_child(barco)
		barco.queue_free()
		barco = null
	if zona_actual.modo_barco:
		_subir_al_barco(entrada)
	else:
		jugador.visible = true
		jugador.process_mode = Node.PROCESS_MODE_INHERIT
		camara.objetivo = jugador
		Microfono.desactivar()

	_ajustar_camara()
	zona_cambiada.emit(zona_actual)
	modo_cambio.emit(barco != null, barco.vida if barco else jugador.vida)


func _subir_al_barco(entrada: String) -> void:
	barco = escena_barco.instantiate() as Barco
	barco.global_position = zona_actual.punto_entrada(entrada)
	add_child(barco) # hermano del jugador: se ordena por Y con los objetos de la zona
	# Mira hacia el interior del mapa: abajo si entra por la mitad de arriba.
	var limites := zona_actual.obtener_limites()
	var abajo := not limites.has_area() or barco.global_position.y < limites.get_center().y
	barco.mirar(Vector2.DOWN if abajo else Vector2.UP)
	barco.hundido.connect(_al_hundirse)
	jugador.visible = false
	jugador.process_mode = Node.PROCESS_MODE_DISABLED
	camara.objetivo = barco
	Microfono.activar()


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
