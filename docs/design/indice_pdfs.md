# Índice de los PDF de diseño

Los PDF están en `docs/pdf/` (**fuera de git**, ver `.gitignore`; cada miembro del equipo los tiene en local) y también en la carpeta externa `Leonidas_12_pruebas/Assets_guion_todo/`.

| Archivo | Páginas | Qué es |
|---|---|---|
| `docs/pdf/Jugabilidad.pdf` (51 MB) | 22 | Presentación de mecánicas generales ("funcionamiento básico a respetar en cada parte") |
| `docs/pdf/Guión Multimedia (1).pdf` (140 MB) | 145 | Guion por niveles (1 a 8), enemigos, jefes, interfaces de jefe y fichas de personaje |

Las dos presentaciones son de 1440×809 pt (16:9). El texto de las láminas también está extraído (con ruido) en `jugabilidad_laminas.txt` y `guion_multimedia_laminas.txt`.

## Cómo consultar una página

Con `tools/pdf_paginas.swift` (PDFKit de macOS, no hay que instalar nada):

```bash
# texto de unas páginas (rápido, sirve para buscar)
swift tools/pdf_paginas.swift texto "docs/pdf/Guión Multimedia (1).pdf" 15 16 17
# miniaturas numeradas de un rango, para saber qué hay
swift tools/pdf_paginas.swift hoja docs/pdf/Jugabilidad.pdf /tmp/hoja.jpg 13 22 4
# una página en grande (1600 para leer; 4000 para medir píxeles del arte)
swift tools/pdf_paginas.swift render docs/pdf/Jugabilidad.pdf /tmp 4000 16
```

Guardar los renders en el scratchpad o en `/tmp`, **nunca en el repo**. El PDF del guion tarda unos segundos por página.
Ojo: las maquetas "in game" son montajes (la p. 15 lo dice: "captura in game que realmente no es in game"). Su escala NO es la del juego: ver `guia_interfaz.md`.

---

## Jugabilidad.pdf

| Pág. | Contenido | Útil para |
|---|---|---|
| 1 | Portada (logo del equipo "AVE LUX") | — |
| 2 | Descripción: exploración + combate + acertijos; estilo gráfico distinto por bioma; jefe al final de cada punto importante. Homólogos: Zelda Minish Cap, Pokémon BW. Sprites de Leonidas con espada | Tono general |
| 3 | Problema/oportunidad: mitología griega, cámara cenital | — |
| 4 | Perfil del jugador (foto de un cartel a mano: 15+, PC, teclado/mando) | Controles: teclado y mando |
| 5 | Mapa general del mundo por biomas (pintado) | Orden de los niveles |
| 6 | Cómo funcionan las pantallas (mapa de Minish Cap): la cámara sigue al jugador hasta un tope; al salir se carga la siguiente pantalla; se pasa de bioma venciendo al jefe | Sistema de zonas (hecho: `Zona` + `SalidaZona`) |
| 7 | **Acciones del personaje**: movimiento 8 direcciones, ataque (arma base, sustituible por bombas/arco), voltereta con estamina (para que no se abuse), agarrar y tirar objetos. Sprites de cada acción | Jugador (hecho) |
| 8 | **Vida**: game over al perder toda la vida; daño de enemigos y trampas (espinas); recuperar vida con frutas de cada bioma (manzana, coco, pitahaya…) o pagando en posadas. Sprites: daño, morir, trampa de espinas, **comer manzana** | Vida, daño, consumibles |
| 9 | **Barco**: sin ataque, solo moverse; esquivar remolinos y tiburones que hunden el barco; llegar con toda la salud posible. Idea: soplar para ir más rápido. Sprites: barco en 4 direcciones, remolino, tiburón | Minijuego del barco |
| 10 | **NPCs** + las **3 burbujas** sobre la cabeza (diálogo "…", misión "!", tienda). NPC para hablar (cabra), NPC que vende mapas (serpiente), uno de los sabios (toro) | `ZonaDialogo` (hecho); NPCs |
| 11 | **Enemigos** del primer bioma: seta bomba, falsa flor, montón Tocotón (sprites). Algunos solo mueren con objetos especiales o en su punto débil | Enemigos nivel 1 |
| 12 | **Jefes**: patrón propio; al vencerlo dan un objeto y **un corazón extra**. Medusa (estilo provisional) | Jefes, vida máxima |
| 13 | Dirección estética: cada nivel con su estética; **la interfaz del jefe de cada nivel tiene estética propia conservando la disposición del primer nivel**. Ilustraciones de jefes | UI de jefe |
| 14 | Ilustraciones de jefes (Hidra, Minotauro, Ares, Cancerbero…) | Fuera de alcance |
| 15 | **INTERFAZ: interacción con NPCs (demo)** — maqueta con flechas que nombran cada elemento | **UI: ver `guia_interfaz.md`** |
| 16 | **INTERFAZ** (HUD): barra de vida, objeto equipado, inventario, contador de dinero | **UI: HUD (hecho)** |
| 17 | **MENÚS**: boceto del menú del inventario ("no hay más presupuesto") con mapa, objetos, maldiciones y misiones | **UI: menú de inventario (pendiente)** |
| 18 | Escenarios: bocetos de mapas, isla, bosque nocturno; mapa del nivel 3 (Khymera) numerado | Referencia de escenarios |
| 19 | Escenarios: ciudad en ruinas, laberinto, storyboard, ruinas en llamas | Fuera de alcance |
| 20 | **SFX**: música por bioma; sonido al ser herido, al hablar, en eventos, al atacar y en la voltereta, de enemigos | Audio (pendiente) |
| 21 | **Efectos visuales**: partículas (arena, hierba al caminar); shaders para noche, zonas oscuras y antorchas en vez de dibujar otro fondo | Efectos (pendiente) |
| 22 | "Thank you!" | — |

---

## Guión Multimedia (1).pdf

### Comunes
| Pág. | Contenido |
|---|---|
| 1 | Portada e integrantes (Emilia Cárdenas, Alexadra Criollo, Rafaela Castro, Valeria Idrovo, Ana Sanmartin, Sofia Quezada, Lucia Segura) |
| 2 | **INTERFAZ** = misma lámina que Jugabilidad p. 16 (HUD) |

### Nivel 1 — ciudad y bosque (EN ALCANCE)
| Pág. | Contenido |
|---|---|
| 3 | Portada "Nivel 1" |
| 4 | Descripción: el nivel es un **tutorial**; ciudad = zona segura (interactuar y NPCs), bosque = peligro (combate y esquivar). **Sin jefe.** Historia: 15.º cumpleaños, misión de matar a Medusa; Leonidas es conocido por ser patoso y rebelde. Mapa pintado de la ciudad (ciudad circular amurallada rodeada de bosque, costa al sur) |
| 5 | Moodboard: **pixel art** tradicional, ciudad griega, colores vivos ("aventura infantil") |
| 6 | Guion gráfico: empieza en casa; la madre le recuerda el cumpleaños y que debe ir a la sala de reuniones; tira y afloja entre los dos (= cinemática, hecha) |
| 7 | Al salir de casa se gana el control: **tutorial de moverse e interactuar**; Leonidas va al **norte** de la ciudad, a la sala de reuniones |
| 8 | Los **sabios** le asignan la misión (isla de Medusa) y le dicen que vaya al **sur**, a la orilla, donde le espera una barca y alguien que le explicará |
| 9 | Bosque: los enemigos atacan al verle; se puede huir o luchar (desbloquear zonas, conseguir dinero); explorar da recompensas |
| 10 | Playa: un NPC habla del mundo, advierte de la siguiente zona y explica el barco |
| 11 | Sección del barco hacia el sur → isla de Medusa |
| 12 | **Leonidas**: ~25 px de alto, animado frame a frame, estilo Link (A Link to the Past / Minish Cap) + **paleta de colores** |
| 13 | **NPCs** del nivel (cabra, mujer/Kathita, toro sabio, serpiente) + las **3 burbujas** (diálogo normal, misión, tienda). Al principio dan información y tiendas con pocos objetos; más tarde, misiones secundarias |
| 14 | **Manzanas**: en los árboles fuera de la ciudad; se golpea el árbol con la espada, cae una y se recoge al acercarse (va al inventario); el árbol no da más hasta visitar otro bioma (sin farmeo). Sprites de manzana y manzanos |
| 15 | **Seta bomba**: camina, al acercarse "explota" (daño en área); luego queda quieta e inofensiva un rato → momento de atacarla. Esquivar con voltereta |
| 16 | **Falsa flor**: camuflada como flor; al acercarse sale, se estira y ataca, se queda fuera un rato; si no se la mata, se esconde y reaparece en otro sitio |
| 17 | **Montón Tocotón**: obstáculo/tanque (mucha vida) que bloquea caminos; es una pila: al derrotar al de abajo baja el siguiente; persigue un poco pero vuelve a bloquear su sitio. Ataques físicos simples. **Es el único arte del Tocotón que hay** |
| 18 | **Barco**: minijuego, solo moverse, esquivar obstáculos y enemigos que quitan vida al barco. Sprites del barco, remolino, tiburón |
| 19 | **Mapa** (boceto a mano, "no es la versión final"): corto y lineal; cofres con consumibles, NPCs con misiones; bajar hasta el NPC del barco |

### Nivel 2 — isla de Medusa (EN ALCANCE)
| Pág. | Contenido |
|---|---|
| 20 | Portada "Nivel 2" |
| 21 | Descripción: isla solo accesible en barco, primer jefe, lugar hostil con pocos NPCs. Estatuas = personas petrificadas. Mapa pintado de la isla |
| 22 | Moodboard: playa, colores cálidos, **estética "lineless" con mucha textura** (NO es pixel art), animación con **rig/esqueleto**, fondos con espirales y zigzags. ⚠ Implica otro pipeline de arte (Skeleton2D / ilustración) y revisar la escala 480×270: hay que hablarlo con la artista |
| 23 | Pocos NPCs y no dicen dónde está Medusa; hay que **seguir estatuas** que indican la dirección |
| 24 | Leonidas encuentra un **escudo** (primer objeto intercambiable): bloquea ataques gastando estamina |
| 25 | **Cueva de Medusa**: enemigos nuevos; activar un **mecanismo** para abrir la puerta a la zona final |
| 26 | Encuentro y breve diálogo con Medusa → combate |
| 27 | Se gana; Medusa suplica, cuenta que está maldita por los dioses |
| 28 | Fingen su muerte: Medusa le da una réplica de piedra de su cabeza como prueba; Leonidas vuelve |
| 29 | En la orilla de su ciudad aparece **Hermes**: los dioses aceptan su "reto"; vendrán más pruebas (gancho del final) |
| 30 | Leonidas en estilo lineless + paleta |
| 31 | NPCs: una **sirena** (misión secundaria) y un **comerciante de mapas** (serpiente) |
| 32 | **Coco**: consumible que da más defensa durante un rato (los enemigos hacen menos daño) |
| 33 | **Gran pinza** (cangrejo): persigue y bloquea de frente con la pinza; hay que rodearlo con la voltereta y golpear por la espalda |
| 34 | **Espada pez**: carga en línea recta a toda velocidad; apartarse; vulnerable en el cooldown (con un ataque más débil) |
| 35 | **La gamba**: básico (ve, persigue, ataca) pero en grupos |
| 36 | **Cíclope serpiente**: solo en la cueva, antes de Medusa; dispara un rayo que hay que esquivar |
| 37 | **Medusa (jefa)**: lore; Leonidas se niega a matarla |
| 38 | **Patrón de Medusa**: embiste con la espada al suelo donde está el jugador; invoca cíclopes serpiente y es **invulnerable hasta que mueren**; a mitad de vida lanza trozos de estatua a distancia. **Barra de vida de la jefa: 5 corazones con su propio estilo** (ver `guia_interfaz.md`) |
| 39 | Mapa (boceto): seguir estatuas hasta la cueva; **varios niveles de altura**; estética de playa |

### Niveles 3–8 (FUERA DE ALCANCE; solo como referencia)
| Págs. | Nivel |
|---|---|
| 40–53 | Nivel 3, desierto de **Khymera**: mapa numerado (p. 43, 46), loop del juego (p. 45), escorpiones, remolinos de arena, tunas; ataques de Khymera (p. 49–51) |
| 54–75 | Nivel 4, pantano de **Aracne**: Dríade, libélulas, musgos, reflejos, plantas medicinales, papeles de historia; **p. 68: interfaz de vida de Aracne** (corazones en telaraña); ataques (p. 70–73); tabla de momentos (p. 75) |
| 76–92 | Nivel 5, **Hidra de Lerna**: aldea destruida, inmovilizar las 7 cabezas; storyboards (p. 88–92) |
| 93–104 | Nivel 6, prisión del **Minotauro**: rata comerciante, prisioneros, moneda propia del nivel (p. 99), seta-apuesta (p. 100) |
| 105–122 | Nivel 7, **Cancerbero**: oasis y arándanos; **p. 113: interfaz de corazones** (lleno / medio / vacío y barra del jefe con su cabeza a la izquierda); ataques (p. 116–120) |
| 123–134 | Nivel 8 (final), **Ares**: arena circular, fases al 50 % |

### Fichas de personaje
| Pág. | Personaje |
|---|---|
| 135 | Portada "Fichas de personaje" |
| 136 | **Medusa** (EN ALCANCE): ilustración, datos, historia, paleta |
| 137 | Khymera |
| 138 | **Leonidas** (versión nivel 3, pero con vistas frente/lado/espalda, expresiones, detalles y paleta: útil para retratos de diálogo) |
| 139 | Aracne |
| 140 | Hidra de Lerna |
| 141 | Leónidas (versión heráldica, nivel 5) |
| 142 | Cancerbero |
| 143 | Ares |
| 144 | Leónidas (versión nivel 8) |
| 145 | **Enlace a la carpeta de animaciones** (Google Drive): `https://drive.google.com/drive/folders/1FzMoCkFLrw-YCepZzYDl0uZiStLWHqhB?usp=drive_link` |
