extends Node
## Arena de pruebas de los enemigos del nivel 2 dentro del juego real (Game + HUD + zona pintada).
## Abrir tools/pintados/arena_enemigos.tscn y pulsar F6. Herramienta de desarrollo (tools/ no se
## exporta): carga `game.tscn` en `zona`, con espada, libro y misión, y coloca los enemigos
## alrededor de Leonidas (desplazamientos en px de mundo).

@export_file("*.tscn") var zona := "res://scenes/levels/isla_orilla.tscn"
@export var entrada := "inicio"
@export var escena_game: PackedScene
## Dibuja las formas de colisión (como Depurar → Formas de colisión visibles).
@export var ver_formas := false
## Leonidas no recibe daño (para observar ataques con calma).
@export var invulnerable := false
## Cámara lenta (Engine.time_scale): con 0,2 da tiempo a capturar cada fase de un ataque.
@export_range(0.05, 1.0) var escala_tiempo := 1.0
## Vida con la que empieza Leonidas, en cuartos (0 = llena). 1 = muere al primer golpe.
@export var vida_inicial := 0
@export var gamba: PackedScene
@export var gambas: Array[Vector2] = []
@export var pez_espada: PackedScene
@export var peces: Array[Vector2] = []
@export var ciclope: PackedScene
@export var ciclopes: Array[Vector2] = []
## Medusa (jefa): al colocarla se llama a `empezar_combate()`. Necesita sitio: para verla,
## `zona` = `cueva_jefe.tscn`, `entrada` = `desde_cueva` y un desplazamiento como (0, -200)
## (el centro de la sala; las otras listas, vacías).
@export var medusa: PackedScene
@export var medusas: Array[Vector2] = []


var _jugador: Jugador


func _physics_process(_delta: float) -> void:
	# La voltereta apaga `invulnerable_extra` al acabar: se vuelve a poner en cada tick.
	if invulnerable and _jugador:
		_jugador.vida.invulnerable_extra = true


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _ready() -> void:
	EstadoJuego.reiniciar()
	get_tree().debug_collisions_hint = ver_formas
	Engine.time_scale = escala_tiempo
	var game := escena_game.instantiate() as Game
	game.zona_inicial = zona
	game.entrada_inicial = entrada
	game.depurar_saltar_kathita = true
	game.depurar_mision_recibida = true
	add_child(game)
	_jugador = game.jugador
	if vida_inicial > 0:
		game.jugador.vida.fijar(vida_inicial)
	var contenedor: Node = game.zona_actual.get_node_or_null(^"Objetos")
	if contenedor == null:
		contenedor = game.zona_actual
	for par in [[gamba, gambas], [pez_espada, peces], [ciclope, ciclopes], [medusa, medusas]]:
		for desplazamiento: Vector2 in par[1]:
			var e := (par[0] as PackedScene).instantiate() as Node2D
			e.position = game.jugador.global_position + desplazamiento - (contenedor as Node2D).global_position
			contenedor.add_child(e)
			if e is Medusa:
				(e as Medusa).empezar_combate()
