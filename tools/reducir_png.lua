-- Reduce un PNG de pixel art que la artista exportó agrandado (cada "píxel" del dibujo
-- ocupa N×N píxeles reales) a su tamaño real, sin suavizar (vecino más cercano).
--
-- Uso:
--   aseprite -b --script-param entrada=assets/ui/dialog_box.png \
--     --script-param salida=assets/ui/caja_dialogo.png --script-param factor=6 \
--     --script tools/reducir_png.lua
--
-- El factor se puede detectar: es el máximo común divisor de los tramos de color
-- (dialog_box.png y dialog_continue_arrow.png están a ×6).

local entrada = app.params.entrada or error("Falta entrada=")
local salida = app.params.salida or error("Falta salida=")
local f = tonumber(app.params.factor or error("Falta factor="))

local im = Image{ fromFile = entrada }
local w, h = im.width // f, im.height // f
local out = Image(w, h, ColorMode.RGB)
for y = 0, h - 1 do
  for x = 0, w - 1 do
    -- muestrea el centro de cada bloque
    out:drawPixel(x, y, im:getPixel(x * f + f // 2, y * f + f // 2))
  end
end
out:saveAs(salida)
print(string.format("[reducir_png] %s (%dx%d) -> %s (%dx%d)", entrada, im.width, im.height, salida, w, h))
