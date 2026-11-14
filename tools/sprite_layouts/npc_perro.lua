-- assets/sprites/npc_perro.aseprite (70×39 px, 1 frame, 1 capa): NPC del pueblo.
-- Una sola pose (no camina) en 3 columnas: frente / lado / espalda. El "lado" mira a la
-- izquierda (derecha = flip_h). Sin animación de caminar: usar con `paseo = false`.
-- `ax` = centro de los pies; `foot` = fila más baja de los pies.

return {
  source = "assets/sprites/npc_perro.aseprite",
  name = "npc_perro",
  out_dir = "assets/sprites/strips/npc_perro",

  -- misma celda que los otros NPC: offset (0, -24)
  cell = { w = 56, h = 52, origin = { x = 28, y = 50 } },
  side_faces = "izquierda",

  columns = {
    frente  = { x = 0,   w = 22, ax = 11 },
    lado    = { x = 22, w = 26, ax = 32 },
    espalda = { x = 48, w = 22, ax = 58 },
  },

  rows = {
    { name = "parado", y = 0, h = 37, foot = 36, loop = true },
  },
}
