@tool
class_name BosqueDenso
extends StaticBody2D
## Bosque cerrado que no se puede atravesar (manchas rojas del layout del nivel 2): un polígono
## sólido (`Forma`, CollisionPolygon2D hijo, en la capa mundo) lleno de árboles pintados.
##
## Uso (scenes/entorno/bosque_denso.tscn): instanciarlo dentro de `Objetos` (y_sort), dibujar el
## contorno en el editor 2D con los puntos de `Forma` y pulsar «Poblar» en el Inspector. Los
## árboles se guardan en la escena como `Sprite2D` hijos de `Arboles` (y_sort: se ordenan por Y
## con Leonidas, que pasa por delante y por detrás de las copas del borde). Misma `semilla` =
## mismo bosque; cambiarla y volver a pulsar para otro reparto. Los árboles no tienen colisión
## propia: la pone el polígono. La posición de cada árbol es la base del tronco.
##
## No es un TileMap ni una MultiMesh: son pocos cientos de árboles grandes y distintos, y así
## se pueden mover o borrar a mano en el editor si alguno estorba.

## Dibujos entre los que elige (arte pintado del nivel 2).
@export var texturas: Array[Texture2D] = []
## Alto de cada árbol en px de mundo, al azar en este intervalo.
@export var alto_min := 80.0
@export var alto_max := 110.0
## Distancia media entre árboles (px de mundo). Rejilla al tresbolillo con desplazamiento al azar.
@export var separacion := Vector2(44, 30)
@export var semilla := 1
## Rellena el polígono de árboles (borra los que hubiera).
@export_tool_button("Poblar") var _boton_poblar := poblar

## Reparte árboles por el polígono de `Forma`. Pensado para el editor (los árboles quedan con
## la escena editada como dueño); funciona también fuera del árbol de escena (así lo usa
## tools/zonas/isla/montar_isla.gd, que les pone el dueño después).
func poblar() -> void:
	var forma := get_node(^"Forma") as CollisionPolygon2D
	var arboles := get_node(^"Arboles") as Node2D
	for h in arboles.get_children():
		arboles.remove_child(h)
		h.queue_free()
	if texturas.is_empty() or forma.polygon.size() < 3:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var poligono := forma.transform * forma.polygon
	var caja := _caja(poligono)
	var fila := 0
	var y := caja.position.y + separacion.y * 0.5
	while y < caja.end.y:
		var x := caja.position.x + (separacion.x * 0.5 if fila % 2 else 0.0)
		while x < caja.end.x:
			var p := Vector2(x, y) + Vector2(rng.randf_range(-0.35, 0.35) * separacion.x,
					rng.randf_range(-0.35, 0.35) * separacion.y)
			if Geometry2D.is_point_in_polygon(p, poligono):
				_plantar(arboles, p.round(), rng)
			x += separacion.x
		y += separacion.y
		fila += 1


func _plantar(arboles: Node2D, p: Vector2, rng: RandomNumberGenerator) -> void:
	var t := texturas[rng.randi() % texturas.size()]
	var s := Sprite2D.new()
	s.name = "Arbol%d" % (arboles.get_child_count() + 1)
	s.texture = t
	s.centered = false
	s.offset = Vector2(-t.get_width() / 2.0, -t.get_height())
	var escala := rng.randf_range(alto_min, alto_max) / t.get_height()
	s.scale = Vector2(escala, escala)
	s.flip_h = rng.randf() < 0.5
	s.position = p
	arboles.add_child(s, true)
	if Engine.is_editor_hint() and is_inside_tree() and get_tree().edited_scene_root:
		s.owner = get_tree().edited_scene_root


func _caja(poligono: PackedVector2Array) -> Rect2:
	var r := Rect2(poligono[0], Vector2.ZERO)
	for p in poligono:
		r = r.expand(p)
	return r
