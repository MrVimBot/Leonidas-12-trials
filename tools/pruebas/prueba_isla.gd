extends "res://tools/pruebas/base_prueba.gd"
## Isla del nivel 2 con el arte definitivo (scenes/levels/isla.tscn, montada con
## tools/zonas/isla/montar_isla.gd):
## - Recorrido (zona suelta, con la forma del jugador como verificar_zonas.gd): desde la llegada
##   se llega a todos los cofres y a todos los enemigos, y a las dos elevaciones SOLO por sus
##   aberturas (con las aberturas tapadas, ni la «U» ni la elevación del noroeste se alcanzan,
##   pero la cueva sí).
## - Enemigos a ≥ 96 px de las entradas.
## - Cofres (en el juego): dan su premio una vez, se quedan abiertos al volver a la zona y tras
##   guardar/cargar; con el inventario lleno no se abren.
## - Palmera coquera: suelta cocos al golpearla; el coco se recoge y cura como la manzana.

const Explorador := preload("res://tools/zonas/explorador.gd")
const ISLA := "res://scenes/levels/isla.tscn"
const DATOS := "res://tools/zonas/isla/isla_datos.json"
const PASO := 8.0


func ejecutar() -> void:
	tiempo_maximo = 240.0
	await recorrido()
	await cofres_y_cocos()


# --- Recorrido ------------------------------------------------------------------------

func recorrido() -> void:
	var zona := (load(ISLA) as PackedScene).instantiate() as Zona
	var enemigos: Array[Vector2] = []
	for n in zona.find_children("*", "CharacterBody2D", true, false):
		enemigos.append((n as Node2D).position + (n.get_parent() as Node2D).position)
	var elevados := _elevados()
	Explorador.quitar_cuerpos(zona)
	get_tree().root.add_child(zona)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ex := Explorador.new(get_tree().root.get_world_2d().direct_space_state)
	var limites := Rect2(zona.obtener_limites())
	var llegada := (zona.get_node(^"Entradas/desde_orilla") as Node2D).global_position
	var cueva := (zona.get_node(^"Entradas/desde_cueva") as Node2D).global_position

	var libre := _alcanzado(ex, llegada, limites, Callable())
	ok("se llega a la cueva", _cerca(libre, cueva, PASO))
	var cofres := zona.find_children("*", "Cofre", true, false)
	ok("hay 5 cofres", cofres.size() == 5, str(cofres.size()))
	var sin_llegar: Array[String] = []
	for c in cofres:
		if not _cerca(libre, (c as Node2D).global_position, 24.0):
			sin_llegar.append(c.name)
	ok("se llega a todos los cofres", sin_llegar.is_empty(), str(sin_llegar))
	var lejos: Array[Vector2] = []
	for e in enemigos:
		if not _cerca(libre, e, 16.0):
			lejos.append(e)
	ok("se llega a todos los enemigos (%d)" % enemigos.size(), lejos.is_empty(), str(lejos))
	var cerca_entrada: Array[Vector2] = []
	for e in enemigos:
		if e.distance_to(llegada) < 96.0 or e.distance_to(cueva) < 96.0:
			cerca_entrada.append(e)
	ok("ningún enemigo a < 96 px de una entrada", cerca_entrada.is_empty(), str(cerca_entrada))

	# Con las aberturas tapadas no se sube a ninguna elevación.
	var aberturas: Array = _datos().aberturas
	var tapadas := func(p: Vector2) -> bool:
		for a: Array in aberturas:
			if p.distance_to(Vector2(a[0], a[1])) <= float(a[2]):
				return true
		return false
	var cerrado := _alcanzado(ex, llegada, limites, tapadas)
	ok("sin aberturas se sigue llegando a la cueva", _cerca(cerrado, cueva, PASO))
	for nombre: String in elevados:
		ok("sin aberturas no se llega a %s" % nombre, not _cerca(cerrado, elevados[nombre], 12.0)
				and _cerca(libre, elevados[nombre], 12.0))
	get_tree().root.remove_child(zona)
	zona.free()


## Un punto de cada elevación (px de mundo): el cofre del final de la «U» y la cima del noroeste.
func _elevados() -> Dictionary:
	return {"la U (cofre del oeste)": Vector2(41, 800), "la elevación del noroeste": Vector2(620, 440)}


func _datos() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATOS))


func _alcanzado(ex: Explorador, inicio: Vector2, limites: Rect2, bloqueado: Callable) -> Dictionary:
	var vistos := {}
	ex.recorrer(inicio, limites, PASO, func(p: Vector2) -> bool:
		vistos[Vector2i((p / PASO).round())] = true
		return false
	, bloqueado, true)
	vistos[Vector2i((inicio / PASO).round())] = true
	return vistos


func _cerca(vistos: Dictionary, p: Vector2, radio: float) -> bool:
	var c := Vector2i((p / PASO).round())
	var r := ceili(radio / PASO)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if vistos.has(c + Vector2i(dx, dy)):
				return true
	return false


# --- Cofres y cocos (en el juego) -----------------------------------------------------

func cofres_y_cocos() -> void:
	await crear_game(true, true)
	await ir(ISLA, "desde_orilla")
	for e in game.find_children("*", "CharacterBody2D", true, false):
		if e != j and e.get_parent().name == &"Enemigos":
			e.process_mode = Node.PROCESS_MODE_DISABLED
	j.vida.invulnerable_extra = true

	var c1 := game.find_children("Cofre1", "Cofre", true, false)[0] as Cofre
	var c2 := game.find_children("Cofre2", "Cofre", true, false)[0] as Cofre
	var monedas := EstadoJuego.monedas
	ok("Cofre1 da monedas", c1.monedas > 0 and c1.objeto == null)
	c1.interactuar(j)
	await ticks(5)
	ok("abrir bloquea al jugador", j.esta_bloqueado())
	await cerrar_dialogos()
	await ticks(5)
	ok("Cofre1 abierto y monedas sumadas", c1.abierto and EstadoJuego.monedas == monedas + c1.monedas)
	ok("jugador libre tras el aviso", not j.esta_bloqueado())
	c1.interactuar(j)
	await ticks(5)
	ok("un cofre abierto no da más", not Dialogos.abierto and EstadoJuego.monedas == monedas + c1.monedas)

	# Inventario lleno: no se abre.
	var id := c2.objeto.id
	EstadoJuego.agregar_objeto(id, EstadoJuego.maximo(id) - EstadoJuego.cantidad(id))
	c2.interactuar(j)
	await ticks(5)
	await cerrar_dialogos()
	ok("lleno: Cofre2 sigue cerrado", not c2.abierto and not EstadoJuego.cofre_abierto(c2.clave()))
	EstadoJuego.gastar_objeto(id, EstadoJuego.cantidad(id))
	c2.interactuar(j)
	await ticks(5)
	await cerrar_dialogos()
	ok("Cofre2 da su objeto", c2.abierto and EstadoJuego.cantidad(id) == c2.cantidad)

	# Guardar / cargar y volver a la zona.
	var clave := c1.clave()
	ok("clave del cofre", clave == &"isla/Cofre1", String(clave))
	EstadoJuego.guardar(game.datos_guardado())
	EstadoJuego.reiniciar()
	ok("reiniciar cierra los cofres", not EstadoJuego.cofre_abierto(clave))
	EstadoJuego.cargar()
	EstadoJuego.lugar_cargado = null
	ok("cargar los recuerda", EstadoJuego.cofre_abierto(clave) and EstadoJuego.cofre_abierto(c2.clave()))
	await ir(ISLA, "desde_orilla")
	var c1b := game.find_children("Cofre1", "Cofre", true, false)[0] as Cofre
	ok("al volver a la zona sigue abierto", c1b.abierto)

	# Palmera coquera → cocos.
	EstadoJuego.gastar_objeto(EstadoJuego.OBJ_COCO, EstadoJuego.cantidad(EstadoJuego.OBJ_COCO))
	var palmera: Decorado = null
	for n in game.find_children("*", "Decorado", true, false):
		if n.scene_file_path == "res://scenes/entorno/palmera_coquera.tscn":
			palmera = n
			break
	ok("hay palmera coquera", palmera != null)
	ok("en capa interactuable (la ve la espada)", palmera.get_collision_layer_value(Capas.NUMERO_INTERACTUABLE))
	for i in 5:
		palmera.recibir_golpe(1, j.global_position)
	await ticks(2)
	var cocos := palmera.get_parent().get_children().filter(func(n: Node) -> bool:
		return n is ObjetoSuelto and (n as ObjetoSuelto).objeto and (n as ObjetoSuelto).objeto.id == EstadoJuego.OBJ_COCO)
	ok("suelta cocos", not cocos.is_empty(), str(cocos.size()))
	await ticks(120) # que caigan al suelo
	for coco: Node2D in cocos:
		if is_instance_valid(coco):
			j.global_position = coco.global_position
			await ticks(10)
	ok("los cocos se recogen", EstadoJuego.cantidad(EstadoJuego.OBJ_COCO) == cocos.size(),
			"%d de %d" % [EstadoJuego.cantidad(EstadoJuego.OBJ_COCO), cocos.size()])
	j.vida.invulnerable_extra = false
	j.vida.vida = j.vida.vida_max - 6
	var antes := j.vida.vida
	j.comer(EstadoJuego.objeto(EstadoJuego.OBJ_COCO))
	await esperar_hasta(func() -> bool: return j.vida.vida != antes, 240)
	ok("el coco cura 1 corazón", j.vida.vida == antes + 4, "%d → %d" % [antes, j.vida.vida])
	await liberar_game()
