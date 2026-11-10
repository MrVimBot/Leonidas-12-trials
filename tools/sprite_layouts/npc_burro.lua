-- assets/sprites/npc_burro.aseprite (85×105 px, 8 frames, sin tags).
-- Rejilla 3 columnas (frente / lado / espalda) × 2 filas (parado, caminar).
-- Cada fila está en su propia capa. El "lado" mira a la izquierda.
-- Ver tools/sprite_layouts/leonidas_mini.lua para el significado de cada campo.

return {
  source = "assets/sprites/npc_burro.aseprite",
  name = "npc_burro",
  out_dir = "assets/sprites/strips/npc_burro",

  -- offset del AnimatedSprite2D = (w/2 - origin.x, h/2 - origin.y) = (0, -24)
  cell = { w = 56, h = 52, origin = { x = 28, y = 50 } },
  side_faces = "izquierda",

  -- ax = centro del cuerpo en el lienzo (igual en las dos filas para que no salte)
  columns = {
    frente  = { x = 0,  w = 30, ax = 13 },
    lado    = { x = 30, w = 31, ax = 45 },
    espalda = { x = 61, w = 24, ax = 74 },
  },

  -- foot = fila más baja de los pies + 1 (los pies quedan en la fila 49 de la celda)
  rows = {
    { name = "parado",  y = 0,  h = 52, foot = 48,  loop = true, layers = { "parado" } },
    { name = "caminar", y = 52, h = 53, foot = 102, loop = true,
      columns = {
        frente  = { x = 0,  w = 30, ax = 13, layers = { "caminar de frente" } },
        lado    = { x = 30, w = 31, ax = 45, layers = { "caminar de lado" } },
        espalda = { x = 61, w = 24, ax = 74, layers = { "caminar de espalda" } },
      } },
  },
}
