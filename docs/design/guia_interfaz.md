# Guía de la interfaz (UI)

Qué hay hecho, de dónde sale cada pieza y qué mirar antes de construir la siguiente.
Las páginas se refieren a los PDF de `docs/pdf/`; el índice completo está en `indice_pdfs.md`.

## Reglas que ya están decididas

- **Resolución 480×270**, escala entera ×4 (decidido el 2026-11-09). Toda la UI se diseña en píxeles de 480×270.
- **El arte de la artista se usa a su tamaño real**, nunca reescalado a mano en Godot. Si llega agrandado (como `dialog_box.png`, que venía ×6), se reduce con `tools/reducir_png.lua`.
- **Las maquetas de los PDF NO están a la escala del juego.** La del HUD (Jugabilidad p. 16) mide ~192×108 píxeles de arte (cada píxel ≈ 12,7 px en un render a 4000 de ancho), o sea, con la cámara mucho más cerca. De las maquetas se toma **la disposición** (qué va en cada esquina) y el **estilo**, no el tamaño.
- **Fuente:** `assets/fonts/perfect_dos_vga_437_win.ttf` a 16 px (glifos de 9×16), tema global `resources/ui/tema.tres`. No tiene Á Í Ó Ú mayúsculas: pasar los textos por `CajaDialogo.adaptar_a_fuente()`. A 8 px solo se lee en modo `CANVAS_ITEMS` (como hace la carta de la cinemática).
- **Textos y arte provisionales** van en `assets/ui/provisional/` o marcados como PROVISIONAL; se sustituyen cuando la artista entregue el definitivo.
- La UI va en `CanvasLayer` (HUD = capa 5, carta de la cinemática = 15, diálogos = 20, fundidos = 10/30). Los nodos de UI llevan `mouse_filter = 2` (ignorar) salvo los menús que se usen con el ratón.
- La UI solo **escucha señales** (de `Jugador`, `EstadoJuego`…); no contiene lógica del juego.

## Mapa de referencias

| Elemento | Dónde mirar | Estado |
|---|---|---|
| HUD (vida, objeto, inventario, dinero) | Jugabilidad **p. 16** (= Guión p. 2) | ✅ Hecho |
| Cuadro de diálogo, nombre, retrato, "pasar" | Jugabilidad **p. 15** + `assets/ui/dialog_box.png` | ✅ Hecho (sin retratos dibujados) |
| Burbujas sobre los NPC (… ! $) | Jugabilidad **p. 10**, Guión **p. 13** | ✅ Hecho (arte provisional) |
| Menú de ajustes / pausa | Jugabilidad **p. 15** (iconos abajo a la izquierda) | ❌ Pendiente |
| Menú del inventario | Jugabilidad **p. 17** | ❌ Pendiente |
| Vida del jefe (Medusa) | Guión **p. 38**; estilo: Jugabilidad **p. 13**; ejemplos: Guión p. 68 y p. 113 | ❌ Pendiente (nivel 2) |
| Tienda del mercader | Ninguna maqueta | ✅ Hecha (diseño provisional): `scenes/ui/menu_tienda.tscn` |
| Game over | Jugabilidad p. 8 (solo el texto "game over") | ❌ Pendiente: diseñar |
| Menú principal / título | Ninguna maqueta | ✅ Hecho (arte provisional: `scenes/ui/menu_principal.tscn`) |
| Barco: vida del barco | Jugabilidad p. 9, Guión p. 18 (solo el texto) | ✅ Hecho (provisional): corazones del barco + `MedidorViento` |

---

## Hecho

### HUD — Jugabilidad p. 16
`scenes/ui/hud.tscn` + `scripts/ui/hud.gd` (dentro de `game.tscn`, `jugador` asignado en el Inspector).

| Nodo | Posición (480×270) | Arte | Notas |
|---|---|---|---|
| `Corazones` | (2, 1), arriba a la izquierda | `assets/ui/corazones.png` (61×12, 5 estados cada 12 px: lleno, ¾, ½, ¼, vacío) | Vida en cuartos: `Vida.vida_max = 12` → 3 corazones. Añade corazones solo si sube `vida_max` (un jefe da un corazón extra, Jugabilidad p. 12) |
| `RanuraObjeto` + `Icono` | (2, 14), debajo de los corazones | `provisional/ranura_objeto.png` 14×14, `provisional/icono_espada.png` | La espada se ve si `jugador.tiene_espada`. En el nivel 2 aquí irá también el **escudo** (Guión p. 24) |
| `Inventario` | (457, 1), arriba a la derecha | `provisional/bolsa_inventario.png` 17×24, con "[ i ]" | Aún no abre nada (ver menú del inventario) |
| `Monedas` (`ContadorMonedas`) | (441, 255), abajo a la derecha | `provisional/placa_dinero.png` 39×12 + dígitos de 4×6 px dibujados en código | Escucha `EstadoJuego.monedas_cambio`, máximo 999 |
| `BarraEstamina` | Sobre la cabeza de Leonidas (−8, −33 de los pies) | Dibujada en código (16×3) | No sale en la maqueta; solo se ve mientras la estamina no está llena |

### Diálogos — Jugabilidad p. 15
Autoload `Dialogos` = `scenes/ui/caja_dialogo.tscn` (`scripts/ui/caja_dialogo.gd`).
- Caja de 300×105 en (90, 166), centrada abajo. Arte: `assets/ui/caja_dialogo.png` + `flecha_dialogo.png` (mismo lienzo; reducidos de los ×6 de la artista).
- Pestaña del nombre: x 47–136, y 9–23. Texto: x 20–260, y 33–81 (3 renglones de ~26 letras). Si una línea no cabe, se parte sola en varios cuadros.
- **Retrato** (en la p. 15, el cuadro con la cara a la izquierda: "solo personajes importantes"): `CajaDialogo.retratos` = {"Nombre" → textura de ~46×46}; con retrato el texto se estrecha 50 px. **Faltan los retratos**: pedir a la artista al menos Leonidas, Kathita, los sabios y Medusa. Las fichas del Guión p. 136 (Medusa) y p. 138 (Leonidas, expresiones) sirven de referencia.
- La caja de la maqueta de la p. 15 es distinta (dorada, sin borde azul): **manda el PNG que entregó la artista**.
- Uso: `await Dialogos.mostrar(recurso_dialogo)`; los textos se escriben en `resources/dialogues/*.tres` (ver `scripts/systems/dialogo.gd`).

### Burbujas de NPC — Jugabilidad p. 10
`ZonaDialogo` (`scripts/componentes/zona_dialogo.gd`): al acercarse el jugador muestra `burbuja_hablar` "…", `burbuja_mision` "!" o `burbuja_tienda` "$" (26×24, `assets/ui/provisional/`) en `posicion_burbuja`. En la p. 15 la burbuja sale justo encima de la cabeza del NPC.

---

## Pendiente: qué dicen los PDF

### Menú de ajustes / pausa — Jugabilidad p. 15
En la maqueta hay tres iconos abajo a la izquierda (engranaje, lista, "?") con la nota "**posiblemente quitar y volver un botón del teclado**". Con la caja de diálogo abajo en el centro no caben bien; la propuesta es **no dibujarlos** y abrir la pausa con **Esc** (`ui_cancel`, que ya usa la cinemática para saltarse) o Start en el mando. Contenido mínimo: continuar, volumen de música/efectos, controles, salir. No hay arte: pedir a la artista un marco/fondo o reutilizar el estilo de la caja de diálogo.

### Menú del inventario — Jugabilidad p. 17
Boceto ("no hay más presupuesto"):
- Un panel grande con el título **INVENTARIO en vertical** en el borde izquierdo.
- Una **rejilla de casillas** (en el boceto, 3 filas: 6, 5 y 2 casillas).
- **Pestañas abajo**: MAPA · MALDICIONES · OBJETOS · GUÍA/MISIONES.

Qué contiene cada parte, según el texto de la lámina:
- **Mapa:** hay que explorarlo o comprarlo para tenerlo completo (en el nivel 2 hay un comerciante de mapas, Guión p. 31).
- **Objetos:** consumibles (manzanas en el nivel 1, cocos en el nivel 2) y objetos importantes (espada, escudo, la cabeza de piedra de Medusa).
- **Maldiciones:** facilitan zonas a cambio de un precio. No salen en los niveles 1–2: dejar la pestaña sin contenido o quitarla.
- **Misiones:** registro de las misiones principales y secundarias (la sirena del nivel 2 da una).

Se abre con la tecla que muestra la bolsa del HUD: **[ i ]** (falta crear la acción `inventario` en el mapa de entradas: I y Select/Back en el mando).
Prioridad para la entrega: la pestaña **Objetos** (comer manzanas es la forma de curarse) y **Misiones**; el mapa puede ser una imagen fija.

### Vida del jefe (Medusa) — Guión p. 38, Jugabilidad p. 13
- En la p. 38 la vida de Medusa son **5 corazones grandes con su propio estilo** (rojos con detalles dorados, como escamas). Son los únicos que hay para Medusa.
- Regla de la p. 13: la interfaz del jefe **cambia de estética en cada nivel pero conserva la disposición del primer nivel**.
- Ejemplos de otros niveles (fuera de alcance; solo para ver cómo se coloca):
  - **Guión p. 113:** barra horizontal con la cara del jefe a la izquierda y los corazones a la derecha; también muestra corazón lleno, medio y vacío.
  - **Guión p. 68:** 5 corazones con telarañas, para Aracne.
- Propuesta: una barra arriba en el centro (los corazones del jugador están arriba a la izquierda y la bolsa a la derecha) que aparezca al empezar el combate. Pedir a la artista los corazones de Medusa a tamaño de juego (unos 12–16 px).
- Mecánicas que la UI tiene que poder mostrar:
  - Medusa es **invulnerable mientras haya cíclopes serpiente** (p. ej. los corazones en gris o con un brillo).
  - Al llegar a la **mitad de la vida** cambia de fase.

### Tienda del mercader — sin maqueta
Jugabilidad p. 10 y Guión p. 13 solo dicen que hay NPCs con tienda (burbuja "$") y "tiendas con ítems limitados"; el mercader vende consumibles (manzanas). Propuesta: reutilizar la caja de diálogo con una lista de 2–3 objetos y su precio, y descontar con `EstadoJuego.gastar_monedas()`.
- **Hecho (2026-11-10):** autoload `Tienda` (`MenuTienda`) sobre `caja_dialogo.png`, en el mismo sitio que el diálogo; pestaña = nombre del vendedor. Renglones 1–2: `> [icono] Manzana (2)   3 mon.` y `Salir` (se desplaza si hay más artículos); renglón 3: descripción o aviso en rojo oscuro (#8a1c12). Las monedas se ven en la placa del HUD, que queda libre a la derecha. Sin monedas para lo más barato, la tendera solo habla (`ComponenteTienda.dialogo_sin_monedas`).
- Pendiente de la artista: icono de moneda para el precio (ahora "mon.") y, si quiere, un marco propio para la tienda.

### Game over — sin maqueta
Jugabilidad p. 8: perder toda la vida = game over; el jugador reaparece en el último punto de control (ya implementado: `Jugador.murio` / `reaparecio`). Falta la pantalla: fundido, texto y "continuar". La animación `morir` de Leonidas ya existe.

### Barco — sin maqueta de UI (hecho, provisional)
Jugabilidad p. 9 / Guión p. 18: el barco tiene su propia vida ("llegar con toda la salud posible").
- Game emite `modo_cambio(en_barco, vida)` y el HUD llama a `seguir_vida(vida)`: los **corazones** muestran la vida del barco mientras se navega (la de Leonidas no cambia).
- En barco se ocultan la ranura del objeto y la barra de estamina.
- **`MedidorViento`** (`BarraEstamina` reutilizada, 40×5 px en (2, 15), relleno celeste `7cc4d0`, `umbral_bajo = 0`): fuerza del soplido, la misma que usa el barco (`Barco.soplido()`).
- **Pista `[Espacio]`** (Label hijo del medidor) mientras `Microfono.disponible == false` (sin permiso, sin dispositivo o sin sonido).
- Pendiente: icono de vela/viento de la artista en lugar de la barra; la pista con la fuente a 16 px ocupa mucho.

### Efectos y sonido (no son UI, pero afectan a ella)
- **Jugabilidad p. 20:** sonido para cuando los personajes hablan → en `CajaDialogo`, un "blip" por cada letra.
- **Jugabilidad p. 21:** shaders para la noche y las zonas oscuras.

---

## Cómo trabajar una pieza nueva de UI

1. Mirar su página con `swift tools/pdf_paginas.swift render <pdf> /tmp 1600 <pag>`. Para sacar arte de la maqueta, renderizar a 4000 y muestrear el centro de cada bloque de píxeles (así se sacó lo de `assets/ui/provisional/`).
2. Decidir la posición en 480×270 respetando las esquinas de la maqueta (HUD arriba-izq./arriba-der./abajo-der., diálogo abajo-centro).
3. Crear `scenes/ui/<nombre>.tscn` + `scripts/ui/<nombre>.gd` (mismo nombre base), en un `CanvasLayer`, y que solo escuche señales.
4. Si el arte es provisional, guardarlo en `assets/ui/provisional/` y anotarlo en CLAUDE.md ("Assets que faltan").
5. Probar en el juego a ×4 y comprobar que no se ve borroso (posiciones enteras, filtro Nearest).
