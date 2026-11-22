extends Node
## Estado global de la partida que sobrevive a los cambios de zona.
## Autoload: se accede desde cualquier script como `EstadoJuego`.
##   EstadoJuego.agregar_monedas(5)
##   if EstadoJuego.gastar_monedas(10): ...
##   EstadoJuego.agregar_objeto(EstadoJuego.OBJ_MANZANA)
##   EstadoJuego.empezar_mision(EstadoJuego.MISION_DERROTAR_MEDUSA)
## Morir no quita nada; `reiniciar()` (al pulsar Jugar en el menú) lo pone todo a cero.
## `guardar(lugar)` / `cargar()` lo escriben/leen en `ruta_partida` (user://partida.cfg: página
## Guardar del libro y opción Continuar del menú principal). El lugar (zona, posición, vida)
## lo da quien guarda (el libro, preguntando a Game): este autoload no conoce ninguna escena.
##
## Objetos: `objetos` = id → cantidad, en el orden en que se consiguieron. Cada id tiene su
## recurso en resources/objetos/<id>.tres (`Objeto`: nombre, icono, tipo, máximo...).
## `tiene_libro` y `tiene_espada` son atajos sobre `objetos`.
##
## Seguridad: `ConfigFile` puede deserializar objetos si alguien edita el archivo a mano.
## Es un riesgo teórico (juego offline, solo su propia partida); el formato no se cambia.

signal monedas_cambio(monedas: int)
signal objetos_cambio(id: StringName, cantidad: int)
signal misiones_cambio
## Se ha puesto todo de golpe (`reiniciar()` o `cargar()`): quien muestre el estado debe
## refrescarse entero.
signal estado_restablecido

enum EstadoMision { ACTIVA, COMPLETADA }

const MONEDAS_MAX := 999
const RUTA_OBJETOS := "res://resources/objetos/%s.tres"
const RUTA_MISIONES := "res://resources/misiones/%s.tres"

## Ids de los objetos (resources/objetos/<id>.tres) y misiones (resources/misiones/<id>.tres)
## que el código nombra; mejor la constante que un literal (un id mal escrito falla en silencio).
const OBJ_ESPADA := &"espada"
const OBJ_LIBRO := &"libro"
const OBJ_MANZANA := &"manzana"
const OBJ_CARTA := &"carta"
const OBJ_CABEZA_PIEDRA := &"cabeza_piedra"
const OBJ_COCO := &"coco"
const MISION_IR_AL_TEMPLO := &"ir_al_templo"
const MISION_DERROTAR_MEDUSA := &"derrotar_medusa"
const MISION_REGRESAR_CON_SABIOS := &"regresar_con_sabios"
const MISION_DERROTAR_MINOTAURO := &"derrotar_minotauro"

## Progreso que se guarda en la sección "progreso": nombre de la variable → valor inicial.
## `reiniciar()`, `guardar()` y `cargar()` la recorren: una bandera nueva solo se declara
## aquí y como variable. Las claves son las del archivo: no renombrar.
const PROGRESO := {
	&"tutorial_barco_visto": false,
	&"mision_recibida": false,
	&"voltereta_aprendida": false,
	&"avisos_zeus": 0,
	&"tiempo_jugado": 0.0,
	&"jefes_derrotados": 0,
	&"corazones_extra": 0,
	&"medusa_derrotada": false,
}

## Dónde se guarda la partida (variable para poder probar sin tocar la real).
var ruta_partida := "user://partida.cfg"

var monedas := 0
## id → cantidad (solo los que se tienen; en el orden en que se consiguieron).
var objetos: Dictionary[StringName, int] = {}
## id → EstadoMision (en el orden en que empezaron). En el archivo se guardan como enteros.
var misiones: Dictionary[StringName, EstadoMision] = {}
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
## Corazones que se suman a los 3 de Leonidas (uno por jefe vencido, Jugabilidad p. 12). Lo
## aplica Game: `jugador.vida.vida_max` = base + 4 por corazón (`Game.aplicar_corazones_extra`).
var corazones_extra := 0
## Medusa vencida (escena del encuentro, `EscenaMedusa`): al volver a `cueva_jefe` se queda en
## la sala con su recordatorio, sin combate.
var medusa_derrotada := false
## Cofres ya abiertos (`Cofre.clave()`: zona/nombre del nodo). No va en PROGRESO: es una lista,
## y las constantes de PROGRESO se copian tal cual (una lista constante sería de solo lectura).
var cofres_abiertos: Array[StringName] = []
## Lo pone Game mientras existe: el menú y la cinemática no cuentan como tiempo jugado.
var contando_tiempo := false

## Al cargar una partida: dónde debe empezar Game (zona, entrada, posición y vida). Game lo
## consume en su _ready y lo pone a null. null = partida nueva.
var lugar_cargado: DatosLugar = null

## El libro que le regala Kathita al salir de casa: es el inventario (objetos), el mapa
## y el guardado de la partida. El HUD solo muestra su icono cuando se tiene.
var tiene_libro: bool:
	get:
		return cantidad(OBJ_LIBRO) > 0
	set(valor):
		_poner(OBJ_LIBRO, 1 if valor else 0)

## La dan los sabios. Sin ella, J no ataca.
var tiene_espada: bool:
	get:
		return cantidad(OBJ_ESPADA) > 0
	set(valor):
		_poner(OBJ_ESPADA, 1 if valor else 0)

var _cache_objetos: Dictionary[StringName, Objeto] = {}
var _cache_misiones: Dictionary[StringName, Mision] = {}


func _process(delta: float) -> void:
	if contando_tiempo and not get_tree().paused:
		tiempo_jugado += delta


## Empieza una partida nueva.
func reiniciar() -> void:
	_poner_a_cero()
	_avisar_restablecido()


func _poner_a_cero() -> void:
	monedas = 0
	objetos.clear()
	misiones.clear()
	cofres_abiertos.clear()
	for clave: StringName in PROGRESO:
		set(clave, PROGRESO[clave])
	lugar_cargado = null


func _avisar_restablecido() -> void:
	monedas_cambio.emit(monedas)
	misiones_cambio.emit()
	estado_restablecido.emit()


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


# --- Misiones -------------------------------------------------------------------------

## El recurso de la misión (resources/misiones/<id>.tres), o null si no existe.
func mision(id: StringName) -> Mision:
	if not _cache_misiones.has(id):
		var ruta := RUTA_MISIONES % id
		_cache_misiones[id] = load(ruta) as Mision if ResourceLoader.exists(ruta) else null
	return _cache_misiones[id]


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


## Ya se recibió (activa o completada).
func mision_empezada(id: StringName) -> bool:
	return misiones.has(id)


func mision_completada(id: StringName) -> bool:
	return misiones.get(id, -1) == EstadoMision.COMPLETADA


# --- Cofres ---------------------------------------------------------------------------

func cofre_abierto(clave: StringName) -> bool:
	return clave in cofres_abiertos


func marcar_cofre_abierto(clave: StringName) -> void:
	if not cofre_abierto(clave):
		cofres_abiertos.append(clave)


# --- Guardar / cargar -----------------------------------------------------------------

func hay_partida() -> bool:
	return FileAccess.file_exists(ruta_partida)


## Guarda la partida. `lugar` (zona, entrada, posición y vida) lo da quien llama: el libro
## se lo pregunta a `Game.datos_guardado()`. Al cargar se reaparece donde se guardó.
func guardar(lugar: DatosLugar) -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("lugar", "zona", lugar.zona)
	cfg.set_value("lugar", "entrada", lugar.entrada)
	if lugar.posicion.is_finite():
		cfg.set_value("lugar", "posicion", lugar.posicion)
	cfg.set_value("jugador", "vida", lugar.vida)
	cfg.set_value("jugador", "monedas", monedas)
	cfg.set_value("jugador", "objetos", _a_cadenas(objetos))
	cfg.set_value("progreso", "misiones", _a_cadenas(misiones))
	cfg.set_value("progreso", "cofres", PackedStringArray(cofres_abiertos))
	for clave: StringName in PROGRESO:
		cfg.set_value("progreso", clave, get(clave))
	var err := cfg.save(ruta_partida)
	if err != OK:
		push_error("EstadoJuego.guardar: error %d al escribir %s" % [err, ruta_partida])
	return err == OK


## Lee la partida guardada. Después hay que cargar game.tscn: empezará en `lugar_cargado`.
func cargar() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(ruta_partida) != OK:
		return false
	_poner_a_cero()
	var zona: String = cfg.get_value("lugar", "zona", "")
	if not zona.is_empty():
		lugar_cargado = DatosLugar.new()
		lugar_cargado.zona = zona
		lugar_cargado.entrada = cfg.get_value("lugar", "entrada", "inicio")
		lugar_cargado.posicion = cfg.get_value("lugar", "posicion", Vector2.INF)
		lugar_cargado.vida = cfg.get_value("jugador", "vida", -1)
	monedas = cfg.get_value("jugador", "monedas", 0)
	var objs: Dictionary = cfg.get_value("jugador", "objetos", {})
	for id: Variant in objs:
		@warning_ignore("unsafe_call_argument") # claves/valores de ConfigFile: Variant
		objetos[StringName(id)] = int(objs[id])
	var mis: Dictionary = cfg.get_value("progreso", "misiones", {})
	for id: Variant in mis:
		@warning_ignore("unsafe_call_argument") # claves/valores de ConfigFile: Variant
		misiones[StringName(id)] = int(mis[id]) as EstadoMision
	var cofres: PackedStringArray = cfg.get_value("progreso", "cofres", PackedStringArray())
	for clave in cofres:
		cofres_abiertos.append(StringName(clave))
	for clave: StringName in PROGRESO:
		set(clave, cfg.get_value("progreso", clave, PROGRESO[clave]))
	_avisar_restablecido()
	return true


## "1:05:09" o "42:07".
func tiempo_texto() -> String:
	var s := int(tiempo_jugado)
	if s >= 3600:
		@warning_ignore("integer_division")
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	@warning_ignore("integer_division")
	return "%02d:%02d" % [s / 60, s % 60]


## ConfigFile guarda StringName como texto con & : mejor claves String.
static func _a_cadenas(d: Dictionary) -> Dictionary:
	var r := {}
	for k: Variant in d:
		@warning_ignore("unsafe_call_argument") # claves de un Dictionary sin tipo
		r[String(k)] = d[k]
	return r
