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
## Va dentro de Game; se asignan `jugador` y `game` en el Inspector. Solo ESCUCHA señales:
##   jugador.vida.cambio, jugador.estamina.cambio, EstadoJuego.monedas_cambio,
##   EstadoJuego.objetos_cambio y estado_restablecido (espada y libro),
##   Game.modo_cambio → `_al_cambiar_modo` (conectada en game.tscn; al ir en barco los
##   corazones son los del barco). Como la conexión está en la escena, ya existe cuando
##   Game emite la primera en su `_ready` (después del de este hijo), también si la
##   partida empieza en el mar.
## En barco: se oculta la ranura del objeto y la estamina, y aparece el `MedidorViento`
## (fuerza del soplido) con la pista "[Espacio]" si no llega audio del micrófono.
## Vida en CUARTOS de corazón: assets/ui/corazones.png tiene 5 estados cada 12 px
## (lleno, 3/4, 1/2, 1/4, vacío).

const CUARTOS_POR_CORAZON := 4
const ANCHO_CELDA := 12

@export var jugador: Jugador
## Para leer el soplido del barco actual (`game.barco`) en el medidor de viento.
@export var game: Game
@export var textura_corazones: Texture2D = preload("res://assets/ui/corazones.png")
## Segundos que la barra de estamina sigue visible después de llenarse.
@export var ocultar_estamina_tras := 0.6
## Dónde va la barra de estamina respecto a los pies de Leonidas (en pantalla).
@export var posicion_estamina := Vector2(-8, -33)

var _estados: Array[AtlasTexture] = []
var _tiempo_estamina_llena := 0.0
var _vida: ComponenteVida = null
var _en_barco := false

@onready var corazones: HBoxContainer = %Corazones
@onready var icono_objeto: TextureRect = %Icono
@onready var barra_estamina: BarraEstamina = %BarraEstamina
@onready var libro: CanvasItem = %Inventario
@onready var monedas: ContadorMonedas = %Monedas
@onready var ranura_objeto: Control = %RanuraObjeto
## Es una `BarraEstamina` (barra genérica) usada aquí como medidor de viento.
@onready var medidor_viento: BarraEstamina = %MedidorViento
@onready var pista_viento: Label = %Pista


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
		_al_cambiar_estamina(jugador.estamina.estamina, jugador.estamina.estamina_max) # valor inicial
	EstadoJuego.monedas_cambio.connect(_al_cambiar_monedas)
	_al_cambiar_monedas(EstadoJuego.monedas)
	EstadoJuego.objetos_cambio.connect(_al_cambiar_objetos)
	EstadoJuego.estado_restablecido.connect(_actualizar_objetos)
	_actualizar_objetos()
	barra_estamina.modulate.a = 0.0
	medidor_viento.visible = false


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


## Conectada en game.tscn a `Game.modo_cambio`.
func _al_cambiar_modo(en_barco: bool, vida: ComponenteVida) -> void:
	seguir_vida(vida)
	modo_barco(en_barco)


func _process(delta: float) -> void:
	if _en_barco:
		var barco := game.barco if game else null
		medidor_viento.valor = barco.soplido() if barco else 0.0
		pista_viento.visible = not Microfono.disponible
		return
	if jugador == null:
		return
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


func _al_cambiar_objetos(_id: StringName, _cantidad: int) -> void:
	_actualizar_objetos()


## Objeto equipado y libro: solo cambian al ganar/perder objetos o al reiniciar/cargar la
## partida (señales de EstadoJuego), no hace falta mirarlos cada fotograma.
func _actualizar_objetos() -> void:
	# Objeto equipado: de momento solo la espada (la dan los sabios).
	icono_objeto.visible = EstadoJuego.tiene_espada
	# El libro (inventario + mapa + guardar) lo da Kathita al salir de casa.
	libro.visible = EstadoJuego.tiene_libro


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
