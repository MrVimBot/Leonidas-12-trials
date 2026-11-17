#!/usr/bin/env bash
# Copia la entrega de la artista (fotogramas pintados del nivel 2) a fuente/nivel2/,
# con los nombres de carpeta en snake_case ("pez espada" -> pez_espada). No toca el origen.
#
#   tools/pintados/copiar_fuente.sh "/ruta/a/Assets nivel 2"
#
# fuente/ NO va al repo (.gitignore: son ~160 MB de PNG a 1280×720) y lleva .gdignore para
# que Godot no los importe. Lo que usa el juego lo genera tools/pintados/normalizar.sh.
set -euo pipefail

ORIGEN="${1:?Uso: $0 <carpeta de la entrega>}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DESTINO="$ROOT/fuente/nivel2"

snake() {  # minúsculas, sin acentos, espacios y guiones -> _
  printf '%s' "$1" | iconv -f UTF-8 -t ASCII//TRANSLIT | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[ -]+/_/g; s/[^a-z0-9_.]//g'
}

mkdir -p "$DESTINO"
touch "$ROOT/fuente/.gdignore"
find "$ORIGEN" -type f -iname '*.png' | while read -r f; do
  rel="${f#"$ORIGEN"/}"
  personaje="$(snake "$(dirname "$(dirname "$rel")")")"
  anim="$(snake "$(basename "$(dirname "$rel")")")"
  archivo="$(snake "$(basename "$rel")")"
  mkdir -p "$DESTINO/$personaje/$anim"
  cp -p "$f" "$DESTINO/$personaje/$anim/$archivo"
done
echo "Copiado a $DESTINO:"
for d in "$DESTINO"/*/*/; do echo "  ${d#"$DESTINO"/} $(ls "$d" | wc -l | tr -d ' ') fotogramas"; done
