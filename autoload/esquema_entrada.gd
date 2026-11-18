class_name EsquemaEntrada
extends Node
## Tipo de entrada que el jugador dice usar (Teclado o Mando). Autoload `Entrada`
## (el autoload no puede llamarse como su clase).
##
## NO filtra la entrada: el mapa de entradas acepta teclado y mando a la vez. Solo decide
## qué tecla o botón NOMBRA el juego en sus textos de ayuda («Pulsa [J]» / «Pulsa [X]»).
## Se elige en el menú de pausa («Tipo de entrada»).
##
## Los textos escritos por el equipo de guion usan marcadores con el nombre de la acción:
## `{atacar}`, `{inventario}`… que `sustituir()` cambia por «[J]» o «[X]» según el tipo
## (lo hace `CajaDialogo` con todo lo que muestra).
##
## Es un ajuste del jugador, no de la partida: va en `user://ajustes.cfg` (como el filtro
## de daltonismo) y `EstadoJuego.reiniciar()` no lo toca.

signal cambio(tipo: Tipo)

enum Tipo { TECLADO, MANDO }

const NOMBRES: Array[String] = ["Teclado", "Mando"]

## Nombre de cada acción en teclado y en mando (mismo orden que `Tipo`). Los del mando son
## los de un DualSense de PS5 (confirmados por el equipo). Si se cambia una tecla en el mapa
## de entradas, cambiarla también aquí. `volver` no es una acción: es lo que cierra una
## pantalla sin botones (en el mando, `ui_accept` incluye el botón 1 = Círculo).
const ETIQUETAS: Dictionary = {
	&"atacar": ["J", "Cuadrado"],
	&"pirueta": ["Espacio", "Círculo"],
	&"interactuar": ["E", "X"],
	&"inventario": ["I", "Touchpad"],
	&"pausa": ["Esc", "Options"],
	&"pagina_anterior": ["Q", "L1"],
	&"pagina_siguiente": ["R", "R1"],
	&"volver": ["Esc", "Círculo"],
}

## Ruta de icono (plugin Controller Icons, estilo PS5) de lo que NO se dibuja solo a partir
## del mapa de entradas: el plugin no sabe pintar el touchpad (botón 20), y `volver` no es una
## acción. El resto de acciones usan su propio nombre como ruta (ver `IconoMando`).
const RUTAS_ICONO: Dictionary = {
	&"inventario": "ps5/touch_pad",
	&"volver": "ps5/circle",
}

## Variable (no const) para que las pruebas usen otro archivo, como `EstadoJuego.ruta_partida`.
var ruta_ajustes := "user://ajustes.cfg"

var tipo := Tipo.TECLADO:
	set(valor):
		if valor == tipo:
			return
		tipo = valor
		cambio.emit(tipo)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cargar()


## Pasa al otro tipo (Teclado ↔ Mando) y lo guarda.
func siguiente() -> void:
	tipo = ((tipo + 1) % Tipo.size()) as Tipo
	_guardar()


func nombre() -> String:
	return NOMBRES[tipo]


## Tecla o botón de la acción según el tipo elegido («J», «X»…). Acción desconocida: su nombre.
func etiqueta(accion: StringName) -> String:
	var nombres: Array = ETIQUETAS.get(accion, [])
	if nombres.is_empty():
		return String(accion)
	var n: String = nombres[tipo]
	return n


## ¿Se enseñan iconos del mando en vez de texto? Solo con el tipo Mando; con Teclado se
## nombran las teclas como texto («[J]»).
func usa_iconos() -> bool:
	return tipo == Tipo.MANDO


## Ruta del icono de la acción para `IconoMando` (su nombre, salvo las de `RUTAS_ICONO`).
func ruta_icono(accion: StringName) -> String:
	return RUTAS_ICONO.get(accion, String(accion))


## Cambia los marcadores `{accion}` de un texto por «[tecla]».
func sustituir(texto: String) -> String:
	if not texto.contains("{"):
		return texto
	for accion: StringName in ETIQUETAS:
		texto = texto.replace("{%s}" % accion, "[%s]" % etiqueta(accion))
	return texto


func _cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ruta_ajustes) != OK:
		return
	var valor: Variant = cfg.get_value("entrada", "tipo", 0)
	if not valor is int:
		return
	var n: int = valor
	if n >= 0 and n < Tipo.size():
		tipo = n as Tipo


func _guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.load(ruta_ajustes) # conserva otros ajustes si los hay
	cfg.set_value("entrada", "tipo", int(tipo))
	cfg.save(ruta_ajustes)
