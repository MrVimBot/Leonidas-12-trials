class_name SalidaZona
extends Area2D
## Al entrar el jugador, Game carga `zona_destino` y lo coloca en `entrada_destino`.
## Se pone en el borde del mapa (camino que sale del pueblo) o en una puerta.
## Necesita un CollisionShape2D hijo. Capa 0, máscara jugador (2).
##
## Ojo: el Marker2D de entrada de la zona destino no debe estar encima de su salida
## de vuelta, o el jugador rebotaría entre las dos zonas.

## Escena de la zona a la que lleva.
@export_file("*.tscn") var zona_destino := ""
## Nombre del Marker2D (dentro de "Entradas") de la zona destino.
@export var entrada_destino := "inicio"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # jugador
	monitorable = false
	body_entered.connect(_al_entrar)


func _al_entrar(cuerpo: Node2D) -> void:
	if not cuerpo is Jugador or zona_destino.is_empty():
		return
	var game := get_tree().get_first_node_in_group(&"game")
	if game:
		game.cambiar_zona.call_deferred(zona_destino, entrada_destino)
	else:
		push_warning("SalidaZona: no hay ningún nodo en el grupo 'game'")
