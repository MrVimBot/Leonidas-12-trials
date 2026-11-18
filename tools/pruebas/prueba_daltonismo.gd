extends "res://tools/pruebas/base_prueba.gd"
## Filtro de daltonismo (autoload `Daltonismo`) desde el menú de pausa:
## a) sin ajuste guardado empieza en «No» y la capa está oculta;
## b) el botón «Daltonismo» del menú de pausa cicla No → Protanopía → Deuteranopía → No con E,
##    el texto lo dice (con la marca "> ") y el shader recibe el tipo;
## c) se guarda en el archivo de ajustes y se recupera al cargar.
## Usa `user://prueba_ajustes.cfg`: no toca los ajustes reales.

const RUTA_AJUSTES_PRUEBA := "user://prueba_ajustes.cfg"

var _tipo_real: FiltroDaltonismo.Tipo
var _ruta_real: String


func ejecutar() -> void:
	_ruta_real = Daltonismo.ruta_ajustes
	_tipo_real = Daltonismo.tipo
	Daltonismo.ruta_ajustes = RUTA_AJUSTES_PRUEBA
	DirAccess.remove_absolute(RUTA_AJUSTES_PRUEBA)
	Daltonismo.tipo = FiltroDaltonismo.Tipo.NINGUNO

	# a)
	Daltonismo._cargar()
	ok("a) sin ajustes: No", Daltonismo.tipo == FiltroDaltonismo.Tipo.NINGUNO)
	ok("a) capa oculta", not Daltonismo.visible)

	# b)
	await crear_game(true, true)
	var pausa := game.find_child("MenuPausa", true, false) as MenuPausa
	var boton := pausa.find_child("Daltonismo", true, false) as Button
	await pulsar(&"pausa")
	boton.grab_focus()
	await ticks(1)
	ok("b) texto inicial", boton.text == "> Daltonismo: No", boton.text)
	var material := (Daltonismo.get_node(^"%Filtro") as ColorRect).material as ShaderMaterial
	for esperado: Array in [[FiltroDaltonismo.Tipo.PROTANOPIA, "Protanopía"],
			[FiltroDaltonismo.Tipo.DEUTERANOPIA, "Deuteranopía"], [FiltroDaltonismo.Tipo.NINGUNO, "No"]]:
		await pulsar_tecla(KEY_E)
		var tipo: FiltroDaltonismo.Tipo = esperado[0]
		ok("b) E → %s" % esperado[1], Daltonismo.tipo == tipo, str(Daltonismo.tipo))
		ok("b) texto %s" % esperado[1], boton.text == "> Daltonismo: %s" % esperado[1], boton.text)
		ok("b) shader %s" % esperado[1], material.get_shader_parameter(&"tipo") == int(tipo))
		ok("b) capa visible = %s" % (tipo != FiltroDaltonismo.Tipo.NINGUNO),
			Daltonismo.visible == (tipo != FiltroDaltonismo.Tipo.NINGUNO))
		ok("b) la pausa sigue abierta", pausa.abierto)
	await pulsar(&"pausa")

	# c)
	Daltonismo.siguiente() # Protanopía, guardado
	Daltonismo.tipo = FiltroDaltonismo.Tipo.NINGUNO
	Daltonismo._cargar()
	ok("c) se recupera lo guardado", Daltonismo.tipo == FiltroDaltonismo.Tipo.PROTANOPIA)

	DirAccess.remove_absolute(RUTA_AJUSTES_PRUEBA)
	Daltonismo.ruta_ajustes = _ruta_real
	Daltonismo.tipo = _tipo_real
