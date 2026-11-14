# Assets en el repo que aún no usa el juego

> Actualizado el 2026-11-14, al sincronizar el repo con la carpeta de la artista
> (`Assets_Leonidas`: ENEMIGOS, INTERFAZ, MAPAS, NPCs, assets varios, icono).
> Todo lo de aquí ya está importado en Godot y su arte derivado (tiras, SpriteFrames,
> recortes, TileSet) está generado. Para regenerarlo: `tools/export_sprites.sh`
> (mejor con el editor cerrado; ver CLAUDE.md, «Pipeline de sprites»).
>
> Cuando algo de esta lista se use en una escena, quitarlo de aquí.

## Resumen

| Asset | Preparado | Para qué | Falta |
|---|---|---|---|
| Tiles de transición | atlas + fuente 1 de `naturaleza.tres` | caminos, estanques, plaza | pintarlos en las zonas |
| Los 4 sabios | 4 layouts, tiras, SpriteFrames | escena de los sabios (espada + misión) | la escena |
| Gallo y perro | layouts, tiras, SpriteFrames | más NPC del pueblo | colocarlos + diálogos |
| Libro (inventario) | 4 láminas + 6 iconos + marco de selección, reducidos a ×0,4 | menú del libro | el menú entero (`plan_inventario_libro.md`) |
| `icono.aseprite` | — | icono de la app / retrato pequeño | exportarlo a PNG |

---

## Tiles de transición

- **Ruta:** `assets/sprites/tiles_y_como_funcionan.aseprite` (hoja de la artista; render en
  `docs/reference/tiles_y_como_funcionan.png`) → `assets/tilesets/tiles_transiciones.png`
  (fuente 1 de `naturaleza.tres`) con `tools/recortes/tiles_transiciones.lua`.
- **USADOS** desde el 2026-11-14 (ver `docs/design/plan_tiles_transiciones.md` y `CLAUDE.md` →
  "Transiciones"): autotiler `scripts/entorno/transiciones.gd`, botón `AutoTransiciones` en cada
  zona. Pueblo (canales con bordillo, caminos de tierra), bosque (estanque natural), casa_arbol,
  playa e islas.
- **Falta (pedir a la artista):**
  - **Rellenos** de *tierra* (liso y con piedras) y de *piedra*, 16×16. No existen: hoy son
    provisionales (fila 4 del atlas, una esquina interior con el pico de hierba tapado). Cuando
    lleguen, cambiar las coords de la fila 4 en `tiles_transiciones.lua` (o en la tabla).
  - Transiciones **hierba↔arena** (playa; hoy la arena es tierra) y **mar↔hierba/arena** completas.
  - Opcional: piezas diagonales (dos zonas que se tocan por una esquina) y un **puente** para los
    vados del pueblo.
  - El suelo de **piedra** está preparado pero no se usa en ninguna zona: decidir dónde va.

## Los sabios

- **Ruta:** `assets/sprites/los_sabios.aseprite` (150×140, 8 frames de 100 ms; capas
  `parados` y `caminando`). Cuatro sabios en fila, **solo de frente**:
  1 toro (cuernos, túnica roja) · 2 carnero (cuernos enroscados, túnica a rayas) ·
  3 fauno (corona de laurel, cola) · 4 ave (pico; el más alto).
- **Preparado:** `tools/sprite_layouts/sabio_{1..4}.lua` → `assets/sprites/strips/sabio_N/`
  → `resources/sprite_frames/sabio_N.tres` con `parado_frente` (respiran) y `caminar_frente`
  (andan en el sitio). Celda 48×60, origen (24, 58): en el `AnimatedSprite2D`
  `offset = (0, −28)` para que la posición sean los pies.
- **Dónde va:** escena de los sabios en el templo del pueblo (dan la espada y ponen
  `EstadoJuego.mision_recibida = true`). Se pueden instanciar como `scenes/npcs/npc.tscn`
  con `sprite_frames = sabio_N.tres`, `paseo = false` y `burbuja = MISION`.
- **Falta:** la escena y sus diálogos; no hay vistas de lado ni de espalda (el
  `AnimadorDireccional` usará la de frente); retratos para la caja de diálogo.

## Gallo y perro

- **Rutas:** `assets/sprites/npc_gallo.aseprite` (70×40) y `assets/sprites/npc_perro.aseprite`
  (70×39). 1 frame, 1 capa: una pose en frente / lado (mira a la izquierda) / espalda.
- **Preparado:** `tools/sprite_layouts/npc_{gallo,perro}.lua` → tiras →
  `resources/sprite_frames/npc_{gallo,perro}.tres` (`parado_frente/lado/espalda`). Misma
  celda que los otros NPC (56×52, origen (28, 50)): `offset (0, −24)`, el que ya trae `npc.tscn`.
- **Dónde va:** NPC del pueblo (`Objetos/NPCs` de `pueblo.tscn`, a mano).
- **Falta:** no tienen animación de caminar → usar `paseo = false` (o pedir la animación);
  diálogos en `resources/dialogues/npc_*.tres`.

## Libro (menú de inventario)

- **Rutas** (`.aseprite` en `assets/sprites/inventario/`):
  - `cobertura.aseprite` (1119×576): tapas del libro (fondo azul oscuro).
  - `pag_1.aseprite`: página derecha «Objetos Importantes» (rejilla 4×3 + casilla suelta).
  - `pag_2y3.aseprite`: «Inventario» (rejilla 4×3 + casilla) y «Mapa» (zona oscura, rosa de
    los vientos, cartela).
  - `pag_4y5.aseprite`: «Misiones» (Principales / Secundarias, 3 líneas cada una) y
    «Guardar» (retrato de Leonidas, «Tiempo jugado», «Jefes derrotados», botón Guardar).
  - `iconos_de_inventario.aseprite` (270×150): las 6 pestañas.
  - `seleccion_de_casilla_de_inventario.aseprite` (80×80): marco blanco de la casilla elegida.
  - `inventario_y_como_se_debe_de_ver.aseprite`: **maqueta** de cómo se combina todo (render
    en `docs/reference/inventario_maqueta.png`). No se exporta: es referencia.
- **Preparado** (recortes en `assets/ui/inventario/`, con `tools/recortes/inventario_*.lua`,
  **reducidos a ×0,4** con la opción `escala` de `export_recortes.lua`):
  `cobertura.png`, `pag_1.png`, `pag_2y3.png`, `pag_4y5.png` (lienzo completo 448×230:
  se superponen en (0, 0) sobre la cobertura), `icono_{salir,herramientas,objetos,mapa,misiones,guardar}.png`
  (26×22) y `seleccion_casilla.png` (32×32).
- **Cómo se ve (maqueta):** pestañas arriba a la izquierda sobre el borde del libro; la
  elegida sube 18 px (7 reducido) y las demás van «apagadas» (= el icono con negro al 67 %
  encima: en Godot `modulate = Color(0.33, 0.33, 0.33)`). La X (salir) va abajo a la
  izquierda. En la maqueta la llama es la pestaña de Misiones y el libro abierto la de Guardar.
- **Escala (decidido 2026-11-14):** el original mide 1119×576 a 1:1 (no agrandado), más del
  doble que la pantalla (480×270). Se usa reducido a 448×230 en el viewport normal; se pidió
  a la artista que lo retoque/redibuje a ese tamaño. Medidas de casillas, pestañas y mapa, y
  el plan del menú: **`plan_inventario_libro.md`**.
- **Sustituye a:** `assets/ui/provisional/icono_libro.png` (lo usa `scenes/ui/hud.tscn`) y
  `bolsa_inventario.png` (posible: `icono_guardar.png` o `icono_objetos.png`, aunque a 64×56 son grandes para
  el HUD) y al menú del libro, que aún no existe (ver CLAUDE.md, «Escena de Kathita», y
  `guia_interfaz.md`).
- **Falta:** todo el menú (acción `inventario`, navegación por pestañas y casillas, mapa,
  misiones, guardado en disco); iconos de los objetos para las casillas.

## Icono

- **Ruta:** `assets/sprites/icono.aseprite` (21×17): cabeza de Leonidas.
- **Dónde va:** icono de la aplicación (hoy `res://icon.svg`) o retrato mini.
- **Falta:** exportarlo a PNG (agrandado sin suavizar si se usa como icono de la app) y
  ponerlo en `application/config/icon`.

## Ya en el repo antes de esta sincronización y sin usar todavía

- `assets/sprites/environment/*.png`: ilustraciones grandes (~600 px), no pixel art a escala.
- `assets/ui/dialog_box.png`, `dialog_continue_arrow.png`: originales a ×6; el juego usa
  `caja_dialogo.png` / `flecha_dialogo.png`.
- `leonidas.aseprite`: versión antigua de Leonidas, no la usa ninguna escena.
