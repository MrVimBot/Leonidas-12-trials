-- assets/sprites/remolino.aseprite (20×20 px, 4 frames de 100 ms, una capa).
-- Una sola animación sin direcciones. El remolino trae su propio fondo de agua
-- (#3e6395): la escena lo vuelve transparente con un shader (quitar_color).
-- Origen en el centro → offset del AnimatedSprite2D = (0, 0).

return {
  source = "assets/sprites/remolino.aseprite",
  name = "remolino",
  out_dir = "assets/sprites/strips/remolino",
  cell = { w = 20, h = 20, origin = { x = 10, y = 10 } },

  columns = { frente = { x = 0, w = 20 } },

  rows = {
    { name = "girar", y = 0, h = 20, foot = 10, loop = true,
      columns = { frente = { name = "girar", x = 0, w = 20, ax = 10 } } },
  },
}
