-- assets/sprites/tiburon.aseprite (90×90 px, 8 frames de 100 ms, 3 capas que no se solapan).
--   Layer 1 (y 4–23): dos tiburones (un solo dibujo repetido, no se usa), mirando a la IZQUIERDA:
--     x 3–28 con la boca abierta (embestir) y x 34–58 con la boca cerrada (nadar).
--   Layer 2 (y 33–53): la misma pareja, con el ciclo de nado (la capa 1 es un solo dibujo).
--   Layer 3 (y 60–83): un tiburón que salta, abre la boca y se sumerge (morder).
-- Sin direcciones: el cerebro espeja con flip_h (espejar_sin_direccion).
-- `ax` = centro del cuerpo; `foot` = línea del agua (fila más baja).
-- offset del AnimatedSprite2D = (w/2 - origin.x, h/2 - origin.y) = (0, -11)

return {
  source = "assets/sprites/tiburon.aseprite",
  name = "tiburon",
  out_dir = "assets/sprites/strips/tiburon",
  cell = { w = 40, h = 28, origin = { x = 20, y = 25 } },
  side_faces = "izquierda",

  columns = { frente = { x = 0, w = 90 } },

  rows = {
    { name = "nadar", layer = "Layer 2", y = 33, h = 21, foot = 53, loop = true,
      columns = { frente = { name = "nadar", x = 32, w = 29, ax = 46 } } },
    { name = "embestir", layer = "Layer 2", y = 33, h = 21, foot = 53, loop = true,
      columns = { frente = { name = "embestir", x = 2, w = 30, ax = 17 } } },
    { name = "morder", layer = "Layer 3", y = 58, h = 26, foot = 83, loop = false,
      columns = { frente = { name = "morder", x = 2, w = 35, ax = 20 } } },
  },
}
