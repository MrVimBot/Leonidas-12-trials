-- assets/sprites/game_over.aseprite (192×108, 1 frame, 6 capas; entregado el 2026-11-17):
-- pantalla de Game Over. Una pieza por capa, a lienzo completo y a tamaño real, para que
-- scenes/ui/game_over/arte_game_over.tscn las superponga (y anime) en su sitio.
-- 192×108 ×10 = 1920×1080: se dibuja en modo pintura (ver scripts/ui/pantalla_game_over.gd).
-- Si la artista renombra las capas, cambiar los nombres de aquí.
local L = { x = 0, y = 0, w = 192, h = 108 }
local function pieza(nombre, capas)
  return { nombre = nombre, capas = capas, x = L.x, y = L.y, w = L.w, h = L.h }
end
return {
  source = "assets/sprites/game_over.aseprite",
  out_dir = "assets/ui/game_over",
  recortes = {
    pieza("fondo", { "Layer 2" }),            -- fondo tramado + cono blanco del foco
    pieza("haz", { "Layer 7" }),              -- tramado amarillo del haz
    pieza("luz_suelo", { "Layer 3" }),        -- círculo de luz en el suelo
    pieza("leonidas", { "Layer 1" }),         -- Leonidas tumbado
    pieza("cartel", { "Layer 5", "Layer 6" }), -- tabla + letras «Game Over»
  },
}
