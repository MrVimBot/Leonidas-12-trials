class_name PrecargaZonas
extends Node
## Carga en segundo plano las zonas vecinas de la actual (a las que llevan sus `SalidaZona`) y
## las guarda mientras sigan siendo vecinas. Así, al cruzar una salida, la zona ya está en
## memoria y el cambio no congela el juego en negro. Lo notaban sobre todo las zonas del nivel 2:
## las capas pintadas de la `isla` (9828×5873) tardaban ~2 s en cargarse con `load()`.
##
## Hijo de Game (game.tscn). Game le pide la escena con `escena(ruta)` y, ya cargada la zona
## nueva, le avisa con `preparar(zona, ruta, ruta_anterior, escena_anterior)`. Guardar la
## PackedScene mantiene vivos sus recursos (texturas) en la caché de Godot: al volver de la
## cueva a la isla tampoco hay que recargarlas.

## Vecinas ya cargadas: ruta → escena.
var _listas: Dictionary[String, PackedScene] = {}
## Rutas pedidas a ResourceLoader en segundo plano que aún no se han recogido.
var _pendientes: Array[String] = []
## Vecinas de la zona actual (las que se conservan).
var _vecinas: Array[String] = []


func _ready() -> void:
	set_process(false)


## Al salir (se cierra el juego, se vuelve al menú, se libera Game en una prueba): espera a
## que terminen las cargas en segundo plano y las recoge. Si el juego se cerrase con una a medias,
## el hilo de carga se cortaría y Godot daría errores de lectura de esos archivos.
func _exit_tree() -> void:
	for r in _pendientes:
		ResourceLoader.load_threaded_get(r)
	_pendientes.clear()
	_listas.clear()


## La escena de la zona `ruta`: la precargada si la hay; si aún se está cargando, espera a que
## termine (sin empezar otra carga); si no, la carga ahora.
func escena(ruta: String) -> PackedScene:
	if _listas.has(ruta):
		return _listas[ruta]
	if ruta in _pendientes:
		_pendientes.erase(ruta)
		return ResourceLoader.load_threaded_get(ruta) as PackedScene
	return load(ruta) as PackedScene


## Ya está `zona` (cargada de `ruta`): conserva la zona de la que se viene (`ruta_anterior`,
## `escena_anterior`) si es vecina, suelta las que ya no lo son y empieza a cargar las demás.
func preparar(zona: Zona, ruta: String, ruta_anterior: String, escena_anterior: PackedScene) -> void:
	_vecinas.clear()
	for salida in zona.find_children("*", "SalidaZona", false, false):
		var destino := (salida as SalidaZona).zona_destino
		if not destino.is_empty() and destino != ruta and not destino in _vecinas:
			_vecinas.append(destino)
	for r: String in _listas.keys():
		if not r in _vecinas:
			_listas.erase(r)
	if escena_anterior and ruta_anterior in _vecinas:
		_listas[ruta_anterior] = escena_anterior
	for r in _vecinas:
		if _listas.has(r) or r in _pendientes:
			continue
		if ResourceLoader.load_threaded_request(r) == OK:
			_pendientes.append(r)
	set_process(not _pendientes.is_empty())


## Recoge las cargas terminadas (las que ya no son vecinas se recogen igual, para que
## ResourceLoader las suelte, y se descartan).
func _process(_delta: float) -> void:
	for r: String in _pendientes.duplicate():
		match ResourceLoader.load_threaded_get_status(r):
			ResourceLoader.THREAD_LOAD_LOADED:
				_pendientes.erase(r)
				var e := ResourceLoader.load_threaded_get(r) as PackedScene
				if e and r in _vecinas:
					_listas[r] = e
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_pendientes.erase(r)
				push_warning("PrecargaZonas: no se pudo precargar %s" % r)
	if _pendientes.is_empty():
		set_process(false)
