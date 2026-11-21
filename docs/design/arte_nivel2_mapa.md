# Arte definitivo del mapa del nivel 2 (llegó el 2026-11-21, INTEGRADO en la `isla`)

La artista entregó el arte pintado de la isla del nivel 2 (carpeta `Assets Leonidas/Fondo/Nivel_2`).
Desde el 2026-11-21 la zona `isla` está **rehecha con él siguiendo el layout** (no es la isla de
islotes que generaba `tools/build_zonas.gd`), y las palmeras de `isla_orilla` también son las nuevas.

Estética "lineless" pintada, como los personajes (ver `arte_pintado.md`): no es pixel art, así que las
zonas del nivel 2 van en modo pintura (`Zona.pintada = true`, CANVAS_ITEMS).

## Dónde está

| Qué | Ruta | Tamaño |
|---|---|---|
| 5 capas del mapa | `assets/backgrounds/nivel2/{piso,mar,orilla,monte_1,monte_2}.png` | 9828×5873 cada una (16–40 MB) |
| 19 objetos sueltos | `assets/sprites/entorno/nivel2/*.png` | ver tabla |
| 6 layouts de referencia | `docs/reference/nivel2/layout/*.jpeg` | ~1000×600 (no se exportan) |

Todos con mipmaps activados en su `.import`. El filtro `Linear Mipmap` lo pone el nodo que los
dibuja (el del proyecto es Nearest): el nodo `Mapa`, `Decorado` con `escala` ≠ 1, el `Arboles` de
`BosqueDenso` y el `Visual` del cofre. Las capas entraron **sin reducir** (decisión de Esteban; la
versión web no importa).

## Cómo está montada la `isla`

- **Escala 0,25**: el lienzo ocupa **2457×1468 px de mundo** (`limites_camara`); en modo pintura,
  1 px del arte = 1 px de pantalla a 1920×1080.
- **Capas**: nodo `Mapa` (`z_index −1`) con un `Sprite2D` por capa en (0, 0), de abajo arriba
  `mar` → `piso` → `orilla` → `monte_1` → `monte_2` (comprobado: encajan así). `orilla` es la «U»
  elevada del sur con su acantilado; `monte_1`/`monte_2` son la elevación del noroeste (con sus
  rampas). `Suelo` (TileMapLayer) se queda vacío.
- **Layouts**: son el mapa entero estirado a su tamaño (comprobado superponiéndolos), así que un
  punto del layout pasa a mundo multiplicando por 9828/ancho y 5873/alto, y por 0,25.
- **Montaje**: `tools/zonas/isla/analizar_isla.py` saca del arte y los layouts los datos
  (`isla_datos.json`) y `tools/zonas/isla/montar_isla.gd` montó la escena **una vez** (ver sus
  cabeceras). La escena tiene el metadato `editada_a_mano`: se retoca en el editor y ningún
  generador la sobrescribe. `build_zonas.gd` ya no la genera.

### Significado de los layouts (confirmado por Esteban el 2026-11-21)

| Anotación | Significa | En el juego |
|---|---|---|
| Manchas rojas | bosque muy denso, infranqueable (medio laberinto) | 7 `BosqueDenso` (`Objetos/Bosques`): polígono sólido + ~530 árboles pintados |
| Puntos azules | enemigos | 28 enemigos en `Objetos/Enemigos`: 3 peces espada (los puntos con más sitio para correr), 3 cíclopes (noreste y junto a la cueva) y 22 gambas |
| Puntos amarillos | cofres | 5 `Cofre` en `Objetos/Cofres` |
| Contorno rosa | elevación | «U» del sur y elevación del noroeste |
| Círculos naranjas | únicas entradas/salidas de una elevación | huecos en la pared de la elevación (`aberturas` de `isla_datos.json`): 2 en la del noroeste, 1 en la «U» (punta del brazo este) |
| X junto a la cueva | nada | — |

- **Colisión**: `Colisiones/Costa` (mar, acantilados de `orilla`/`monte_*`, franja de costa del
  oeste y borde del mapa) y `Colisiones/BordesElevacion` (pared fina de 4 px alrededor de cada
  elevación, salvo en las aberturas): polígonos simples por trozos, editables punto a punto en
  el editor 2D. `Colisiones/ColisionCueva`: contorno del montículo con una muesca hasta la boca.
  La voltereta no los atraviesa (capa mundo).
- **Entradas**: `desde_orilla` (125, 60) y `SalidaOrilla` arriba a la izquierda (el camino de arena
  que sale por el borde superior); `PuntoControlIsla` (125, 110); `SalidaCueva` en la boca de la
  `cueva` (2245, 780) y `desde_cueva` (2245, 848). Los nombres no cambian: `isla_orilla` y
  `cueva_medusa` no se tocaron.
- **Objetos**: palmeras `palmera_1..4` y `mini_palmera`, dos `arbol`, rocas `roca_2`/`roca_3` en
  tierra, cristales `roca_1` en el mar (sin colisión), las cuatro estatuas por el recorrido y tres
  **palmeras coqueras** (`scenes/entorno/palmera_coquera.tscn`: sueltan cocos al golpearlas, como
  el manzano). Las columnas y ruinas del layout se quitaron (decidido).
- **Cofres** (`scenes/entorno/cofre.tscn`): se abren con interactuar, dan su premio una vez y se
  quedan abiertos (`EstadoJuego.cofres_abiertos`, en la partida). Premios PROVISIONALES: 10
  monedas · 2 manzanas · 20 monedas · 30 monedas + 2 cocos (final de la «U») · 3 cocos.
- **Coco** (`resources/objetos/coco.tres`): consumible como la manzana (cura 1 corazón, máx. 9, se
  come desde el libro). Iconos PROVISIONALES reducidos del `coco.png` pintado.
- Prueba: `tools/pruebas/prueba_isla.gd` (se llega a cofres y enemigos; a las elevaciones, solo
  por las aberturas; cofres; cocos). El verificador de zonas la recorre como a las demás.

## Objetos de entorno (`assets/sprites/entorno/nivel2/`)

PNG con alfa, dibujados a tamaño grande: se reducen con la escala del nodo (`Decorado.escala`), no
regenerando los PNG. Escalas usadas (px de mundo de alto aproximados entre paréntesis):

| Archivo | Tamaño | Escala en la isla |
|---|---|---|
| `arbol`, `arbusto` | 1920×1920 (con margen) | 0,052 (100) · en bosques, 80–110 de alto |
| `palmera_1..4` | 2000×2232 · 1486×1974 · 1220×1956 · 1209×1547 | 0,036 · 0,041 · 0,041 · 0,052 (~80) |
| `palmera_coquera` | 2099×2863 | 0,032 (92) |
| `mini_palmera` | 527×612 | 0,049 (30) |
| `coco` | 1752×1469 | solo para los iconos del objeto |
| `cueva` | 1776×1228 | 0,197 (350 de ancho, como en el layout) |
| `estatua_1..4` | 826×939 · 774×1010 · 548×1198 · 1384×1086 | ~50 de alto |
| `roca_1..3` | 351×609 · 459×446 · 675×509 | cristal 0,06–0,08 · 0,076 · 0,055 |
| `cofre_cerrado`, `cofre_abierto` | 646×445 · 636×583 | 0,04 (26 de ancho) |

`arbol` y `arbusto` traen ~150 px de margen vacío bajo el tronco: a su escala, el tronco queda
~8 px por encima del punto de apoyo (se nota poco; si molesta, recortar el margen en la textura
importada con un `AtlasTexture`).

## Qué sustituyó a qué

| Antes (provisional) | Ahora |
|---|---|
| suelo, arena y agua de la `isla` (tiles) | capas del mapa |
| palmeras de `isla` e `isla_orilla` (`entorno/provisional/palmera*`) | `palmera_1..4`, `mini_palmera` |
| `provisional/entrada_cueva.png` | `cueva` |
| estatuas, pedestales y ruinas de pixel art de la `isla` | `estatua_1..4` (sin ruinas) |
| manzanos y vasijas de la `isla` | palmeras coqueras y cofres |

**Sigue provisional:** los tiles de `cueva_medusa` y `cueva_jefe` (`roca_cueva.png` incluida), el
muelle y el suelo de `isla_orilla`, el rayo del cíclope, los trozos de estatua, el aviso del golpe
de Medusa y demás piezas de la tabla «Arte PROVISIONAL en el juego» de `arte_pintado.md`.
`assets/sprites/entorno/provisional/` y `tools/build_arte_provisional.gd` **no se retiran**: la
playa (nivel 1) sigue usando las palmeras provisionales y las cuevas, sus tiles y la roca
(`entrada_cueva.png` ya no la usa nadie).
