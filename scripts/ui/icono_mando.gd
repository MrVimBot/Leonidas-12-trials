class_name IconoMando
extends TextureRect
## Icono de un botón del mando de PS5 (plugin Controller Icons). Escena `scenes/ui/icono_mando.tscn`.
##
## `ruta` es una acción del mapa de entradas (`atacar`, `pirueta`…): el icono sale del botón que
## tiene asignado en el mando, así que si se cambia el mapa se actualiza solo. Para lo que el
## plugin no sabe dibujar o no es una acción (el touchpad, Círculo = volver) se pone una ruta
## directa a sus iconos: `ps5/touch_pad`, `ps5/circle`…
##
## Siempre se dibuja el estilo PS5 y el del mando (nunca el del teclado), aunque la persona
## esté usando otro mando o el teclado: es el tipo que eligió en «Tipo de entrada». Los
## iconos del plugin son de 100×100 px, así que el nodo los dibuja con filtro lineal y
## mipmaps (sus `.import` los generan) para que a ~20 px no salgan con dientes; el resto del
## juego va con filtro Nearest.

## Acción (`atacar`) o ruta directa de iconos (`ps5/touch_pad`).
@export var ruta := "":
	set(valor):
		ruta = valor
		if is_node_ready():
			_poner_icono()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_poner_icono()


func _poner_icono() -> void:
	if ruta.is_empty():
		texture = null
		return
	var icono := ControllerIconTexture.new()
	icono.force_type = ControllerIconTexture.ForceType.CONTROLLER
	icono.force_controller_icon_style = ControllerSettings.Devices.PS5
	icono.path = ruta
	texture = icono
