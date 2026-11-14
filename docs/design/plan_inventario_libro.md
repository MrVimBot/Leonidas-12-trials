# Plan: el libro (menú de inventario)

> Escrito el 2026-11-14 a partir de los mensajes de Lucía (artista) y del arte que ya está en
> `assets/sprites/inventario/`. Relacionado: `plan_entrega_libro_kathita.md` (cómo se consigue
> el libro), `guia_interfaz.md` («Menú del inventario») y `assets_pendientes.md` («Libro»).

## Qué pidió la artista

- El libro abierto ocupa la pantalla. Tres pares de páginas:
  1. tapa vacía + **Objetos Importantes** (rejilla 4×3 + una casilla suelta);
  2. **Inventario** (rejilla 4×3 + casilla suelta) + **Mapa**;
  3. **Misiones** (3 principales, 3 secundarias) + **Guardar** (retrato, tiempo jugado, jefes
     derrotados, botón Guardar).
- Cinco pestañas arriba a la izquierda (espada, bolsa, mapa, llama, libro) y una X abajo a la
  izquierda. **La pestaña de la página en la que estoy se enciende y sube; el resto se apaga.**
- **La casilla suelta de abajo es para el artículo seleccionado** (su descripción).
- Falta decidir **cómo se mueve uno** entre las casillas y qué opciones tiene cada objeto.
- Los iconos de los objetos de las casillas los entrega después.

## El problema del tamaño (medido)

| Pieza | Tamaño | Notas |
|---|---|---|
| Lienzo de páginas y tapas | 1119×576 | el libro ocupa 1079×542 dentro |
| Maqueta con pestañas | 1119×600 | las pestañas asoman 24 px por arriba |
| Pestañas | 64×56 | |
| Casillas de la rejilla | 68×68, cada ~93 px en x y ~88 px en y | |
| Casilla suelta | ~77×75 | |
| Marco de selección | 80×80 | |
| **Pantalla del juego** | **480×270** | el libro es 2,3 veces más ancho |

Comprobado píxel a píxel: el arte **no viene agrandado** (no hay bloques de 2×2, 3×3…; las
tapas tienen ~6000 colores, es pintura a 1:1). No se puede «deshacer una ampliación» como
se hizo con la caja de diálogo (que venía a ×6).

### Opciones

| | Cómo | A favor | En contra |
|---|---|---|---|
| **A. Tamaño real** | Mostrarlo a 1:1 sobre la ventana de 1920×1080 con `content_scale_mode = CANVAS_ITEMS` (como las pinturas de la cinemática) | Se ve cada píxel que dibujó Lucía | Ocupa solo el 58 % del ancho; sus píxeles son 4 veces más pequeños que los del juego (dos estilos a la vez); hay que cambiar el modo de la ventana al abrir/cerrar; en una ventana que no sea 1920×1080 la escala deja de ser entera; la fuente del juego a ese tamaño queda diminuta |
| **B. Reducido a ×0,4** (recomendada) | Reducir todo a 448×230 (240 con pestañas) y usarlo en el viewport normal de 480×270 | Llena la pantalla (93 % del ancho); mismo tamaño de píxel que el resto del juego; nada especial en el código; la fuente del juego (16 px) cabe en renglones y títulos | Se pierde detalle fino; los rótulos pequeños («Tiempo jugado:») quedan borrosos; las casillas quedan en ~27 px y no todas idénticas (0,4 no es entero) |
| C. Redibujado | Lucía lo rehace a ~448×230 | El mejor resultado | Tiempo de la artista, a dos semanas de la entrega |

Comparativas (a 1920×1080, como se vería en pantalla):
`docs/reference/inventario_escala_a_tamano_real.png`,
`docs/reference/inventario_escala_b_reducido.png` y
`docs/reference/inventario_escala_b_reducido_misiones.png`.

**Decidido (2026-11-14): B de momento, C cuando la artista entregue todo.** El menú se monta ya con el arte reducido por script; al llegar el arte redibujado a 448×230 se sustituye (quitar `escala` de `tools/recortes/inventario_*.lua` y volver a medir casillas y pestañas). Propuesta original: empezar con **B** hecha por script (se regenera sola si Lucía cambia el arte)
y, si le sobra tiempo, que retoque encima el PNG reducido (casillas, rótulos pequeños) → eso
ya sería C sin empezar de cero. Enseñarle las comparativas antes de montar nada.

### Consecuencias de B que conviene avisar a Lucía

- **Iconos de los objetos:** la casilla reducida mide ~27×27 → dibujarlos a **16×16** (o
  hasta 24×24), como el resto del pixel art del juego, no a 68×68.
- **Rótulos pequeños** de Guardar («Tiempo jugado:», «Jefes derrotados:»): ilegibles al
  reducir. Mejor que entregue esa página sin ellos y los escribe el juego con su fuente
  (así además se pueden poner los valores al lado).
- Los seis «!» de Misiones vienen pintados: con menos de seis misiones quedarían «!» sueltos.
  Pedir la página sin ellos (o el «!» aparte) y que los dibuje el juego.
- El retrato de Leonidas de Guardar está dibujado más grande que el pixel art del juego; al
  reducir queda bien, no hace falta tocarlo.

## Diseño de la navegación (propuesta para Lucía)

### Abrir y cerrar
- Acción nueva **`inventario`**: tecla **I**, mando **Select/Back**. Solo con
  `EstadoJuego.tiene_libro`, a pie, en estado NORMAL (no en diálogos, tienda, cinemáticas ni
  en el barco).
- Al abrir, el juego **se pausa** de verdad (`get_tree().paused`): no basta con bloquear a
  Leonidas, porque los enemigos seguirían atacando.
- Cerrar: I, Esc, Espacio/K (cuando no hay nada que cancelar) o la X.
- Se abre siempre en **Inventario** (la página más usada).

### Moverse
(Aprobado por el equipo.) Dos niveles, todo con las flechas/WASD y los botones de siempre:

1. **Dentro de una página** (lo normal): las flechas mueven el marco blanco
   (`seleccion_casilla`) por la rejilla. Al salir por un lado de la rejilla se pasa a la
   página vecina (del Inventario hacia la derecha → Mapa; desde la primera columna hacia la
   izquierda → Objetos Importantes, pasando la hoja). Desde la fila de arriba, ↑ sube a las
   pestañas.
2. **En las pestañas**: ←/→ cambian de página; ↓ o E/J entra en ella.

Atajo: **Q / R** (mando L1/R1) pasan de página desde cualquier sitio (acciones
`pagina_anterior` / `pagina_siguiente`).

**Pestañas (decidido):** solo se enciende y sube (7 px) la pestaña de **la página en la
que está el cursor**; las otras cuatro, apagadas (`modulate` 0,33), aunque su página se vea
al lado.

### Casilla suelta = artículo seleccionado (decidido)
En la casilla va el **icono** del objeto elegido y, a su derecha, en el hueco café libre
(x 86–195, y 172–204 del lienzo reducido: ~110×32 px), el **texto**: nombre y cantidad
arriba («Manzana x3») y qué hace debajo («Cura 1 corazón»). Con Gravity Bold a 10 px caben
unas 20 letras por renglón y 3 renglones. Casilla vacía → nada.

### Opciones de un objeto
- **E/J sobre un consumible:** lo usa directamente (manzana → cura y se cierra el libro para
  ver a Leonidas comer con la animación `sin_nombre`/comer). Sin submenú: solo hay un
  consumible en la entrega. Si la vida está llena: aviso «Ya estás bien.» y no se gasta.
- **Objetos importantes** (espada, libro, carta de los sabios): solo se miran (nombre y
  descripción).
- Si más adelante hay varios objetos equipables, E/J equiparía y la ranura del HUD lo
  mostraría; fuera del alcance de esta entrega.

### Las demás páginas
- **Mapa:** imagen fija dentro de la zona oscura (~165×160 px reducida). La cartela de abajo
  a la derecha (~60×28) muestra el nombre de la zona actual (≤ 6 letras: Pueblo, Bosque,
  Playa, Mar, Isla, Cueva) y una marca parpadeante señala dónde está Leonidas. Sin cursor.
  Arte: no hay → esquema provisional de las 9 zonas (cajas unidas, generado a partir de
  `plan_mapa_mundo.md`) hasta que Lucía pinte el mapa.
- **Misiones:** hasta 3 principales y 3 secundarias, un renglón cada una (~25 letras con Gravity Bold 10). Las
  completadas, tachadas o en gris. Sin cursor (solo lectura).
- **Guardar:** un único botón «Guardar» (E/J) → «¡Partida guardada!». Muestra el tiempo
  jugado («00:42») y los jefes derrotados («0»).

## Textos: fuente Gravity (decidido 2026-11-14)

**Todo el texto del libro lo escribe el juego**, no va pintado en el arte, y usa la fuente
**Gravity** (`assets/fonts/gravity_regular.otf` y `gravity_bold.otf`; licencia CC BY 4.0, ver
`gravity_readme.txt`: **hay que nombrar a Vincenzo Vuono en los créditos**). El resto del
juego (diálogos, tienda, menú) sigue con Perfect DOS VGA.

- Tiene todos los caracteres del español, incluidas Á É Í Ó Ú Ñ ¿ ¡ (no hace falta
  `adaptar_a_fuente()`).
- **No es una fuente de píxeles.** Probada sobre el libro reducido a 480×270: a **8 px no se
  lee**; **Bold a 10 px** se lee bien y es el mínimo; Regular solo a partir de 12 px.
  Propuesta: **Bold 10** para el texto (misiones, descripción, valores), **Bold 12** para
  los títulos de página. Unos 5,5 px de ancho por letra a 10 px.
- Importación: **con** antialiasing en grises (sin él las letras salen rotas a 10 px), sin
  subpíxel (`subpixel_positioning` desactivado) y hinting ligero. Es lo contrario que la
  fuente DOS. Color de tinta: el azul oscuro de los rótulos, #1c2254.
- Tema propio dentro de la escena del libro (como el del menú principal), para no tocar
  `resources/ui/tema.tres`.
- **Arte:** las páginas actuales traen pintados los títulos («Inventario», «Mapa»,
  «Misiones», «Principales», «Secundarias», «Guardar», «Objetos Importantes»), los rótulos
  de Guardar y el botón. Pedir a Lucía las páginas **sin ningún texto** (las líneas a los
  lados del título pueden quedarse). Hasta entonces se usan los títulos pintados y el juego
  solo escribe lo demás.

## Plan técnico

### Fase 0 — Escala y arte (hecha el 2026-11-14: opción B)
- `tools/export_recortes.lua` admite **`escala = 0.4`** (por recorte o para toda la tabla):
  promedia el área de cada píxel de salida, alfa binario y, si el original tiene ≤ 256
  colores (iconos, marco), ajusta cada píxel al color original más parecido. Los seis
  `tools/recortes/inventario_*.lua` la llevan; se regenera con `tools/export_sprites.sh`.
- Resultado en `assets/ui/inventario/`: `cobertura`, `pag_1`, `pag_2y3`, `pag_4y5` a
  **448×230** (mismo lienzo, se superponen en (0, 0)), pestañas a **26×22**,
  `seleccion_casilla` a **32×32**. Prueba compuesta:
  `docs/reference/inventario_escala_b_reducido.png`.
- **Medidas sobre los PNG reducidos** (coordenadas del lienzo de 448×230):
  - Casillas (interior oscuro de 26–27 px): columnas en x 52 / 89 / 127 / 164 (Inventario)
    y 254 / 291 / 328 / 366 (Objetos Importantes); filas en y 58 / 94 / 129.
  - Casilla suelta: (53, 174) y (254, 174), 29×29.
  - Marco de selección (32×32): se coloca en (casilla − 3, casilla − 3).
  - Zona oscura del mapa: x 224–425, y 19–218 (contorno irregular).
  - Pestañas: x ≈ 43 / 74 / 104 / 136 / 166; y −2 apagada, −9 encendida (asoman por encima
    del lienzo: dejar 10 px libres arriba). X de salir: ≈ (10, 182).
  - Libro centrado en pantalla: lienzo en (16, 25).
- **Pendiente de Lucía:** que lo redibuje/retoque a este tamaño (pedírselo; ver
  «Preguntas abiertas»). Cuando entregue PNG/aseprite ya a 448×230, quitar `escala` de los
  recortes y volver a medir.

### Fase 1 — Esqueleto del menú (1 día)
- Autoload **`Libro`** = `scenes/ui/menu_libro.tscn` + `scripts/ui/menu_libro.gd`
  (`class_name MenuLibro`; mismo patrón que `Tienda`/`MenuTienda`). CanvasLayer por encima
  del HUD, `process_mode = ALWAYS`.
- Nodos: `Cobertura`, `Pagina` (cambia de textura según el par), `Pestanas` (5 TextureRect),
  `Salir`, `Seleccion`, y un nodo por página con su contenido.
- Acciones `inventario`, `pagina_anterior`, `pagina_siguiente` en el mapa de entradas (por
  MCP si el editor está abierto).
- Abrir/cerrar con pausa; comprobar que no se abre con `Dialogos`/`Tienda` activos ni con el
  jugador bloqueado, y que la primera pulsación de I al cerrar no lo reabre.
- Navegación entre pestañas y páginas, sin contenido todavía.
- Quitar el «Pulsa [I]» provisional de la lista de pendientes: ya funcionará.

### Fase 2 — Objetos (1 día)
- Recurso **`Objeto`** (`scripts/systems/objeto.gd`, en `resources/objetos/*.tres`): `id`,
  `nombre`, `descripcion` (2 renglones de ~20 letras), `icono`, `tipo` (CONSUMIBLE /
  IMPORTANTE), `maximo`. `ArticuloTienda` pasa a apuntar a un `Objeto` + `precio` (hoy
  duplica nombre, descripción e icono).
- `EstadoJuego.objetos: Dictionary` (id → cantidad) con `agregar_objeto`, `gastar_objeto`,
  `cantidad`, señal `objetos_cambio`. `manzanas` y sus funciones quedan como atajos para no
  romper la tienda. **`tiene_espada` pasa de `Jugador` a `EstadoJuego`** (hoy vive en el
  jugador y no sobreviviría a guardar/cargar).
- Página Inventario: consumibles con su cantidad en la esquina de la casilla. Página Objetos
  Importantes: espada, libro, carta.
- Usar la manzana: `Vida.curar(4)` (1 corazón; **confirmar la cantidad con el guion**),
  estado nuevo `COMER` en `Jugador` con la animación de comer (renombrar `sin_nombre` en el
  layout de `leonidas_mini`).
- Iconos provisionales en `assets/ui/provisional/` hasta que lleguen los de Lucía.

### Fase 3 — Misiones (½ día)
- Recurso `Mision` (`id`, `titulo` ≤ 25 letras, `principal`) y en `EstadoJuego`
  `misiones: Dictionary` (id → ACTIVA / COMPLETADA) con `empezar_mision` / `completar_mision`.
- Para la entrega: principal «Habla con los sabios» → «Derrota a Medusa»; secundaria, la de
  la sirena si llega a existir. Los títulos los escribe el equipo de guion.

### Fase 4 — Guardar (1–1½ días)
- `EstadoJuego.guardar()` / `cargar()` con `ConfigFile` en `user://partida.cfg`: zona y
  entrada (punto de control), vida, monedas, objetos, misiones, banderas (`tiene_libro`,
  `mision_recibida`, `voltereta_aprendida`, `tutorial_barco_visto`, `avisos_zeus`), tiempo
  jugado y jefes derrotados.
- `EstadoJuego.tiempo_jugado` (suma en `_process`, no cuenta en pausa) y `jefes_derrotados`.
- Menú principal: opción **Continuar** si existe la partida; `Game` arranca en la zona y
  entrada guardadas.
- Al cargar se reaparece en la entrada de la zona, no en el punto exacto.

### Fase 5 — Mapa (½ día)
- Imagen provisional + marca de «estás aquí» por zona (tabla zona → posición en el mapa) y
  nombre en la cartela. `Game` ya sabe la zona actual.

### Orden y prioridad
Quedan ~12 días para la entrega (2026-11-26) y aún faltan sabios, Tocotón y Medusa. Orden
propuesto: **1 → 2** (imprescindible: comer manzanas es la única forma de curarse) →
**3** → **5** → **4**. Si falta tiempo, Guardar puede quedar como página visible con el botón
desactivado («Próximamente»); las demás páginas son baratas.

## Verificación
1. I abre y cierra; con el libro abierto los enemigos y el reloj del juego no avanzan.
2. No se abre sin libro, en diálogo, en tienda, en la cinemática ni en el barco.
3. Recorrer las 5 páginas con flechas, con Q/R y por las pestañas; las pestañas encendidas
   coinciden con las páginas visibles.
4. Comprar 2 manzanas, recibir daño, comer una: sube 1 corazón, baja el contador; con la
   vida llena no se gasta.
5. Guardar, cerrar el juego, Continuar: misma zona, monedas, objetos y banderas.
6. Pruebas con pulsaciones simuladas: `await process_frame` antes de cada pulsación (ver
   CLAUDE.md, «Tienda»).

## Decisiones ya tomadas
- Escala: **opción B por ahora** (libro reducido a 448×230 por script); **opción C** (redibujado por Lucía a ese tamaño) en cuanto lo entregue todo.
- Solo se enciende la pestaña de la página con el cursor.
- Casilla suelta: icono dentro, texto al lado en el hueco café.
- Navegación: la propuesta de arriba.
- Todo el texto lo pone el juego con Gravity.

## Pendiente de Lucía
1. Libro a 448×230, pestañas 26×22, marco 32×32, **páginas sin texto** y Misiones sin «!».
2. Iconos de objetos a 16×16: manzana, espada, libro, carta de los sabios.
3. ¿Habrá mapa pintado para la zona oscura, o usamos el esquema provisional?
