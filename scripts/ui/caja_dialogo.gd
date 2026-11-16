class_name CajaDialogo
extends CanvasLayer
## Cuadro de diálogo del juego. Es un AUTOLOAD llamado `Dialogos`
## (scenes/ui/caja_dialogo.tscn), así que se usa desde cualquier script:
##
##   await Dialogos.mostrar(preload("res://resources/dialogues/sabios.tres"))
##   await Dialogos.mostrar_texto("Kathita: ¡Leonidas, despierta!")
##
## `await` espera a que el jugador termine de leer. Mientras está abierto, el jugador
## queda bloqueado (motivo &"dialogo"; una escena con varios diálogos seguidos pone además
## el suyo, &"escena", para que no recupere el control entre uno y otro). E / J (o B / X en mando) avanzan; si el texto aún se está
## escribiendo, la primera pulsación lo completa.
##
## Retratos (lámina "Interfaz interacción con NPCs" de Jugabilidad.pdf): solo los
## personajes importantes tienen cara en el cuadro. Se asignan en `retratos`
## (nombre tal como sale en el diálogo → textura de unos 46×46). Sin retrato, el texto
## ocupa todo el ancho.

signal empezo
signal termino

## La fuente DOS (perfect_dos_vga_437_win.ttf) no tiene Á Í Ó Ú mayúsculas:
## se muestran sin tilde, como se hacía en mayúsculas antes.
const SIN_GLIFO := { "Á": "A", "Í": "I", "Ó": "O", "Ú": "U" }

## Velocidad del efecto máquina de escribir.
@export var letras_por_segundo := 40.0
## Parpadeo de la flecha de continuar (segundos por estado).
@export var parpadeo_flecha := 0.4
## Nombre del personaje → retrato (Texture2D). Ej.: {"Kathita": preload(...)}.
@export var retratos: Dictionary = {}
## Espacio que ocupa el retrato a la izquierda del texto (ancho + separación).
@export var ancho_retrato := 50

var abierto := false

var _paginas: Array[Dictionary] = []
var _indice := 0
var _escribiendo := false
var _letras := 0.0

@onready var caja: Control = $Caja
@onready var nombre: Label = $Caja/Nombre
@onready var texto: Label = $Caja/Texto
@onready var flecha: CanvasItem = $Caja/Flecha
@onready var retrato: TextureRect = $Caja/Retrato
@onready var _texto_x := texto.position.x
@onready var _texto_ancho := texto.size.x


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # funciona aunque el juego esté en pausa
	caja.visible = false


## Muestra un recurso Dialogo y espera a que termine.
func mostrar(dialogo: Dialogo) -> void:
	if dialogo:
		await mostrar_lineas(dialogo.lineas())


## Muestra texto escrito directamente ("Nombre: texto", una línea por cuadro).
func mostrar_texto(t: String) -> void:
	await mostrar_lineas(Dialogo.parsear(t))


## Muestra una lista de {nombre, texto} y espera a que termine.
func mostrar_lineas(lineas: Array[Dictionary]) -> void:
	if lineas.is_empty():
		return
	# Si ya hay un diálogo abierto, esperar a que termine en vez de perder este. Se
	# vuelve a comprobar `abierto` tras cada espera: si dos esperan a la vez, el
	# primero en despertar abre su cuadro y el otro sigue esperando.
	while abierto:
		await termino
	_paginas = _paginar(lineas)
	_indice = 0
	abierto = true
	var jugador := _jugador()
	if jugador:
		jugador.bloquear(&"dialogo")
	caja.visible = true
	_mostrar_pagina()
	empezo.emit()
	await termino


func _process(delta: float) -> void:
	if not abierto:
		return
	if _escribiendo:
		_letras += letras_por_segundo * delta
		texto.visible_characters = int(_letras)
		if texto.visible_characters >= texto.get_total_character_count():
			_terminar_escritura()
	else:
		flecha.visible = int(Time.get_ticks_msec() / (parpadeo_flecha * 1000.0)) % 2 == 0


## E/J avanzan. Mientras está abierto se consumen siempre, para que nadie más las vea.
## Orden de reparto: la escena actual recibe el evento antes que este autoload, pero el
## Jugador está BLOQUEADO y no lo toca. La pulsación que ABRE el diálogo la consumió el
## Jugador al interactuar, así que no llega aquí; la que lo CIERRA ya ha pasado por el
## Jugador (aún bloqueado) y se consume aquí: no reabre la conversación ni ataca.
## `is_action_pressed` ignora las repeticiones de tecla: mantener E/J no salta páginas.
func _unhandled_input(event: InputEvent) -> void:
	if not abierto:
		return
	if not (event.is_action_pressed(&"interactuar") or event.is_action_pressed(&"atacar")):
		return
	get_viewport().set_input_as_handled()
	if _escribiendo:
		_terminar_escritura()
	else:
		_indice += 1
		if _indice >= _paginas.size():
			_cerrar()
		else:
			_mostrar_pagina()


## Cierra el diálogo abierto de inmediato (p. ej. al saltar una cinemática).
func cerrar() -> void:
	if abierto:
		_cerrar()


static func adaptar_a_fuente(t: String) -> String:
	for c: String in SIN_GLIFO:
		var sustituto: String = SIN_GLIFO[c]
		t = t.replace(c, sustituto)
	return t


func _mostrar_pagina() -> void:
	var p: Dictionary = _paginas[_indice]
	var p_nombre: String = p.nombre
	var p_texto: String = p.texto
	var cara: Texture2D = retratos.get(p_nombre)
	retrato.texture = cara
	retrato.visible = cara != null
	texto.position.x = _texto_x + (ancho_retrato if cara else 0)
	texto.size.x = _texto_ancho - (ancho_retrato if cara else 0)
	nombre.text = adaptar_a_fuente(p_nombre)
	texto.text = adaptar_a_fuente(p_texto)
	texto.visible_characters = 0
	_letras = 0.0
	_escribiendo = true
	flecha.visible = false


func _terminar_escritura() -> void:
	_escribiendo = false
	texto.visible_characters = -1


func _cerrar() -> void:
	abierto = false
	caja.visible = false
	# Se emite ANTES de quitar el motivo: quien esperaba `termino` sigue en el acto (dentro
	# de emit) y, si abre otro diálogo o la tienda (saludo → tienda), pone su motivo
	# mientras el de este aún está; así el jugador no llega a pasar por NORMAL ni se le
	# repinta la pose. Si lo que se abrió es otro diálogo, el motivo &"dialogo" es ya el
	# suyo y se queda. No hace falta esperar a que "pase" la pulsación: ya está consumida.
	termino.emit()
	if not abierto:
		var jugador := _jugador()
		if jugador:
			jugador.desbloquear(&"dialogo")


func _jugador() -> Jugador:
	return get_tree().get_first_node_in_group(&"jugador") as Jugador


## Parte cada línea en páginas que quepan en el área de texto (ancho y nº de líneas).
func _paginar(lineas: Array[Dictionary]) -> Array[Dictionary]:
	var fuente := texto.get_theme_font(&"font")
	var tam := texto.get_theme_font_size(&"font_size")
	var ancho_base: float = _texto_ancho
	var max_lineas := maxi(1, floori(texto.size.y / fuente.get_height(tam)))
	var paginas: Array[Dictionary] = []
	for l in lineas:
		var l_texto: String = l.texto
		var ancho := ancho_base - (ancho_retrato if retratos.has(l.nombre) else 0)
		var renglones := _partir_en_renglones(l_texto, fuente, tam, ancho)
		for i in range(0, renglones.size(), max_lineas):
			var trozo := renglones.slice(i, i + max_lineas)
			paginas.append({ "nombre": l.nombre, "texto": "\n".join(trozo) })
	return paginas


func _partir_en_renglones(t: String, fuente: Font, tam: int, ancho: float) -> PackedStringArray:
	var renglones := PackedStringArray()
	var actual := ""
	for palabra in t.split(" ", false):
		var prueba := palabra if actual.is_empty() else actual + " " + palabra
		if fuente.get_string_size(prueba, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x <= ancho:
			actual = prueba
		else:
			if not actual.is_empty():
				renglones.append(actual)
			actual = palabra
	if not actual.is_empty():
		renglones.append(actual)
	return renglones
