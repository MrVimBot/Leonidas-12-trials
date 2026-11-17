-- assets/sprites/objetos_arrojables.aseprite (120×80, 6 frames, 4 capas).
-- Capa "objetos agarrables" (igual en los 6 frames): vasijas, piedra, arbusto y tocón.
-- Las capas "roto ..." (animación de romperse) están en y >= 43: no entran en estos
-- rectángulos, que son de la fila de arriba (pies en la fila 31). La flecha (88,7) queda fuera.
-- La animación de romperse sale por tools/sprite_layouts/objetos_arrojables.lua.
return {
  source = "assets/sprites/objetos_arrojables.aseprite",
  out_dir = "assets/sprites/entorno",
  recortes = {
    { nombre = "vasija_azul",    x = 10, y = 23, w = 10, h = 9 },
    { nombre = "vasija_naranja", x = 27, y = 8,  w = 13, h = 24 },
    { nombre = "piedra",         x = 48, y = 21, w = 15, h = 11 },
    { nombre = "arbusto",        x = 71, y = 15, w = 19, h = 17 },
    { nombre = "tocon",          x = 97, y = 25, w = 9,  h = 7 },
  },
}
