-- assets/sprites/inventario/iconos_de_inventario.aseprite (270×150, una capa por icono).
-- Pestañas del libro (64×56 cada una, con su marco dorado). Nombres = capas de la artista.
-- La versión "apagada" (pestaña no elegida) de la maqueta es el mismo icono con una capa
-- negra encima al 67 % (opacidad 170): en Godot, modulate = Color(0.33, 0.33, 0.33).
-- La pestaña elegida sube 18 px (maqueta: y 20 en vez de 38).
return {
  source = "assets/sprites/inventario/iconos_de_inventario.aseprite",
  out_dir = "assets/ui/inventario",
  recortes = {
    { nombre = "icono_salir",        x = 16,  y = 9,  w = 64, h = 56 },
    { nombre = "icono_herramientas", x = 104, y = 9,  w = 64, h = 56 }, -- espada
    { nombre = "icono_objetos",      x = 192, y = 9,  w = 64, h = 56 }, -- bolsa
    { nombre = "icono_mapa",         x = 16,  y = 81, w = 64, h = 56 },
    { nombre = "icono_misiones",     x = 104, y = 81, w = 64, h = 56 }, -- llama
    { nombre = "icono_guardar",      x = 192, y = 81, w = 64, h = 56 }, -- libro
  },
}
