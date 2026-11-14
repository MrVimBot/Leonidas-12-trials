# Plan: usar los tiles de transición en las zonas

> **Para quién es:** un modelo (Opus/Sonnet) o persona que lo va a implementar sin más contexto.
> **Antes de empezar:** lee `CLAUDE.md` entero (sobre todo "Mundo") y `docs/design/assets_pendientes.md`
> → "Tiles de transición". Responde y escribe en español.
> **Escrito el 2026-11-14**, después de añadir `tiles_transiciones.png` como fuente 1 de `naturaleza.tres`.
> Todo lo de la sección 2 se comprobó píxel a píxel contra la hoja de ejemplos de la artista
> (`docs/reference/tiles_y_como_funcionan.png`) y con pruebas `--headless` en Godot 4.7.2.

## 1. Objetivo y alcance

Que los caminos y estanques de las zonas dejen de tener **cortes bruscos** y usen las transiciones
de la artista, **de forma automática** (sin elegir tile a tile a mano) y **sin romper** lo que ya
funciona (colisiones, barreras, verificador, `VariadorPasto`).

**Dentro:** tabla de transiciones, autotiler propio, colisiones parciales, rellenos que faltan,
aplicarlo en `pueblo`, `bosque`, `casa_arbol` y arreglar el relleno de arena de `playa`/`isla`/`isla_orilla`.
**Fuera:** hierba↔arena y mar↔hierba (no hay arte completo), tiles de cueva/muelle, puentes,
el suelo de la plaza (greca, ya funciona).

### Decisiones propuestas (Esteban decide las marcadas con ❓)
1. **Autotiler propio, no los *terrains* de Godot.** Motivo: nos faltan piezas (diagonales, rellenos)
   y varias piezas solo existen **giradas** (bandera de transformación). Los terrains de Godot solo
   miran tiles/alternativas reales, no las banderas, y su modo "esquinas" pinta mal cuando faltan
   combinaciones. Un autotiler de ~150 líneas es determinista y lo pueden usar a la vez el generador
   (`build_zonas.gd`) y el editor (botón en el Inspector, como `VariadorPasto`).
2. **Giros con banderas** (`TileSetAtlasSource.TRANSFORM_FLIP_H/FLIP_V/TRANSPOSE` sumadas al id de
   alternativa), no con alternativas nuevas. **Comprobado:** la colisión se transforma sola
   (un tile con colisión solo a la izquierda, con `FLIP_H`, choca solo a la derecha). El material del
   agua también vale (es por `TileData` y las olas van en coordenadas de mundo).
3. **Colisión parcial por cuadrantes** en todo lo que tiene agua (hoy son cuadrados enteros: una
   esquina exterior bloquea 3/4 de hierba).
4. ❓ **Qué va en cada zona** (sección 5): propuesta = canales del pueblo con bordillo, caminos de
   tierra en todo el nivel 1, estanque natural en el bosque, piedra solo donde Esteban/la artista
   digan (p. ej. acceso al templo).
5. ❓ **Rellenos que faltan** (sección 3): pedirlos a la artista y, mientras, generar unos provisionales.

## 2. Cómo funcionan estos tiles (lo importante)

### 2.1 Son un juego de **esquinas** ("wang de 2 esquinas")
Cada tile se define por sus **4 esquinas**: cada una es *terreno* (agua, tierra, piedra) o *hierba*.
Con 4 esquinas hay 16 combinaciones; la artista dibujó 14 por familia:

| Pieza | Esquinas de terreno | Cuántas |
|---|---|---|
| relleno | las 4 | 1 |
| borde | 2 del mismo lado | 4 (hierba arriba / abajo / izquierda / derecha) |
| esquina exterior | 1 | 4 |
| esquina interior | 3 (la hierba asoma en una esquina) | 4 |
| *diagonal* | 2 opuestas | **0: no existen** |
| hierba | 0 | (es el pasto normal) |

Consecuencias:
- **El borde va dentro del tile.** Un camino de 2 tiles de ancho es *solo* bordes (izquierdo +
  derecho), sin relleno: así son todos los ejemplos de la hoja.
- **Anchura mínima 2 tiles.** Una franja de 1 tile no tiene dibujo.
- **Nada de diagonales**: dos zonas del mismo terreno que se tocan solo por una esquina no se pueden
  dibujar. El autotiler debe avisar.
- Las transiciones son solo terreno↔hierba. **No hay** tierra↔agua, piedra↔tierra, etc.: entre dos
  terrenos distintos siempre queda una franja de hierba (sale sola, ver 4.2).

### 2.2 Tabla completa (fuente:columna,fila · `+H`/`+V`/`+HV` = bandera de volteo)
"Ext." = esquina exterior, nombrada por la **esquina del área** que forma (sup-izq = el terreno
queda abajo a la derecha del tile). "Int." = esquina interior, nombrada por
**dónde asoma la hierba**. Si hay varias, son variantes intercambiables (elegir al azar con semilla).

| Pieza | Piedra | Bordillo (estanque) | Estanque natural | Tierra |
|---|---|---|---|---|
| relleno | **FALTA** | 0:16,0 | 1:0,2 (+volteos) | **FALTA** |
| borde, hierba arriba | 1:4,0 · 1:5,0 | 1:0,1 | 1:2,2 | 1:0,3 · 1:1,3 |
| borde, hierba abajo | 0:7,0 · 0:8,0 · 1:6,0 · 1:7,0 | 1:1,1 | 1:1,2 | 1:2,3 · 0:1,1 |
| borde, hierba izq. | 0:10,0 · 0:11,0 | 0:17,0 | 1:3,2 | 1:3,3 |
| borde, hierba dcha. | 0:10,0+H · 0:11,0+H | 0:17,0+HV | 1:4,2 | 1:4,3 |
| ext. sup-izq | 1:0,0 | 1:2,1 | 1:9,2 | 1:5,3 |
| ext. sup-der | 1:1,0 | 1:3,1 | 1:10,2 | 1:6,3 |
| ext. inf-izq | 1:2,0 · 0:6,0 | 0:18,0 | 1:11,2 | 1:7,3 |
| ext. inf-der | 1:3,0 | 1:6,1 | 1:12,2 | 1:8,3 · 0:2,1 |
| int. hierba arriba-izq | 1:8,0 | 1:4,1 | 1:5,2 | 1:9,3+V |
| int. hierba arriba-dcha | 1:9,0 · 0:9,0 | 1:5,1 | 1:6,2 | 1:10,3+V |
| int. hierba abajo-izq | 1:10,0 | 1:7,1 | 1:7,2 | 1:9,3 · 0:3,1 |
| int. hierba abajo-dcha | 1:11,0 | 1:8,1 | 1:8,2 | 1:10,3 |

Notas que corrigen lo que se creía:
- **`0:3,1` (`ARENA`/`CAMINO`) no es un relleno**: es una esquina interior (asoma hierba abajo a la
  izquierda). `0:1,1` (`ARENA_PIEDRAS`) es un borde con hierba abajo. Hoy rellenan ~3 000 celdas
  (pueblo, bosque, playa, isla…) y por eso se ve un piquito de hierba repetido cada 16 px.
- **`1:9,3` y `1:10,3` tampoco son relleno** (el comentario de `tools/recortes/tiles_transiciones.lua`
  y de `assets_pendientes.md` está mal): son esquinas interiores.
- **Tierra y piedra no tienen relleno.** Con lo que hay solo se pueden hacer caminos de 2 tiles.
- Las piezas que la artista dejó fuera de la hoja por ser un giro de otra se usan con bandera: borde
  derecho de piedra (`0:10,0+H`), borde derecho del bordillo (`0:17,0+HV`, así lo usa la hoja) y las
  interiores de arriba de la tierra (`+V`; la hoja usa `0:3,1+HV` para la de arriba-dcha, vale igual).
- El bordillo tiene sombra marrón abajo: **no girarlo** salvo `0:17,0+HV` (vertical, sin sombra).
  Piedra, tierra y estanque natural sí admiten giros (la propia hoja los usa).
- Comprobación de la tabla: el ejemplo del estanque con bordillo y el del estanque natural de la hoja
  se reconstruyen **exactos** con ella; el de tierra también (salvo deco).

## 3. Fase 1 — Rellenos que faltan (❓)

Hacen falta para caminos de 3+ tiles (camino principal del pueblo = 3, entradas de bosque y
casa_arbol = 4) y para la arena provisional de playa/isla.

1. **Pedir a la artista** (añadir a "Faltan" de `CLAUDE.md` y `assets_pendientes.md`): *tierra lisa*,
   *tierra con piedras* y *piedra lisa*, 16×16, en `tiles_y_como_funcionan.aseprite`.
2. **Mientras, provisionales**: añadir a `tools/recortes/tiles_transiciones.lua` una **fila 4**
   generada con un "parche": tomar una esquina interior y tapar su esquina de hierba con el mismo
   trozo (4×4–6×6 px) de otra interior de la misma familia que tenga esa esquina limpia:
   - tierra: `0:3,1` (hierba abajo-izq) + parche abajo-izq sacado de `1:10,3`;
   - tierra con piedras: `1:9,3` + parche de `1:10,3`;
   - piedra: `1:8,0` (hierba arriba-izq) + parche arriba-izq de `1:11,0`.
   Implementarlo en `tools/export_recortes.lua` como opción `parche = {de = {x, y}, rect = {x, y, w, h}}`
   por tile del atlas (o, si es más simple, en un script GDScript con `Image.blit_rect` que escriba
   la fila 4). Revisar a ojo ampliado: no debe verse costura. Marcar como **PROVISIONAL**.
3. En `build_tilesets.gd`, fuente 1: añadir la fila 4 a `tiles` y a `volteables` (los rellenos sin
   dirección se pueden voltear para romper la repetición).

**Hecho cuando:** existen los 3 rellenos, `naturaleza.tres` conserva su UID y las zonas actuales
se ven igual (aún no se usan).

## 4. Fase 2 — Tabla, autotiler y colisiones

### 4.1 Tabla compartida: `scripts/entorno/transiciones.gd`
`class_name Transiciones extends RefCounted` con solo datos y funciones estáticas (la usan el
generador, la herramienta del editor y `build_tilesets.gd`; así la tabla está en **un** sitio).

```gdscript
# Máscara de esquinas: bit 1 = arriba-izq, 2 = arriba-dcha, 4 = abajo-izq, 8 = abajo-dcha
# (1 = terreno). 15 = relleno, 0 = hierba.
const FAMILIAS := {
	&"tierra": {
		"piezas": { 15: [[1, Vector2i(0, 4)], ...], 12: [[1, Vector2i(0, 3)], [1, Vector2i(1, 3)]], ... },
		"solido": false,
	},
	&"bordillo": { ..., "solido": true },
	...
}
```
- Cada pieza = `[fuente, coords, banderas]` (banderas opcional, 0 por defecto). Rellenar con la
  tabla 2.2 tal cual. Orden de preferencia: primero los originales, luego los girados.
- `familia_de(capa, celda) -> StringName`: a qué familia pertenece una celda mirando su tile
  (**fuente y coords**, nunca solo coords: `1:0,0` es piedra y `0:0,0` es pasto). Precalcular un
  diccionario `Vector3i(fuente, x, y) → familia` con todas las piezas.
- `mascaras` por familia para las colisiones (4.3).

### 4.2 Autotiler: regla de "erosión"
Para cada celda `c` y cada familia `F`, la esquina compartida por 4 celdas es de `F` **solo si las
4 celdas son de `F`**. La máscara de `c` = sus 4 esquinas. Así:
- **El área pintada es el área final**: los bordes se dibujan hacia dentro (como en la hoja).
- Pintar con *cualquier* tile de la familia vale (el relleno, un borde…), y volver a aplicar da el
  mismo resultado (**idempotente**): se puede pulsar el botón tantas veces como se quiera.
- Dos terrenos distintos que se tocan quedan separados por hierba automáticamente (p. ej. donde un
  camino cruza un canal: el canal acaba en dos remates redondeados y el camino pasa entre medias,
  un "vado" con orillas; hoy `build_pueblo.gd` ya pinta los caminos encima del agua).
- **Borde del mapa:** las celdas de fuera cuentan como la celda de dentro más cercana (si no, un
  camino que sale por la puerta acabaría en un remate).
- Opción por familia `une_con: [...]` (tiles que cuentan como de la familia) para que un camino entre
  en la plaza (greca/baldosa) sin franja de hierba. ❓ probar a ojo si queda mejor con o sin.

Resultado por celda de `F`:
- máscara con pieza → poner una variante (elegida con `hash(celda) ^ semilla`, determinista);
- máscara 0 (franja de 1 tile o celda suelta) o diagonal (6 / 9) → **avisar** con la celda
  (`push_warning`) y dejar pasto. Mejor avisar que inventar.

Funciones: `static func aplicar(capa: TileMapLayer, semilla := 1, region := Rect2i()) -> Array[String]`
(devuelve los avisos). Solo escribe celdas de alguna familia; no toca pasto, mar, plaza, setos.

### 4.3 Colisiones (`tools/build_tilesets.gd`)
- Sustituir la lista a mano de `solidos` de la fuente 1 (y `16,0`, `17,0`, `18,0` de la fuente 0) por
  polígonos generados desde `Transiciones`: para cada pieza de una familia con `solido = true`, el
  polígono = **unión de los cuadrantes de 8×8 de sus esquinas de agua** (borde = medio tile,
  exterior = un cuarto, interior = una L de 6 vértices, relleno = entero). Las piezas giradas no
  necesitan nada: la bandera gira la colisión.
- Dejar un `margen` por familia (px que la colisión se mete en la hierba; 0 al empezar) por si el
  bordillo pide que no se pueda pisar.
- El mar (`19,0`, `0,1`, `17–19,1`) no se toca.
- `16,0` sigue entero. `17,0`/`18,0` hoy no los usa ninguna zona (se comprobó decodificando los
  `.tscn`), así que cambiarlos no rompe nada existente.

### 4.4 Herramientas que hay que corregir (antes de pintar nada)
- **`scripts/entorno/variador_pasto.gd`**: hoy compara solo `atlas_coords`; con la fuente 1 pintada
  convertiría las esquinas de piedra `1:0–3,0` en pasto. Saltar celdas cuya fuente no sea 0.
- **`tools/zonas/constructor_zona.gd`**: `suelo_ocupado()` y `OCUPADOS` también miran solo coords →
  usar `Transiciones.familia_de()` (o "fuente 1 = ocupado"). Igual `_suelo_ocupado` de
  `build_pueblo.gd` (aunque el pueblo ya no se regenera).
- `scripts/enemies/flor_falsa.gd` usa física y `source_id != -1`: no necesita cambios.

### 4.5 Herramienta del editor: `AutoTransiciones`
`scripts/entorno/auto_transiciones.gd`, `@tool`, igual que `VariadorPasto`: `@export var capa`,
`@export var semilla`, `@export_tool_button("Aplicar transiciones")`. Imprime los avisos. Se añade a
cada zona (el constructor lo añade solo, como el `VariadorPasto`).
**Flujo de trabajo a mano:** pintar el área con el relleno de la familia en `Suelo` → "Aplicar
transiciones" → "Variar pasto". En la escena `pueblo.tscn` es la única forma (no se regenera).

### 4.6 Constructor de zonas
- Constantes nuevas: `TIERRA`, `TIERRA_PIEDRAS`, `PIEDRA`, `AGUA_NATURAL` (los rellenos, fuente 1) y
  `AGUA` (bordillo, sigue siendo `0:16,0`). `_poner()` tiene que aceptar la fuente (hoy pone siempre 0).
- `guardar()`: llamar a `Transiciones.aplicar(suelo, semilla)` **antes** del `VariadorPasto`;
  si hay avisos, imprimirlos (y que `build_zonas.gd` falle si se quiere ser estricto).

**Hecho cuando:** una zona de prueba temporal (`scenes/levels/prueba_transiciones.tscn`, **no** se
sube) con las 4 formas de los ejemplos de la hoja se ve como la hoja; el botón es idempotente; un
camino de 1 tile y una diagonal dan aviso.

## 5. Fase 3 — Aplicarlo zona por zona

Pintar en este orden, comprobando cada una (sección 6) antes de pasar a la siguiente.

| Zona | Cómo se edita | Qué cambiar |
|---|---|---|
| `bosque` | `build_zonas.gd -- bosque` (no tiene retoques a mano: último cambio = el generador) | `_arena` → `TIERRA` (+ `TIERRA_PIEDRAS` al 12 %). Estanque `[36,14,47,21]` → `AGUA_NATURAL`. Entradas de 4 tiles necesitan el relleno. |
| `casa_arbol` | `build_zonas.gd -- casa_arbol` | `_arena` → tierra. Camino de 2 tiles + boca de 4. |
| `pueblo` | **a mano** con `AutoTransiciones` (editor/MCP). **No** ejecutar `build_pueblo.gd` (borraría barreras, NPC, Kathita…). | Canales (`AGUA_RECTS`, todos de 2 tiles: quedan como el canal izquierdo de la hoja) → **bordillo** (ya son `0:16,0`: basta con aplicar). Caminos (`CAMINO_RECTS`) → tierra; el principal norte–sur tiene 3 tiles → necesita relleno (o ensancharlo a 4 ❓). Vados: donde la calle este–oeste (filas 44–45) cruza los canales de las columnas 52–53 y 61–62. El canal que sale al este por la muralla llega al borde del mapa (regla del borde). Piedra ❓ (acceso al templo / alrededor de la plaza, si la artista lo quiere). El mar de abajo a la izquierda no se toca. |
| `playa`, `isla_orilla`, `isla` | `build_zonas.gd` | **Solo** cambiar el relleno de la arena (`ARENA` = `0:3,1`, la esquina interior) por el relleno de tierra nuevo, sin transiciones (siguen faltando hierba↔arena; los cortes rectos se quedan). Comprobar antes si alguna tiene retoques a mano. |
| `mar`, `cueva_medusa`, `cueva_jefe` | — | Nada (solo tiles provisionales). |

Recordatorio: `build_zonas.gd` **sobrescribe** las escenas. Antes de ejecutarlo, `git diff`/`git log`
de cada `.tscn` para asegurarse de que no hay retoques a mano que se perderían.

## 6. Verificación (después de cada zona)

1. `godot --headless --path . --script res://tools/verificar_zonas.gd` (enlaces, entradas libres,
   recorridos). Las colisiones parciales **abren huecos** donde antes había agua sólida entera.
2. **Pueblo, crítico:** repetir las búsquedas en anchura de `CLAUDE.md`:
   - el rincón de la casa sigue cerrado por `BarreraCartel` + `BarreraCartelOeste` (la segunda tapa
     "el hueco entre el canal y la muralla": si el remate del canal deja ahora 8 px libres, puede
     haber un hueco nuevo);
   - `Disparador` + `DisparadorOeste` de la escena de Kathita siguen encerrando la salida de casa;
   - los vados se pueden cruzar y el resto del canal no.
3. Mirar cada zona en el editor (captura con el MCP `editor_screenshot`) contra la hoja de la
   artista: sin piquitos de hierba repetidos, sin bordes cortados, agua animada también en las piezas
   giradas.
4. Jugarla: el jugador no se queda enganchado en las esquinas de las orillas y puede pisar la parte
   de hierba de los bordes.
5. `VariadorPasto` después de aplicar no cambia ningún tile de la fuente 1.

## 7. Documentación (al terminar)
- `CLAUDE.md` → "Mundo": modelo de esquinas, regla de erosión, `AutoTransiciones`, anchura mínima 2,
  sin diagonales, banderas de giro, colisión por cuadrantes; quitar "Aún no se usan en ninguna zona";
  añadir los rellenos a "Faltan" si siguen provisionales.
- `docs/design/assets_pendientes.md` → "Tiles de transición": marcar como usado; corregir lo de
  `9,3`/`10,3`.
- `tools/recortes/tiles_transiciones.lua`: corregir el comentario de la fila 3 (9–10 son esquinas
  interiores) y documentar la fila 4.
- `docs/design/plan_mapa_mundo.md` tabla de tiles: `3,1` no es relleno.

## 8. Riesgos y avisos
- **Editor abierto:** regenerar `naturaleza.tres` con el editor abierto deja la caché vieja (avisos
  "invalid UID") → cerrar Godot o "Proyecto → Recargar proyecto actual".
- **Mismo número de ancho para todo:** si alguien pinta un camino de 1 tile, desaparece (aviso).
  Explicárselo al equipo: "mínimo 2 de ancho".
- Las pruebas del pueblo con barreras dependen de colisiones: no dar por bueno el pueblo sin el
  punto 6.2.
- Si la artista entrega los rellenos, basta con cambiar las coordenadas de la fila 4 (o la fuente) en
  la tabla y volver a aplicar: el autotiler es idempotente.
