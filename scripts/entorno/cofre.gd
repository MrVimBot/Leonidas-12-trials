@tool
class_name Cofre
extends StaticBody2D
## Cofre que se abre con interactuar (E/L/X del mando) y da su premio una sola vez: monedas,
## un objeto (`objeto` x `cantidad`) o las dos cosas. Se queda abierto para siempre: la clave
## del cofre se apunta en `EstadoJuego.cofres_abiertos` (va en la partida guardada).
##
## Escena: scenes/entorno/cofre.tscn (capas mundo + interactuable, como las vasijas: el
## jugador choca con él y su `ComponenteInteraccion` lo encuentra). La posición del nodo es la
## base del cofre (orden por Y). El dibujo es arte pintado (nivel 2) reducido en el `Visual`.
## `@tool` solo para avisar en el editor de un cofre sin premio.

## Lo da al abrirse (el contador del HUD lo enseña).
@export_range(0, 999) var monedas := 0:
	set(valor):
		monedas = valor
		update_configuration_warnings()
## Objeto que da (resources/objetos/<id>.tres). Vacío = solo monedas.
@export var objeto: Objeto:
	set(valor):
		objeto = valor
		update_configuration_warnings()
@export_range(1, 99) var cantidad := 1
## Clave en la partida. Vacía = «<zona>/<nombre del nodo>» (ver `clave()`): basta con no
## renombrar el nodo después de publicar la demo; si hay que renombrarlo, poner aquí la de antes.
@export var id: StringName
## Dibujos (arte pintado: el `Visual` de la escena lleva la escala y Linear Mipmap).
@export var textura_cerrado: Texture2D
@export var textura_abierto: Texture2D
## Suena al abrirse.
@export var sonido_abrir: AudioStreamPlayer2D

var abierto := false
## Mientras sale el aviso: que una segunda pulsación no lo abra dos veces.
var _abriendo := false

@onready var _visual: Sprite2D = %Visual


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_poner_textura(textura_cerrado)
	if EstadoJuego.cofre_abierto(clave()):
		_poner_abierto()


func _get_configuration_warnings() -> PackedStringArray:
	if monedas == 0 and objeto == null:
		return PackedStringArray(["El cofre no da nada: pon `monedas` o un `objeto`."])
	return PackedStringArray()


## Clave con la que se guarda que está abierto.
func clave() -> StringName:
	if not id.is_empty():
		return id
	var zona := Zona.de(self)
	var nombre_zona := zona.scene_file_path.get_file().get_basename() if zona else ""
	return StringName("%s/%s" % [nombre_zona, name])


## Contrato de interacción (lo llama el `ComponenteInteraccion` del jugador).
func interactuar(quien: Node) -> void:
	if abierto or _abriendo or Dialogos.abierto:
		return
	if objeto and not EstadoJuego.cabe(objeto.id, cantidad):
		await Dialogos.mostrar_texto("No puedes llevar más.")
		return
	_abriendo = true
	_poner_abierto()
	EstadoJuego.marcar_cofre_abierto(clave())
	if sonido_abrir:
		sonido_abrir.play()
	if monedas > 0:
		EstadoJuego.agregar_monedas(monedas)
	if objeto:
		EstadoJuego.agregar_objeto(objeto.id, cantidad)
	var jugador := quien as Jugador
	if jugador:
		# Bloqueo propio: entre el aviso y la pose no debe moverse (ver «Bloqueo por motivos»).
		jugador.bloquear(&"escena")
		if objeto:
			jugador.mostrar_objeto_obtenido(objeto.icono, 0.0)
	await Dialogos.mostrar_texto(texto_premio())
	if jugador and is_instance_valid(jugador):
		jugador.ocultar_objeto_obtenido()
		jugador.desbloquear(&"escena")
	_abriendo = false


## «¡Obtuviste Coco x2 y 10 monedas!»
func texto_premio() -> String:
	var partes: PackedStringArray = []
	if objeto:
		partes.append(objeto.nombre if cantidad == 1 else "%s x%d" % [objeto.nombre, cantidad])
	if monedas > 0:
		partes.append("%d moneda%s" % [monedas, "" if monedas == 1 else "s"])
	return "¡Obtuviste %s!" % " y ".join(partes)


func _poner_abierto() -> void:
	abierto = true
	_poner_textura(textura_abierto)


## Las dos texturas no miden lo mismo: la base del dibujo queda siempre en el origen.
func _poner_textura(t: Texture2D) -> void:
	if t == null:
		return
	_visual.texture = t
	_visual.centered = false
	_visual.offset = Vector2(-t.get_width() / 2.0, -t.get_height())
