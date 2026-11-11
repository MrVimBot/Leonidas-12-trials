extends RefCounted
## Ayudante para los generadores de zonas (tools/build_zonas.gd). Encapsula lo que
## tools/build_pueblo.gd hace a mano: crea la estructura de una Zona, pinta el suelo,
## coloca decorados, entradas, salidas y límites, y guarda la escena conservando su UID.
##
## Uso:
##   const Constructor := preload("res://tools/zonas/constructor_zona.gd")
##   var z := Constructor.new("Bosque", "Bosque", 64, 56, 21)
##   z.rect([0, 0, 63, 55], Constructor.PASTO)
##   ...
##   z.guardar("res://scenes/levels/bosque.tscn")
##
## Coordenadas: rectángulos de tiles [col0, fila0, col1, fila1] inclusivos; posiciones de
## objetos en píxeles del mundo (la base del objeto, como los pies del jugador).
## Todo es determinista: misma semilla → misma escena.

# Tiles del atlas naturaleza (fuente 0 de resources/tilesets/naturaleza.tres).
const PASTO := Vector2i(0, 0)
const SETO := Vector2i(12, 0)
const AGUA := Vector2i(16, 0)
const MAR := Vector2i(19, 0)
const MAR_ORILLA := Vector2i(0, 1)
const ARENA := Vector2i(3, 1)
const ARENA_PIEDRAS := Vector2i(1, 1)
const BALDOSA := Vector2i(6, 1)
# Tiles del atlas provisional (resources/tilesets/provisional.tres).
const SUELO_CUEVA := Vector2i(0, 0)
const SUELO_CUEVA_B := Vector2i(1, 0)
const PARED_CUEVA := Vector2i(2, 0)
const VACIO := Vector2i(3, 0)
const MAR_NAV := Vector2i(4, 0)
const MAR_NAV_OLA := Vector2i(5, 0)
const LOSA_JEFE := Vector2i(6, 0)
const MUELLE := Vector2i(7, 0)
const ARRECIFE := Vector2i(8, 0)

## Tiles de naturaleza donde dispersar() no pone nada (caminos, agua, mar, orillas).
const OCUPADOS := [ARENA, ARENA_PIEDRAS, AGUA, Vector2i(17, 0), Vector2i(18, 0), MAR, MAR_ORILLA,
	Vector2i(17, 1), Vector2i(18, 1), Vector2i(19, 1), BALDOSA, Vector2i(4, 1), Vector2i(5, 1)]

const DIR_ENTORNO := "res://assets/sprites/entorno/"
const DIR_ZONAS := "res://scenes/levels/"
const DISTANCIA_LIBRE := 48.0 # dispersar() no pone nada a menos de esto de entradas y salidas

var raiz: Node2D
var suelo: TileMapLayer
var suelo_prov: TileMapLayer
var objetos: Node2D
var entradas: Node2D
var limites: StaticBody2D
var ancho: int
var alto: int
var semilla: int

var _rng := RandomNumberGenerator.new()
var _decorado: PackedScene
var _reservas: Array = [] # [Vector2 centro, float radio]
var _contador := {} # nombre base → último número usado


func _init(nodo: String, nombre_zona: String, ancho_tiles: int, alto_tiles: int, semilla_zona: int) -> void:
	ancho = ancho_tiles
	alto = alto_tiles
	semilla = semilla_zona
	_rng.seed = semilla_zona
	_decorado = load("res://scenes/entorno/decorado.tscn")

	raiz = Node2D.new()
	raiz.name = nodo
	raiz.y_sort_enabled = true
	raiz.set_script(load("res://scripts/systems/zona.gd"))
	raiz.set("nombre_zona", nombre_zona)
	raiz.set("limites_camara", Rect2i(0, 0, ancho * 16, alto * 16))

	suelo = TileMapLayer.new()
	suelo.name = "Suelo"
	suelo.z_index = -1
	suelo.tile_set = load("res://resources/tilesets/naturaleza.tres")
	_agregar(raiz, suelo)
	raiz.set("suelo", suelo)

	suelo_prov = TileMapLayer.new()
	suelo_prov.name = "SueloProvisional"
	suelo_prov.z_index = -1
	suelo_prov.tile_set = load("res://resources/tilesets/provisional.tres")
	_agregar(raiz, suelo_prov)

	objetos = _nodo_ysort(raiz, "Objetos")

	entradas = Node2D.new()
	entradas.name = "Entradas"
	_agregar(raiz, entradas)

	limites = StaticBody2D.new()
	limites.name = "Limites"
	limites.collision_layer = 1
	limites.collision_mask = 0
	_agregar(raiz, limites)


# --- Suelo -------------------------------------------------------------------

## Pinta el rectángulo de tiles `r` con `tile`. Con `prov` pinta en SueloProvisional y
## borra esas celdas de Suelo (y al revés), para que nunca quede un tile sólido debajo.
## Con `variante`/`prob` cada celda pasa a ser `variante` con esa probabilidad.
func rect(r: Array, tile: Vector2i, prov := false, variante := Vector2i(-1, -1), prob := 0.0) -> void:
	for f in range(maxi(r[1], 0), mini(r[3], alto - 1) + 1):
		for c in range(maxi(r[0], 0), mini(r[2], ancho - 1) + 1):
			_poner(Vector2i(c, f), tile, prov, variante, prob)


## Rellena las celdas con ((c-cx)/rx)² + ((f-cy)/ry)² ≤ 1.
func elipse(centro: Vector2i, radios: Vector2, tile: Vector2i, prov := false) -> void:
	for f in alto:
		for c in ancho:
			var d := Vector2((c - centro.x) / radios.x, (f - centro.y) / radios.y)
			if d.length_squared() <= 1.0:
				_poner(Vector2i(c, f), tile, prov)


## Anillo de `grosor` tiles en el borde del mapa.
func marco(grosor: int, tile: Vector2i, prov := false) -> void:
	rect([0, 0, ancho - 1, grosor - 1], tile, prov)
	rect([0, alto - grosor, ancho - 1, alto - 1], tile, prov)
	rect([0, 0, grosor - 1, alto - 1], tile, prov)
	rect([ancho - grosor, 0, ancho - 1, alto - 1], tile, prov)


func _poner(celda: Vector2i, tile: Vector2i, prov: bool, variante := Vector2i(-1, -1), prob := 0.0) -> void:
	var t := tile
	if variante != Vector2i(-1, -1) and _rng.randf() < prob:
		t = variante
	if prov:
		suelo_prov.set_cell(celda, 0, t)
		suelo.erase_cell(celda)
	else:
		suelo.set_cell(celda, 0, t)
		suelo_prov.erase_cell(celda)


## true si en `pos` (mundo) hay camino, agua, mar o cualquier tile provisional.
func suelo_ocupado(pos: Vector2) -> bool:
	var celda := Vector2i(floori(pos.x / 16.0), floori(pos.y / 16.0))
	if suelo_prov.get_cell_source_id(celda) != -1:
		return true
	return suelo.get_cell_atlas_coords(celda) in OCUPADOS


# --- Objetos -------------------------------------------------------------------

## Instancia decorado.tscn bajo Objetos/<grupo>. `textura` es relativa a
## assets/sprites/entorno/ sin ".png" (admite "provisional/palmera").
## `op`: propiedades del Decorado (solido, sombra, base, desplazamiento_base...).
func deco(grupo: String, textura: String, pos: Vector2, op := {}) -> Node2D:
	var d := _decorado.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D
	d.name = _nombre_nuevo(textura.get_file().to_pascal_case())
	d.position = pos.round()
	_agregar(_grupo(grupo), d)
	d.set("textura", load(DIR_ENTORNO + textura + ".png"))
	for clave in op:
		d.set(clave, op[clave])
	return d


## Rejilla al tresbolillo (paso `paso`, desplazamiento aleatorio ±8, ±5 px) dentro del
## rectángulo de tiles `r_tiles`, con texturas al azar de `texturas`. Se salta las
## posiciones sobre camino/agua/mar/tiles provisionales (debajo, 40 px por encima o a
## los lados) y las cercanas a entradas, salidas o zonas reservadas.
func dispersar(grupo: String, texturas: Array, r_tiles: Array, paso: Vector2, op := {}) -> int:
	var a := Vector2(r_tiles[0] * 16 + 8, r_tiles[1] * 16 + 8)
	var b := Vector2(r_tiles[2] * 16 + 8, r_tiles[3] * 16 + 8)
	var n := 0
	var y := a.y
	var fila := 0
	while y <= b.y:
		var x := a.x + (paso.x / 2.0 if fila % 2 else 0.0)
		while x <= b.x:
			var pos := (Vector2(x, y) + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-5, 5))).round()
			var textura: String = texturas[_rng.randi() % texturas.size()]
			x += paso.x
			if _hay_algo(pos, textura):
				continue
			deco(grupo, textura, pos, op)
			n += 1
		y += paso.y
		fila += 1
	return n


func _hay_algo(pos: Vector2, textura: String) -> bool:
	# A los lados: al menos 16 px, o lo que mide media base del objeto (80 % del ancho).
	var tex := load(DIR_ENTORNO + textura + ".png") as Texture2D
	var lado := maxf(16.0, tex.get_width() * 0.4 + 4.0) if tex else 16.0
	for d in [Vector2.ZERO, Vector2(0, -40), Vector2(-lado, 0), Vector2(lado, 0)]:
		if suelo_ocupado(pos + d):
			return true
	for r in _reservas:
		if pos.distance_to(r[0]) < r[1]:
			return true
	return false


## dispersar() no pondrá nada a menos de `radio` px de `pos`.
func reservar(pos: Vector2, radio: float) -> void:
	_reservas.append([pos, radio])


## Reserva un rectángulo de tiles entero (lo cubre con círculos de 24 px de radio).
func reservar_rect(r: Array) -> void:
	for f in range(r[1], r[3] + 1, 2):
		for c in range(r[0], r[2] + 1, 2):
			reservar(Vector2(c * 16 + 16, f * 16 + 16), 24.0)


## Instancia una escena (enemigos...) bajo Objetos/<grupo> y reserva su sitio.
func instancia(grupo: String, ruta_escena: String, pos: Vector2) -> Node:
	var escena := load(ruta_escena) as PackedScene
	var n := escena.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	n.name = _nombre_nuevo(ruta_escena.get_file().get_basename().to_pascal_case())
	if n is Node2D:
		n.position = pos.round()
	_agregar(_grupo(grupo), n)
	reservar(pos, 40.0)
	return n


## Cartel con ZonaDialogo (como _poner_cartel de build_pueblo.gd).
func cartel(pos: Vector2, ruta_dialogo: String) -> Node2D:
	var c := deco("Carteles", "cartel", pos)
	var zona := Area2D.new()
	zona.name = "ZonaDialogo"
	zona.set_script(load("res://scripts/componentes/zona_dialogo.gd"))
	_agregar(c, zona)
	zona.set("dialogo", load(ruta_dialogo))
	zona.set("posicion_burbuja", Vector2(0, -42))
	var forma := CollisionShape2D.new()
	forma.name = "Forma"
	forma.position = Vector2(0, -18)
	var r := RectangleShape2D.new()
	r.size = Vector2(30, 36)
	forma.shape = r
	_agregar(zona, forma)
	reservar(pos, 40.0)
	return c


# --- Entradas, salidas, límites y marcadores ---------------------------------------

## Marker2D en Entradas. La primera también crea "inicio" en el mismo sitio.
func entrada(nombre: String, pos: Vector2) -> void:
	if entradas.get_child_count() == 0 and nombre != "inicio":
		_marcador(entradas, "inicio", pos)
	_marcador(entradas, nombre, pos)
	reservar(pos, DISTANCIA_LIBRE)


## SalidaZona (Area2D) con una forma rectangular. `zona_destino` es el nombre corto
## ("playa" → res://scenes/levels/playa.tscn).
func salida(nombre: String, centro: Vector2, tamano: Vector2, zona_destino: String, entrada_destino: String) -> void:
	var s := Area2D.new()
	s.name = nombre
	s.set_script(load("res://scripts/systems/salida_zona.gd"))
	s.position = centro
	_agregar(raiz, s)
	s.set("zona_destino", DIR_ZONAS + zona_destino + ".tscn")
	s.set("entrada_destino", entrada_destino)
	var forma := CollisionShape2D.new()
	forma.name = "Forma"
	var r := RectangleShape2D.new()
	r.size = tamano
	forma.shape = r
	_agregar(s, forma)
	reservar(centro, DISTANCIA_LIBRE)


## Pared invisible (rectángulo en píxeles del mundo).
func limite(nombre: String, r: Rect2) -> void:
	var forma := CollisionShape2D.new()
	forma.name = nombre
	forma.position = r.get_center()
	var rr := RectangleShape2D.new()
	rr.size = r.size
	forma.shape = rr
	_agregar(limites, forma)


## Marker2D hijo de la raíz: puntos para tareas futuras (barco, mecanismo, jefe...).
func marcador(nombre: String, pos: Vector2) -> void:
	_marcador(raiz, nombre, pos)


# --- Guardar -------------------------------------------------------------------------

func guardar(ruta: String) -> Error:
	if suelo.get_used_cells().size() > 0:
		var variador := Node.new()
		variador.name = "VariadorPasto"
		variador.set_script(load("res://scripts/entorno/variador_pasto.gd"))
		_agregar(raiz, variador)
		variador.set("capa", suelo)
		variador.set("semilla", semilla)
		variador.call("variar")
	var escena := PackedScene.new()
	var err := escena.pack(raiz)
	if err != OK:
		push_error("No se pudo empaquetar %s (error %d)" % [ruta, err])
		raiz.free()
		return err
	var uid_anterior := ResourceLoader.get_resource_uid(ruta) if FileAccess.file_exists(ruta) else ResourceUID.INVALID_ID
	err = ResourceSaver.save(escena, ruta)
	if err != OK:
		push_error("No se pudo guardar %s (error %d)" % [ruta, err])
	else:
		# Conservar el UID anterior (las referencias por UID siguen valiendo) o dar uno nuevo.
		ResourceSaver.set_uid(ruta, uid_anterior if uid_anterior != ResourceUID.INVALID_ID else ResourceUID.create_id())
	raiz.free()
	return err


# --- Internos ------------------------------------------------------------------------

func _agregar(padre: Node, hijo: Node) -> void:
	padre.add_child(hijo, true)
	hijo.owner = raiz


func _nodo_ysort(padre: Node, nombre: String) -> Node2D:
	var n := Node2D.new()
	n.name = nombre
	n.y_sort_enabled = true
	_agregar(padre, n)
	return n


func _grupo(nombre: String) -> Node2D:
	var g := objetos.get_node_or_null(nombre) as Node2D
	return g if g else _nodo_ysort(objetos, nombre)


func _nombre_nuevo(base: String) -> String:
	_contador[base] = _contador.get(base, 0) + 1
	return "%s%d" % [base, _contador[base]]


func _marcador(padre: Node, nombre: String, pos: Vector2) -> void:
	var m := Marker2D.new()
	m.name = nombre
	m.position = pos
	_agregar(padre, m)
