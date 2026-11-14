class_name ComponenteTienda
extends Node
## Convierte a un NPC (o cualquier cosa con ZonaDialogo) en vendedor.
## Se pone como hijo y se asigna en `tienda` del NPC / de la ZonaDialogo.
##
## Al hablarle:
##   - si no tienes monedas para lo más barato → dice `dialogo_sin_monedas` y ya;
##   - si te alcanza → `dialogo_saludo`, se abre el menú (autoload Tienda)
##     y al cerrarlo, `dialogo_despedida`.

signal compro(articulo: ArticuloTienda)

## Lo que vende, en el orden de la lista.
@export var articulos: Array[ArticuloTienda] = []
## Nombre en la pestaña del menú de la tienda.
@export var nombre_vendedor := "Tendera"
@export var dialogo_saludo: Dialogo
@export var dialogo_sin_monedas: Dialogo
@export var dialogo_despedida: Dialogo

enum Resultado { COMPRADO, SIN_MONEDAS, LLENO }


func precio_minimo() -> int:
	var minimo := -1
	for a in articulos:
		if a and (minimo < 0 or a.precio < minimo):
			minimo = a.precio
	return maxi(minimo, 0)


## Lo llama ZonaDialogo al interactuar. Termina cuando el jugador acaba de comprar.
func atender(_quien: Node) -> void:
	if articulos.is_empty() or EstadoJuego.monedas < precio_minimo():
		await Dialogos.mostrar(dialogo_sin_monedas)
		return
	await Dialogos.mostrar(dialogo_saludo)
	await Tienda.abrir(self)
	await Dialogos.mostrar(dialogo_despedida)


## Intenta comprar. No cobra si no hay sitio para el objeto.
func comprar(articulo: ArticuloTienda) -> Resultado:
	if EstadoJuego.monedas < articulo.precio:
		return Resultado.SIN_MONEDAS
	if not cabe(articulo):
		return Resultado.LLENO
	EstadoJuego.gastar_monedas(articulo.precio)
	entregar(articulo)
	compro.emit(articulo)
	return Resultado.COMPRADO


## Cuántos tiene el jugador de ese objeto (para "Tienes: N").
static func cantidad(articulo: ArticuloTienda) -> int:
	return EstadoJuego.cantidad(articulo.id)


static func cabe(articulo: ArticuloTienda) -> bool:
	return EstadoJuego.cabe(articulo.id)


## Da el objeto al jugador (cualquier `Objeto` de resources/objetos/).
static func entregar(articulo: ArticuloTienda) -> void:
	if not EstadoJuego.agregar_objeto(articulo.id):
		push_warning("ComponenteTienda: no cabe '%s'" % articulo.id)
