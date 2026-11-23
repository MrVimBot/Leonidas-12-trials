-- assets/sprites/menu_pausa.aseprite (400×400, 1 frame, 3 capas; entregado el 2026-11-23):
-- marco del menú de pausa. Una pieza por capa, recortadas todas al mismo rectángulo (el del
-- dibujo entero, 362×333), para que scenes/ui/menu_pausa.tscn las superponga en su sitio.
-- No cabe en 480×270: se dibuja en modo pintura a escala entera (×3 en 1920×1080), como el libro.
-- Si la artista renombra las capas, cambiar los nombres de aquí.
local L = { x = 21, y = 46, w = 362, h = 333 }
local function pieza(nombre, capas)
  return { nombre = nombre, capas = capas, x = L.x, y = L.y, w = L.w, h = L.h }
end
return {
  source = "assets/sprites/menu_pausa.aseprite",
  out_dir = "assets/ui/menu_pausa",
  recortes = {
    pieza("marco", { "marco" }),              -- columnas, laureles, cartela y pergamino
    pieza("leonidas", { "Leonida pendejo" }), -- Leonidas asomado por encima de la cartela
    pieza("titulo", { "Pausa" }),             -- letras «Pausa» de la cartela
  },
}
