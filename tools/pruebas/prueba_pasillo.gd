extends "res://tools/pruebas/base_prueba.gd"
## Pasillo de Medusa con el arte definitivo (scenes/levels/cueva_medusa.tscn). La colisión sale
## de los trazos de la diseñadora (tools/zonas/pasillo/calcular_colision.py): Leonidas no puede
## pisar lo que dibujan los cristales, las estatuas ni las rocas de abajo, y aun así llega de
## una salida a la otra y a todos los enemigos.
## - Recorrido con la forma del jugador (zona suelta, como verificar_zonas.gd).
## - Ningún píxel dibujado de un pilar, estatua o roca es alcanzable.
## - Los enemigos están en suelo libre y a ≥ 96 px de las entradas.

const Explorador := preload("res://tools/zonas/explorador.gd")
const ZONA := "res://scenes/levels/cueva_medusa.tscn"
const PASO := 4.0
const PREFIJOS := ["pasillo_cristal", "pasillo_estatua", "pasillo_rocas"]


func ejecutar() -> void:
	tiempo_maximo = 120.0
	var zona := (load(ZONA) as PackedScene).instantiate() as Zona
	var enemigos: Array[Vector2] = []
	for n in zona.find_children("*", "CharacterBody2D", true, false):
		enemigos.append((n as Node2D).position + (n.get_parent() as Node2D).position)
	Explorador.quitar_cuerpos(zona)
	get_tree().root.add_child(zona)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ex := Explorador.new(get_tree().root.get_world_2d().direct_space_state)
	var limites := Rect2(zona.obtener_limites())
	var izquierda := (zona.get_node(^"Entradas/desde_isla") as Node2D).global_position
	var derecha := (zona.get_node(^"Entradas/desde_jefe") as Node2D).global_position

	var vistos := {}
	ex.recorrer(izquierda, limites, PASO, func(p: Vector2) -> bool:
		vistos[Vector2i((p / PASO).round())] = true
		return false
	, Callable(), true)
	ok("de la entrada izquierda se llega a la derecha", _cerca(vistos, derecha, PASO))
	for nombre in ["SalidaIsla", "SalidaJefe"]:
		var area := zona.get_node(NodePath(nombre)) as Node2D
		var hueco := area.get_node(^"Forma") as CollisionShape2D
		var r := (hueco.shape as RectangleShape2D).size
		var dentro := false
		for dy in range(int(-r.y / 2.0), int(r.y / 2.0) + 1, 4):
			for dx in range(int(-r.x / 2.0), int(r.x / 2.0) + 1, 4):
				if vistos.has(Vector2i(((area.global_position + Vector2(dx, dy)) / PASO).round())):
					dentro = true
		ok("se llega a %s" % nombre, dentro)
	var perdidos: Array[Vector2] = []
	for e in enemigos:
		if not _cerca(vistos, e, 8.0):
			perdidos.append(e)
	ok("los %d enemigos están en suelo libre" % enemigos.size(), perdidos.is_empty(), str(perdidos))
	var cerca: Array[Vector2] = []
	for e in enemigos:
		if e.distance_to(izquierda) < 96.0 or e.distance_to(derecha) < 96.0:
			cerca.append(e)
	ok("ningún enemigo a < 96 px de una entrada", cerca.is_empty(), str(cerca))

	# Lo dibujado de pilares, estatuas y rocas no se puede pisar.
	var objetos := 0
	var pisables: Array[String] = []
	for d in zona.find_children("*", "Decorado", true, false):
		var deco := d as Decorado
		if deco.textura == null or not _es_pilar(deco.textura.resource_path):
			continue
		objetos += 1
		var img := deco.textura.get_image()
		var esc := deco.escala
		var tam := Vector2(img.get_size())
		var paso_px := int(PASO / esc)
		var dentro := 0
		var donde := []
		for y in range(0, img.get_height(), paso_px):
			for x in range(0, img.get_width(), paso_px):
				if img.get_pixel(x, y).a < 0.5:
					continue
				var p := deco.global_position + Vector2((x - tam.x / 2.0) * esc, (y - tam.y) * esc)
				if _cerca(vistos, p, 0.0):
					dentro += 1
					donde.append(p.round())
		if dentro > 0:
			pisables.append("%s (%d puntos) %s" % [deco.name, dentro, donde.slice(0, 4)])
	ok("hay 9 pilares, estatuas y rocas", objetos == 9, str(objetos))
	ok("nada de lo dibujado en ellos se puede pisar", pisables.is_empty(), str(pisables))
	zona.queue_free()


func _es_pilar(ruta: String) -> bool:
	for p in PREFIJOS:
		if ruta.contains(p):
			return true
	return false


func _cerca(vistos: Dictionary, p: Vector2, radio: float) -> bool:
	var c := Vector2i((p / PASO).round())
	var r := ceili(radio / PASO)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if vistos.has(c + Vector2i(dx, dy)):
				return true
	return false
