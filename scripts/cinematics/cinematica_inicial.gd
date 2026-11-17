class_name CinematicaInicial
extends Node
## Cinemática con la que empieza el juego (escena principal del proyecto). Sigue el
## video del prototipo de Unity y docs/design/guion_primera_cinematica.md:
##
##   1. Ilustración del cumpleaños (fondo_2.png) + diálogo con Kathita.
##   2. Exterior pintado pasando del día a la noche (fotogramas clave de atardecer/).
##   3. Cuarto en pixel art: Kathita entra, Leonidas no se despierta, se despierta de
##      golpe, recibe la carta de los sabios y la lee.
##   4. Fundido a negro y se carga `escena_siguiente` (game.tscn).
##
## Esc (ui_cancel) salta la cinemática. E/J avanzan los diálogos (los lee `Dialogos`) y,
## con la carta abierta, bajan una página o la cierran (los lee esta escena).
## Los textos están en resources/dialogues/cinematica_*.tres (los edita el guion).
##
## Las ilustraciones pintadas se ven a la resolución real de la ventana: mientras
## salen, la ventana pasa a content_scale_mode = CANVAS_ITEMS (en el modo normal
## "viewport" todo se dibuja a 480×270 y una pintura se vería pixelada). El cuarto
## vuelve al modo normal, como el resto del juego (`Pantalla.modo_pintura`).

@export_file("*.tscn") var escena_siguiente := "res://game.tscn"
@export var duracion_fundido := 0.6
## Ilustración del cumpleaños (paso 1).
@export var fondo_cumpleanos: Texture2D

@export_group("Diálogos")
@export var dialogo_cumpleanos: Dialogo
@export var dialogo_despertar: Dialogo
@export var dialogo_mision: Dialogo
@export var dialogo_entrega: Dialogo
@export var texto_carta: Dialogo
@export var dialogo_final: Dialogo

@export_group("Atardecer")
## Fotogramas clave: <carpeta>/atardecer_00.jpg ... (se funden entre sí).
@export_dir var carpeta_atardecer := "res://assets/backgrounds/cinematica/atardecer"
@export var cuadros_atardecer := 39
## Cuántos fotogramas clave se piden por adelantado (en hilo) mientras se funden los
## actuales. Cada JPG ocupa ~8 MB ya descomprimido: precargar los 39 (~320 MB) es mucho
## para la web, así que se mantiene solo una ventana deslizante.
@export var cuadros_por_adelantado := 2
@export var duracion_atardecer := 6.5
@export var espera_antes_atardecer := 1.2
@export var espera_despues_atardecer := 1.5

@export_group("Cuarto")
## Fondo del cuarto (FALTA el arte: mientras tanto se ven dos rectángulos provisionales).
@export var fondo_cuarto: Texture2D
@export var mama_destino_x := 134.0
@export var velocidad_mama := 30.0

@export_group("Carta")
## Píxeles por segundo al desplazar la carta con arriba/abajo.
@export var velocidad_carta := 60.0

var _saltando := false
## `_terminar()` ya se ejecutó (por el final normal o por Esc): no se repite.
var _terminada := false
## Fotogramas clave del atardecer ya cargados (índice → textura) y pedidos al cargador.
var _cuadros: Dictionary[int, Texture2D] = {}
var _pedidos: Dictionary[int, bool] = {}
## La carta está abierta y acepta E/J (solo entonces esta escena los lee).
var _leyendo_carta := false
## E/J pulsado con la carta abierta; lo pone `_unhandled_input` y lo gasta `_leer_carta`.
var _pulsado := false

@onready var ilustracion: CanvasLayer = $Ilustracion
@onready var pintura: TextureRect = $Ilustracion/Pintura
@onready var pintura_encima: TextureRect = $Ilustracion/PinturaEncima
@onready var cuarto: Node2D = $Cuarto
@onready var cuarto_fondo: Sprite2D = $Cuarto/Fondo
@onready var provisional: Node2D = $Cuarto/Provisional
@onready var cama: AnimatedSprite2D = $Cuarto/Cama
@onready var mama: AnimatedSprite2D = $Cuarto/Mama
@onready var carta: CanvasLayer = $Carta
@onready var papel: Control = $Carta/Papel
@onready var recorte: Control = $Carta/Papel/Recorte
@onready var texto: Label = $Carta/Papel/Recorte/Texto
@onready var flecha_carta: CanvasItem = $Carta/Papel/Flecha
@onready var negro: ColorRect = $Fundido/Negro


func _ready() -> void:
	negro.color.a = 1.0
	cuarto.visible = false
	carta.visible = false
	pintura_encima.modulate.a = 0.0
	if fondo_cuarto:
		cuarto_fondo.texture = fondo_cuarto
		provisional.visible = false
	_reproducir()


## Esta escena recibe los eventos ANTES que el autoload `Dialogos`: E/J solo se leen (y
## consumen) con la carta abierta; con un diálogo abierto pasan de largo hasta la caja.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_saltar()
	elif _leyendo_carta and (event.is_action_pressed(&"interactuar") or event.is_action_pressed(&"atacar")):
		get_viewport().set_input_as_handled()
		_pulsado = true


func _reproducir() -> void:
	# 1. Cumpleaños
	Pantalla.modo_pintura(self, true)
	# Los primeros fotogramas del atardecer se cargan en hilo mientras sale el diálogo.
	for i in cuadros_por_adelantado + 1:
		_pedir_cuadro(i)
	pintura.texture = fondo_cumpleanos
	await _fundir(0.0)
	if not await _dialogo(dialogo_cumpleanos): return
	if not await _fundir(1.0): return

	# 2. Atardecer
	pintura.texture = _cuadro_atardecer(0)
	await _fundir(0.0)
	if not await _esperar(espera_antes_atardecer): return
	if not await _atardecer(): return
	if not await _esperar(espera_despues_atardecer): return
	if not await _fundir(1.0): return

	# 3. Cuarto
	ilustracion.visible = false
	Pantalla.modo_pintura(self, false)
	cuarto.visible = true
	cama.play(&"dormido")
	mama.play(&"caminar_regalo")
	await _fundir(0.0)
	if not await _mover_mama(mama_destino_x): return
	mama.play(&"parada_regalo")
	if not await _esperar(0.4): return
	if not await _dialogo(dialogo_despertar): return

	cama.play(&"despertar")
	await cama.animation_finished
	if _saltando: return
	cama.play(&"despierto")
	if not await _dialogo(dialogo_mision): return

	mama.play(&"dar_regalo")
	await mama.animation_finished
	if _saltando: return
	mama.play(&"parada")
	if not await _dialogo(dialogo_entrega): return

	# La carta
	if not await _leer_carta(): return
	if not await _dialogo(dialogo_final): return

	# 4. Al juego
	if not await _fundir(1.0): return
	_terminar()


## Cada paso devuelve false si mientras tanto se saltó la cinemática.
func _dialogo(d: Dialogo) -> bool:
	if d:
		await Dialogos.mostrar(d)
	return not _saltando


func _esperar(segundos: float) -> bool:
	await get_tree().create_timer(segundos).timeout
	return not _saltando


func _fundir(alfa: float) -> bool:
	var t := create_tween()
	t.tween_property(negro, ^"color:a", alfa, duracion_fundido)
	await t.finished
	return not _saltando


func _ruta_cuadro(i: int) -> String:
	return "%s/atardecer_%02d.jpg" % [carpeta_atardecer, i]


## Pide en hilo el fotograma clave `i` (si existe y no se había pedido).
func _pedir_cuadro(i: int) -> void:
	if i < 0 or i >= cuadros_atardecer or _pedidos.has(i):
		return
	_pedidos[i] = true
	ResourceLoader.load_threaded_request(_ruta_cuadro(i))


## Devuelve el fotograma clave `i`. Si aún no ha terminado de cargarse espera a que acabe
## (en el peor caso, igual que un `load()`).
func _cuadro_atardecer(i: int) -> Texture2D:
	if not _cuadros.has(i):
		_pedir_cuadro(i)
		_cuadros[i] = ResourceLoader.load_threaded_get(_ruta_cuadro(i)) as Texture2D
	return _cuadros[i]


## Funde un fotograma clave con el siguiente: `pintura` lleva el actual y
## `pintura_encima` el siguiente, cada vez más opaco.
func _atardecer() -> bool:
	var tramos := cuadros_atardecer - 1
	var t := 0.0
	var actual := -1
	while t < duracion_atardecer:
		await get_tree().process_frame
		if _saltando:
			return false
		t += get_process_delta_time()
		var pos := clampf(t / duracion_atardecer, 0.0, 1.0) * tramos
		var i := mini(floori(pos), tramos - 1)
		if i != actual:
			actual = i
			pintura.texture = _cuadro_atardecer(i)
			pintura_encima.texture = _cuadro_atardecer(i + 1)
			# Ventana deslizante: se piden los siguientes y se sueltan los ya pasados.
			for k in range(i + 2, i + 2 + cuadros_por_adelantado):
				_pedir_cuadro(k)
			for k in _cuadros.keys():
				if k < i:
					_cuadros.erase(k)
		pintura_encima.modulate.a = pos - i
	pintura.texture = _cuadro_atardecer(tramos)
	pintura_encima.modulate.a = 0.0
	return true


func _mover_mama(x: float) -> bool:
	var t := create_tween()
	t.tween_property(mama, ^"position:x", x, absf(mama.position.x - x) / velocidad_mama)
	await t.finished
	return not _saltando


## Muestra la carta de los sabios. Arriba/abajo la desplazan; E/J baja una página y,
## al final, la cierra.
func _leer_carta() -> bool:
	var parrafos := PackedStringArray()
	if texto_carta:
		for l in texto_carta.lineas():
			var parrafo: String = l.texto
			parrafos.append(parrafo)
	texto.text = CajaDialogo.adaptar_a_fuente("\n\n".join(parrafos))
	texto.position.y = 0.0

	Pantalla.modo_pintura(self, true) # el texto de la carta es pequeño: necesita la resolución real
	carta.visible = true
	papel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(papel, ^"modulate:a", 1.0, 0.4)
	await t.finished
	if _saltando: return false

	var alto_linea := texto.get_line_height()
	var maximo := maxf(0.0, texto.get_line_count() * alto_linea - recorte.size.y)
	var y := 0.0
	var objetivo := -1.0 # página a la que se está desplazando con E
	_pulsado = false
	_leyendo_carta = true
	while true:
		await get_tree().process_frame
		if _saltando:
			_leyendo_carta = false
			return false
		var delta := get_process_delta_time()
		var eje := Input.get_axis(&"mover_arriba", &"mover_abajo")
		if eje != 0.0:
			objetivo = -1.0
			y += eje * velocidad_carta * delta
		elif objetivo >= 0.0:
			y = move_toward(y, objetivo, velocidad_carta * 3.0 * delta)
			if is_equal_approx(y, objetivo):
				objetivo = -1.0
		y = clampf(y, 0.0, maximo)
		texto.position.y = -roundf(y * 4.0) / 4.0 # cuartos de píxel = píxeles reales a ×4
		var al_final := y >= maximo - 0.5
		@warning_ignore("integer_division") # parpadeo: medio segundo entero a propósito
		flecha_carta.visible = int(Time.get_ticks_msec() / 400) % 2 == 0
		if _pulsado:
			_pulsado = false
			if al_final:
				break
			objetivo = minf(maximo, y + recorte.size.y - alto_linea)

	# La pulsación que la cierra ya está consumida: no avanzará el diálogo siguiente.
	_leyendo_carta = false
	t = create_tween()
	t.tween_property(papel, ^"modulate:a", 0.0, 0.3)
	await t.finished
	carta.visible = false
	Pantalla.modo_pintura(self, false)
	return not _saltando


func _saltar() -> void:
	if _saltando:
		return
	_saltando = true
	Dialogos.cerrar()
	var t := create_tween()
	t.tween_property(negro, ^"color:a", 1.0, 0.25)
	await t.finished
	_terminar()


func _terminar() -> void:
	if _terminada:
		return
	_terminada = true
	# La carta de los sabios va al libro (Objetos Importantes) y abre la primera misión,
	# también si se salta la cinemática.
	EstadoJuego.agregar_objeto(EstadoJuego.OBJ_CARTA)
	EstadoJuego.empezar_mision(EstadoJuego.MISION_IR_AL_TEMPLO)
	Pantalla.modo_pintura(self, false)
	get_tree().change_scene_to_file(escena_siguiente)
