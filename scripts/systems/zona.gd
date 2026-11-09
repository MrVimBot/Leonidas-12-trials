class_name Zona
extends Node2D
## Una zona del mundo (cuarto, casa, pueblo, bosque, playa...). Cada una es su propia
## escena en scenes/levels/ y Game la carga dentro de su nodo "Mundo".
##
## Estructura esperada:
##   Zona (este script, y_sort_enabled)
##   ├─ Suelo (TileMapLayer)       tiles pintados; z_index -1 para quedar siempre debajo
##   ├─ Objetos (Node2D, y_sort)   Decorados, NPC, enemigos... ordenados por Y con el jugador
##   ├─ Entradas (Node2D)          Marker2D con nombre: donde aparece el jugador ("inicio", "desde_bosque"...)
##   └─ SalidaXxx (SalidaZona)     zonas que llevan a otra escena

## Nombre para mostrar (cartel de zona, guardado...).
@export var nombre_zona := ""
## Límites de la cámara en píxeles. Si está vacío se usa el rectángulo pintado en `suelo`.
@export var limites_camara := Rect2i()
@export var suelo: TileMapLayer


## Rectángulo (en píxeles del mundo) que la cámara no debe sobrepasar.
func obtener_limites() -> Rect2i:
	if limites_camara.has_area():
		return limites_camara
	if suelo == null:
		return Rect2i()
	var usadas := suelo.get_used_rect()
	var tam := suelo.tile_set.tile_size
	return Rect2i(usadas.position * tam, usadas.size * tam)


## Posición donde aparece el jugador al entrar por `nombre`.
func punto_entrada(nombre: String) -> Vector2:
	var marcador := get_node_or_null(NodePath("Entradas/" + nombre)) as Node2D
	if marcador == null:
		push_warning("Zona %s: no existe la entrada '%s', uso 'inicio'" % [name, nombre])
		marcador = get_node_or_null(^"Entradas/inicio") as Node2D
	return marcador.global_position if marcador else global_position
