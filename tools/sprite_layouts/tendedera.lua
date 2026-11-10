-- assets/sprites/tendedera.aseprite (26×36 px, 1 frame): la tendera del mercado.
-- Solo tiene una pose de frente (no camina).

return {
  source = "assets/sprites/tendedera.aseprite",
  name = "tendedera",
  out_dir = "assets/sprites/strips/tendedera",

  -- misma celda que los otros NPC: offset (0, -24)
  cell = { w = 56, h = 52, origin = { x = 28, y = 50 } },
  side_faces = "izquierda",

  columns = {
    frente = { x = 0, w = 26, ax = 13 },
  },

  rows = {
    { name = "parado", y = 0, h = 36, foot = 36, loop = true },
  },
}
