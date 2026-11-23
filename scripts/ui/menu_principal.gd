class_name MenuPrincipal
extends Control
## Menú principal (escena principal del proyecto). Jugar → `escena_jugar`
## (la cinemática inicial, que a su vez carga game.tscn). Salir cierra el juego.
## Continuar (solo si hay partida guardada, ver EstadoJuego.guardar) abre `PantallaContinuar`
## (resumen de la partida: ya la deja cargada); desde ahí se va a `escena_continuar`
## (game.tscn), en la zona y posición guardadas, o se vuelve al menú.
##
## PROVISIONAL: no hay arte de menú todavía. El fondo es una pintura VERTICAL
## (assets/backgrounds/menu/menu_vertical.png, 931×2000) escalada al ancho de la
## pantalla: al abrir el menú la vista baja del cielo hasta Leonidas (`duracion_pan`)
## y se queda ahí. El título es `titulo.png` (pixel art a ×0,5: 2 px de pantalla por píxel
## de arte). Los botones son texto con la fuente del juego.
## Cuando la artista entregue el logo/botones, sustituir `Titulo` por un
## TextureRect y dar a los botones su textura (o un tema propio).
##
## Como la pintura mide 1920×1080, mientras el menú está abierto la ventana pasa a
## content_scale_mode = CANVAS_ITEMS (igual que la cinemática): las coordenadas
## siguen siendo 480×270, pero la pintura se ve a la resolución real.
##
## Teclado/mando: arriba/abajo eligen y `ui_accept` (Enter, Espacio, E, L, J y los botones 0, 1 y 2
## del mando; ver el mapa de entradas) pulsa el botón con foco: lo hace la GUI de Godot, sin código aquí.
## El ratón también funciona (pasar por encima = seleccionar).
##
## Créditos: `PantallaCreditos` (en la escena, con el texto en `TextoCreditos` para que el equipo
## lo edite desde el Inspector). Solo fuentes y plugins (decidido el 2026-11-18): la licencia de
## Gravity (CC BY 4.0) y la de Controller Icons (MIT) obligan a nombrarlos dentro del juego.
## Arriba/abajo desplazan el texto; `ui_accept`, `ui_cancel` o `pausa` vuelven (no hay botón
## con foco: el de «Volver» es para el ratón).

@export_file("*.tscn") var escena_jugar := "res://scenes/cinematics/cinematica_inicial.tscn"
@export_file("*.tscn") var escena_continuar := "res://game.tscn"
@export var duracion_fundido := 0.5
## Segundos que tarda la vista en bajar del cielo hasta Leonidas (0 = sin movimiento, ya abajo).
@export var duracion_pan := 9.0
## Píxeles que se desplaza el texto de los créditos por pulsación de arriba/abajo.
@export var paso_desplazamiento := 16

## True mientras se ven los créditos.
var viendo_creditos := false

var _eligiendo := true
## Texto del botón «Volver» tal como está en la escena, con su marcador `{volver}`.
var _plantilla_volver := ""

@onready var botones: BotonesConMarca = %Botones
@onready var boton_continuar: Button = %Continuar
@onready var boton_jugar: Button = %Jugar
@onready var boton_salir: Button = %Salir
@onready var boton_creditos: Button = %Creditos
@onready var pantalla_creditos: Control = %PantallaCreditos
@onready var desplazamiento: ScrollContainer = %Desplazamiento
@onready var texto_creditos: Label = %TextoCreditos
@onready var boton_volver: Button = %Volver
@onready var negro: ColorRect = %Negro
@onready var fondo: Control = %Fondo
@onready var panel: Control = %Panel
@onready var titulo: Control = %Titulo
@onready var pantalla_continuar: PantallaContinuar = %PantallaContinuar


func _ready() -> void:
	Pantalla.modo_pintura(self, true)
	# La fuente no tiene Á É Í Ó Ú mayúsculas (como en los diálogos, se escriben sin tilde).
	texto_creditos.text = CajaDialogo.adaptar_a_fuente(texto_creditos.text)
	_plantilla_volver = boton_volver.text
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
	_bajar_fondo()


## La pintura es más alta que la pantalla: empieza en el cielo y baja hasta el suelo.
func _bajar_fondo() -> void:
	var recorrido := fondo.offset_bottom - fondo.offset_top - size.y
	var final_y := -recorrido
	if duracion_pan <= 0.0:
		fondo.position.y = final_y
		return
	fondo.position.y = 0.0
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(fondo, ^"position:y", final_y, duracion_pan).set_delay(duracion_fundido)


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


## Botón Continuar: enseña el resumen de la partida (que ya la carga).
func _continuar() -> void:
	if not _eligiendo:
		return
	if not pantalla_continuar.abrir():
		push_warning("MenuPrincipal: no se pudo leer la partida; se empieza una nueva")
		_jugar()
		return
	panel.visible = false # al ocultarse, el botón con foco lo suelta
	titulo.visible = false


## La tarjeta de la partida en `PantallaContinuar`: la partida ya está cargada.
func _continuar_partida() -> void:
	_fundir_y(get_tree().change_scene_to_file.bind(escena_continuar))


func _volver_de_continuar() -> void:
	panel.visible = true
	titulo.visible = true
	boton_continuar.grab_focus()
	botones.actualizar_marcas()


func _empezar_partida() -> void:
	EstadoJuego.reiniciar() # partida nueva: monedas y manzanas a cero
	get_tree().change_scene_to_file(escena_jugar)


func _mostrar_creditos() -> void:
	if not _eligiendo:
		return
	viendo_creditos = true
	# «{volver} Volver» → «[Esc] Volver» o «[Círculo] Volver» según el tipo de entrada.
	boton_volver.text = Entrada.sustituir(_plantilla_volver)
	desplazamiento.scroll_vertical = 0
	panel.visible = false # al ocultarse, el botón con foco lo suelta
	titulo.visible = false # se transparentaría detrás del panel
	pantalla_creditos.visible = true


func _volver_de_creditos() -> void:
	if not viendo_creditos:
		return
	viendo_creditos = false
	SonidosUI.volver()
	pantalla_creditos.visible = false
	panel.visible = true
	titulo.visible = true
	boton_creditos.grab_focus()
	botones.actualizar_marcas()


func _unhandled_input(event: InputEvent) -> void:
	if not viendo_creditos:
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel") \
			or event.is_action_pressed(&"pausa"):
		get_viewport().set_input_as_handled()
		_volver_de_creditos()
	elif event.is_action_pressed(&"mover_abajo", true):
		get_viewport().set_input_as_handled()
		desplazamiento.scroll_vertical += paso_desplazamiento
	elif event.is_action_pressed(&"mover_arriba", true):
		get_viewport().set_input_as_handled()
		desplazamiento.scroll_vertical -= paso_desplazamiento


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
