extends Node
## Estado global de la partida que sobrevive a los cambios de zona.
## Autoload: se accede desde cualquier script como `EstadoJuego`.
##   EstadoJuego.agregar_monedas(5)
##   if EstadoJuego.gastar_monedas(10): ...
##   EstadoJuego.agregar_manzanas(1)
## Dura lo que dura la partida: no se guarda en disco. Morir no quita nada;
## `reiniciar()` (al pulsar Jugar en el menú) lo pone todo a cero.
## Aquí irán también la misión actual, más objetos del inventario, puntos de control...

signal monedas_cambio(monedas: int)
signal manzanas_cambio(manzanas: int)

const MONEDAS_MAX := 999
const MANZANAS_MAX := 9

var monedas := 0
var manzanas := 0
## El tutorial del barco (y la calibración del micrófono) sale solo la primera vez.
var tutorial_barco_visto := false
## El libro que le regala Kathita al salir de casa: es el inventario (objetos), el mapa
## y el guardado de la partida. El HUD solo muestra su icono cuando se tiene.
var tiene_libro := false


## Empieza una partida nueva.
func reiniciar() -> void:
	monedas = 0
	manzanas = 0
	tutorial_barco_visto = false
	tiene_libro = false
	monedas_cambio.emit(monedas)
	manzanas_cambio.emit(manzanas)


func agregar_monedas(cantidad: int) -> void:
	monedas = clampi(monedas + cantidad, 0, MONEDAS_MAX)
	monedas_cambio.emit(monedas)


## Gasta si hay suficientes (mercader). Devuelve false si no alcanza.
func gastar_monedas(cantidad: int) -> bool:
	if cantidad > monedas:
		return false
	monedas -= cantidad
	monedas_cambio.emit(monedas)
	return true


## Devuelve false (y no cambia nada) si no caben todas.
func agregar_manzanas(cantidad: int) -> bool:
	if manzanas + cantidad > MANZANAS_MAX:
		return false
	manzanas += cantidad
	manzanas_cambio.emit(manzanas)
	return true


## Para comer: devuelve false si no hay suficientes.
func gastar_manzanas(cantidad: int) -> bool:
	if cantidad > manzanas:
		return false
	manzanas -= cantidad
	manzanas_cambio.emit(manzanas)
	return true
