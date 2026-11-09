-- Recortes de assets/sprites/todos_los_assets.aseprite (1000×600, 1 frame, 1 capa).
-- Cada entrada: nombre, x, y, w, h (en el lienzo), y opcionalmente:
--   aislar = true  -> se queda solo con la mancha conexa más grande del rectángulo
--                     (para objetos que se solapan con otros, p. ej. el templo).
--   dir = "..."    -> carpeta de salida (por defecto out_dir).
-- Las coordenadas salieron de detectar las manchas de píxeles del archivo; si la
-- artista mueve algo, hay que corregirlas aquí.

return {
  source = "assets/sprites/todos_los_assets.aseprite",
  out_dir = "assets/sprites/entorno",

  recortes = {
    -- Tiles de 16×16 con 1 px de separación entre ellos (20 columnas × 2 filas).
    { nombre = "tiles_naturaleza", x = 0, y = 0, w = 339, h = 33, dir = "assets/tilesets" },

    -- Casas (abierta = puerta oscura, cerrada = puerta de madera)
    { nombre = "casa_amarilla_abierta", x = 16,  y = 35,  w = 147, h = 140, aislar = true },
    { nombre = "casa_amarilla_cerrada", x = 187, y = 35,  w = 147, h = 140, aislar = true },
    { nombre = "casa_balcon_abierta",   x = 342, y = 4,   w = 183, h = 159, aislar = true },
    { nombre = "casa_balcon_cerrada",   x = 540, y = 4,   w = 183, h = 159, aislar = true },
    { nombre = "casa_teja_abierta",     x = 7,   y = 178, w = 167, h = 173, aislar = true },
    { nombre = "casa_teja_cerrada",     x = 187, y = 180, w = 167, h = 173, aislar = true },
    { nombre = "templo",                x = 370, y = 173, w = 367, h = 324, aislar = true },
    { nombre = "casa_tocon",            x = 720, y = 193, w = 279, h = 237, aislar = true },
    { nombre = "puesto_mercado",        x = 3,   y = 510, w = 118, h = 80,  aislar = true },

    -- Vegetación
    { nombre = "pino",            x = 151, y = 374, w = 65, h = 99,  aislar = true },
    { nombre = "cipres",          x = 260, y = 409, w = 59, h = 124, aislar = true },
    { nombre = "cipres_dorado",   x = 101, y = 405, w = 71, h = 139, aislar = true },
    { nombre = "arbol_naranja",   x = 446, y = 498, w = 75, h = 94,  aislar = true },
    { nombre = "manzano_1",       x = 188, y = 538, w = 48, h = 56,  aislar = true },
    { nombre = "manzano_2",       x = 236, y = 538, w = 48, h = 56,  aislar = true },
    { nombre = "manzano_3",       x = 284, y = 538, w = 48, h = 56,  aislar = true },
    { nombre = "manzano_4",       x = 332, y = 538, w = 48, h = 56,  aislar = true },
    { nombre = "arbusto_dorado",  x = 126, y = 550, w = 25, h = 43,  aislar = true },
    { nombre = "arbusto_verde",   x = 153, y = 550, w = 25, h = 43,  aislar = true },
    { nombre = "arbusto_1",       x = 383, y = 184, w = 47, h = 34,  aislar = true },
    { nombre = "arbusto_2",       x = 343, y = 188, w = 37, h = 27,  aislar = true },
    { nombre = "macizo_flores_1", x = 359, y = 216, w = 49, h = 41,  aislar = true },
    { nombre = "macizo_flores_2", x = 356, y = 261, w = 53, h = 41,  aislar = true },
    { nombre = "tronco",          x = 339, y = 165, w = 34, h = 18,  aislar = true },
    { nombre = "troncos_apilados", x = 402, y = 165, w = 31, h = 16, aislar = true },
    { nombre = "girasol",         x = 380, y = 168, w = 20, h = 12,  aislar = true },
    { nombre = "manzana",         x = 431, y = 179, w = 9,  h = 10,  aislar = true },
    -- Sombra de referencia de la artista: óvalo opaco #106165 de 29×9.
    -- ComponenteSombra la dibuja a cualquier tamaño con el mismo color y proporción.
    { nombre = "sombra",          x = 367, y = 184, w = 29, h = 9 },

    -- Piedra y ruinas
    { nombre = "estatua",         x = 380, y = 481, w = 70, h = 118, aislar = true },
    { nombre = "arco_ruinas",     x = 220, y = 360, w = 137, h = 113, aislar = true },
    { nombre = "columna_1",       x = 2,   y = 389, w = 31, h = 69,  aislar = true },
    { nombre = "columna_2",       x = 35,  y = 389, w = 29, h = 69,  aislar = true },
    { nombre = "columna_3",       x = 67,  y = 379, w = 41, h = 79,  aislar = true },
    { nombre = "columna_rota_1",  x = 3,   y = 467, w = 29, h = 31,  aislar = true },
    { nombre = "columna_rota_2",  x = 35,  y = 461, w = 29, h = 37,  aislar = true },
    { nombre = "columna_rota_3",  x = 73,  y = 468, w = 29, h = 30,  aislar = true },
    { nombre = "muro_enredadera_1", x = 656, y = 483, w = 32, h = 114, aislar = true },
    { nombre = "muro_enredadera_2", x = 689, y = 483, w = 32, h = 112, aislar = true },
    { nombre = "muro_enredadera_3", x = 722, y = 483, w = 32, h = 112, aislar = true },
    { nombre = "roca_grande",     x = 175, y = 485, w = 51, h = 43,  aislar = true },
    { nombre = "roca",            x = 358, y = 465, w = 43, h = 31,  aislar = true },
    { nombre = "cartel",          x = 219, y = 484, w = 34, h = 41,  aislar = true },
    { nombre = "pedestal",        x = 321, y = 488, w = 37, h = 41,  aislar = true },
  },
}
