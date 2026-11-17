class_name MenuPrincipal
extends Control
## Menú principal (escena principal del proyecto). Jugar → `escena_jugar`
## (la cinemática inicial, que a su vez carga game.tscn). Salir cierra el juego.
## Continuar (solo si hay partida guardada, ver EstadoJuego.guardar) carga la partida
## y va directo a `escena_continuar` (game.tscn), en la zona y entrada guardadas.
##
## PROVISIONAL: no hay arte de menú todavía. El fondo es la pintura del exterior
## de la cinemática (fondo_1.png) y los botones son texto con la fuente del juego.
## Cuando la artista entregue el logo/botones, sustituir `Titulo` por un
## TextureRect y dar a los botones su textura (o un tema propio).
##
## Como la pintura mide 1920×1080, mientras el menú está abierto la ventana pasa a
## content_scale_mode = CANVAS_ITEMS (igual que la cinemática): las coordenadas
## siguen siendo 480×270, pero la pintura se ve a la resolución real.
##
## Teclado/mando: arriba/abajo eligen, Enter/Espacio/E/J (o A/B/X) confirman.
## El ratón también funciona (pasar por encima = seleccionar).

@export_file("*.tscn") var escena_jugar := "res://scenes/cinematics/cinematica_inicial.tscn"
@export_file("*.tscn") var escena_continuar := "res://game.tscn"
@export var duracion_fundido := 0.5

var _eligiendo := true

@onready var botones: BotonesConMarca = %Botones
@onready var boton_continuar: Button = %Continuar
@onready var boton_jugar: Button = %Jugar
@onready var boton_salir: Button = %Salir
@onready var negro: ColorRect = %Negro


func _ready() -> void:
	Pantalla.modo_pintura(self, true)
	# En la web no se puede cerrar la ventana: Salir no pinta nada.
	boton_salir.visible = not OS.has_feature("web")
	boton_continuar.visible = EstadoJuego.hay_partida()
	# Arriba/abajo dan la vuelta entre el primer y el último botón visible.
	var visibles: Array[Button] = []
	for b: Button in botones.get_children():
		if b.visible:
			visibles.append(b)
	visibles[0].focus_neighbor_top = visibles[0].get_path_to(visibles[-1])
	visibles[-1].focus_neighbor_bottom = visibles[-1].get_path_to(visibles[0])
	(boton_continuar if boton_continuar.visible else boton_jugar).grab_focus()
	botones.actualizar_marcas()
	negro.color.a = 1.0
	create_tween().tween_property(negro, ^"color:a", 0.0, duracion_fundido)


func _unhandled_input(event: InputEvent) -> void:
	if not _eligiendo:
		return
	# Las teclas del juego (E/J, botones del mando) también confirman.
	if event.is_action_pressed(&"interactuar") or event.is_action_pressed(&"atacar"):
		var b := get_viewport().gui_get_focus_owner() as Button
		if b:
			get_viewport().set_input_as_handled()
			b.pressed.emit()


## Fundido a negro y, al terminar, `accion`. Ignora pulsaciones mientras tanto.
func _fundir_y(accion: Callable) -> void:
	if not _eligiendo:
		return
	_eligiendo = false
	_bloquear_botones()
	var t := create_tween()
	t.tween_property(negro, ^"color:a", 1.0, duracion_fundido)
	await t.finished
	Pantalla.modo_pintura(self, false)
	accion.call()


func _jugar() -> void:
	_fundir_y(_empezar_partida)


func _continuar() -> void:
	_fundir_y(_cargar_partida)


func _empezar_partida() -> void:
	EstadoJuego.reiniciar() # partida nueva: monedas y manzanas a cero
	get_tree().change_scene_to_file(escena_jugar)


func _cargar_partida() -> void:
	if not EstadoJuego.cargar():
		push_warning("MenuPrincipal: no se pudo leer la partida; se empieza una nueva")
		_empezar_partida()
		return
	get_tree().change_scene_to_file(escena_continuar)


func _salir() -> void:
	if not _eligiendo:
		return
	_eligiendo = false
	_bloquear_botones()
	get_tree().quit()


func _bloquear_botones() -> void:
	for b: Button in botones.get_children():
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
