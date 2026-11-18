class_name Game
extends Node2D
## Escena principal (game.tscn). Contiene lo que persiste entre zonas (jugador, cámara,
## y luego HUD y diálogos) y carga las zonas del mundo dentro de "Mundo".
##
##   Game (este script, y_sort_enabled)
##   ├─ Mundo (Node2D, y_sort)    aquí se instancia la zona actual
##   ├─ Jugador
##   ├─ (Barco)                   solo en zonas con `modo_barco`: lo crea ModoBarco
##   ├─ Camara (CamaraPixel)      sigue al jugador o al barco; límites según la zona
##   ├─ Transicion (CanvasLayer)  fundido a negro al cambiar de zona
##   ├─ HUD, MenuPausa
##   ├─ PantallaGameOver          al morir a pie (`Jugador.murio`); Continuar = reaparecer
##   └─ ModoBarco                 crea/quita el barco, micrófono, premio y tutorial
##
## En una zona con `modo_barco` (el mar) Leonidas viaja en barco: este script solo carga
## la zona y avisa a ModoBarco (`subir` / `bajar`), que hace el resto.
##
## Está en el grupo "game" (asignado en game.tscn): desde cualquier nodo, `Game.actual(self)`.

signal zona_cambiada(zona: Zona)
## Cambia entre ir a pie y en barco; `vida` es la que debe mostrar el HUD.
signal modo_cambio(en_barco: bool, vida: ComponenteVida)
## Empieza un combate de jefe: el HUD enseña su barra de vida (`BarraJefe`, ver su contrato).
## Se emite con `empezar_jefe()`.
signal jefe_empezo(jefe: Node, nombre: String)
## Acaba el combate de jefe (vencido, reiniciado tras el Game Over o al cambiar de zona).
signal jefe_termino

@export_file("*.tscn") var zona_inicial := "res://scenes/levels/pueblo.tscn"
@export var entrada_inicial := "inicio"
@export var duracion_fundido := 0.25

@export_group("Depuración")
## Estas opciones solo actúan en compilaciones de depuración (editor, exportación debug):
## si alguien deja una marcada, no llega a la versión exportada.
## Empieza como si Kathita ya hubiera dado el libro y enseñado la voltereta (para probar
## los sabios sin repetir su escena).
@export var depurar_saltar_kathita := false
## Empieza como si los sabios ya hubieran pasado: misión, espada y misiones al día (las
## puertas del pueblo dejan pasar). Para probar el bosque y la playa.
@export var depurar_mision_recibida := false
## Empieza con la espada (en una partida nueva), sin la misión. Normalmente la dan los
## sabios (scenes/cinematics/escena_sabios.tscn).
@export var depurar_dar_espada := false

var zona_actual: Zona = null
## Barco actual (solo lectura; null a pie). Lo lleva ModoBarco.
var barco: Barco:
	get:
		return modo_barco.barco if modo_barco else null
## Ruta de la zona actual (res://scenes/levels/<nombre>.tscn). Solo lectura.
var ruta_zona: String:
	get:
		return _ruta_actual
## ¿Se está cambiando de zona (fundido en curso)? Solo lectura.
var cambiando: bool:
	get:
		return _cambiando

var _cambiando := false
## Jefe cuya barra se ve ahora (null si ninguno).
var _jefe: Node = null
## Vida máxima de Leonidas sin corazones extra (la de jugador.tscn: 12 = 3 corazones).
var _vida_base := 0
var _ruta_actual := ""
var _entrada_actual := ""

@onready var mundo: Node2D = $Mundo
@onready var jugador: Jugador = $Jugador
@onready var camara: CamaraPixel = $Camara
@onready var fundido: ColorRect = $Transicion/Fundido
@onready var modo_barco: ModoBarco = $ModoBarco
@onready var pantalla_game_over: PantallaGameOver = $PantallaGameOver


## El Game de la partida en curso (o null, p. ej. en el menú o con una zona suelta).
static func actual(desde: Node) -> Game:
	if desde == null or not desde.is_inside_tree():
		return null
	return desde.get_tree().get_first_node_in_group(&"game") as Game


func _ready() -> void:
	Pantalla.modo_pintura(self, false) # red de seguridad; `_cargar_zona` pone el de la zona
	var depurar := OS.is_debug_build()
	if depurar and depurar_saltar_kathita:
		EstadoJuego.tiene_libro = true
		EstadoJuego.voltereta_aprendida = true
	if depurar and depurar_mision_recibida:
		EstadoJuego.mision_recibida = true
		EstadoJuego.voltereta_aprendida = true
		EstadoJuego.tiene_espada = true
		EstadoJuego.completar_mision(EstadoJuego.MISION_IR_AL_TEMPLO)
		EstadoJuego.empezar_mision(EstadoJuego.MISION_DERROTAR_MEDUSA)
	if depurar and depurar_dar_espada and EstadoJuego.lugar_cargado == null:
		EstadoJuego.tiene_espada = true
	EstadoJuego.contando_tiempo = true
	# Corazones extra (uno por jefe vencido): antes de fijar la vida guardada, que puede pasar de 12.
	_vida_base = jugador.vida.vida_max
	aplicar_corazones_extra(true)
	EstadoJuego.estado_restablecido.connect(aplicar_corazones_extra)
	fundido.color.a = 0.0
	jugador.reaparecio.connect(camara.saltar_a_objetivo)
	jugador.vida.danado.connect(_sacudir_camara)
	# Partida cargada (Continuar en el menú): su zona, su entrada (o el punto exacto
	# donde se guardó) y su vida.
	var zona := zona_inicial
	var entrada := entrada_inicial
	var posicion := Vector2.INF
	var lugar := EstadoJuego.lugar_cargado
	if lugar != null:
		zona = lugar.zona
		entrada = lugar.entrada
		posicion = lugar.posicion
		if lugar.vida > 0:
			jugador.vida.fijar(lugar.vida) # el HUD ya está conectado: se actualiza
		EstadoJuego.lugar_cargado = null
	_cargar_zona(zona, entrada)
	if posicion.is_finite() and barco == null:
		_colocar_jugador(posicion)
	modo_barco.mostrar_tutorial()


func _exit_tree() -> void:
	EstadoJuego.contando_tiempo = false
	Musica.detener()


## Lo que EstadoJuego.guardar() necesita saber del mundo (lo llama el libro). La posición solo
## a pie (en el barco no se abre el libro; si algún día se guarda en el mar, se vuelve a la entrada).
func datos_guardado() -> DatosLugar:
	var datos := DatosLugar.new()
	datos.zona = _ruta_actual
	datos.entrada = _entrada_actual
	datos.vida = jugador.vida.vida
	if barco == null:
		datos.posicion = jugador.global_position
	return datos


## Vida máxima de Leonidas = la de su escena + 4 cuartos por `EstadoJuego.corazones_extra`.
## Se llama al empezar, al restablecerse EstadoJuego y al ganar un corazón (escena del jefe,
## con `llenar` = true: cura del todo). El barco tiene su propia vida: no se toca.
func aplicar_corazones_extra(llenar := false) -> void:
	jugador.vida.fijar_maximo(_vida_base + ComponenteVida.CUARTOS_POR_CORAZON * EstadoJuego.corazones_extra, llenar)


## La escena de un jefe lo llama al empezar el combate: el HUD enseña su barra de vida.
## `jefe` cumple el contrato de `BarraJefe` (`vida`, y opcionalmente `invulnerable_cambio`).
func empezar_jefe(jefe: Node, nombre: String) -> void:
	_jefe = jefe
	jefe_empezo.emit(jefe, nombre)


## Al vencer al jefe o reiniciar su combate: se oculta su barra. Sin jefe no hace nada.
func terminar_jefe() -> void:
	if _jefe == null:
		return
	_jefe = null
	jefe_termino.emit()


## Pone al jugador en `pos` (partida cargada): ahí reaparece si muere y ahí va la cámara.
func _colocar_jugador(pos: Vector2) -> void:
	jugador.global_position = pos
	jugador.velocity = Vector2.ZERO
	jugador.punto_control = pos
	camara.saltar_a_objetivo()


## Cambia de zona con fundido a negro. La llaman las SalidaZona.
func cambiar_zona(ruta: String, entrada: String = "inicio") -> void:
	if _cambiando:
		return
	_cambiando = true
	_bloquear(true)
	modo_barco.premiar_travesia(ruta) # solo si se baja del barco en la otra orilla
	await _transicion(ruta, entrada)
	modo_barco.mostrar_tutorial() # la primera vez que se sube al barco


## Fundido a negro → carga la zona → fundido de vuelta, con los cuerpos bloqueados
## (motivo &"zona"). Quien llama pone `_cambiando` a true antes; aquí se quita al final.
func _transicion(ruta: String, entrada: String) -> void:
	SonidosUI.zona_cambio()
	await _fundir(1.0)
	_cargar_zona(ruta, entrada)
	_bloquear(true) # el barco puede ser nuevo (al jugador, repetir el motivo no le hace nada)
	await _fundir(0.0)
	_bloquear(false)
	_cambiando = false


## Bloqueo por cambio de zona (motivo &"zona"): no toca los de diálogos o escenas.
func _bloquear(b: bool) -> void:
	if b:
		jugador.bloquear(&"zona")
		if barco:
			barco.bloquear(&"zona")
	else:
		jugador.desbloquear(&"zona")
		if barco:
			barco.desbloquear(&"zona")


## Al morir Leonidas (señal `Jugador.murio`, conectada en game.tscn; en esta escena el
## Jugador tiene `reaparecer_automatico = false`): pantalla de Game Over con el arte de la zona.
func _al_morir_jugador() -> void:
	pantalla_game_over.mostrar(zona_actual.arte_game_over if zona_actual else null)


## «Continuar» del Game Over (señal `PantallaGameOver.continuar_pedido`, conectada en
## game.tscn): la pantalla ya se cerró; en negro reaparece en su punto de control (la
## entrada de la zona o donde se cargó la partida) y se vuelve a ver el mundo.
func _al_continuar_game_over() -> void:
	_cambiando = true # que no se abran la pausa ni el libro durante el fundido
	fundido.color.a = 1.0
	jugador.reaparecer()
	await _fundir(0.0)
	_cambiando = false


## Al hundirse (señal `ModoBarco.hundido`, conectada en game.tscn): fundido y se vuelve
## a empezar la travesía por la misma entrada.
func _al_hundirse() -> void:
	if _cambiando:
		return
	_cambiando = true
	await _transicion(_ruta_actual, _entrada_actual)


func _cargar_zona(ruta: String, entrada: String) -> void:
	var escena := load(ruta) as PackedScene
	var raiz := escena.instantiate() if escena else null
	var nueva := raiz as Zona
	if nueva == null:
		if raiz:
			raiz.free()
		# Ruta mala o raíz que no es una Zona (p. ej. una partida guardada con una zona
		# renombrada): no se puede seguir sin zona; se cae a la zona inicial.
		push_error("Game: %s no es una zona válida" % ruta)
		if ruta == zona_inicial:
			return
		_cargar_zona(zona_inicial, entrada_inicial)
		return
	terminar_jefe() # el jefe se va con su zona
	if zona_actual:
		mundo.remove_child(zona_actual)
		zona_actual.queue_free()
	zona_actual = nueva
	mundo.add_child(zona_actual)

	jugador.global_position = zona_actual.punto_entrada(entrada)
	jugador.velocity = Vector2.ZERO
	jugador.punto_control = jugador.global_position # se reaparece al entrar a la zona
	var desde := _ruta_actual if ruta != _ruta_actual else "" # "" = se recarga la misma
	_ruta_actual = ruta
	_entrada_actual = entrada

	if zona_actual.modo_barco:
		modo_barco.subir(zona_actual, entrada, desde)
	else:
		modo_barco.bajar()

	# Cada zona decide su modo de dibujo (las pintadas, CANVAS_ITEMS). Aquí, dentro del negro
	# del fundido (o antes del primer fotograma), para que el cambio no se vea.
	Pantalla.restaurar(self)
	_ajustar_camara()
	Musica.reproducir(zona_actual.musica)
	zona_cambiada.emit(zona_actual)
	modo_cambio.emit(barco != null, barco.vida if barco else jugador.vida)


## Al recibir daño el jugador, la cámara tiembla (la del barco la conecta ModoBarco).
func _sacudir_camara(_cantidad: int, _origen: Vector2) -> void:
	camara.sacudir()


func _ajustar_camara() -> void:
	var r := zona_actual.obtener_limites()
	if r.has_area():
		camara.limit_left = r.position.x
		camara.limit_top = r.position.y
		camara.limit_right = r.end.x
		camara.limit_bottom = r.end.y
	# Coloca la cámara de golpe (sin el suavizado) sobre el jugador.
	camara.saltar_a_objetivo()


func _fundir(alfa: float) -> void:
	var t := create_tween()
	t.tween_property(fundido, ^"color:a", alfa, duracion_fundido)
	await t.finished
