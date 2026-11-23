extends "res://tools/pruebas/base_prueba.gd"
## Sala del jefe (scenes/levels/cueva_jefe.tscn): las estatuas rotas bloquean todo su cuerpo, no
## solo un rectángulo en la base (tools/zonas/medusa/colision_estatuas_arena.py).
## - El cuerpo dibujado de cada estatua (píxeles opacos con vecinos opacos: sin polvo ni
##   trocitos sueltos) no se puede pisar.
## - Desde la entrada se sigue llegando a todo el centro de la losa y a Medusa.

const Explorador := preload("res://tools/zonas/explorador.gd")
const ZONA := "res://scenes/levels/cueva_jefe.tscn"
const PASO := 3.0
## Parte de cada PNG que debe bloquear (px de textura). Lo que no sale aquí es todo el PNG. Lo
## demás (lanza, casco roto, escombros) está tirado en el suelo y se pisa a propósito
## (RECORTE y AREA_MINIMA de colision_estatuas_arena.py).
const CUERPO := {
	&"Estatua2": Rect2(134, 0, 283, 375),
	&"Estatua3": Rect2(255, 0, 130, 437),
}


func ejecutar() -> void:
	tiempo_maximo = 120.0
	var zona := (load(ZONA) as PackedScene).instantiate() as Zona
	var medusa_pos := (zona.get_node(^"Objetos/Jefe/Medusa") as Node2D).global_position
	Explorador.quitar_cuerpos(zona)
	get_tree().root.add_child(zona)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ex := Explorador.new(get_tree().root.get_world_2d().direct_space_state)
	var entrada := (zona.get_node(^"Entradas/desde_cueva") as Node2D).global_position
	var vistos := {}
	ex.recorrer(entrada, Rect2(zona.obtener_limites()), PASO, func(p: Vector2) -> bool:
		vistos[Vector2i((p / PASO).round())] = true
		return false
	, Callable(), true)
	ok("desde la entrada se llega junto a Medusa", _cerca(vistos, medusa_pos + Vector2(0, 40), 6.0))
	var estatuas := zona.find_children("Estatua*", "Decorado", true, false)
	ok("hay 4 estatuas", estatuas.size() == 4, str(estatuas.size()))
	var pisables: Array[String] = []
	for d in estatuas:
		var deco := d as Decorado
		var img := deco.textura.get_image()
		var esc := deco.escala
		var tam := Vector2(img.get_size())
		# el origen del nodo es el `ancla` (los pies); sin ella, el centro de abajo del PNG
		var origen: Vector2 = deco.ancla if deco.ancla != Vector2.ZERO else Vector2(tam.x / 2.0, tam.y)
		var cuerpo: Rect2 = CUERPO.get(StringName(deco.name), Rect2(Vector2.ZERO, tam))
		var paso_px := maxi(int(PASO / esc), 1)
		var dentro := 0
		for y in range(8, img.get_height() - 8, paso_px):
			for x in range(8, img.get_width() - 8, paso_px):
				if not cuerpo.has_point(Vector2(x, y)) or not _solido(img, x, y):
					continue
				var p := deco.global_position + (Vector2(x, y) - origen) * esc
				if _cerca(vistos, p, 0.0):
					dentro += 1
		if dentro > 0:
			pisables.append("%s (%d puntos)" % [deco.name, dentro])
	ok("el cuerpo de las estatuas no se puede pisar", pisables.is_empty(), str(pisables))
	zona.queue_free()


## Opaco con los ocho vecinos (a 6 px) también opacos: cuerpo, no polvo.
func _solido(img: Image, x: int, y: int) -> bool:
	for dy in [-6, 0, 6]:
		for dx in [-6, 0, 6]:
			if img.get_pixel(x + dx, y + dy).a < 0.7:
				return false
	return true


func _cerca(vistos: Dictionary, p: Vector2, radio: float) -> bool:
	var c := Vector2i((p / PASO).round())
	var r := ceili(radio / PASO)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if vistos.has(c + Vector2i(dx, dy)):
				return true
	return false
