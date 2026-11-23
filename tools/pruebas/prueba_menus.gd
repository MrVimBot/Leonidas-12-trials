extends "res://tools/pruebas/base_prueba.gd"
## Menús con botones (principal y pausa) con eventos REALES (InputEventKey / InputEventJoypadButton):
##  a) `ui_accept` lleva las teclas del juego (E, L, J) y los botones 0, 1 y 2 del mando además de
##     Enter, Enter numérico y Espacio;
##  b) menú principal: cada tecla de aceptar pulsa el botón con foco UNA sola vez (la GUI de Godot lo
##     hace sola; no hay reenvío manual), arriba/abajo mueven el foco y dan la vuelta;
##  b2) créditos: se abren, nombran Gravity y Controller Icons, arriba/abajo desplazan el texto y se vuelve
##     con Enter, Esc o el botón de ratón «Volver», con el foco de nuevo en «Créditos»;
##  b3) Continuar abre la pantalla de la partida (`PantallaContinuar`) con su vida, monedas, jefes
##     e inventario; Esc y la flecha vuelven al menú con el foco en Continuar, y la tarjeta la carga;
##  c) pausa: Continuar con E y con Enter, Controles con J y volver con E/J/Enter/Espacio/Esc, Salir;
##  d) el libro abierto no se ve afectado (Enter no hace nada, Espacio lo cierra, nadie tiene foco)
##     y a pie E/J siguen interactuando/atacando.
## Los botones de Jugar/Salir se desconectan de su acción real (cambiarían de escena o cerrarían
## el juego) y se cuentan las pulsaciones.

const MENU_PRINCIPAL := preload("res://scenes/ui/menu_principal.tscn")

## Cada forma de aceptar: [nombre, keycode (0 = mando), botón del mando].
const ACEPTAR := [
	["Enter", KEY_ENTER, -1], ["Enter numérico", KEY_KP_ENTER, -1], ["Espacio", KEY_SPACE, -1],
	["E", KEY_E, -1], ["L", KEY_L, -1], ["J", KEY_J, -1],
	["mando 0", 0, 0], ["mando 1", 0, 1], ["mando 2", 0, 2],
]


func ejecutar() -> void:
	_caso_a()
	await _caso_b()
	await crear_game(true, true)
	await _caso_c()
	await _caso_d()


## Pulsa y suelta una de las formas de ACEPTAR con eventos reales.
func _aceptar(forma: Array) -> void:
	if forma[2] >= 0:
		await _boton_mando(forma[2] as int)
	else:
		await pulsar_tecla(forma[1] as Key)


func _boton_mando(boton: int) -> void:
	for pulsado in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = boton as JoyButton
		e.pressed = pulsado
		Input.parse_input_event(e)
		await ticks(2)


# --- a) Mapa de entradas ------------------------------------------------------------------------

func _caso_a() -> void:
	for forma: Array in ACEPTAR:
		var e: InputEvent
		if forma[2] >= 0:
			var m := InputEventJoypadButton.new()
			m.button_index = forma[2] as JoyButton
			m.pressed = true
			e = m
		else:
			var k := InputEventKey.new()
			k.keycode = forma[1] as Key
			k.physical_keycode = forma[1] as Key
			k.pressed = true
			e = k
		ok("a) ui_accept incluye %s" % forma[0], e.is_action(&"ui_accept"))


# --- b) Menú principal --------------------------------------------------------------------------

func _caso_b() -> void:
	var menu := MENU_PRINCIPAL.instantiate() as MenuPrincipal
	get_tree().root.add_child(menu)
	await ticks(3)
	menu.boton_continuar.visible = true # no hay partida guardada en la prueba
	var cuenta := {}
	for b: Button in [menu.boton_continuar, menu.boton_jugar, menu.boton_creditos, menu.boton_salir]:
		for c: Dictionary in b.pressed.get_connections():
			b.pressed.disconnect(c["callable"] as Callable)
		cuenta[b] = 0
		b.pressed.connect(func() -> void: cuenta[b] += 1)
	ok("b) arranca con foco en un botón", get_viewport().gui_get_focus_owner() is Button)
	for b: Button in [menu.boton_continuar, menu.boton_jugar, menu.boton_creditos, menu.boton_salir]:
		for forma: Array in ACEPTAR:
			b.grab_focus()
			await ticks(1)
			cuenta[b] = 0
			await _aceptar(forma)
			ok("b) %s con foco + %s → 1 pulsación" % [b.name, forma[0]], cuenta[b] == 1, str(cuenta[b]))
	# Arriba y abajo.
	menu.boton_jugar.grab_focus()
	await ticks(1)
	await pulsar_tecla(KEY_DOWN)
	ok("b) abajo: Jugar → Créditos", get_viewport().gui_get_focus_owner() == menu.boton_creditos)
	await pulsar_tecla(KEY_UP)
	ok("b) arriba: Créditos → Jugar", get_viewport().gui_get_focus_owner() == menu.boton_jugar)
	menu.boton_continuar.visible = false
	menu.boton_jugar.grab_focus()
	await pulsar_tecla(KEY_UP)
	ok("b) arriba desde el primero da la vuelta", get_viewport().gui_get_focus_owner() == menu.boton_salir)
	await pulsar_tecla(KEY_DOWN)
	ok("b) abajo desde el último da la vuelta", get_viewport().gui_get_focus_owner() == menu.boton_jugar)
	menu.free()
	await ticks(2)
	await _caso_creditos()
	await _caso_continuar()


func _caso_creditos() -> void:
	var menu := MENU_PRINCIPAL.instantiate() as MenuPrincipal
	get_tree().root.add_child(menu)
	await ticks(3)
	ok("b2) nombran la fuente Gravity y el plugin Controller Icons",
		menu.texto_creditos.text.contains("Vincenzo Vuono") and menu.texto_creditos.text.contains("Ricardo Subtil"))
	for vuelta: Array in [["Enter", KEY_ENTER], ["Esc", KEY_ESCAPE], ["ratón", 0]]:
		menu.boton_creditos.grab_focus()
		await ticks(1)
		await pulsar_tecla(KEY_ENTER)
		ok("b2) Enter sobre Créditos los abre", menu.viendo_creditos and menu.pantalla_creditos.visible
			and not menu.panel.visible and get_viewport().gui_get_focus_owner() == null)
		ok("b2) el botón Volver nombra la tecla", not menu.boton_volver.text.contains("{"), menu.boton_volver.text)
		# Solo hay desplazamiento si el texto no cabe (depende del texto que ponga el equipo).
		var barra := menu.desplazamiento.get_v_scroll_bar()
		var sobra := barra.max_value - barra.page > 1.0
		var antes := menu.desplazamiento.scroll_vertical
		await pulsar_tecla(KEY_DOWN)
		await ticks(1)
		ok("b2) abajo desplaza el texto (si no cabe)", not sobra or menu.desplazamiento.scroll_vertical > antes,
			"%d → %d" % [antes, menu.desplazamiento.scroll_vertical])
		await pulsar_tecla(KEY_UP)
		await ticks(1)
		ok("b2) arriba lo devuelve", menu.desplazamiento.scroll_vertical == antes)
		ok("b2) arriba/abajo no se escapan al menú", menu.viendo_creditos and get_viewport().gui_get_focus_owner() == null)
		if vuelta[1] == 0:
			menu.boton_volver.pressed.emit()
			await ticks(2)
		else:
			await pulsar_tecla(vuelta[1] as Key)
		ok("b2) se vuelve con %s y el foco queda en Créditos" % vuelta[0], not menu.viendo_creditos
			and menu.panel.visible and not menu.pantalla_creditos.visible
			and get_viewport().gui_get_focus_owner() == menu.boton_creditos)
	menu.free()
	await ticks(2)


func _caso_continuar() -> void:
	# Una partida de prueba (base_prueba ya apunta EstadoJuego.ruta_partida a la de prueba).
	EstadoJuego.reiniciar()
	EstadoJuego.agregar_monedas(7)
	EstadoJuego.agregar_objeto(EstadoJuego.OBJ_ESPADA)
	EstadoJuego.agregar_objeto(EstadoJuego.OBJ_MANZANA, 3)
	EstadoJuego.medusa_derrotada = true
	EstadoJuego.corazones_extra = 1
	var lugar := DatosLugar.new()
	lugar.zona = "res://scenes/levels/pueblo.tscn"
	lugar.vida = 6
	EstadoJuego.guardar(lugar)
	EstadoJuego.reiniciar()
	var menu := MENU_PRINCIPAL.instantiate() as MenuPrincipal
	var pantalla := menu.get_node(^"PantallaContinuar") as PantallaContinuar
	var pedidos := [0]
	for c: Dictionary in pantalla.continuar_pedido.get_connections():
		pantalla.continuar_pedido.disconnect(c["callable"] as Callable)
	pantalla.continuar_pedido.connect(func() -> void: pedidos[0] += 1)
	get_tree().root.add_child(menu)
	await ticks(3)
	ok("b3) con partida se ve Continuar y tiene el foco", menu.boton_continuar.visible
		and get_viewport().gui_get_focus_owner() == menu.boton_continuar)
	for vuelta: String in ["Esc", "flecha"]:
		menu.boton_continuar.grab_focus()
		await ticks(1)
		await pulsar_tecla(KEY_ENTER)
		var tarjeta := pantalla.get_node(^"Lienzo/Tarjeta") as Button
		ok("b3) Enter sobre Continuar abre la pantalla (sin cargar aún)", pantalla.abierta
			and not menu.panel.visible and pedidos[0] == 0 and get_viewport().gui_get_focus_owner() == tarjeta)
		if vuelta == "Esc":
			var corazones := pantalla.get_node(^"Lienzo/Corazones") as FilaCorazones
			ok("b3) 4 corazones con 6 cuartos", corazones.get_child_count() == 4
				and corazones.cuartos_visibles() == 6, "%d / %d" % [corazones.get_child_count(), corazones.cuartos_visibles()])
			ok("b3) monedas", (pantalla.get_node(^"Lienzo/Monedas") as Label).text == "7")
			ok("b3) laurel de Medusa con trofeo y el siguiente vacío",
				(pantalla.get_node(^"Lienzo/Laureles/Laurel1/Trofeo") as TextureRect).texture != null
				and (pantalla.get_node(^"Lienzo/Laureles/Laurel2/Trofeo") as TextureRect).texture == null)
			var casilla := pantalla.get_node(^"Lienzo/Casillas/Casilla1") as TextureRect
			ok("b3) inventario: manzanas (sin la espada)", casilla.texture == EstadoJuego.objeto(EstadoJuego.OBJ_MANZANA).icono
				and (casilla.get_node(^"Cantidad") as Label).text == "3"
				and (pantalla.get_node(^"Lienzo/Casillas/Casilla2") as TextureRect).texture == null)
			await pulsar_tecla(KEY_ESCAPE)
		else:
			await pulsar_tecla(KEY_DOWN)
			ok("b3) abajo pasa a la flecha", get_viewport().gui_get_focus_owner() == pantalla.get_node(^"Lienzo/Volver"))
			await pulsar_tecla(KEY_ENTER)
		ok("b3) se vuelve con %s y el foco queda en Continuar" % vuelta, not pantalla.abierta
			and menu.panel.visible and get_viewport().gui_get_focus_owner() == menu.boton_continuar)
	await pulsar_tecla(KEY_ENTER)
	await pulsar_tecla(KEY_ENTER)
	ok("b3) Enter sobre la tarjeta pide cargar la partida una vez", pedidos[0] == 1
		and EstadoJuego.lugar_cargado != null, str(pedidos[0]))
	menu.free()
	await ticks(2)
	EstadoJuego.reiniciar()
	borrar_partida_prueba()


# --- c) Pausa -----------------------------------------------------------------------------------

func _caso_c() -> void:
	var pausa := game.find_child("MenuPausa", true, false) as MenuPausa
	var salir := pausa.find_child("Salir", true, false) as Button
	var cuenta_salir := [0]
	for c: Dictionary in salir.pressed.get_connections():
		salir.pressed.disconnect(c["callable"] as Callable)
	salir.pressed.connect(func() -> void: cuenta_salir[0] += 1)
	# Continuar con cada forma de aceptar.
	for forma: Array in ACEPTAR:
		await pulsar(&"pausa")
		var abierta := pausa.abierto and get_tree().paused
		await _aceptar(forma)
		ok("c) pausa + Continuar con %s" % forma[0],
			abierta and not pausa.abierto and not get_tree().paused)
	# Controles con cada forma y vuelta con cada una (más Esc).
	var controles := pausa.find_child("Controles", true, false) as Button
	var panel_controles := pausa.find_child("PanelControles", true, false) as Control
	for entrada: Array in ACEPTAR:
		for vuelta: Array in ACEPTAR + [["Esc", KEY_ESCAPE, -1]]:
			await pulsar(&"pausa")
			controles.grab_focus()
			await ticks(1)
			await _aceptar(entrada)
			var viendo := panel_controles.visible
			await _aceptar(vuelta)
			var de_vuelta := not panel_controles.visible and pausa.abierto \
				and get_viewport().gui_get_focus_owner() == controles
			ok("c) Controles con %s y volver con %s" % [entrada[0], vuelta[0]], viendo and de_vuelta)
			await pulsar(&"pausa") # cierra la pausa
			if pausa.abierto:
				ok("c) la pausa se cierra con Esc", false)
				return
	# Salir.
	for forma: Array in ACEPTAR:
		await pulsar(&"pausa")
		salir.grab_focus()
		await ticks(1)
		cuenta_salir[0] = 0
		await _aceptar(forma)
		ok("c) Salir con %s → 1 pulsación" % forma[0], cuenta_salir[0] == 1, str(cuenta_salir[0]))
		await pulsar(&"pausa")
	ok("c) la pausa acaba cerrada", not pausa.abierto and not get_tree().paused)


# --- d) El resto del juego sigue igual ---------------------------------------------------------

func _caso_d() -> void:
	# A pie: J ataca (la GUI no se lo come).
	await ticks(5)
	tecla(KEY_J, true)
	await ticks(2)
	ok("d) a pie J ataca", j.estado == Jugador.Estado.ATAQUE, str(j.estado))
	tecla(KEY_J, false)
	await esperar_normal()
	await ticks(5)
	# Libro: Enter no hace nada, E/J no abren foco, Espacio cierra.
	var libro := Libro
	await pulsar(&"inventario")
	ok("d) el libro se abre", libro.abierto)
	ok("d) con el libro abierto nadie tiene foco", get_viewport().gui_get_focus_owner() == null)
	await pulsar_tecla(KEY_ENTER)
	ok("d) Enter no cierra el libro", libro.abierto)
	await pulsar_tecla(KEY_SPACE)
	ok("d) Espacio cierra el libro", not libro.abierto)
	await ticks(5)
