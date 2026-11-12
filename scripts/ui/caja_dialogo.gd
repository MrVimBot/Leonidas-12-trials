class_name CajaDialogo
extends CanvasLayer
## Cuadro de diálogo del juego. Es un AUTOLOAD llamado `Dialogos`
## (scenes/ui/caja_dialogo.tscn), así que se usa desde cualquier script:
##
##   await Dialogos.mostrar(preload("res://resources/dialogues/sabios.tres"))
##   await Dialogos.mostrar_texto("Kathita: ¡Leonidas, despierta!")
##
## `await` espera a que el jugador termine de leer. Mientras está abierto, el jugador
## queda bloqueado. E / J (o B / X en mando) avanzan; si el texto aún se está
## escribiendo, la primera pulsación lo completa.
##
## Retratos (lámina "Interfaz interacción con NPCs" de Jugabilidad.pdf): solo los
## personajes importantes tienen cara en el cuadro. Se asignan en `retratos`
## (nombre tal como sale en el diálogo → textura de unos 46×46). Sin retrato, el texto
## ocupa todo el ancho.

signal empezo
signal termino

## Velocidad del efecto máquina de escribir.
@export var letras_por_segundo := 40.0
## Parpadeo de la flecha de continuar (segundos por estado).
@export var parpadeo_flecha := 0.4
## Nombre del personaje → retrato (Texture2D). Ej.: {"Kathita": preload(...)}.
@export var retratos: Dictionary = {}
## Espacio que ocupa el retrato a la izquierda del texto (ancho + separación).
@export var ancho_retrato := 50

var abierto := false
## Una escena con varios diálogos seguidos lo pone en true para que el jugador no
## recupere el control entre uno y otro; al acabar, la escena lo vuelve a poner en
## false y desbloquea al jugador ella misma (`desbloquear_jugador()`).
var mantener_bloqueo := false

var _paginas: Array[Dictionary] = []
var _indice := 0
var _escribiendo := false
var _letras := 0.0
var _frame_apertura := -1

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
	if abierto or lineas.is_empty():
		return
	_paginas = _paginar(lineas)
	_indice = 0
	abierto = true
	_frame_apertura = Engine.get_process_frames()
	_bloquear_jugador(true)
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

	# La misma pulsación que abrió el diálogo (hablar con alguien) no debe avanzarlo.
	if Engine.get_process_frames() == _frame_apertura:
		return
	if Input.is_action_just_pressed(&"interactuar") or Input.is_action_just_pressed(&"atacar"):
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


## La fuente DOS (perfect_dos_vga_437_win.ttf) no tiene Á Í Ó Ú mayúsculas:
## se muestran sin tilde, como se hacía en mayúsculas antes.
const SIN_GLIFO := { "Á": "A", "Í": "I", "Ó": "O", "Ú": "U" }


static func adaptar_a_fuente(t: String) -> String:
	for c in SIN_GLIFO:
		t = t.replace(c, SIN_GLIFO[c])
	return t


func _mostrar_pagina() -> void:
	var p := _paginas[_indice]
	var cara: Texture2D = retratos.get(p.nombre)
	retrato.texture = cara
	retrato.visible = cara != null
	texto.position.x = _texto_x + (ancho_retrato if cara else 0)
	texto.size.x = _texto_ancho - (ancho_retrato if cara else 0)
	nombre.text = adaptar_a_fuente(p.nombre)
	texto.text = adaptar_a_fuente(p.texto)
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
	termino.emit()
	# Esperar a que pase la pulsación de cerrar: si no, el jugador la leería como
	# "interactuar" y volvería a abrir la conversación.
	await get_tree().process_frame
	await get_tree().physics_frame
	if not abierto and not mantener_bloqueo:
		_bloquear_jugador(false)


## Para quien usó `mantener_bloqueo`: devuelve el control al jugador.
func desbloquear_jugador() -> void:
	mantener_bloqueo = false
	if not abierto:
		_bloquear_jugador(false)


func _bloquear_jugador(bloquear: bool) -> void:
	var jugador := get_tree().get_first_node_in_group(&"jugador")
	if jugador and jugador.has_method(&"set_bloqueado"):
		jugador.set_bloqueado(bloquear)


## Parte cada línea en páginas que quepan en el área de texto (ancho y nº de líneas).
func _paginar(lineas: Array[Dictionary]) -> Array[Dictionary]:
	var fuente := texto.get_theme_font(&"font")
	var tam := texto.get_theme_font_size(&"font_size")
	var ancho_base: float = _texto_ancho
	var max_lineas := maxi(1, floori(texto.size.y / fuente.get_height(tam)))
	var paginas: Array[Dictionary] = []
	for l in lineas:
		var ancho := ancho_base - (ancho_retrato if retratos.has(l.nombre) else 0)
		var renglones := _partir_en_renglones(l.texto, fuente, tam, ancho)
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
