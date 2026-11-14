-- assets/sprites/piedras_barquito.aseprite (90×90, 1 frame, 1 capa): rocas del mar para
-- el minijuego del barco (sustituyen a las provisionales roca_mar_* de
-- assets/sprites/entorno/provisional/). Traen la línea del agua y la sombra pintadas.
-- Se solapan en el lienzo: `aislar` se queda con la mancha más grande del rectángulo.
return {
  source = "assets/sprites/piedras_barquito.aseprite",
  out_dir = "assets/sprites/entorno",
  recortes = {
    { nombre = "roca_barco_pequena", x = 38, y = 3,  w = 36, h = 24 },
    { nombre = "roca_barco_alta",    x = 1,  y = 9,  w = 58, h = 47, aislar = true },
    { nombre = "roca_barco_grande",  x = 19, y = 33, w = 70, h = 55, aislar = true },
  },
}
