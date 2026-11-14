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
| Rocas del barco | 3 recortes PNG | sustituyen a `roca_mar_*` provisionales | cambiarlas en `mar` |
| Libro (inventario) | 4 láminas + 6 iconos + marco de selección | menú del libro | el menú entero |
| `icono.aseprite` | — | icono de la app / retrato pequeño | exportarlo a PNG |

---

## Tiles de transición

- **Ruta:** `assets/sprites/tiles_y_como_funcionan.aseprite` (500×380, 1 capa). Hoja de la
  artista: tiles sueltos de 16×16 arriba y en medio, y debajo ejemplos de cómo se combinan
  (render en `docs/reference/tiles_y_como_funcionan.png`).
- **Qué está preparado:**
  - De los 69 tiles sueltos, 24 ya estaban en `tiles_naturaleza.png` (iguales o girados/
    volteados; comprobado píxel a píxel). Los **45 nuevos** se empaquetan en
    `assets/tilesets/tiles_transiciones.png` (atlas 16×16, 1 px de separación) con
    `tools/recortes/tiles_transiciones.lua` (ahí está qué es cada tile y de dónde sale).
  - `tools/build_tilesets.gd` los añade como **fuente 1** de `resources/tilesets/naturaleza.tres`
    (clave nueva `fuentes_extra`; la fuente 0 no cambia, así que las zonas ya pintadas siguen
    igual). Filas: 0 suelo de piedra clara · 1 estanque con bordillo · 2 estanque natural ·
    3 camino de tierra.
  - Colisión (capa mundo) en todo lo que tiene agua (filas 1 y 2), igual que la orilla 17,0.
    Agua animada: fila 1 con `agua_estanque.tres`, fila 2 con el material nuevo
    `resources/shaders/agua_estanque_natural.tres` (su agua es de otro tono, #4db4b9).
  - Volteos (alternativas 1–3) en el agua lisa del estanque natural (0,2) y la tierra con
    piedras (9,3 y 10,3).
- **Dónde va:** suelo del pueblo (caminos de tierra y de piedra, estanques con bordillo de
  los canales), bosque y playa. Sustituye a los cortes bruscos actuales de los caminos.
- **Falta:**
  - Pintarlos: en el TileMapLayer `Suelo` de cada zona, elegir la fuente 1 en el panel de
    TileSet. `build_pueblo.gd` y `build_zonas.gd` **no** los usan (y sobrescriben las zonas):
    si se pinta a mano, no volver a ejecutarlos para esa zona.
  - Opcional: terrains (autotiling) de Godot con estas transiciones.
  - La colisión es un cuadrado entero: las orillas mixtas (media hierba, medio agua) bloquean
    también su parte de hierba. Si molesta, poner polígonos parciales en `build_tilesets.gd`.
  - Siguen faltando las transiciones **hierba↔arena** (playa).

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

## Rocas del mar (minijuego del barco)

- **Ruta:** `assets/sprites/piedras_barquito.aseprite` (90×90, 1 frame).
- **Preparado:** `tools/recortes/piedras_barquito.lua` →
  `assets/sprites/entorno/roca_barco_{pequena,alta,grande}.png` (36×24, 58×47, 70×55).
  Traen pintadas la línea del agua y la sombra (no poner `ComponenteSombra`).
- **Sustituye a:** `assets/sprites/entorno/provisional/roca_mar_{1,2,3}.png`, que usa la zona
  `mar` (generada por `tools/build_zonas.gd`).
- **Falta:** cambiar `"provisional/roca_mar_%d"` por `"roca_barco_…"` en
  `tools/build_zonas.gd` (línea de las `Rocas` de `mar`) y regenerar `mar`, o cambiarlas a mano
  en `mar.tscn`; ajustar la base de colisión de cada `Decorado` a la línea del agua pintada
  (no medida aún). Después, `verificar_zonas.gd`.

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
- **Preparado** (recortes en `assets/ui/inventario/`, con `tools/recortes/inventario_*.lua`):
  `cobertura.png`, `pag_1.png`, `pag_2y3.png`, `pag_4y5.png` (lienzo completo 1119×576:
  se superponen en (0, 0) sobre la cobertura), `icono_{salir,herramientas,objetos,mapa,misiones,guardar}.png`
  (64×56) y `seleccion_casilla.png`.
- **Cómo se ve (maqueta):** pestañas arriba a la izquierda sobre el borde del libro; la
  elegida sube 18 px y las demás van «apagadas» (= el icono con negro al 67 % encima: en
  Godot `modulate = Color(0.33, 0.33, 0.33)`). La X (salir) va abajo a la izquierda. En la
  maqueta la llama es la pestaña de Misiones y el libro abierto la de Guardar.
- **Escala — ojo:** está dibujado a tamaño real (no agrandado), pero mide 1119×576, más del
  doble que la pantalla del juego (480×270). Opciones: mostrar el menú con
  `content_scale_mode = CANVAS_ITEMS` como las pinturas de la cinemática (se ve a la
  resolución de la ventana, 1119 px ≈ 58 % de 1920), o pedir a la artista una versión a
  ~460 px. Decidirlo antes de montar el menú. Los textos («Inventario», «Mapa»…) ya vienen
  pintados.
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
