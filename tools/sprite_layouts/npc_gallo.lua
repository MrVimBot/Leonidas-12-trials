-- assets/sprites/npc_gallo.aseprite (70×40 px, 1 frame, 1 capa): NPC del pueblo.
-- Una sola pose (no camina) en 3 columnas: frente / lado / espalda. El "lado" mira a la
-- izquierda (derecha = flip_h). Sin animación de caminar: usar con `paseo = false`.
-- `ax` = centro de los pies; `foot` = fila más baja de los pies.

return {
  source = "assets/sprites/npc_gallo.aseprite",
  name = "npc_gallo",
  out_dir = "assets/sprites/strips/npc_gallo",

  -- misma celda que los otros NPC: offset (0, -24)
  cell = { w = 56, h = 52, origin = { x = 28, y = 50 } },
  side_faces = "izquierda",

  columns = {
    frente  = { x = 0,   w = 20, ax = 10 },
    lado    = { x = 21, w = 27, ax = 30 },
    espalda = { x = 50, w = 18, ax = 59 },
  },

  rows = {
    { name = "parado", y = 0, h = 38, foot = 37, loop = true },
  },
}
