extends "res://tools/pruebas/base_prueba.gd"
## Pantalla de Game Over (`PantallaGameOver`, dentro de game.tscn): al morir a pie sale con el
## árbol en pausa y en modo pintura, la pausa no se abre encima, los botones no responden
## mientras aparece, «Continuar» (ui_accept) reaparece en el punto de control con la vida llena
## y vuelve al modo normal; una zona con `arte_game_over` propio lo usa y la siguiente sin él
## vuelve al de siempre; «Menú principal» vuelve a la escena principal.
## No comprueba el aspecto (headless), solo el flujo.

const ARTE := "res://scenes/ui/game_over/arte_game_over.tscn"


func _pantalla() -> PantallaGameOver:
	return game.get_node(^"PantallaGameOver") as PantallaGameOver


func _arte() -> Control:
	return _pantalla().get_node(^"Raiz/Lienzo/Arte") as Control


func _morir() -> void:
	# Tras reaparecer es invulnerable un rato: el golpe no contaría.
	await esperar_hasta(func() -> bool: return not j.vida.es_invulnerable(), 900)
	j.vida.recibir_danio(999)
	await esperar_hasta(func() -> bool: return _pantalla().abierta, 900)


## Espera a que los botones se puedan pulsar (acaba la entrada).
func _esperar_botones() -> bool:
	var boton := _pantalla().get_node(^"%Continuar") as Button
	return await esperar_hasta(func() -> bool: return not boton.disabled, 900)


func ejecutar() -> void:
	await crear_game(true, true)
	var pg := _pantalla()
	ok("game.tscn: el Jugador no reaparece solo", not j.reaparecer_automatico)
	ok("empieza oculta", not pg.visible and not pg.abierta)

	# Morir → pantalla
	var control := j.punto_control
	j.global_position = control + Vector2(40, 0)
	await _morir()
	ok("al morir: se abre, pausa y modo pintura", pg.abierta and pg.visible and get_tree().paused
		and get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	ok("arte por defecto", _arte().scene_file_path == ARTE, _arte().scene_file_path)
	await pulsar(&"ui_accept")
	ok("mientras aparece: ui_accept no hace nada", pg.abierta)
	await pulsar(&"pausa")
	ok("la pausa no se abre encima", not (game.get_node(^"MenuPausa") as MenuPausa).abierto)
	ok("los botones llegan a activarse", await _esperar_botones())

	# Continuar
	await pulsar(&"ui_accept")
	ok("Continuar: se cierra, sin pausa, modo normal", not pg.abierta and not pg.visible
		and not get_tree().paused
		and get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT)
	await esperar_normal()
	ok("Continuar: reaparece en el punto de control con la vida llena",
		j.global_position == control and j.vida.vida == j.vida.vida_max
		and j.estado == Jugador.Estado.NORMAL, str(j.global_position))

	# Arte propio de la zona y vuelta al de siempre
	var propio := PackedScene.new()
	var raiz := Control.new()
	raiz.size = Vector2(100, 50)
	propio.pack(raiz)
	raiz.free()
	propio.resource_path = "res://prueba_arte_game_over.tscn" # solo en memoria: no se guarda
	game.zona_actual.arte_game_over = propio
	await _morir()
	ok("zona con arte propio: lo usa", _arte().scene_file_path == propio.resource_path,
		_arte().scene_file_path)
	await _esperar_botones()
	await pulsar(&"ui_accept")
	await esperar_normal()
	game.zona_actual.arte_game_over = null
	await _morir()
	ok("zona sin arte: vuelve al de siempre", _arte().scene_file_path == ARTE, _arte().scene_file_path)

	# Menú principal
	await _esperar_botones()
	get_tree().current_scene = game # change_scene_to_file sustituye la escena actual
	var menu := pg.get_node(^"Raiz/Botones/Menu") as Button
	menu.grab_focus()
	await pulsar(&"ui_accept")
	await esperar_hasta(func() -> bool: return get_tree().current_scene is MenuPrincipal, 300)
	var principal: String = ProjectSettings.get_setting("application/run/main_scene")
	var actual := get_tree().current_scene
	ok("Menú principal: vuelve a la escena principal sin pausa",
		actual != null and actual.scene_file_path == principal and not get_tree().paused,
		actual.scene_file_path if actual else "null")
	if actual and actual != self:
		actual.queue_free()
	await ticks(5)
