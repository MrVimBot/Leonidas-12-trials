extends RefCounted
## Coordenadas con nombre de los tiles de los atlas del mundo, en UN solo sitio para los
## generadores (constructor_zona.gd, build_zonas.gd, build_pueblo.gd).
##
## Uso (sin class_name: tools/ no se exporta con el juego):
##   const Tiles := preload("res://tools/zonas/tiles.gd")
##
## ⚠ Si la artista mueve un tile, acordarse también de scripts/entorno/transiciones.gd
## (tabla FAMILIAS: coordenadas de las piezas de caminos y estanques). Ese archivo es código
## del juego y del editor y no puede depender de tools/, así que repite las coordenadas.
##
## Un tile es Vector2i (fuente 0) o Vector3i(fuente, columna, fila).

# --- Atlas naturaleza (fuente 0 de resources/tilesets/naturaleza.tres) ---------------
const PASTO := Vector2i(0, 0)
const SETO := Vector2i(12, 0)
const MAR := Vector2i(19, 0)
const MAR_ORILLA := Vector2i(0, 1)
const CAMINO_PIEDRAS := Vector2i(1, 1)
const CAMINO := Vector2i(3, 1)
const GRECA_ESQUINA := Vector2i(4, 1)
const GRECA_BORDE := Vector2i(5, 1)
const BALDOSA := Vector2i(6, 1)

# Rellenos de las familias de transiciones (scripts/entorno/transiciones.gd): se pinta el
# área con el relleno y guardar() pone los bordes y esquinas. Mínimo 2 tiles de ancho.
const AGUA := Vector2i(16, 0) # estanque con bordillo
const AGUA_NATURAL := Vector3i(1, 0, 2) # estanque natural (orilla de hierba)
const TIERRA := Vector3i(1, 0, 4) # camino de tierra (relleno PROVISIONAL)
const TIERRA_B := Vector3i(1, 1, 4) # otra variante del relleno de tierra
const PIEDRA := Vector3i(1, 2, 4) # suelo de piedra (relleno PROVISIONAL)
# Arena de playa/isla: hasta que lleguen las transiciones hierba↔arena es el relleno de
# tierra SIN bordes (zonas con `transiciones = false`). Antes era 3,1, que es una esquina
# interior (por eso se veía un pico de hierba cada 16 px).
const ARENA := TIERRA
const ARENA_PIEDRAS := TIERRA_B

# --- Atlas provisional (resources/tilesets/provisional.tres) -------------------------
const SUELO_CUEVA := Vector2i(0, 0)
const SUELO_CUEVA_B := Vector2i(1, 0)
const PARED_CUEVA := Vector2i(2, 0)
const VACIO := Vector2i(3, 0)
const MAR_NAV := Vector2i(4, 0)
const MAR_NAV_OLA := Vector2i(5, 0)
const LOSA_JEFE := Vector2i(6, 0)
const MUELLE := Vector2i(7, 0)
const ARRECIFE := Vector2i(8, 0)

## Tiles de la fuente 0 donde dispersar() no pone nada (caminos, agua, mar, orillas). Toda
## la fuente 1 (transiciones) cuenta también como ocupada.
const OCUPADOS := [Vector2i(3, 1), Vector2i(1, 1), Vector2i(2, 1), AGUA, Vector2i(17, 0), Vector2i(18, 0),
	MAR, MAR_ORILLA, Vector2i(17, 1), Vector2i(18, 1), Vector2i(19, 1), BALDOSA, Vector2i(4, 1), Vector2i(5, 1),
	Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0), Vector2i(9, 0), Vector2i(10, 0), Vector2i(11, 0)]
