extends Node2D
## Vista previa del arte PINTADO del nivel 2 junto a Leonidas (pixel art), para juzgar escala y
## nitidez. Abrir tools/pintados/vista_previa.tscn y pulsar F6. Herramienta de desarrollo: no se
## exporta (tools/ está en el exclude_filter).
##
## Con `modo_pintura` (por defecto) la ventana dibuja en CANVAS_ITEMS, que es como el plan propone
## dibujar las zonas del nivel 2 (ver docs/design/arte_pintado.md). Desactivarlo para ver cómo
## quedaría en el modo normal del juego (viewport de 480×270: el arte pintado se emborrona).
## Teclas: atacar (J) cambia de animación; pirueta (Espacio) espeja.

@export var modo_pintura := true

var _anim := 0
const ANIMS := [&"parado", &"caminar", &"atacar", &"correr"]


func _ready() -> void:
	Pantalla.modo_pintura(self, modo_pintura)
	_reproducir()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed(&"atacar"):
		_anim = (_anim + 1) % ANIMS.size()
		_reproducir()
	elif evento.is_action_pressed(&"pirueta"):
		for s in %Pintados.get_children():
			(s as AnimatedSprite2D).flip_h = not (s as AnimatedSprite2D).flip_h


func _reproducir() -> void:
	for s: AnimatedSprite2D in %Pintados.get_children():
		var nombre: StringName = ANIMS[_anim]
		s.play(nombre if s.sprite_frames.has_animation(nombre) else &"parado")
	%Rotulo.text = "%s  ·  J: otra  ·  Espacio: espejar" % ANIMS[_anim]
