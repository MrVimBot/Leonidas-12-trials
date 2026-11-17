extends "res://tools/pruebas/base_prueba.gd"
## Caracterización de las animaciones: para cada entidad (jugador, barco, NPC, enemigos), cada
## dirección y cada animación, anota (animación elegida, flip_h, dirección del AnimadorDireccional)
## y lo compara con la referencia versionada `referencias/animaciones.txt`. Detecta que un cambio en
## el animador o en los SpriteFrames cambie qué dibujo sale (p. ej. el espejo del lado izquierdo).
##
## Todo es síncrono (sin esperar fotogramas) para que sea determinista.
##
## CUANDO LA ARTISTA CAMBIE SPRITES (animaciones nuevas, renombradas o tiras distintas) la
## diferencia es esperada: revisa el diff y regenera la referencia a propósito con
##     godot --headless --path . --script res://tools/pruebas/lanzar.gd -- prueba_animaciones generar
## y súbela junto al cambio de arte. Sin el argumento `generar` solo compara.
## Usa miembros privados del Jugador y del Barco (`_pirueta`, `_atacar`, `_al_recibir_danio`,
## `_reproducir`...) con `call()`: es la única forma de provocar cada animación sin simular
## el juego entero.

const REFERENCIA := "res://tools/pruebas/referencias/animaciones.txt"
const DIRS := {"abajo": Vector2.DOWN, "izq": Vector2.LEFT, "der": Vector2.RIGHT, "arriba": Vector2.UP}

var lineas: PackedStringArray = []
var raiz: Node2D


func registrar(caso: String, sprite: AnimatedSprite2D, anim: AnimadorDireccional) -> void:
	lineas.append("CASO %s | %s | %s | %s" % [caso, sprite.animation, sprite.flip_h, anim.direccion])


func ejecutar() -> void:
	raiz = Node2D.new()
	add_child(raiz)
	_jugador()
	_barco()
	_npcs()
	_enemigos()
	raiz.queue_free()
	if OS.get_cmdline_user_args().has("generar"):
		var f := FileAccess.open(REFERENCIA, FileAccess.WRITE)
		f.store_string("\n".join(lineas) + "\n")
		f.close()
		ok("referencia regenerada (%d casos) en %s" % [lineas.size(), REFERENCIA], true)
		return
	var esperadas := FileAccess.get_file_as_string(REFERENCIA).strip_edges().split("\n")
	ok("la referencia existe y tiene casos", esperadas.size() > 10 and esperadas[0].begins_with("CASO"), REFERENCIA)
	ok("mismo número de casos (%d)" % esperadas.size(), lineas.size() == esperadas.size(), "obtenidos %d" % lineas.size())
	var distintos := 0
	for i in mini(lineas.size(), esperadas.size()):
		if lineas[i] != esperadas[i]:
			distintos += 1
			if distintos <= 10:
				print("   esperado: %s\n   obtenido: %s" % [esperadas[i], lineas[i]])
	ok("todos los casos coinciden con la referencia (%d distintos)" % distintos, distintos == 0)


func _jugador() -> void:
	var j := (load("res://scenes/player/jugador.tscn") as PackedScene).instantiate() as Jugador
	raiz.add_child(j)
	var a := j.animador
	var s := a.sprite
	registrar("jugador inicial", s, a)
	var manzana := load("res://resources/objetos/manzana.tres") as Objeto
	for k: String in DIRS:
		var d: Vector2 = DIRS[k]
		for base: StringName in [&"parado", &"caminar", &"parado_objeto", &"caminar_objeto", &"agarrar", &"tirar", &"comer", &"morir", &"recibir_dano"]:
			j.estado = Jugador.Estado.NORMAL
			a.mirar(d)
			a.reproducir(base)
			registrar("jugador %s %s" % [base, k], s, a)
		j.estado = Jugador.Estado.NORMAL
		j.estamina.llenar()
		j.call(&"_pirueta", d)
		registrar("jugador pirueta %s" % k, s, a)
		j.call(&"_terminar_pirueta")
		j.estado = Jugador.Estado.NORMAL
		a.mirar(d)
		j.call(&"_atacar")
		registrar("jugador ataque %s" % k, s, a)
		j.estado = Jugador.Estado.NORMAL
		a.mirar(d)
		j.vida.restaurar()
		j.call(&"_al_recibir_danio", 1, j.global_position + Vector2(5, 5))
		registrar("jugador dano %s" % k, s, a)
		j.estado = Jugador.Estado.NORMAL
		a.mirar(d)
		j.comer(manzana)
		registrar("jugador comer() %s" % k, s, a)
		a.reproducir(&"parado")
		registrar("jugador parado tras comer %s" % k, s, a)
		j.estado = Jugador.Estado.NORMAL
		a.mirar(d)
		j.mostrar_objeto_obtenido(manzana.icono, 0.0)
		registrar("jugador objeto_obtenido %s" % k, s, a)
		j.ocultar_objeto_obtenido()
		registrar("jugador ocultar_objeto %s" % k, s, a)
	j.queue_free()


func _barco() -> void:
	var b := (load("res://scenes/player/barco.tscn") as PackedScene).instantiate() as Barco
	raiz.add_child(b)
	var a := b.animador
	registrar("barco inicial", b.sprite, a)
	for k: String in DIRS:
		var d: Vector2 = DIRS[k]
		b.mirar(d)
		registrar("barco mirar %s" % k, b.sprite, a)
		for base: StringName in [&"barco_quieto", &"barco_moviendo"]:
			b.call(&"_reproducir", base)
			registrar("barco %s %s" % [base, k], b.sprite, a)
	b.queue_free()


func _npcs() -> void:
	for nombre: String in ["npc_burro", "npc_zorro", "npc_gallo", "npc_perro", "tendedera", "sabio_1", "sabio_4"]:
		var npc := (load("res://scenes/npcs/npc.tscn") as PackedScene).instantiate() as NPC
		npc.sprite_frames = load("res://resources/sprite_frames/%s.tres" % nombre)
		npc.paseo = false
		raiz.add_child(npc)
		var a := npc.get_node(^"Animador") as AnimadorDireccional
		var s := npc.get_node(^"Sprite") as AnimatedSprite2D
		registrar("%s inicial" % nombre, s, a)
		for k: String in DIRS:
			var d: Vector2 = DIRS[k]
			a.mirar(d)
			for base: StringName in [&"parado", &"caminar", &"parado"]:
				npc.animar(base)
				registrar("%s %s %s" % [nombre, base, k], s, a)
		npc.queue_free()


func _enemigos() -> void:
	var casos := {
		"seta_bomba": [&"parado", &"caminar", &"explotar", &"salir", &"esconderse", &"nube"],
		"flor_falsa": [&"quieta", &"salir", &"esconderse", &"escondida", &"morder", &"morder_exito", &"recibir_dano"],
		"tiburon": [&"nadar", &"embestir", &"morder"],
	}
	for nombre: String in casos:
		var e := (load("res://scenes/enemies/%s.tscn" % nombre) as PackedScene).instantiate()
		raiz.add_child(e)
		var a := e.get_node(^"Animador") as AnimadorDireccional
		var s := e.get_node(^"Sprite") as AnimatedSprite2D
		registrar("%s inicial" % nombre, s, a)
		for k: String in DIRS:
			var d: Vector2 = DIRS[k]
			for base: StringName in casos[nombre]:
				a.mirar(d)
				a.reproducir(base, true)
				registrar("%s %s %s" % [nombre, base, k], s, a)
		e.queue_free()
