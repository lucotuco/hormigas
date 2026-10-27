#!/usr/bin/env bash
# Corre todas las pruebas lógicas en modo headless.
#
# Uso (desde la carpeta del proyecto):
#   GODOT=/ruta/a/godot tests/correr_todas.sh
# En Windows se puede correr desde Git Bash, con GODOT apuntando al .exe.
#
# Sale con código 1 si alguna prueba falla o tira errores de script.
set -u

GODOT="${GODOT:-godot}"

cd "$(dirname "$0")/.."

# Toda escena tests/prueba_*.tscn es una suite: una prueba nueva corre sola.
SUITES=()
for escena in tests/prueba_*.tscn; do
	SUITES+=("$(basename "$escena" .tscn)")
done

echo "Importando recursos..."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

fallo=0
for suite in "${SUITES[@]}"; do
	salida=$("$GODOT" --headless --fixed-fps 60 --path . "res://tests/$suite.tscn" 2>&1)
	codigo=$?
	errores=$(printf '%s\n' "$salida" | grep -cE "SCRIPT ERROR|^ERROR" || true)
	if [ "$codigo" -ne 0 ] || [ "$errores" -ne 0 ]; then
		echo "FALLA  $suite (código $codigo, errores de script: $errores)"
		printf '%s\n' "$salida" | grep -E "FALLA|SCRIPT ERROR|^ERROR" -A3 | head -40
		fallo=1
	else
		resumen=$(printf '%s\n' "$salida" | grep -E "verificaciones|Todo bien|fallas\." | tail -1)
		echo "OK     $suite  $resumen"
	fi
done

if [ "$fallo" -ne 0 ]; then
	echo
	echo "Hay pruebas fallando."
	exit 1
fi
echo
echo "Todas las pruebas pasaron."
