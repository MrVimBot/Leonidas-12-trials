#!/usr/bin/env bash
# Regenera tiras PNG + SpriteFrames a partir de los .aseprite.
#
#   tools/export_sprites.sh                 # todos los layouts de tools/sprite_layouts/
#   tools/export_sprites.sh leonidas_mini   # solo uno
#
# Variables opcionales: ASEPRITE (ruta al binario), GODOT (ruta al binario).
# Trabaja siempre sobre una copia temporal del .aseprite: los originales no se tocan.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASEPRITE="${ASEPRITE:-$(command -v aseprite || echo "$HOME/Developer/aseprite/build/bin/aseprite")}"
GODOT="${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"

cd "$ROOT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [[ $# -gt 0 ]]; then
  layouts=(); for n in "$@"; do layouts+=("tools/sprite_layouts/$n.lua"); done
else
  layouts=(tools/sprite_layouts/*.lua)
fi

for layout in "${layouts[@]}"; do
  # el layout declara su source = "assets/sprites/xxx.aseprite"
  src="$(sed -n 's/^[[:space:]]*source[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' "$layout" | head -1)"
  [[ -f "$src" ]] || { echo "No existe $src (declarado en $layout)" >&2; exit 1; }
  cp "$src" "$TMP/copia.aseprite"
  "$ASEPRITE" -b "$TMP/copia.aseprite" \
    --script-param layout="$layout" \
    --script-param root="$ROOT" \
    --script tools/export_strips.lua
done

# Importar los PNG nuevos y construir los SpriteFrames.
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT" --script res://tools/build_sprite_frames.gd
