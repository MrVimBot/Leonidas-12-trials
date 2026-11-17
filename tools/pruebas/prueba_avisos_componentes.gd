extends "res://tools/pruebas/base_prueba.gd"
## Avisos de configuración de los componentes (`_get_configuration_warnings()`, el triángulo
## amarillo del árbol de escenas; tarea F8 de docs/plan/05_componentes_y_fisica.md):
## 1. Cada componente con avisos, sin configurar, da el aviso esperado; bien configurado, ninguno.
## 2. Ningún componente de las escenas reales (scenes/**/*.tscn y game.tscn) tiene avisos.
## Las escenas se instancian SIN añadirlas al árbol (no corre su `_ready`): las referencias de
## los `@export` a nodos ya se resuelven al instanciar, y los avisos solo miran exports, padre e hijos.
## Que en el editor no hagan nada (`Engine.is_editor_hint()`) no se puede probar en headless.

const CARPETA_COMPONENTES := "res://scripts/componentes/"

## Nodos sueltos creados en la parte 1, para liberarlos al final.
var _creados: Array[Node] = []


func ejecutar() -> void:
	_probar_componentes()
	_probar_escenas()
	for n in _creados:
		if is_instance_valid(n):
			n.free()


## Comprueba que `nodo` da exactamente `cuantos` avisos y que cada texto de `contienen`
## aparece en alguno.
func _avisos(nombre: String, nodo: Node, cuantos: int, contienen: Array[String] = []) -> void:
	var avisos: PackedStringArray = nodo.call(&"_get_configuration_warnings")
	var bien := avisos.size() == cuantos
	for texto in contienen:
		if not "\n".join(avisos).contains(texto):
			bien = false
	ok(nombre, bien, "avisos=%s" % [avisos])


## Crea `nodo` (y lo apunta para liberarlo) como hijo de `padre` si se da.
func _nuevo(nodo: Node, padre: Node = null) -> Node:
	if padre:
		padre.add_child(nodo)
	else:
		_creados.append(nodo)
	return nodo


func _forma(padre: Node, forma: Shape2D) -> CollisionShape2D:
	var c := CollisionShape2D.new()
	c.shape = forma
	padre.add_child(c)
	return c


func _probar_componentes() -> void:
	# AnimadorDireccional
	var anim := _nuevo(AnimadorDireccional.new()) as AnimadorDireccional
	_avisos("Animador sin sprite avisa", anim, 1, ["`sprite`"])
	anim.sprite = _nuevo(AnimatedSprite2D.new()) as AnimatedSprite2D
	_avisos("Animador con sprite: sin avisos", anim, 0)

	# ComponenteAtaque
	var ataque := _nuevo(ComponenteAtaque.new()) as ComponenteAtaque
	_avisos("Ataque sin nada: hitbox y animador", ataque, 2, ["`hitbox`", "`animador`"])
	var hb := _nuevo(Hitbox.new()) as Hitbox
	ataque.hitbox = hb
	ataque.animador = anim
	_avisos("Ataque con Hitbox sin forma avisa", ataque, 1, ["rectangular"])
	var circulo := _forma(hb, CircleShape2D.new())
	_avisos("Ataque con Hitbox de forma circular avisa", ataque, 1, ["rectangular"])
	circulo.shape = RectangleShape2D.new()
	_avisos("Ataque bien configurado: sin avisos", ataque, 0)

	# Hitbox
	var hb_solo := _nuevo(Hitbox.new()) as Hitbox
	_avisos("Hitbox sin forma avisa", hb_solo, 1, ["CollisionShape2D"])
	hb_solo.add_child(CollisionPolygon2D.new())
	_avisos("Hitbox solo con CollisionPolygon2D avisa", hb_solo, 1, ["CollisionShape2D"])
	_forma(hb_solo, RectangleShape2D.new())
	_avisos("Hitbox con CollisionShape2D: sin avisos", hb_solo, 0)

	# ComponenteCarga
	var carga := _nuevo(ComponenteCarga.new()) as ComponenteCarga
	_avisos("Carga suelta: punto_carga y portador", carga, 2, ["`punto_carga`", "`portador`"])
	var dueno_carga := _nuevo(Node2D.new()) as Node2D
	_creados.erase(carga)
	dueno_carga.add_child(carga)
	carga.punto_carga = _nuevo(Node2D.new(), dueno_carga) as Node2D
	_avisos("Carga hija de Node2D con punto_carga: sin avisos", carga, 0)

	# ComponenteDeteccion
	var det := _nuevo(ComponenteDeteccion.new()) as ComponenteDeteccion
	_avisos("Detección suelta avisa de `cuerpo`", det, 1, ["`cuerpo`"])
	det.cuerpo = _nuevo(Node2D.new()) as Node2D
	_avisos("Detección con cuerpo: sin avisos", det, 0)
	det.radio_perder = det.radio_vision - 1.0
	_avisos("Detección con radio_perder < radio_vision avisa", det, 1, ["`radio_perder`"])

	# ComponenteInteraccion
	var inter := _nuevo(ComponenteInteraccion.new()) as ComponenteInteraccion
	_avisos("Interacción suelta: forma y portador", inter, 2, ["CollisionShape2D", "`portador`"])
	inter.portador = _nuevo(Node2D.new()) as Node2D
	_forma(inter, CircleShape2D.new())
	_avisos("Interacción con forma y portador: sin avisos", inter, 0)

	# ComponenteManzano
	var manzano := _nuevo(ComponenteManzano.new()) as ComponenteManzano
	_avisos("Manzano suelto: cuerpo y escena_manzana", manzano, 2, ["Decorado", "`escena_manzana`"])
	var arbol := _nuevo(Decorado.new()) as Decorado
	_creados.erase(manzano)
	arbol.add_child(manzano)
	manzano.escena_manzana = PackedScene.new()
	_avisos("Manzano hijo de Decorado con escena: sin avisos", manzano, 0)

	# ComponenteMovimiento
	var mov := _nuevo(ComponenteMovimiento.new()) as ComponenteMovimiento
	_avisos("Movimiento suelto avisa del CharacterBody2D", mov, 1, ["CharacterBody2D"])
	var cuerpo := _nuevo(CharacterBody2D.new()) as CharacterBody2D
	_creados.erase(mov)
	cuerpo.add_child(mov)
	_avisos("Movimiento con cuerpo no flotante avisa", mov, 1, ["Floating"])
	cuerpo.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_avisos("Movimiento hijo de CharacterBody2D flotante: sin avisos", mov, 0)

	# ComponenteMuerte
	var muerte := _nuevo(ComponenteMuerte.new()) as ComponenteMuerte
	_avisos("Muerte sin vida avisa", muerte, 1, ["`vida`"])
	muerte.vida = _nuevo(ComponenteVida.new()) as ComponenteVida
	_avisos("Muerte con vida: sin avisos", muerte, 0)

	# ComponenteParpadeo
	var parpadeo := _nuevo(ComponenteParpadeo.new()) as ComponenteParpadeo
	_avisos("Parpadeo sin objetivo avisa", parpadeo, 1, ["`objetivo`"])
	parpadeo.objetivo = _nuevo(Sprite2D.new()) as Sprite2D
	_avisos("Parpadeo con objetivo: sin avisos", parpadeo, 0)

	# ComponentePaseo
	var paseo := _nuevo(ComponentePaseo.new()) as ComponentePaseo
	_avisos("Paseo sin movimiento avisa", paseo, 1, ["`movimiento`"])
	paseo.movimiento = mov
	_avisos("Paseo con movimiento: sin avisos", paseo, 0)

	# ComponenteTienda
	var tienda := _nuevo(ComponenteTienda.new()) as ComponenteTienda
	_avisos("Tienda sin artículos avisa", tienda, 1, ["`articulos`"])
	var articulo := ArticuloTienda.new()
	tienda.articulos = [articulo]
	_avisos("Tienda con artículo sin objeto avisa", tienda, 1, ["artículo 0"])
	articulo.objeto = Objeto.new()
	_avisos("Tienda con artículo completo: sin avisos", tienda, 0)


## Instancia cada escena y comprueba que ningún componente con avisos los tiene.
func _probar_escenas() -> void:
	var rutas: Array[String] = ["res://game.tscn"]
	_buscar_escenas("res://scenes", rutas)
	var revisados := 0
	var con_avisos: Array[String] = []
	for ruta in rutas:
		var escena := load(ruta) as PackedScene
		if escena == null:
			ok("carga %s" % ruta, false)
			continue
		var raiz := escena.instantiate()
		var pendientes: Array[Node] = [raiz]
		while not pendientes.is_empty():
			var n: Node = pendientes.pop_back()
			pendientes.append_array(n.get_children())
			var script := n.get_script() as Script
			if script == null or not script.resource_path.begins_with(CARPETA_COMPONENTES):
				continue
			if not n.has_method(&"_get_configuration_warnings"):
				continue
			revisados += 1
			var avisos: PackedStringArray = n.call(&"_get_configuration_warnings")
			if not avisos.is_empty():
				con_avisos.append("%s:%s → %s" % [ruta, raiz.get_path_to(n), avisos])
		raiz.free()
	for linea in con_avisos:
		print("  AVISO  ", linea)
	ok("componentes de las escenas reales sin avisos", con_avisos.is_empty() and revisados > 0,
		"%d escenas, %d componentes revisados, %d con avisos" % [rutas.size(), revisados, con_avisos.size()])


func _buscar_escenas(carpeta: String, rutas: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(carpeta):
		_buscar_escenas(carpeta.path_join(sub), rutas)
	for archivo in DirAccess.get_files_at(carpeta):
		if archivo.ends_with(".tscn"):
			rutas.append(carpeta.path_join(archivo))
