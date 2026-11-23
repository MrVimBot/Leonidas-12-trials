# Nivel 3: laberinto del Minotauro (PROVISIONAL)

Montado el 2026-11-22 con el arte que entregó la artista ese día (fondo del laberinto por capas,
fotogramas del Minotauro, rejas y el cuerno) y la idea de la escena que propuso:

> Leonidas entra por arriba, dice algo como «¿y por dónde salgo ahora?», la cámara enseña la
> salida de abajo, dice «oh, vale, por allí», se apagan las luces, la cámara enseña al Minotauro
> en el centro y empieza la batalla.

Más lo que pidió Esteban: rejas en las dos salidas que se cierran al apagarse la luz, un filtro
oscuro con luz en los aros dorados y el cuerno en un cofre de la esquina de abajo a la derecha.
Según los sabios, sin el cuerno el Minotauro es invencible. Cambio del 2026-11-23 (Esteban): no es
invisible sino **invencible** (se le ve; la espada no le quita vida), se mueve más rápido, no da
monedas y, como Medusa, al vencerlo hay diálogo y premio: el **cuerno del Minotauro** (trofeo,
otro objeto distinto del cuerno del cofre).

## Cómo se llega

`isla` (orilla al sur de la boca de la cueva) → `laberinto` (entrada de arriba). La orilla está
cerrada con una `BarreraMision` (requisito `MINOTAURO`) hasta que los sabios dan la misión del
Minotauro. Mientras no exista el segundo nivel del mar (ver `plan_minijuego_barco.md`,
«Segundo mar»), la orilla lleva directamente al laberinto.

## Piezas

| Pieza | Dónde |
|---|---|
| Zona | `scenes/levels/laberinto.tscn` (montada con `tools/zonas/laberinto/montar_laberinto.gd`) |
| Datos del arte | `tools/zonas/laberinto/analizar_laberinto.py` → `laberinto_datos.json` |
| Escena del combate | `scenes/cinematics/escena_minotauro.tscn` + `scripts/cinematics/escena_minotauro.gd` |
| Jefe | `scenes/enemies/minotauro.tscn` + `scripts/enemies/minotauro.gd` |
| Rutas por el laberinto | `scripts/componentes/componente_ruta.gd` (`AStarGrid2D`) |
| Rejas | `scenes/entorno/reja.tscn` + `scripts/entorno/reja.gd` |
| Antorchas | `scripts/entorno/luz_antorcha.gd` + `resources/luces/luz_radial.tres` |
| Cuerno (cofre) y trofeo | `resources/objetos/cuerno.tres`, `cuerno_minotauro.tres`; icono `assets/ui/inventario/objetos/icono_cuerno.png` (el mismo, PROVISIONAL para el trofeo) |
| Textos | `resources/dialogues/minotauro_*.tres`, `leonidas_orilla_sur.tres`, `leonidas_fin_demo.tres` |
| Prueba | `tools/pruebas/prueba_laberinto.gd` |

## Decisiones

- **Escala 0,3** (3223×1994 → 966×598 px de mundo): pasillos de 35–60 px, losas de ~20 px.
- **Colisión = todo lo que no es suelo libre**, en rectángulos (convexos: Godot no tiene que
  partir polígonos cóncavos), con las rendijas entre muros cerradas y **encogida ~4 px**, pero
  conservando un núcleo de ~2 px a lo largo del eje de cada muro (los muros finos que se ven siguen
  cerrando). Con la colisión justa (y luego encogida solo 2 px) se sentían paredes invisibles en
  los bordes (lo probó Esteban el 2026-11-23). El único paso a la salida de abajo es una rendija
  dibujada de ~12 px (x 175–230, y 398–407). Se comprobó que encoger no abre atajos (ningún punto
  queda más de 40 px más cerca de la entrada que antes). Las caras de piedra siguen siendo sólidas
  salvo su borde.
- **Pedestales con aro**: sólo su pie es sólido (están pintados sobre el suelo).
- **Rejas**: la de arriba en la boca del pasillo de entrada (al pie de la cara del muro), la de
  abajo en el hueco de la salida. Empiezan abiertas (el verificador de zonas recorre los pasos).
- **Minotauro**: dibujado de frente con la espada a su izquierda (derecha de la pantalla); se
  espeja para mirar a la izquierda. El espadazo barre el suelo a su lado (fotogramas 39–44 de
  `atacar`, a 30 fps) y después se queda con la espada clavada hasta el fotograma ~113: el momento
  para atacarle. Invencible sin el cuerno (`vida.invulnerable_extra`, barra gris). Camina a 60 px/s
  (Leonidas a 80). Es un jefe: al llegar a 0 no muere como un enemigo (sin monedas): se queda de
  pie para la escena de la derrota y luego se desvanece.
- **Al reintentar** tras el Game Over no se vuelve a enseñar la salida (sí el apagón y la
  aparición). Con el cuerno ya conseguido, se le puede herir desde el principio.

## Pendiente / por preguntar

- La salida de abajo no lleva a ninguna parte: `BarreraFinDemo` dice «fin de la demo».
- Sonidos propios del Minotauro (ahora: invocar y golpe al suelo de Medusa).
- Animaciones de daño y derrota (ahora se queda en `parado` y se desvanece).
- Icono propio del cuerno del Minotauro (usa el del cuerno del cofre).
- ¿El cofre del cuerno va en la esquina de abajo a la derecha (provisional) o en otro sitio?
- Textos definitivos; el cofre del cuerno no tiene diálogo propio.
- Peso del arte: `atacar` son 140 fotogramas (~20 MB de VRAM). Si pesa en la web, saltar
  fotogramas.
