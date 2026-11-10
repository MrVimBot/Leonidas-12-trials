-- assets/sprites/npc_zorro.aseprite (100×100 px, 8 frames, sin tags).
-- Rejilla 3 columnas (frente / lado / espalda) × 2 filas (parado, caminar).
-- Al caminar, la cola de frente ("Layer 5") y la de espalda ("Layer 4") van en capas
-- aparte y la cola del lado llega a tocar al zorro de espalda: por eso cada columna
-- se aplana solo con sus capas (`layers`). El "lado" mira a la izquierda.

return {
  source = "assets/sprites/npc_zorro.aseprite",
  name = "npc_zorro",
  out_dir = "assets/sprites/strips/npc_zorro",

  -- offset del AnimatedSprite2D = (w/2 - origin.x, h/2 - origin.y) = (0, -24)
  cell = { w = 56, h = 52, origin = { x = 28, y = 50 } },
  side_faces = "izquierda",

  columns = {
    frente  = { x = 0,  w = 32, ax = 15 },
    lado    = { x = 31, w = 39, ax = 42 },
    espalda = { x = 66, w = 34, ax = 80 },
  },

  rows = {
    { name = "parado",  y = 0,  h = 50, foot = 45, loop = true, layers = { "parado" },
      columns = {
        frente  = { x = 0,  w = 31, ax = 15 },
        lado    = { x = 31, w = 36, ax = 42 },
        espalda = { x = 67, w = 33, ax = 80, foot = 44 },
      } },
    { name = "caminar", y = 50, h = 50, foot = 97, loop = true,
      columns = {
        frente  = { x = 0,  w = 32, ax = 15, layers = { "caminar delante", "Layer 5" } },
        lado    = { x = 31, w = 40, ax = 42, foot = 96, layers = { "caminar e lado" } },
        espalda = { x = 62, w = 38, ax = 80, layers = { "Layer 3", "Layer 4" } },
      } },
  },
}
