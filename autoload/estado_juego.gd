extends Node
## Estado global de la partida que sobrevive a los cambios de zona.
## Autoload: se accede desde cualquier script como `EstadoJuego`.
##   EstadoJuego.agregar_monedas(5)
##   if EstadoJuego.gastar_monedas(10): ...
##   EstadoJuego.agregar_objeto(&"manzana")      # o el atajo agregar_manzanas(1)
##   EstadoJuego.empezar_mision(&"derrotar_medusa")
## Morir no quita nada; `reiniciar()` (al pulsar Jugar en el menú) lo pone todo a cero.
## `guardar()` / `cargar()` lo escriben/leen en user://partida.cfg (página Guardar del libro
## y opción Continuar del menú principal).
##
## Objetos: `objetos` = id → cantidad, en el orden en que se consiguieron. Cada id tiene su
## recurso en resources/objetos/<id>.tres (`Objeto`: nombre, icono, tipo, máximo...).
## `tiene_libro`, `tiene_espada` y `manzanas` son atajos sobre `objetos`.

signal monedas_cambio(monedas: int)
signal manzanas_cambio(manzanas: int)
signal objetos_cambio(id: StringName, cantidad: int)
signal misiones_cambio

const MONEDAS_MAX := 999
const MANZANAS_MAX := 9
const RUTA_OBJETOS := "res://resources/objetos/%s.tres"
const RUTA_MISIONES := "res://resources/misiones/%s.tres"
const ARCHIVO_PARTIDA := "user://partida.cfg"

enum EstadoMision { ACTIVA, COMPLETADA }

var monedas := 0
## id → cantidad (solo los que se tienen; en el orden en que se consiguieron).
var objetos: Dictionary[StringName, int] = {}
## id → EstadoMision (en el orden en que empezaron).
var misiones: Dictionary[StringName, int] = {}
## El tutorial del barco (y la calibración del micrófono) sale solo la primera vez.
var tutorial_barco_visto := false
## La activan los sabios del templo (misión + espada). Hasta entonces Zeus no deja
## salir del pueblo (`BarreraMision` en sus puertas).
var mision_recibida := false
## Kathita le enseña la voltereta al salir de casa; hasta que la hace una vez, una
## `BarreraMision` (requisito VOLTERETA) no le deja alejarse del cartel.
var voltereta_aprendida := false
## Cuántas veces ha detenido Zeus a Leonidas en una puerta (la 1.ª, diálogo largo).
var avisos_zeus := 0
## Segundos de juego (solo cuentan con Game en marcha y sin pausa: ver `contando_tiempo`).
var tiempo_jugado := 0.0
var jefes_derrotados := 0
## Lo pone Game mientras existe: el menú y la cinemática no cuentan como tiempo jugado.
var contando_tiempo := false

## Al cargar una partida: zona y entrada donde debe empezar Game (y la vida). Game las
## consume en su _ready (vuelven a "" / -1).
var zona_cargada := ""
var entrada_cargada := ""
var vida_cargada := -1

## El libro que le regala Kathita al salir de casa: es el inventario (objetos), el mapa
## y el guardado de la partida. El HUD solo muestra su icono cuando se tiene.
var tiene_libro: bool:
	get:
		return cantidad(&"libro") > 0
	set(valor):
		_poner(&"libro", 1 if valor else 0)

## La dan los sabios. Sin ella, J no ataca.
var tiene_espada: bool:
	get:
		return cantidad(&"espada") > 0
	set(valor):
		_poner(&"espada", 1 if valor else 0)

var manzanas: int:
	get:
		return cantidad(&"manzana")

var _cache_objetos: Dictionary[StringName, Objeto] = {}


func _process(delta: float) -> void:
	if contando_tiempo and not get_tree().paused:
		tiempo_jugado += delta


## Empieza una partida nueva.
func reiniciar() -> void:
	monedas = 0
	objetos.clear()
	misiones.clear()
	tutorial_barco_visto = false
	mision_recibida = false
	voltereta_aprendida = false
	avisos_zeus = 0
	tiempo_jugado = 0.0
	jefes_derrotados = 0
	zona_cargada = ""
	entrada_cargada = ""
	vida_cargada = -1
	monedas_cambio.emit(monedas)
	manzanas_cambio.emit(0)
	objetos_cambio.emit(&"", 0)
	misiones_cambio.emit()


# --- Monedas --------------------------------------------------------------------------

func agregar_monedas(cantidad_: int) -> void:
	monedas = clampi(monedas + cantidad_, 0, MONEDAS_MAX)
	monedas_cambio.emit(monedas)


## Gasta si hay suficientes (mercader). Devuelve false si no alcanza.
func gastar_monedas(cantidad_: int) -> bool:
	if cantidad_ > monedas:
		return false
	monedas -= cantidad_
	monedas_cambio.emit(monedas)
	return true


# --- Objetos --------------------------------------------------------------------------

## El recurso del objeto (resources/objetos/<id>.tres), o null si no existe.
func objeto(id: StringName) -> Objeto:
	if not _cache_objetos.has(id):
		var ruta := RUTA_OBJETOS % id
		_cache_objetos[id] = load(ruta) as Objeto if ResourceLoader.exists(ruta) else null
	return _cache_objetos[id]


func cantidad(id: StringName) -> int:
	return objetos.get(id, 0)


func maximo(id: StringName) -> int:
	var o := objeto(id)
	return o.maximo if o else 1


func cabe(id: StringName, n: int = 1) -> bool:
	return cantidad(id) + n <= maximo(id)


## Devuelve false (y no cambia nada) si no caben todos.
func agregar_objeto(id: StringName, n: int = 1) -> bool:
	if not cabe(id, n):
		return false
	_poner(id, cantidad(id) + n)
	return true


## Para usar/gastar: devuelve false si no hay suficientes.
func gastar_objeto(id: StringName, n: int = 1) -> bool:
	if n > cantidad(id):
		return false
	_poner(id, cantidad(id) - n)
	return true


## Los ids que se tienen de un tipo (Objeto.Tipo), en el orden en que se consiguieron.
func objetos_de_tipo(tipo: Objeto.Tipo) -> Array[StringName]:
	var r: Array[StringName] = []
	for id in objetos:
		var o := objeto(id)
		if o and o.tipo == tipo:
			r.append(id)
	return r


func _poner(id: StringName, n: int) -> void:
	if n <= 0:
		if not objetos.has(id):
			return
		objetos.erase(id)
		n = 0
	else:
		if objetos.get(id, -1) == n:
			return
		objetos[id] = n
	objetos_cambio.emit(id, n)
	if id == &"manzana":
		manzanas_cambio.emit(n)


## Atajos de antes (la tienda y otros scripts los usan).
func agregar_manzanas(n: int) -> bool:
	return agregar_objeto(&"manzana", n)


func gastar_manzanas(n: int) -> bool:
	return gastar_objeto(&"manzana", n)


# --- Misiones -------------------------------------------------------------------------

func mision(id: StringName) -> Mision:
	var ruta := RUTA_MISIONES % id
	return load(ruta) as Mision if ResourceLoader.exists(ruta) else null


## No hace nada si ya estaba (activa o completada).
func empezar_mision(id: StringName) -> void:
	if misiones.has(id):
		return
	misiones[id] = EstadoMision.ACTIVA
	misiones_cambio.emit()


func completar_mision(id: StringName) -> void:
	if misiones.get(id, -1) == EstadoMision.COMPLETADA:
		return
	misiones[id] = EstadoMision.COMPLETADA
	misiones_cambio.emit()


func mision_completada(id: StringName) -> bool:
	return misiones.get(id, -1) == EstadoMision.COMPLETADA


# --- Guardar / cargar -----------------------------------------------------------------

func hay_partida() -> bool:
	return FileAccess.file_exists(ARCHIVO_PARTIDA)


## Guarda la partida. Zona, entrada y vida las pregunta a Game (`datos_guardado()`).
## Al cargar se reaparece en la entrada de la zona, no en el punto exacto.
func guardar() -> bool:
	var game := get_tree().get_first_node_in_group(&"game")
	if game == null or not game.has_method(&"datos_guardado"):
		push_warning("EstadoJuego.guardar: no hay Game")
		return false
	var datos: Dictionary = game.datos_guardado()
	var cfg := ConfigFile.new()
	cfg.set_value("lugar", "zona", datos.zona)
	cfg.set_value("lugar", "entrada", datos.entrada)
	cfg.set_value("jugador", "vida", datos.vida)
	cfg.set_value("jugador", "monedas", monedas)
	cfg.set_value("jugador", "objetos", _a_cadenas(objetos))
	cfg.set_value("progreso", "misiones", _a_cadenas(misiones))
	cfg.set_value("progreso", "tutorial_barco_visto", tutorial_barco_visto)
	cfg.set_value("progreso", "mision_recibida", mision_recibida)
	cfg.set_value("progreso", "voltereta_aprendida", voltereta_aprendida)
	cfg.set_value("progreso", "avisos_zeus", avisos_zeus)
	cfg.set_value("progreso", "tiempo_jugado", tiempo_jugado)
	cfg.set_value("progreso", "jefes_derrotados", jefes_derrotados)
	var err := cfg.save(ARCHIVO_PARTIDA)
	if err != OK:
		push_error("EstadoJuego.guardar: error %d al escribir %s" % [err, ARCHIVO_PARTIDA])
	return err == OK


## Lee la partida guardada. Después hay que cargar game.tscn: empezará en
## `zona_cargada` / `entrada_cargada` con `vida_cargada`.
func cargar() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO_PARTIDA) != OK:
		return false
	reiniciar()
	zona_cargada = cfg.get_value("lugar", "zona", "")
	entrada_cargada = cfg.get_value("lugar", "entrada", "inicio")
	vida_cargada = cfg.get_value("jugador", "vida", -1)
	monedas = cfg.get_value("jugador", "monedas", 0)
	var objs: Dictionary = cfg.get_value("jugador", "objetos", {})
	for id in objs:
		objetos[StringName(id)] = int(objs[id])
	var mis: Dictionary = cfg.get_value("progreso", "misiones", {})
	for id in mis:
		misiones[StringName(id)] = int(mis[id])
	tutorial_barco_visto = cfg.get_value("progreso", "tutorial_barco_visto", false)
	mision_recibida = cfg.get_value("progreso", "mision_recibida", false)
	voltereta_aprendida = cfg.get_value("progreso", "voltereta_aprendida", false)
	avisos_zeus = cfg.get_value("progreso", "avisos_zeus", 0)
	tiempo_jugado = cfg.get_value("progreso", "tiempo_jugado", 0.0)
	jefes_derrotados = cfg.get_value("progreso", "jefes_derrotados", 0)
	monedas_cambio.emit(monedas)
	manzanas_cambio.emit(manzanas)
	objetos_cambio.emit(&"", 0)
	misiones_cambio.emit()
	return true


## "1:05:09" o "42:07".
func tiempo_texto() -> String:
	var s := int(tiempo_jugado)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%02d:%02d" % [s / 60, s % 60]


## ConfigFile guarda StringName como texto con & : mejor claves String.
static func _a_cadenas(d: Dictionary) -> Dictionary:
	var r := {}
	for k in d:
		r[String(k)] = d[k]
	return r
