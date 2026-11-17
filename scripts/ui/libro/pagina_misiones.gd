class_name PaginaMisiones
extends PaginaLibro
## Página de Misiones del libro: 3 renglones de misiones principales y 3 de secundarias
## (hijos de %Renglones, en ese orden, cada uno con su raya `Tachado`). Las completadas
## salen en gris y tachadas. No tiene cursor propio.

## Tinta de las misiones completadas (el color de la raya está en la escena: `Tachado`).
const TINTA_GRIS := Color(0.11, 0.13, 0.33, 0.45)
const POR_GRUPO := 3

var _renglones: Array[Label] = []
var _tachados: Array[ColorRect] = []


func _ready() -> void:
	_renglones.assign(%Renglones.get_children())
	for renglon in _renglones:
		_tachados.append(renglon.get_node(^"Tachado") as ColorRect)


func refrescar() -> void:
	var principales: Array[StringName] = []
	var secundarias: Array[StringName] = []
	for id in EstadoJuego.misiones:
		var m := EstadoJuego.mision(id)
		if m == null:
			continue
		(principales if m.principal else secundarias).append(id)
	var ids: Array[StringName] = []
	_rellenar(ids, principales)
	_rellenar(ids, secundarias)
	var fuente := get_theme_default_font()
	var letra := get_theme_default_font_size()
	for i in ids.size():
		var l := _renglones[i]
		var raya := _tachados[i]
		var id := ids[i]
		var m := EstadoJuego.mision(id) if id != &"" else null
		l.text = m.titulo if m else ""
		var hecha := m != null and EstadoJuego.mision_completada(id)
		if hecha:
			l.add_theme_color_override(&"font_color", TINTA_GRIS)
		else:
			l.remove_theme_color_override(&"font_color")
		raya.visible = hecha
		if hecha:
			# La raya (hija del renglón) tacha solo el texto escrito.
			var ancho := minf(fuente.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, letra).x,
				l.size.x)
			raya.size = Vector2(ancho, 1)


## Añade a `ids` los `POR_GRUPO` primeros de `grupo` (&"" = renglón vacío).
static func _rellenar(ids: Array[StringName], grupo: Array[StringName]) -> void:
	for i in POR_GRUPO:
		ids.append(grupo[i] if i < grupo.size() else &"")
