# Plan: efectos de sonido (SFX) con Codex / ChatGPT

Estado: el juego solo tiene música (`assets/audio/music/*.mp3`, autoload `Musica`). `assets/audio/sfx/` está **vacía**. Este documento sirve para (1) encargar los sonidos a Codex y (2) enchufarlos después en Godot.

## 0. Lo que hay que saber antes

- **ChatGPT (el chat) no genera archivos de audio de efectos.** Puede describir sonidos, pero no entrega un `.wav` creíble. Lo que sí puede hacer **Codex** (o el modo de código de ChatGPT) es **escribir y ejecutar un script de Python que sintetiza los sonidos** (ruido filtrado, barridos de tono, envolventes) y guardar `.wav`. El resultado es de tipo *retro / sintetizado*, no grabaciones reales. Para un RPG pixel art encaja bien, pero conviene escuchar y ajustar.
- **¿Puede leer `CLAUDE.md`?** Codex lee por defecto `AGENTS.md`, no `CLAUDE.md`; si abres el repo con él solo lo leerá si se lo pides por nombre. **No se lo recomiendo**: son miles de líneas de contexto de Godot que no necesita y lo distraen. Es mejor darle el *brief* de la sección 2, que ya trae solo lo relevante. Codex **no debe tocar** escenas ni scripts del juego: solo crear los `.wav`. La integración en Godot la hago yo (sección 4).
- **Plan B / mezcla** (si el sintetizado suena a "videojuego de 1985" y no es lo que se quiere):
  - *jsfxr / ChipTone / Bfxr* (en el navegador, gratis, salida libre de derechos): útiles para golpe, daño, voltereta, caída.
  - *Freesound.org* (filtrar por **CC0**) y *Kenney.nl* / *OpenGameArt* (CC0): bancos de pasos, espadazos, rotura de cerámica, roca. Si un sonido es CC-BY hay que poner al autor en los créditos (igual que la fuente Gravity).
  - *ElevenLabs Sound Effects* (de pago/limitado): genera SFX realistas por texto; revisar la licencia de uso comercial.
  - Para un proyecto universitario lo más seguro: sintetizado por Codex + bancos CC0. Anotar de dónde sale cada sonido en `assets/audio/sfx/LICENCIAS.md`.

## 1. Lista de sonidos (con dónde se disparan en el código)

Duraciones orientativas. Los ciclos del juego: caminar 8 fotogramas a 10 fps (un paso cada ~0,4 s), ataque y pirueta a 20 fps (~0,4 s cada uno; verificar al integrar).

| Archivo (snake_case, sin acentos) | Qué es | Duración | Variantes | Dónde se dispara |
|---|---|---|---|---|
| `paso_1.wav` … `paso_4.wav` | Paso en general, suelo seco/tierra, suave (se repite mucho) | 0,07–0,12 s | 4 | Fotogramas de apoyo de `caminar_*` del jugador (componente nuevo) |
| `espada_1.wav`, `espada_2.wav` | Espadazo al aire (silbido corto, sin impacto) | 0,20–0,30 s | 2 | `Jugador.ataque_empezado` |
| `vasija_romper.wav` | Cerámica que se rompe en trozos | 0,5–0,7 s | 2 (`_1`, `_2`) | `ObjetoAgarrable.romper()` (vasijas) |
| `piedra_caer.wav` | Piedra pesada que cae al suelo tras lanzarla (golpe sordo, **no** se rompe) | 0,2–0,35 s | 2 | `ObjetoAgarrable._aterrizar()` cuando `rompible = false` |
| `golpe_enemigo_1.wav`, `_2` | Espada que impacta a un enemigo (seco, satisfactorio) | 0,15–0,25 s | 2 | Cuando un `Hitbox` del jugador golpea un `Hurtbox` enemigo |
| `leonidas_caer.wav` | Leonidas cae derrotado (cuerpo al suelo + cierre descendente, **sin sangre ni gritos**) | 0,8–1,2 s | 1 | Al empezar el estado MUERTO (`ComponenteVida.murio` del jugador) |
| `barco_golpe.wav` | Casco de madera contra roca + chapoteo | 0,4–0,6 s | 2 | `Barco._al_recibir_danio` (choque, tiburón, remolino) |
| `leonidas_danio.wav` | Leonidas recibe daño (impacto corto, sin voz) | 0,2–0,3 s | 2 | `Jugador._al_recibir_danio` |
| `voltereta.wav` | Rodar: roce de tela + silbido suave + toque de suelo | 0,35–0,45 s | 2 | `Jugador.pirueta_empezada` |

Extras opcionales si sobra tiempo (no se piden ahora): romper arbusto, recoger moneda, comer, abrir libro, menú aceptar/mover, mordisco de la gamba, seta bomba, estocada del pez espada, golpe de Medusa.

## 2. Prompt para Codex (copiar y pegar)

> Eres ingeniero de audio para un videojuego. Necesito efectos de sonido **originales y sintetizados por código** (sin samples externos, sin descargar nada) para un RPG 2D top-down de mitología griega en pixel art, de estilo parecido a *The Legend of Zelda: Minish Cap* (tono ligero, amable, no violento ni realista). El juego es en Godot 4.7.
>
> **Tu trabajo:** escribe un único script `tools/audio/generar_sfx.py` (Python 3; usa solo la librería estándar `wave`, `struct`, `math`, `random`, o `numpy` si está instalado) que genere todos los `.wav` de la lista y los guarde en `assets/audio/sfx/`. Ejecútalo y comprueba el resultado. **No toques ningún otro archivo del repositorio** (nada de escenas, scripts de Godot, `project.godot`, etc.) y **no hagas commits**.
>
> **Formato obligatorio de salida:**
> - WAV PCM 16 bits, **mono**, 44100 Hz.
> - Pico normalizado a **−3 dBFS** (sin recortes/clipping). Los pasos y el espadazo un poco más bajos que los impactos (pico −9 dBFS los pasos).
> - Sin silencio al principio (ataque inmediato) y un fundido de salida de 5–10 ms al final para evitar clics. Sin bucles.
> - Duración dentro del rango indicado (ni más larga: se oirá tarde en el juego).
> - Nombres exactos en `snake_case`, sin acentos ni espacios, como en la tabla. Cada variante debe sonar **distinta pero de la misma familia** (cambia semilla, tono ±8 %, filtro) para que no canse al repetirse.
> - El script debe ser **determinista** (semillas fijas) y tener un diccionario de parámetros por sonido al principio, para poder retocar uno sin tocar el resto (`python tools/audio/generar_sfx.py paso_1 voltereta` regenera solo esos).
> - Al terminar imprime una tabla con nombre, duración (ms) y pico (dBFS) de cada archivo y avisa si alguno incumple el formato.
>
> **Estilo general:** suave y redondeado, poco brillo agudo (estos sonidos se repiten cientos de veces; evita frecuencias estridentes por encima de ~6 kHz), mezclando ruido filtrado y tonos cortos. Nada de voz humana ni gritos. Nada de sangre, desgarros ni realismo crudo.
>
> **Sonidos a crear:**
> 1. `paso_1..4` (0,07–0,12 s): paso de sandalia sobre tierra seca; golpe sordo muy corto (ruido filtrado paso-bajo con un "thump" grave de ~120 Hz). Suave, discreto.
> 2. `espada_1`, `espada_2` (0,20–0,30 s): silbido de espada al cortar el aire; ruido filtrado paso-banda con barrido ascendente-descendente de ~1,2 a 3 kHz y una envolvente que sube rápido y cae. Sin impacto.
> 3. `vasija_romper_1`, `_2` (0,5–0,7 s): cerámica que se rompe; un chasquido inicial brillante + 5–8 "tintineos" de trozos con tonos entre 1 y 4 kHz que caen en cascada, con decaimiento rápido.
> 4. `piedra_caer_1`, `_2` (0,2–0,35 s): piedra pesada que cae al suelo; golpe grave (~70–110 Hz) con un poco de ruido granulado y un rebote pequeño al final. No se rompe.
> 5. `golpe_enemigo_1`, `_2` (0,15–0,25 s): impacto de espada contra un enemigo; "tok" seco con un chasquido corto de ruido y un tono breve de ~300–500 Hz. Satisfactorio, no violento.
> 6. `leonidas_caer` (0,8–1,2 s): el héroe cae derrotado; golpe de cuerpo grave contra el suelo + un cierre de tono descendente (de ~400 a ~120 Hz) con un poco de tristeza, pero ligero. Sin voz.
> 7. `barco_golpe_1`, `_2` (0,4–0,6 s): casco de madera que choca contra una roca; crujido grave de madera (ruido filtrado + tono ~90 Hz) seguido de un chapoteo breve (ruido con paso-banda descendente).
> 8. `leonidas_danio_1`, `_2` (0,2–0,3 s): el héroe recibe un golpe; impacto corto con un tono "ouch" instrumental descendente (no voz), claramente distinto del golpe a enemigos (más agudo y con más cuerpo).
> 9. `voltereta_1`, `_2` (0,35–0,45 s): rodar por el suelo; roce de tela (ruido paso-banda 800–2500 Hz con barrido), un "fuu" suave y un toque sordo de suelo al final.
>
> Si algún sonido no puede quedar bien con síntesis simple, dilo en lugar de entregar algo malo, y propón alternativa. Al final, dame una lista de qué parámetros tocar para que un sonido sea más grave, más largo o más suave.

## 3. Cómo trabajar con Codex (guía)

1. **Antes de empezar:** crear una rama o confirmar que el repo está limpio (Codex va a crear `tools/audio/` y `assets/audio/sfx/`). Que **no haga commit** (los commits los haces tú).
2. **Primera pasada:** pegar el prompt. Pedir que, además de los `.wav`, genere `assets/audio/sfx/LICENCIAS.md` diciendo "sintetizados por código, sin samples externos".
3. **Escuchar todo** en el reproductor del Mac (barra espaciadora en Finder). Comprobar: ¿cansa al repetirse? (sobre todo `paso` y `espada`), ¿se escucha *tarde* (silencio al inicio)?, ¿hay clics?, ¿volumen parejo entre sonidos?
4. **Retoques por nombre y con adjetivos**, p. ej. «`golpe_enemigo`: más grave y más corto; `vasija_romper`: menos agudo; `paso`: la mitad de volumen». Que regenere solo esos (`python tools/audio/generar_sfx.py <nombre>`).
5. **Limitaciones esperables:** la cerámica y el chapoteo son lo más difícil de sintetizar; si no convencen, reemplazarlos por un CC0 de Freesound (o jsfxr) con el mismo nombre de archivo.
6. **Entrega:** avisarme cuando estén los `.wav` en `assets/audio/sfx/` y yo los integro y los pruebo.

## 4. Integración en Godot (HECHA el 2026-11-18)

Se hizo sin `ComponenteSonido`: un `AudioStreamPlayer` por evento con un `AudioStreamRandomizer` (variantes + tono aleatorio) y el bus `SFX`, más `ComponentePasos` para los pasos. Detalle y dónde se dispara cada uno: sección «Sonido» de `CLAUDE.md`. Prueba: `tools/pruebas/prueba_sonidos.gd`.

`assets/audio/sfx/LICENCIAS.md` (lo generó Codex) es opcional: sonidos sintetizados por código no exigen atribución. Si algún día se usa un sonido CC-BY, ese sí va en los créditos.

## 5. Sonidos que faltan (propuesta, por prioridad)

Mismo flujo: se añaden al script de Codex con el mismo formato (WAV mono 16 bits 44100 Hz, pico −3 dBFS, 2 variantes donde se repita mucho) y luego se enchufan.

**Prioridad alta (se oyen todo el rato):**
| Archivo | Qué es | Dónde |
|---|---|---|
| `moneda_recoger` | «cling» corto y brillante (0,15–0,25 s) | `ObjetoSuelto` al recogerse (valor > 0) |
| `objeto_recoger` | tono suave ascendente, para manzana y objetos del inventario (0,3 s) | `ObjetoSuelto` con `objeto` |
| `dialogo_avanzar` | «tic» muy suave por cada pulsación de continuar (0,05 s, 2–3 variantes) | `CajaDialogo` al pasar de cuadro |
| `dialogo_letra` (opcional) | «blip» ultracorto por letra (0,02 s, tono distinto por hablante) | máquina de escribir de `CajaDialogo` (1 de cada 2 letras) |
| `dialogo_abrir` | un clic al abrir el cuadro (0,1 s) | inicio de `Dialogos.mostrar` |
| `comer` | mordisco crujiente + tragar (0,5 s) | `Jugador.comer()` |
| `curar` | arpegio corto ascendente (0,4 s) | al curarse (`ComponenteVida.curado`) |
| `menu_mover`, `menu_aceptar`, `menu_volver` | tics de interfaz (0,05–0,15 s) | menús principal/pausa, tienda y libro |

**Prioridad media (combate y mundo):**
| Archivo | Qué es | Dónde |
|---|---|---|
| `enemigo_muere` | «puf» + estallido ligero (0,4 s) | `ComponenteMuerte` |
| `arbusto_cortar` | hojas que se cortan (0,3 s) | arbusto (`romper`) |
| `agarrar`, `lanzar` | levantar un objeto (0,2 s) y lanzarlo (0,25 s) | `ComponenteCarga` |
| `arbol_golpe` | golpe sordo en el tronco + hojas (0,3 s) | `Decorado.sacudir` / manzano |
| `manzana_cae` | la manzana cae y rebota (0,3 s) | manzano al soltar |
| `tienda_comprar` / `tienda_sin_dinero` | caja registradora suave / «bzz» (0,3 s) | `MenuTienda` |
| `libro_abrir`, `libro_cerrar`, `libro_pagina` | papel que se abre / cierra / pasa (0,3–0,5 s) | `MenuLibro` |
| `guardar_partida` | campanita (0,5 s) | botón Guardar del libro |
| `mision_nueva` | fanfarria corta de 3 notas (0,8 s) | al `empezar_mision` |
| `objeto_importante` | jingle de «¡obtuviste!» (1,2 s) | `mostrar_objeto_obtenido` (espada, libro, cabeza) |
| `zona_cambio` (opcional) | «whoosh» muy bajo al fundido | `Game.cambiar_zona` |
| `game_over` | jingle triste corto (1,5 s) | `PantallaGameOver` |

**Enemigos y jefa (nivel 1 y 2):**
| Archivo | Qué es |
|---|---|
| `seta_inflar`, `seta_explota` | la seta se infla / suelta la nube tóxica |
| `flor_sale`, `flor_muerde` | la falsa flor emerge / muerde |
| `gamba_muerde` | chasquido de pinza |
| `pez_aviso`, `pez_carrera`, `pez_estocada` | aviso, carrera veloz y estocada |
| `ciclope_apuntar`, `rayo_disparo`, `rayo_impacto` | carga del ojo, disparo y chisporroteo del rayo |
| `medusa_invocar`, `medusa_embestida`, `medusa_golpe_suelo`, `medusa_derrotada` | canto de invocación, embestida, golpe de espada en el suelo (con vibración grave), derrota |
| `trozo_estatua_cae` | piedra que cae y se rompe contra el suelo |
| `tiburon_embiste` | chapoteo fuerte del tiburón |

**Barco:** `barco_remo` (bucle suave de oleaje), `barco_viento` (bucle cuyo volumen sigue al soplido del micrófono), `barco_hundir`, `remolino` (bucle grave).

**Ambiente y música (a futuro):** oleaje de la playa, pájaros del bosque, viento en la isla, eco de la cueva (bucles de 10–20 s) en el bus `Ambiente`. Pasos distintos por material (hierba, arena, piedra, madera del muelle) cuando se quiera.

**Notas para encargarlos:** los bucles (`barco_*`, ambiente) necesitan empalme sin clic (que el final encaje con el inicio) y se importan con Loop activado; los sonidos de diálogo deben ser muy discretos porque suenan decenas de veces por conversación; para `dialogo_letra` conviene que cada personaje importante (Kathita, Zeus, los sabios, Medusa) tenga un tono base distinto.
