# Arte definitivo del mapa del nivel 2 (llegó el 2026-11-21, SIN integrar)

La artista entregó el arte pintado de la isla del nivel 2 (carpeta `Assets Leonidas/Fondo/Nivel_2`).
Está copiado e importado en el proyecto, pero **ninguna escena lo usa todavía**: el juego sigue con el
arte provisional. Quien lo integre debe leer esto antes de tocar `tools/build_zonas.gd`.

Estética "lineless" pintada, como los personajes (ver `arte_pintado.md`): no es pixel art, así que las
zonas del nivel 2 van en modo pintura (`Zona.pintada = true`, CANVAS_ITEMS).

## Dónde está

| Qué | Ruta | Tamaño |
|---|---|---|
| 5 capas del mapa | `assets/backgrounds/nivel2/{piso,mar,orilla,monte_1,monte_2}.png` | 9828×5873 cada una (16–40 MB) |
| 19 objetos sueltos | `assets/sprites/entorno/nivel2/*.png` | ver tabla |
| 6 layouts de referencia | `docs/reference/nivel2/layout/*.jpeg` | ~1000×600 (no se exportan) |

Todos con mipmaps activados en su `.import` (como `assets/sprites/pintados/`). Filtro: asignar
`Linear Mipmap` en el nodo que los dibuje (el filtro por defecto del proyecto es Nearest).
No se copió `.orilla.png-autosave.kra` (autosave de Krita, 148 MB: GitHub lo rechaza y no es un asset).

## Las 5 capas del mapa

- **Comparten lienzo**: las cinco miden 9828×5873 y están alineadas en (0, 0). Se colocan todas en el
  mismo punto y encajan solas. `monte_1` y `monte_2` son una colina cada una dibujada en su sitio dentro
  del lienzo (el resto es transparente).
- Orden de apilado (de abajo arriba), deducido del arte: `mar` (agua; el hueco transparente de en medio es
  donde va la isla) → `piso` (arena con dibujo y manchas de hierba) → `orilla` (acantilado y borde de
  hierba del sur y el oeste) → `monte_1`/`monte_2` (colinas) → objetos con orden por Y. Comprobarlo al
  montarlo: solo se vieron las capas sueltas, no apiladas.
- **Escala**: en modo pintura 1 px de mundo = 4 px de pantalla a 1920×1080. A escala 0,25 (1 px de arte =
  1 px de pantalla) la isla ocupa unos **2457×1468 px de mundo**, parecido a la `isla` generada (1792×1472).
  Es una decisión de quien integre; los personajes pintados ya usan `scale = 0.5` con `densidad` 2.
- **Memoria (decisión de Esteban: entran sin reducir)**: cada capa sin comprimir son ~230 MB de
  memoria de vídeo (9828×5873×4 bytes, ×1,33 con mipmaps), unos 1,2 GB las cinco. Es probable que en la
  **versión web** no quepa. `project.godot` solo tiene `import_etc2_astc` activado (no S3TC), así que
  `compress/mode=2` (VRAM) no ayuda en escritorio sin activarlo; si hace falta, opciones: activar
  S3TC/BPTC, reducir a la mitad (4914×2937) o partir las capas en trozos. Medirlo antes de decidir.
- Las capas se pueden dibujar con `Sprite2D` (centrado = false) o `TextureRect`; no hace falta TileMap.
  Las colisiones hay que dibujarlas a mano (polígonos) sobre el mapa, no salen del arte.

## Objetos de entorno (`assets/sprites/entorno/nivel2/`)

PNG con alfa, dibujados a tamaño grande. Hay que reducirlos a su escala de mundo al usarlos (`scale` del
nodo), no regenerar los PNG. Algunos traen margen vacío alrededor (comprobar el recorte al colocarlos).

| Archivo | Tamaño | Notas |
|---|---|---|
| `arbol`, `arbusto` | 1920×1920 | lienzo grande con margen |
| `palmera_1..4` | 2000×2232 · 1486×1974 · 1220×1956 · 1209×1547 | cuatro variantes |
| `palmera_coquera` | 2099×2863 | colores planos, aspecto de boceto; con cocos |
| `mini_palmera` | 527×612 | |
| `coco` | 1752×1469 | sin uso previsto (estaba fuera de alcance) |
| `cueva` | 1776×1228 | boca de la cueva de Medusa, pintada en morados |
| `estatua_1..4` | 826×939 · 774×1010 · 548×1198 · 1384×1086 | estatuas de piedra (la 1, un minotauro con tablilla) |
| `roca_1..3` | 351×609 · 459×446 · 675×509 | rocas de mar/orilla |
| `cofre_cerrado`, `cofre_abierto` | 646×445 · 636×583 | cofre con cerradura dorada; sin uso previsto |

## Layouts de referencia (`docs/reference/nivel2/layout/`)

`Layout_base_nivel_2.jpeg` es **el mapa completo de la isla** en una sola imagen (borrador pintado con
trazos de guía): una isla grande, un recorrido en «U» por el sur y el oeste, la **cueva de Medusa al este**
y rocas de mar alrededor. Los otros cinco son el mismo mapa con anotaciones:

- `…Elevaciones_entradas` y `…puntos_elevaciones`: línea rosa = bordes de las zonas elevadas; flecha y
  círculos naranjas = recorrido y entradas/salidas de la elevación del noroeste y de la esquina sureste.
- `…puntos_amarillos`, `…puntos_azules`, `…zonas_rojas`: puntos amarillos y azules y manchas rojas sobre
  el terreno.

**Interpretación PENDIENTE DE CONFIRMAR con la artista**: nadie ha escrito qué significan los colores
(las manchas rojas podrían ser zonas de enemigos o zonas prohibidas; los puntos, posiciones de objetos
o de enemigos). No poner enemigos ni colisiones a partir de ellos sin preguntar. El mapa base **no
coincide** con la `isla` actual de `build_zonas.gd` (112×92 tiles, islotes unidos por istmos): es otra
forma de isla, así que integrarlo implica rehacer la zona, no cambiar texturas.

## Qué sustituye a qué (arte provisional → definitivo)

| Hoy (provisional) | Dónde | Arte nuevo |
|---|---|---|
| `provisional/palmera.png`, `provisional/mini_palmera.png` | `entorno/provisional/`, `PALMERA`/`MINI_PALMERA` en `build_zonas.gd` | `palmera_1..4`, `palmera_coquera`, `mini_palmera` |
| `provisional/roca_mar_1..3.png` (reducciones de `environment/roca_*`; ya sin uso en `mar`, que usa `roca_barco_*`) | `entorno/provisional/` | `roca_1..3` (rocas de la isla) |
| `provisional/entrada_cueva.png` | `build_zonas.gd`, `cueva_medusa`/`isla` | `cueva` |
| estatuas y pedestales de pixel art en `isla` | `entorno/estatua.png`, `pedestal.png` | `estatua_1..4` (el pedestal no tiene equivalente) |
| suelo, arena (`Tiles.ARENA`, tierra con bordes) y agua de la isla | `provisional.tres`, `Transiciones` | capas `piso`, `orilla`, `monte_*`, `mar` |
| `arbol`, `arbusto`, `cofre_*`, `coco` | — | no sustituyen nada: arte nuevo sin uso |

**Sin arte nuevo (sigue provisional):** `roca_cueva.png` y los tiles de cueva y de la sala del jefe
(`cueva_medusa`, `cueva_jefe`), el muelle, el rayo del cíclope, los trozos de estatua, el aviso del golpe
de Medusa y demás piezas de la tabla «Arte PROVISIONAL en el juego» de `arte_pintado.md`.

## Al integrarlo

1. `tools/build_zonas.gd` **sobrescribe** las escenas de zona: o se cambia el generador, o se monta la zona
   a mano y se marca con el metadato `editada_a_mano` (ver CLAUDE.md, «Generador de zonas»).
2. Recordar que el verificador (`tools/verificar_zonas.gd`) y las pruebas (`prueba_gamba`, `prueba_medusa`…)
   dependen de las entradas, salidas y enemigos de las zonas: ejecutar `tools/verificar_todo.sh`.
3. Cuando ya no quede nada provisional en uso, retirar `tools/build_arte_provisional.gd` y
   `assets/sprites/entorno/provisional/` (y actualizar `assets_pendientes.md`).
