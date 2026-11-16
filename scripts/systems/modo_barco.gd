class_name ModoBarco
extends Node
## Viajar en barco (minijuego del mar). Hijo de Game (game.tscn). Game carga las zonas y
## le dice si la nueva es de barco (`subir`) o no (`bajar`); este nodo hace el resto:
## crea y destruye el Barco, oculta y desactiva al Jugador mientras tanto, mueve la
## cámara de uno a otro, abre y cierra el micrófono, da el premio de la travesía y
## enseña el tutorial la primera vez.
##
## El Barco se añade a `contenedor` (Game), no a este nodo: así es hermano del Jugador y
## se ordena por Y con los objetos de la zona (un Node no es CanvasItem).

## El barco se ha hundido (después de su animación). Game recarga la zona.
signal hundido

@export var escena_barco: PackedScene
## Se muestra la primera vez que se sube al barco; después se calibra el micrófono.
@export var dialogo_tutorial_barco: Dialogo
## Nodo al que se añade el barco (Game, con y_sort).
@export var contenedor: Node2D
@export var jugador: Jugador
@export var camara: CamaraPixel

## Barco actual (null a pie).
var barco: Barco:
	get:
		return _barco

var _barco: Barco = null
## Zona desde la que se subió al barco: al bajar en la orilla contraria hay premio.
var _origen_travesia := ""


## La zona cargada es de barco: crea un barco nuevo en `entrada` (aunque ya hubiera uno:
## al hundirse se empieza de cero). `desde` = ruta de la zona de la que se viene, o ""
## si se recarga la misma zona (entonces se conserva el origen de la travesía).
func subir(zona: Zona, entrada: String, desde: String) -> void:
	if not desde.is_empty():
		_origen_travesia = desde
	_quitar_barco()
	_barco = escena_barco.instantiate() as Barco
	_barco.global_position = zona.punto_entrada(entrada)
	contenedor.add_child(_barco) # hermano del jugador: se ordena por Y con los objetos de la zona
	# Mira hacia el interior del mapa: abajo si entra por la mitad de arriba.
	var limites := zona.obtener_limites()
	var abajo := not limites.has_area() or _barco.global_position.y < limites.get_center().y
	_barco.mirar(Vector2.DOWN if abajo else Vector2.UP)
	_barco.hundido.connect(hundido.emit)
	_barco.vida.danado.connect(_sacudir_camara)
	jugador.visible = false
	jugador.process_mode = Node.PROCESS_MODE_DISABLED
	camara.objetivo = _barco
	Microfono.activar()


## La zona cargada es a pie: quita el barco (si lo había) y vuelve Leonidas.
func bajar() -> void:
	_quitar_barco()
	jugador.visible = true
	jugador.process_mode = Node.PROCESS_MODE_INHERIT
	camara.objetivo = jugador
	Microfono.desactivar()


## Al salir del mar hacia `ruta_destino`: si no es la orilla de la que se salió, una
## moneda por corazón entero que conserve el barco.
func premiar_travesia(ruta_destino: String) -> void:
	if _barco and ruta_destino != _origen_travesia:
		EstadoJuego.agregar_monedas(floori(_barco.vida.vida / 4.0))


## La primera vez que se sube al barco: explica los controles y calibra el micrófono.
## Mientras tanto el barco queda bloqueado (motivo &"escena").
func mostrar_tutorial() -> void:
	if EstadoJuego.tutorial_barco_visto or _barco == null:
		return
	EstadoJuego.tutorial_barco_visto = true
	var este_barco := _barco
	este_barco.bloquear(&"escena")
	await (Dialogos as CajaDialogo).mostrar(dialogo_tutorial_barco)
	await Microfono.calibrar()
	if is_instance_valid(este_barco):
		este_barco.desbloquear(&"escena")


func _quitar_barco() -> void:
	if _barco == null:
		return
	contenedor.remove_child(_barco)
	_barco.queue_free()
	_barco = null


## Al recibir daño el barco, la cámara tiembla (como con el Jugador en Game).
func _sacudir_camara(_cantidad: int, _origen: Vector2) -> void:
	camara.sacudir()
