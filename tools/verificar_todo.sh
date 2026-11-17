#!/usr/bin/env bash
# Ejecuta TODAS las comprobaciones automáticas del proyecto: los dos verificadores del mapa y las
# pruebas de jugabilidad (tools/pruebas/prueba_*.gd). Es el paso obligatorio antes de dar por
# terminada una tarea (ver CLAUDE.md, sección «Pruebas»).
#
#   tools/verificar_todo.sh               # todo
#   tools/verificar_todo.sh libro         # solo lo que contenga «libro» en el nombre
#   tools/verificar_todo.sh -v barco      # además imprime la salida completa de cada una
#
# Variables opcionales:
#   GODOT          binario de Godot (por defecto el del PATH o /Applications/Godot.app/...)
#   TIEMPO_MAXIMO  segundos reales máximos por proceso (por defecto 240). Sin depender de
#                  `timeout` (no existe en macOS): se usa `perl alarm`. Cada prueba lleva además su
#                  propio límite interno (base_prueba.gd, 120 s por defecto).
#
# Cada comprobación va en su propio proceso. Las pruebas se ejecutan con `--fixed-fps 120` (los
# segundos de juego pasan sin esperar al reloj real); la de música lo tolera porque comprueba
# que el audio avanza con el reloj REAL (ver prueba_musica.gd). Salida: una línea por
# comprobación (nombre, OK/FALLO, segundos) y un resumen; código ≠ 0 si algo falla.
# El aviso inofensivo de headless «ERROR: Parameter "t" is null» (captura de pantalla del libro
# con el renderizador vacío), los avisos de recursos al salir y el error que prueba_microfono.gd
# provoca A PROPÓSITO (quitar el bus del micrófono) no cuentan como fallo.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
TIEMPO_MAXIMO="${TIEMPO_MAXIMO:-240}"
VERBOSO=0
if [ "${1:-}" = "-v" ]; then
	VERBOSO=1
	shift
fi
PATRON="${1:-}"

cd "$ROOT" || exit 2
if [ ! -x "$GODOT" ]; then
	echo "No encuentro Godot ('$GODOT'). Define GODOT=/ruta/al/binario" >&2
	exit 2
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ahora() { perl -MTime::HiRes=time -e 'printf "%.3f", time'; }

# Líneas de la salida que cuentan como error del motor/script (menos las conocidas e inofensivas).
errores() {
	grep -E '^(SCRIPT ERROR|ERROR:|USER ERROR|Parse Error)|Parse Error:' "$1" \
		| grep -vE 'Parameter "t" is null|resources still in use at exit|ObjectDB instances leaked|Microfono: falta el bus' || true
}

TOTAL=0
FALLOS=0
LISTA_FALLOS=""
INICIO="$(ahora)"

# comprobar <nombre> <exige_resultado: 0|1> <argumentos de godot...>
comprobar() {
	local nombre="$1" exige="$2"
	shift 2
	local log="$TMP/$nombre.log"
	local t0 t1 codigo motivo=""
	t0="$(ahora)"
	# Límite real con SIGKILL (Godot puede ignorar SIGALRM si se queda en un bucle caliente).
	perl -e 'my $t = shift; my $pid = fork();
		if (!$pid) { exec @ARGV or exit 127 }
		$SIG{ALRM} = sub { kill 9, $pid; waitpid($pid, 0); exit 142 };
		alarm $t; waitpid($pid, 0);
		exit(($? & 127) ? 128 + ($? & 127) : $? >> 8)' "$TIEMPO_MAXIMO" "$GODOT" --headless --path . "$@" >"$log" 2>&1 </dev/null
	codigo=$?
	t1="$(ahora)"
	if [ "$codigo" -eq 142 ]; then
		motivo="tiempo agotado (${TIEMPO_MAXIMO} s)"
	elif [ "$codigo" -ne 0 ]; then
		motivo="código de salida $codigo"
	elif [ "$exige" -eq 1 ] && ! grep -q '^RESULTADO: TODO PASA' "$log"; then
		motivo="sin «RESULTADO: TODO PASA»"
	elif [ -n "$(errores "$log")" ]; then
		motivo="errores del motor o del script"
	fi
	TOTAL=$((TOTAL + 1))
	local seg
	seg="$(perl -e 'printf "%.1f", $ARGV[1]-$ARGV[0]' "$t0" "$t1")"
	if [ -z "$motivo" ]; then
		printf '%-34s OK     %6s s\n' "$nombre" "$seg"
	else
		printf '%-34s FALLO  %6s s   (%s)\n' "$nombre" "$seg" "$motivo"
		FALLOS=$((FALLOS + 1))
		LISTA_FALLOS="$LISTA_FALLOS $nombre"
		{
			grep -E '^(FALLA|RESULTADO|FALLO)|FALLO' "$log" | head -15
			errores "$log" | head -10
		} | sed 's/^/      /'
		if [ "$VERBOSO" -eq 0 ] && ! grep -qE '^(FALLA|SCRIPT ERROR|ERROR)' "$log"; then
			tail -5 "$log" | sed 's/^/      | /'
		fi
	fi
	if [ "$VERBOSO" -eq 1 ]; then
		sed 's/^/      | /' "$log"
	fi
}

coincide() { [ -z "$PATRON" ] || [[ "$1" == *"$PATRON"* ]]; }

for v in verificar_zonas verificar_barreras_pueblo; do
	if coincide "$v"; then
		comprobar "$v" 0 --script "res://tools/$v.gd"
	fi
done

for f in tools/pruebas/prueba_*.gd; do
	nombre="$(basename "$f" .gd)"
	if coincide "$nombre"; then
		comprobar "$nombre" 1 --fixed-fps 120 --script res://tools/pruebas/lanzar.gd -- "res://tools/pruebas/$nombre.gd"
	fi
done

FIN="$(ahora)"
echo "----"
if [ "$TOTAL" -eq 0 ]; then
	echo "Nada que ejecutar con el patrón «$PATRON»" >&2
	exit 2
fi
TIEMPO="$(perl -e 'printf "%.1f", $ARGV[1]-$ARGV[0]' "$INICIO" "$FIN")"
if [ "$FALLOS" -eq 0 ]; then
	echo "TODO OK: $TOTAL comprobaciones en $TIEMPO s"
	exit 0
fi
echo "FALLAN $FALLOS de $TOTAL ($TIEMPO s):$LISTA_FALLOS"
exit 1
