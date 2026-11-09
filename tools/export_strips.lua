-- Exporta tiras PNG (+ JSON) de un .aseprite cuyas animaciones están apiladas
-- en franjas del lienzo, según una tabla de distribución (tools/sprite_layouts/*.lua).
--
-- Uso (desde la raíz del repo, sobre una COPIA del .aseprite):
--   aseprite -b copia.aseprite \
--     --script-param layout=tools/sprite_layouts/leonidas_mini.lua \
--     --script-param root=$(pwd) \
--     --script tools/export_strips.lua
--
-- Normalmente se llama desde tools/export_sprites.sh.
-- El script solo lee el sprite: nunca lo guarda.

local spr = app.activeSprite
if not spr then error("No hay sprite abierto. Pasa el .aseprite antes de --script.") end

local root = app.params.root or "."
local layout_path = app.params.layout or error("Falta --script-param layout=...")
local L = dofile(layout_path)

local out_dir = root .. "/" .. L.out_dir
app.fs.makeAllDirectories(out_dir)

local cell_w, cell_h = L.cell.w, L.cell.h
local ox, oy = L.cell.origin.x, L.cell.origin.y
local nframes = #spr.frames

-- 1) Aplanar cada frame una sola vez (solo capas visibles).
local flat = {}
for i = 1, nframes do
  local img = Image(spr.width, spr.height, ColorMode.RGB)
  img:drawSprite(spr, i)
  flat[i] = img
end

-- ¿La imagen tiene algún píxel no transparente?
local function is_empty(img)
  for it in img:pixels() do
    if app.pixelColor.rgbaA(it()) > 0 then return false end
  end
  return true
end

-- Recorta `rect` del frame y lo pega en una celda con el ancla alineada.
-- Devuelve la celda y cuántos píxeles quedaron fuera de ella.
local function make_cell(frame_img, rect, foot)
  local region = Image(rect.w, rect.h, ColorMode.RGB)
  region:drawImage(frame_img, Point(-rect.x, -rect.y))
  local anchor_x = math.floor(rect.w / 2)       -- centro de la columna
  local anchor_y = foot - rect.y                -- pies, relativo a la región
  local dx, dy = ox - anchor_x, oy - anchor_y
  local cell = Image(cell_w, cell_h, ColorMode.RGB)
  cell:drawImage(region, Point(dx, dy))
  -- detectar recorte: píxeles opacos de la región que caen fuera de la celda
  local clipped = 0
  for it in region:pixels() do
    if app.pixelColor.rgbaA(it()) > 0 then
      local cx, cy = it.x + dx, it.y + dy
      if cx < 0 or cy < 0 or cx >= cell_w or cy >= cell_h then clipped = clipped + 1 end
    end
  end
  return cell, clipped
end

-- JSON mínimo (sin depender de la versión de la API).
local function esc(s) return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"' end
local function to_json(v, ind)
  ind = ind or ""
  local t = type(v)
  if t == "table" then
    local n = #v
    local inner = ind .. "  "
    local parts = {}
    if n > 0 or next(v) == nil then
      for _, x in ipairs(v) do parts[#parts + 1] = to_json(x, inner) end
      return "[" .. table.concat(parts, ", ") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do parts[#parts + 1] = inner .. esc(k) .. ": " .. to_json(v[k], inner) end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. ind .. "}"
  elseif t == "string" then return esc(v)
  elseif t == "boolean" then return v and "true" or "false"
  else return tostring(v) end
end

local manifest = {
  name = L.name,
  source = L.source,
  cell = { w = cell_w, h = cell_h },
  origin = { x = ox, y = oy },
  side_faces = L.side_faces or "izquierda",
  animations = {},
}
local warnings = {}
local dir_order = { "frente", "lado", "espalda" }

for _, row in ipairs(L.rows) do
  for _, dir in ipairs(dir_order) do
    local col = (row.columns and row.columns[dir]) or L.columns[dir]
    local skip = row.skip and row.skip[dir]
    if col and not skip then
      local anim = row.name .. "_" .. dir
      local rect = { x = col.x, y = row.y, w = col.w, h = row.h }
      local cells, durations, dup_of, empty = {}, {}, {}, {}
      local clipped_total = 0
      for i = 1, nframes do
        local c, clipped = make_cell(flat[i], rect, row.foot)
        clipped_total = clipped_total + clipped
        cells[i] = c
        durations[i] = math.floor(spr.frames[i].duration * 1000 + 0.5)
        empty[i] = is_empty(c)
        dup_of[i] = -1
        for j = 1, i - 1 do
          if dup_of[j] == -1 and c:isEqual(cells[j]) then dup_of[i] = j - 1; break end
        end
      end

      -- tira horizontal
      local strip = Image(cell_w * nframes, cell_h, ColorMode.RGB)
      for i = 1, nframes do strip:drawImage(cells[i], Point((i - 1) * cell_w, 0)) end
      local file = anim .. ".png"
      strip:saveAs(out_dir .. "/" .. file)

      -- periodo: menor p (divisor de n) tal que frame[i] == frame[i-p] para todo i >= p.
      -- Ej.: 16 frames donde 8–15 repiten 0–7 -> period = 8. Godot usa solo los `period` primeros.
      local period = nframes
      for p = 1, nframes - 1 do
        if nframes % p == 0 then
          local ok = true
          for i = p + 1, nframes do
            if not cells[i]:isEqual(cells[i - p]) then ok = false; break end
          end
          if ok then period = p; break end
        end
      end

      local unique, empties, dups = 0, {}, {}
      for i = 1, nframes do
        if dup_of[i] == -1 then unique = unique + 1 else dups[#dups + 1] = { i - 1, dup_of[i] } end
        if empty[i] then empties[#empties + 1] = i - 1 end
      end
      if clipped_total > 0 then
        warnings[#warnings + 1] = string.format("%s: %d px quedaron fuera de la celda (agranda cell o ajusta foot)", anim, clipped_total)
      end
      if #empties == nframes then
        warnings[#warnings + 1] = anim .. ": todos los frames están vacíos (¿región mal definida?)"
      end

      manifest.animations[anim] = {
        file = file,
        frame_count = nframes,
        durations_ms = durations,
        loop = row.loop ~= false,
        period = period,
        unique_frames = unique,
        duplicates = dups,          -- pares [frame, igual_a_frame]
        empty_frames = empties,
        region = { rect.x, rect.y, rect.w, rect.h },
        foot = row.foot,
      }
    end
  end
end

manifest.warnings = warnings

local f = io.open(out_dir .. "/" .. L.name .. ".json", "w")
f:write(to_json(manifest) .. "\n")
f:close()

local count = 0
for _ in pairs(manifest.animations) do count = count + 1 end
print(string.format("[export_strips] %s: %d animaciones -> %s", L.name, count, L.out_dir))
for _, w in ipairs(warnings) do print("[export_strips] AVISO " .. w) end
