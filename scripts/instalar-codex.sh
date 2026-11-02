#!/usr/bin/env bash
# Instala para Codex los agentes backend-engineer y frontend-engineer, y las skills normas y
# pruebas, apuntando a ESTE checkout: con `git pull` quedan actualizados.
#
# - Registra cada rol en ~/.codex/config.toml como [agents.<nombre>] con config_file hacia
#   codex/agents/<nombre>.toml (Codex 0.166 no descubre los roles solo por carpeta). Lo escribe
#   dentro de un bloque marcado que se reemplaza en cada corrida; el resto del archivo no se toca.
# - Enlaza las skills en ~/.codex/skills.
#
# Uso: ./scripts/instalar-codex.sh            (instala en ~/.codex)
#      CODEX_HOME=/otra/ruta ./scripts/...     (instala en otra carpeta de Codex)
#      ./scripts/instalar-codex.sh --desinstalar
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
CODEX="${CODEX_HOME:-$HOME/.codex}"
CONFIG="$CODEX/config.toml"
DESINSTALAR="${1:-}"

mkdir -p "$CODEX/skills"
touch "$CONFIG"
cp "$CONFIG" "$CONFIG.bak-accurate-media"

python3 - "$CONFIG" "$RAIZ" "$DESINSTALAR" <<'PY'
import sys, tomllib
from pathlib import Path

config, raiz, modo = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
INICIO, FIN = "# >>> accurate-media agents (scripts/instalar-codex.sh)", "# <<< accurate-media agents"

texto = config.read_text(encoding="utf-8")
if INICIO in texto:
    antes, _, resto = texto.partition(INICIO)
    _, _, despues = resto.partition(FIN)
    texto = antes.rstrip("\n") + "\n" + despues.lstrip("\n")

if modo != "--desinstalar":
    bloque = [INICIO]
    for toml in sorted((raiz / "codex" / "agents").glob("*.toml")):
        rol = tomllib.loads(toml.read_text(encoding="utf-8"))
        nombre = rol["name"]
        desc = rol["description"].replace("\\", "\\\\").replace('"', '\\"')
        bloque += [f'[agents.{nombre}]', f'description = "{desc}"', f'config_file = "{toml}"', ""]
        print(f"ok: rol {nombre} -> {toml}")
    bloque.append(FIN)
    texto = texto.rstrip("\n") + "\n\n" + "\n".join(bloque) + "\n"

tomllib.loads(texto)  # no dejar un config.toml roto
config.write_text(texto.lstrip("\n"), encoding="utf-8")
PY

for skill in normas pruebas; do
  destino="$CODEX/skills/$skill"
  if [ "$DESINSTALAR" = "--desinstalar" ]; then
    [ -L "$destino" ] && rm "$destino" && printf 'quitado: %s\n' "$destino"
    continue
  fi
  if [ -e "$destino" ] && [ ! -L "$destino" ]; then
    printf 'omitido: %s ya existe y no es un enlace; no lo piso\n' "$destino" >&2
    continue
  fi
  ln -sfn "$RAIZ/plugins/accurate-media/skills/$skill" "$destino"
  printf 'ok: skill %s\n' "$skill"
done

printf '\nListo (respaldo en %s). En Codex: «usa el agente backend-engineer para ...»\n' "$CONFIG.bak-accurate-media"
