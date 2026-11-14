-- Tiles sueltos de assets/sprites/tiles_y_como_funcionan.aseprite (500×380, 1 frame, 1 capa).
-- La hoja de la artista muestra arriba/en medio los tiles sueltos (16×16) y debajo
-- ejemplos de cómo se combinan. Aquí solo se sacan los tiles que NO estaban ya en
-- tiles_naturaleza.png (los demás son iguales o un giro/volteo de uno que ya existe;
-- comprobado píxel a píxel). Se empaquetan en un atlas de 16×16 con 1 px de separación
-- (igual que tiles_naturaleza) → assets/tilesets/tiles_transiciones.png, que
-- tools/build_tilesets.gd añade como fuente 1 de resources/tilesets/naturaleza.tres.
--
-- Cada fila del atlas = un grupo; cada tile = {x, y} de su esquina en la hoja.
-- Si la artista mueve tiles en la hoja, corregir aquí las coordenadas.

return {
  source = "assets/sprites/tiles_y_como_funcionan.aseprite",
  out_dir = "assets/tilesets",
  recortes = {},

  atlas = {
    nombre = "tiles_transiciones",
    tamano = 16,
    separacion = 1,
    filas = {
      -- Fila 0: suelo de piedra clara (el de los tiles 6–11,0) → hierba.
      --   0–3 esquinas exteriores redondeadas (sup-izq, sup-der, inf-izq, inf-der)
      --   4–5 borde superior (hierba arriba) · 6–7 borde inferior (hierba abajo)
      --   8–11 relleno con una mata de hierba en una esquina (esquinas interiores)
      --   Los bordes laterales ya estaban: 10,0 y 11,0 de tiles_naturaleza.
      { {160, 4}, {178, 4}, {160, 22}, {178, 22},
        {198, 4}, {216, 4}, {198, 22}, {216, 22},
        {236, 4}, {254, 4}, {236, 22}, {254, 22} },
      -- Fila 1: estanque con bordillo de piedra (agua = la de 16,0).
      --   0 bordillo horizontal: hierba arriba, agua abajo
      --   1 bordillo horizontal: agua arriba, hierba abajo
      --   2–3 esquinas del bordillo vistas desde fuera (agua abajo)
      --   4–8 esquinas y uniones del bordillo con agua a ambos lados (ver los
      --       ejemplos de la hoja: estanque en T). El agua lisa es 16,0.
      { {380, 4}, {399, 5}, {421, 5}, {441, 5}, {462, 5}, {481, 5},
        {441, 24}, {462, 24}, {481, 24} },
      -- Fila 2: estanque natural (orilla de hierba, sin bordillo; otro tono de agua).
      --   0 agua lisa · 1–4 bordes (orilla abajo, arriba, izquierda, derecha)
      --   5–8 esquinas interiores (pico de hierba en una esquina)
      --   9–12 esquinas exteriores (sup-izq, sup-der, inf-izq, inf-der)
      { {22, 194}, {45, 194}, {65, 194}, {45, 215}, {65, 215},
        {89, 194}, {109, 194}, {89, 214}, {109, 214},
        {133, 194}, {152, 194}, {133, 213}, {152, 213} },
      -- Fila 3: camino de tierra (la de 1–3,1) → hierba.
      --   0–1 borde superior (hierba arriba) · 2 borde inferior
      --   3 borde izquierdo · 4 borde derecho
      --   5–6 esquinas exteriores superiores · 7–8 esquinas exteriores inferiores
      --   9–10 esquinas INTERIORES (asoma hierba abajo-izq / abajo-dcha). OJO: no son
      --   relleno, y 3,1 de tiles_naturaleza tampoco (es otra interior abajo-izq).
      { {181, 194}, {200, 194}, {200, 213}, {220, 194}, {239, 194},
        {261, 194}, {281, 194}, {261, 213}, {281, 213}, {306, 213}, {325, 213} },
      -- Fila 4: RELLENOS PROVISIONALES (la artista no dibujó relleno de tierra ni de
      -- piedra). Una esquina interior con su pico de hierba tapado por el mismo trozo de
      -- otra interior que tiene esa esquina limpia. Sustituir cuando la artista los dibuje.
      --   0 tierra (9,3 + abajo-izq de 10,3) · 1 tierra (10,3 + abajo-dcha de 9,3)
      --   2 piedra (8,0 + arriba-izq de 11,0)
      { {306, 213, parche = {325, 213, 0, 11, 6, 5}},
        {325, 213, parche = {306, 213, 10, 11, 6, 5}},
        {236, 4, parche = {254, 22, 0, 0, 8, 7}} },
    },
  },
}
