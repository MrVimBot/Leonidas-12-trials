-- assets/sprites/moneda.aseprite (14×15 px, 4 frames de 100 ms, una capa).
-- La moneda girando; una sola animación sin direcciones.
-- Origen abajo en el centro (el canto inferior de la moneda) → offset (0, −14).

return {
  source = "assets/sprites/moneda.aseprite",
  name = "moneda",
  out_dir = "assets/sprites/strips/moneda",
  cell = { w = 14, h = 15, origin = { x = 7, y = 14 } },

  columns = { frente = { x = 0, w = 14 } },

  rows = {
    { name = "girar", y = 0, h = 15, foot = 14, loop = true,
      columns = { frente = { name = "girar", x = 0, w = 14, ax = 7 } } },
  },
}
