extends Node
## Estado global de la partida que sobrevive a los cambios de zona.
## Autoload: se accede desde cualquier script como `EstadoJuego`.
##   EstadoJuego.agregar_monedas(5)
##   if EstadoJuego.gastar_monedas(10): ...
## Aquí irán también la misión actual, objetos del inventario, puntos de control...

signal monedas_cambio(monedas: int)

const MONEDAS_MAX := 999

var monedas := 0


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
