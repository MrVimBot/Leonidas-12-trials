class_name MenuPausa
extends CanvasLayer
## Menú de pausa: Continuar, Controles, Daltonismo, Tipo de entrada y Salir.
## Va dentro de `game.tscn`. La interfaz (paneles, botones, textos y tema) está
## en `scenes/ui/menu_pausa.tscn` y se edita desde el editor; los botones llaman
## a este script con señales conectadas en la escena.
##
## Se abre y cierra con la acción `pausa` (Esc / Start). Abierto =
## `get_tree().paused`. En la pantalla de controles, `pausa` o `ui_accept` (Enter, Espacio, E/J) vuelven al menú.
## El Esc se lee en `_unhandled_input`. Esta escena (dentro de Game) lo recibe antes que
## los autoload `Libro`, `Tienda` y `Dialogos`: con alguno de ellos abierto la pausa ni se
## abre ni consume el evento (`_puede_abrir`), así que sigue hasta él y es él quien se
## cierra con ese Esc.
##
## «Daltonismo» pasa al siguiente filtro del autoload `Daltonismo` (No → Protanopía →
## Deuteranopía) y el botón muestra el elegido: «Daltonismo: No».
## «Tipo de entrada» alterna Teclado / Mando en el autoload `Entrada` (no filtra la entrada:
## solo cambia qué teclas nombran los textos de ayuda) y la lista de Controles muestra la
## del tipo elegido (`ListaTeclado` en texto / `ListaMando` con iconos de PS5 del plugin
## Controller Icons, `IconoMando`; todo en la escena).
## «Salir» vuelve al menú principal (sin guardar: se guarda desde el libro).
##
## Arte de la artista (`assets/sprites/menu_pausa.aseprite` → `assets/ui/menu_pausa/`, con
## `tools/recortes/menu_pausa.lua`): marco de 362×333 con la cartela «Pausa» y Leonidas asomado.
## No cabe en 480×270, así que, como el libro, se dibuja en modo pintura (`Pantalla.modo_pintura`)
## a la mayor escala entera de pantalla (`Pantalla.ajustar_a_pixel_entero`: ×3 en 1920×1080),
## con una captura del juego detrás para que el mundo no cambie de aspecto. Las coordenadas de
## `Lienzo` son píxeles del arte; el texto va en `Hoja` (sobre el pergamino) con la fuente del
## libro (Gravity). En Controles, la cartela cambia «Pausa» (pintado) por `TituloControles`.

var abierto := false

var _viendo_controles := false

@onready var _fondo: TextureRect = %Fondo
@onready var _lienzo: Control = %Lienzo
@onready var _titulo: Control = %Titulo
@onready var _titulo_controles: Control = %TituloControles
@onready var _panel_menu: Control = %PanelMenu
@onready var _panel_controles: Control = %PanelControles
@onready var _botones: BotonesConMarca = %Botones
@onready var _boton_continuar: Button = %Continuar
@onready var _boton_controles: Button = %Controles
@onready var _boton_daltonismo: Button = %Daltonismo
@onready var _boton_tipo_entrada: Button = %TipoEntrada
@onready var _lista_teclado: Control = %ListaTeclado
@onready var _lista_mando: Control = %ListaMando
@onready var _pie_controles: Label = %Pie
@onready var _pie_mando: Control = %PieMando


func _ready() -> void:
	visible = false
	# El texto de la escena («Daltonismo») es el rótulo; se le añade el filtro elegido.
	_boton_daltonismo.set_meta(&"rotulo", _boton_daltonismo.text)
	_actualizar_daltonismo()
	_boton_tipo_entrada.set_meta(&"rotulo", _boton_tipo_entrada.text)
	_actualizar_tipo_entrada()
	get_window().size_changed.connect(_colocar)


## Escala entera de pantalla para el marco y lo centra. Al abrir y si cambia la ventana.
func _colocar() -> void:
	if abierto:
		Pantalla.ajustar_a_pixel_entero(_lienzo)


## ¿Se puede abrir ahora? No con el libro, la tienda o un diálogo abiertos, ni
## durante un cambio de zona.
func _puede_abrir() -> bool:
	if get_tree().paused:
		return false
	if Libro.abierto or Tienda.abierto or Dialogos.abierto:
		return false
	var game := Game.actual(self)
	return game != null and not game.cambiando


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pausa"):
		if abierto:
			get_viewport().set_input_as_handled()
			if _viendo_controles:
				_volver_de_controles()
			else:
				_cerrar()
		elif _puede_abrir():
			get_viewport().set_input_as_handled()
			_abrir()
		return
	# Con el menú abierto, los botones con foco reciben `ui_accept` por la GUI (Enter, Espacio, E,
	# J...). Solo la pantalla de controles, que no tiene botones, lo lee aquí para volver.
	if abierto and _viendo_controles and event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_volver_de_controles()


func _abrir() -> void:
	# Captura del juego tal como se ve ahora (a 480×270): será el fondo mientras la ventana
	# está en modo CANVAS_ITEMS.
	var captura := get_viewport().get_texture().get_image()
	_fondo.texture = ImageTexture.create_from_image(captura) if captura else null
	abierto = true
	_viendo_controles = false
	_mostrar_panel(false)
	Pantalla.modo_pintura(self, true)
	visible = true
	get_tree().paused = true
	_colocar()
	_boton_continuar.grab_focus()
	_botones.actualizar_marcas()


func _cerrar() -> void:
	abierto = false
	visible = false
	_fondo.texture = null
	Pantalla.restaurar(self) # vuelve al modo de la zona (pintada o no)
	get_tree().paused = false


## Menú (false) o Controles (true), con su título en la cartela.
func _mostrar_panel(controles: bool) -> void:
	_panel_menu.visible = not controles
	_panel_controles.visible = controles
	_titulo.visible = not controles
	_titulo_controles.visible = controles


func _mostrar_controles() -> void:
	_viendo_controles = true
	# Mando: lista con iconos de PS5 y pie «(Círculo) volver»; teclado: todo en texto.
	var con_iconos := Entrada.usa_iconos()
	_lista_teclado.visible = not con_iconos
	_pie_controles.visible = not con_iconos
	_lista_mando.visible = con_iconos
	_pie_mando.visible = con_iconos
	_mostrar_panel(true)


func _volver_de_controles() -> void:
	_viendo_controles = false
	_mostrar_panel(false)
	_boton_controles.grab_focus()


func _filtro_daltonismo() -> void:
	Daltonismo.siguiente()
	_actualizar_daltonismo()
	_botones.actualizar_marcas()


## BotonesConMarca pinta el texto guardado en la meta `texto` (con o sin "> ").
func _actualizar_daltonismo() -> void:
	var rotulo: String = _boton_daltonismo.get_meta(&"rotulo")
	var texto := "%s: %s" % [rotulo, Daltonismo.nombre()]
	_boton_daltonismo.set_meta(&"texto", texto)
	_boton_daltonismo.text = texto


func _tipo_entrada() -> void:
	Entrada.siguiente() # alterna Teclado / Mando
	_actualizar_tipo_entrada()
	_botones.actualizar_marcas()


func _actualizar_tipo_entrada() -> void:
	var rotulo: String = _boton_tipo_entrada.get_meta(&"rotulo")
	var texto := "%s: %s" % [rotulo, Entrada.nombre()]
	_boton_tipo_entrada.set_meta(&"texto", texto)
	_boton_tipo_entrada.text = texto


func _salir() -> void:
	abierto = false
	_fondo.texture = null
	# El menú principal también va en modo pintura: no hace falta restaurar.
	get_tree().paused = false
	var escena_principal: String = ProjectSettings.get_setting("application/run/main_scene")
	get_tree().change_scene_to_file(escena_principal)
