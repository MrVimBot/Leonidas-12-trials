extends "res://tools/pruebas/base_prueba.gd"
## Autoload Microfono SIN micrófono real: activar/desactivar, y que sin el bus `Microfono` (cuando
## falta `default_bus_layout.tres`) no crea buses por su cuenta (en la web eso dejaba el juego
## mudo), queda no disponible con nivel 0 y calibrar() no se cuelga. Lo que NO cubre: que el
## micrófono del equipo entregue muestras (necesita hardware y permiso del sistema).


func ejecutar() -> void:
	tiempo_maximo = 30.0
	Microfono.activar()
	ok("activar → activo", Microfono.esta_activo())
	await ticks(5)
	Microfono.desactivar()
	ok("desactivar → inactivo", not Microfono.esta_activo())
	# Sin el bus declarado
	var idx := AudioServer.get_bus_index(&"Microfono")
	ok("el bus Microfono está declarado en el layout", idx != -1)
	AudioServer.remove_bus(idx)
	var buses := AudioServer.bus_count
	var m := (load("res://autoload/microfono.gd") as GDScript).new() as Node
	add_child(m)
	ok("sin bus: no crea buses", AudioServer.bus_count == buses, "%d/%d" % [buses, AudioServer.bus_count])
	m.activar()
	ok("sin bus: no queda activo", not m.esta_activo())
	await m.calibrar()
	await ticks(5)
	m.desactivar()
	ok("sin bus: disponible = false", m.disponible == false)
	ok("sin bus: nivel 0", m.nivel_efectivo() == 0.0)
	m.queue_free()
