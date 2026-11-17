-- assets/sprites/objetos_arrojables.aseprite (120×80, 6 frames, 4 capas).
-- Aquí solo salen las animaciones de ROMPERSE (los objetos enteros salen como PNG
-- sueltos por tools/recortes/objetos_arrojables.lua). Una capa por objeto, sin
-- direcciones; el frame 1 es el objeto estallando y los 4–6 son los trozos quietos
-- (iguales: la detección de repetidos deja el último y la animación acaba ahí).
-- Pies (fila más baja) y centro medidos en el frame 1 de cada capa.
-- Celda 48×32 con origen (24, 30): offset del AnimatedSprite2D = (0, -14)
-- (w/2 - origin.x, h/2 - origin.y) para que la posición del nodo sean los pies.

return {
  source = "assets/sprites/objetos_arrojables.aseprite",
  name = "objetos_arrojables",
  out_dir = "assets/sprites/strips/objetos_arrojables",
  cell = { w = 48, h = 32, origin = { x = 24, y = 30 } },

  columns = { frente = { x = 0, w = 120 } },

  rows = {
    { name = "romper_vasija_azul", layer = "roto vasija azul", y = 40, h = 32, foot = 69, loop = false,
      columns = { frente = { name = "romper_vasija_azul", x = 0, w = 26, ax = 13 } } },
    { name = "romper_vasija_naranja", layer = "roto, vasija naranja", y = 40, h = 32, foot = 69, loop = false,
      columns = { frente = { name = "romper_vasija_naranja", x = 24, w = 46, ax = 46 } } },
    { name = "romper_arbusto", layer = "roto arbusto", y = 40, h = 32, foot = 70, loop = false,
      columns = { frente = { name = "romper_arbusto", x = 68, w = 52, ax = 92 } } },
  },
}
