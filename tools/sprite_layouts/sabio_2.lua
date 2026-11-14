-- assets/sprites/los_sabios.aseprite (150×140 px, 8 frames de 100 ms, sin tags).
-- Los 4 sabios del pueblo en fila, SOLO de frente, en dos capas que no se solapan:
--   "parados" (y 2–57, respiran) y "caminando" (y 57–113, andan en el sitio).
-- Un layout por sabio (sabio_1..sabio_4, de izquierda a derecha). Este es el 2: carnero (cuernos enroscados, túnica a rayas).
-- Sin vista lateral ni de espalda: el AnimadorDireccional usa la de frente.
-- `ax` = centro de los pies; `foot` = fila más baja de los pies.
-- offset del AnimatedSprite2D = (w/2 - origin.x, h/2 - origin.y) = (0, -28)

return {
  source = "assets/sprites/los_sabios.aseprite",
  name = "sabio_2",
  out_dir = "assets/sprites/strips/sabio_2",
  cell = { w = 48, h = 60, origin = { x = 24, y = 58 } },
  side_faces = "izquierda",

  columns = {
    frente = { x = 36, w = 25, ax = 51 },
  },

  rows = {
    { name = "parado",  layer = "parados",   y = 0,  h = 57, foot = 56,  loop = true },
    { name = "caminar", layer = "caminando", y = 57, h = 57, foot = 112, loop = true },
  },
}
