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
| Libro (inventario) | piezas de la maqueta de 559×300 sin reescalar (`assets/ui/libro/`) | **ya se usa** (`menu_libro.tscn`, a ×3 de pantalla) | páginas sin textos pintados, icono del libro, mapa pintado |
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
    en `docs/reference/inventario_maqueta.png`). No se exporta: es referencia. Desde el
    2026-11-14 es la versión de **559×300** (la de 1119×600 a ×0,5, retocada; textos aún
    pintados; la anterior está en el historial de git).
  - `objetos/{espada,la_nota,manzana}.aseprite`: iconos de objeto (16×16, 13×12, 16×16) →
    `assets/ui/inventario/objetos/icono_{espada,carta,manzana}.png`, **ya en uso** en
    `resources/objetos/`.
- **En uso** (desde el 2026-11-14): `tools/export_libro.lua` saca de la maqueta de 559×300,
  por capas y **sin reescalar**, `assets/ui/libro/`: `cobertura.png`, `pag_1.png`,
  `pag_2y3.png`, `pag_4y5.png` (lienzo completo), `pestana_<pagina>.png` y
  `pestana_<pagina>_apagada.png` (31×28; la apagada lleva la capa «APAGADO» de la artista,
  negro al 67 %), `salir[_apagada].png`, `seleccion.png` (39×40) y `libro.json` (posiciones
  de todo eso y de las 13 casillas de cada rejilla, detectadas en las capas «CASILLAS PARA
  HERRAMIENTAS»). Las piezas reducidas a ×0,4 de los `.aseprite` de 1119×576 se borraron
  (están en el historial de git).
- **Cómo se ve:** pestañas arriba a la izquierda sobre el borde del libro; la elegida sube
  8 px y se ve encendida, las demás apagadas. La X (salir) va abajo a la izquierda, apagada
  salvo con el ratón encima. La llama es la pestaña de Misiones y el libro abierto la de Guardar.
- **Escala (decidido 2026-11-14):** 559×300 no cabe en 480×270; el menú pone la ventana en
  modo `CANVAS_ITEMS` mientras está abierto y dibuja cada píxel del arte a 3 píxeles de
  pantalla en 1920×1080 (2 en ventanas menores). Ver CLAUDE.md («El libro») y
  **`plan_inventario_libro.md`**.
- **Sustituye a:** `assets/ui/provisional/icono_libro.png` (lo usa `scenes/ui/hud.tscn`) y
  `bolsa_inventario.png` (posible: `icono_guardar.png` o `icono_objetos.png`, aunque a 64×56 son grandes para
  el HUD) y al menú del libro, que aún no existe (ver CLAUDE.md, «Escena de Kathita», y
  `guia_interfaz.md`).
- **Falta:** las páginas sin textos pintados (títulos, rótulos de Guardar, «!» de Misiones)
  y el icono del libro (objeto y HUD). La
  espada de 16×16 podría sustituir también a `provisional/icono_espada.png` de la ranura
  del HUD (14×14): no se ha cambiado.

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
