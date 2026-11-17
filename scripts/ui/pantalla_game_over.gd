class_name PantallaGameOver
extends CanvasLayer
## Pantalla de Game Over: al morir Leonidas a pie, el arte de la artista
## (`assets/sprites/game_over.aseprite`, 192×108) con «Continuar» y «Menú principal».
## Va dentro de `game.tscn`; Game la abre con `mostrar()` al recibir `Jugador.murio`.
## La interfaz (negro, lienzo, botones y tema) está en `scenes/ui/pantalla_game_over.tscn`
## y los botones llaman a este script con señales conectadas en la escena.
##
## Abierta = `get_tree().paused` (así la pausa y el libro no se abren encima). Los botones
## con foco los pulsa la GUI con `ui_accept` (Enter, Espacio, E/J...).
##
## ESCALA: 192×108 no cabe a escala entera en 480×270 (sería ×2,5), así que, como el libro,
## se dibuja en modo pintura (CANVAS_ITEMS) a la mayor escala entera de pantalla: ×10 en
## 1920×1080 (`Pantalla.ajustar_a_pixel_entero`). Al cerrar vuelve al modo normal.
##
## ARTE POR ZONA: `Zona.arte_game_over` (vacío = el de la escena, `arte_game_over.tscn`).
## Un arte es una escena con raíz Control de 192×108 (u otro tamaño); si trae un
## AnimationPlayer llamado `Animacion` con la animación `entrada`, se reproduce al abrir.

## «Continuar»: Game reaparece a Leonidas en su punto de control. Al emitirse, la pantalla
## ya se cerró (sin pausa y en modo normal) en este mismo fotograma.
signal continuar_pedido

## El arte que trae la escena (el mismo que la instancia `Arte`): se vuelve a él en las
## zonas sin `arte_game_over`.
@export var arte_por_defecto: PackedScene
## Segundos del fundido a negro antes de que aparezca el arte.
@export var duracion_negro := 0.4
## Segundos del fundido del arte.
@export var duracion_arte := 0.6

var abierta := false

var _tween: Tween

@onready var _negro: ColorRect = %Negro
@onready var _lienzo: Control = %Lienzo
@onready var _arte: Control = %Arte
@onready var _botones: BotonesConMarca = %Botones
@onready var _boton_continuar: Button = %Continuar


func _ready() -> void:
	visible = false
	get_window().size_changed.connect(_colocar)


## Abre la pantalla con `arte` (null = el que trae la escena).
func mostrar(arte: PackedScene = null) -> void:
	if abierta:
		return
	abierta = true
	_poner_arte(arte)
	get_tree().paused = true
	Pantalla.modo_pintura(self, true)
	visible = true
	_colocar()
	_negro.modulate.a = 0.0
	_lienzo.modulate.a = 0.0
	_botones.modulate.a = 0.0
	_activar_botones(false)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_negro, ^"modulate:a", 1.0, duracion_negro)
	_tween.tween_callback(_reproducir_entrada)
	_tween.tween_property(_lienzo, ^"modulate:a", 1.0, duracion_arte)
	_tween.tween_property(_botones, ^"modulate:a", 1.0, 0.2)
	_tween.tween_callback(_activar_botones.bind(true))


func _cerrar() -> void:
	if _tween:
		_tween.kill()
	abierta = false
	visible = false
	Pantalla.restaurar(self) # vuelve al modo de la zona (pintada o no)
	get_tree().paused = false


## Pone `escena` (o `arte_por_defecto`) en el lienzo si no es ya la que hay. El de por
## defecto ya está en la escena; el de una zona se instancia aquí porque depende de la zona.
func _poner_arte(escena: PackedScene) -> void:
	var elegida := escena if escena else arte_por_defecto
	if elegida == null or _arte.scene_file_path == elegida.resource_path:
		return
	var nuevo := elegida.instantiate() as Control
	assert(nuevo != null, "PantallaGameOver: el arte debe tener un Control como raíz")
	_lienzo.remove_child(_arte)
	_arte.queue_free()
	nuevo.name = &"Arte"
	_lienzo.add_child(nuevo)
	_arte = nuevo


func _reproducir_entrada() -> void:
	var anim := _arte.get_node_or_null(^"Animacion") as AnimationPlayer
	if anim and anim.has_animation(&"entrada"):
		anim.play(&"entrada")


## Los botones no se pueden pulsar mientras aparecen (la tecla que remató a Leonidas,
## mantenida, no debe elegir nada).
func _activar_botones(si: bool) -> void:
	for b: Button in _botones.get_children():
		b.disabled = not si
		b.focus_mode = Control.FOCUS_ALL if si else Control.FOCUS_NONE
	if si:
		_boton_continuar.grab_focus()
		_botones.actualizar_marcas()


func _colocar() -> void:
	if abierta:
		_lienzo.size = _arte.size
		Pantalla.ajustar_a_pixel_entero(_lienzo)


## `pressed` de Continuar (conectada en la escena).
func _continuar() -> void:
	_cerrar()
	continuar_pedido.emit()


## `pressed` de Menú principal (conectada en la escena): sin guardar, como «Salir» de la pausa.
func _ir_al_menu() -> void:
	_cerrar()
	var escena_principal: String = ProjectSettings.get_setting("application/run/main_scene")
	get_tree().change_scene_to_file(escena_principal)
