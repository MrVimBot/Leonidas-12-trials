class_name HUD
extends CanvasLayer
## Interfaz durante el juego (scenes/ui/hud.tscn), según la lámina "Interfaz" de
## docs/pdf/Jugabilidad.pdf (p. 16):
##   arriba izq.: corazones y, debajo, la ranura del objeto equipado
##   arriba der.: icono del libro (inventario + mapa + guardar), solo si se tiene
##   abajo der.:  placa de dinero
## La estamina no sale en la maqueta: se muestra como una barrita sobre la cabeza de
## Leonidas, solo mientras no está llena.
##
## Va dentro de Game; se asigna `jugador` en el Inspector. Solo ESCUCHA señales:
##   jugador.vida.cambio, jugador.estamina.cambio, EstadoJuego.monedas_cambio,
##   Game.modo_cambio (al ir en barco los corazones son los del barco)
## En barco: se oculta la ranura del objeto y la estamina, y aparece el `MedidorViento`
## (fuerza del soplido) con la pista "[Espacio]" si no llega audio del micrófono.
## Vida en CUARTOS de corazón: assets/ui/corazones.png tiene 5 estados cada 12 px
## (lleno, 3/4, 1/2, 1/4, vacío).

@export var jugador: Jugador
@export var textura_corazones: Texture2D = preload("res://assets/ui/corazones.png")
## Segundos que la barra de estamina sigue visible después de llenarse.
@export var ocultar_estamina_tras := 0.6
## Dónde va la barra de estamina respecto a los pies de Leonidas (en pantalla).
@export var posicion_estamina := Vector2(-8, -33)

const CUARTOS_POR_CORAZON := 4
const ANCHO_CELDA := 12

var _estados: Array[AtlasTexture] = []
var _tiempo_estamina_llena := 0.0
var _vida: ComponenteVida = null
var _en_barco := false
var _game: Game = null

@onready var corazones: HBoxContainer = $Corazones
@onready var icono_objeto: TextureRect = $RanuraObjeto/Icono
@onready var barra_estamina: BarraEstamina = $BarraEstamina
@onready var libro: CanvasItem = $Inventario
@onready var monedas: ContadorMonedas = $Monedas
@onready var ranura_objeto: Control = $RanuraObjeto
@onready var medidor_viento: BarraEstamina = $MedidorViento
@onready var pista_viento: Label = $MedidorViento/Pista


func _ready() -> void:
	# Una textura por estado: índice = cuartos llenos (0 = vacío ... 4 = lleno).
	for cuartos in range(CUARTOS_POR_CORAZON + 1):
		var a := AtlasTexture.new()
		a.atlas = textura_corazones
		a.region = Rect2((CUARTOS_POR_CORAZON - cuartos) * ANCHO_CELDA, 0, ANCHO_CELDA, ANCHO_CELDA)
		_estados.append(a)
	if jugador:
		seguir_vida(jugador.vida)
		jugador.estamina.cambio.connect(_al_cambiar_estamina)
	EstadoJuego.monedas_cambio.connect(_al_cambiar_monedas)
	_al_cambiar_monedas(EstadoJuego.monedas)
	barra_estamina.modulate.a = 0.0
	medidor_viento.visible = false
	_conectar_game.call_deferred()


## Game puede prepararse después del HUD (y ya haber creado el barco): por eso diferido.
func _conectar_game() -> void:
	_game = get_tree().get_first_node_in_group(&"game") as Game
	if _game == null:
		return
	_game.modo_cambio.connect(_al_cambiar_modo)
	if _game.barco:
		_al_cambiar_modo(true, _game.barco.vida)


## Los corazones muestran esta vida (la de Leonidas o la del barco).
func seguir_vida(v: ComponenteVida) -> void:
	if _vida and _vida.cambio.is_connected(_al_cambiar_vida):
		_vida.cambio.disconnect(_al_cambiar_vida)
	_vida = v
	if _vida:
		_vida.cambio.connect(_al_cambiar_vida)
		_al_cambiar_vida(_vida.vida, _vida.vida_max)


func modo_barco(activo: bool) -> void:
	_en_barco = activo
	ranura_objeto.visible = not activo
	medidor_viento.visible = activo
	if activo:
		barra_estamina.modulate.a = 0.0


func _al_cambiar_modo(en_barco: bool, vida: ComponenteVida) -> void:
	seguir_vida(vida)
	modo_barco(en_barco)


func _process(delta: float) -> void:
	if _en_barco:
		var barco := _game.barco if _game else null
		medidor_viento.valor = barco.soplido() if barco else 0.0
		pista_viento.visible = not Microfono.disponible
		return
	if jugador == null:
		return
	# Objeto equipado: de momento solo la espada (la dan los sabios).
	icono_objeto.visible = jugador.tiene_espada
	# El libro (inventario + mapa + guardar) lo da Kathita al salir de casa.
	libro.visible = EstadoJuego.tiene_libro

	# Estamina sobre la cabeza de Leonidas; se desvanece un rato después de llenarse.
	var en_pantalla := jugador.get_global_transform_with_canvas().origin
	barra_estamina.position = (en_pantalla + posicion_estamina).round()
	if barra_estamina.valor >= 1.0:
		_tiempo_estamina_llena += delta
		if _tiempo_estamina_llena > ocultar_estamina_tras:
			barra_estamina.modulate.a = move_toward(barra_estamina.modulate.a, 0.0, delta * 4.0)
	else:
		_tiempo_estamina_llena = 0.0
		barra_estamina.modulate.a = 1.0


func _al_cambiar_vida(vida: int, vida_max: int) -> void:
	var total := ceili(vida_max / float(CUARTOS_POR_CORAZON))
	while corazones.get_child_count() < total:
		var t := TextureRect.new()
		t.stretch_mode = TextureRect.STRETCH_KEEP
		corazones.add_child(t)
	while corazones.get_child_count() > total:
		var sobra := corazones.get_child(corazones.get_child_count() - 1)
		corazones.remove_child(sobra)
		sobra.queue_free()
	for i in total:
		var cuartos := clampi(vida - i * CUARTOS_POR_CORAZON, 0, CUARTOS_POR_CORAZON)
		(corazones.get_child(i) as TextureRect).texture = _estados[cuartos]


func _al_cambiar_estamina(estamina: float, estamina_max: float) -> void:
	barra_estamina.valor = estamina / estamina_max if estamina_max > 0.0 else 0.0


func _al_cambiar_monedas(cantidad: int) -> void:
	monedas.valor = cantidad
