class_name Remolino
extends Node2D
## Remolino del mar (minijuego del barco). Arrastra al barco hacia su centro, con más
## fuerza cuanto más cerca; en el centro, su Hitbox quita vida. Soplando fuerte (o
## remando hacia fuera) se escapa: la aceleración del barco es mayor que `fuerza`.
## Posición = centro. El sprite va con z_index −1: sobre el agua y bajo el barco.

## Distancia a la que empieza a arrastrar.
@export var radio_arrastre := 56.0
## px/s² en el centro (crece desde 0 en el borde). Tiene que ganar a la fricción del
## barco (90) a media distancia y perder contra su aceleración (240) al remar fuera.
@export var fuerza := 220.0


func _physics_process(delta: float) -> void:
	var barco := get_tree().get_first_node_in_group(&"barco") as Barco
	if barco == null or barco.estado == Barco.Estado.HUNDIDO:
		return
	var hacia := global_position - barco.global_position
	var d := hacia.length()
	if d > radio_arrastre or d < 1.0:
		return
	barco.velocity += hacia / d * fuerza * sqrt(1.0 - d / radio_arrastre) * delta
