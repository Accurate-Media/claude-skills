#!/usr/bin/env bash
# Verifica la integridad estructural del marketplace.
# Exit 0 si todo está bien; exit 1 listando los fallos.
set -uo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
FALLOS=0
LIMITE_DESC=1024

fallo() { printf 'FALLO: %s\n' "$1" >&2; FALLOS=$((FALLOS + 1)); }
ok()    { printf 'ok: %s\n' "$1"; }

json_valido() { python3 -m json.tool "$1" >/dev/null 2>&1; }

# --- 1. marketplace.json parsea -----------------------------------------
MKT="$RAIZ/.claude-plugin/marketplace.json"
if [ ! -f "$MKT" ]; then
  fallo "no existe .claude-plugin/marketplace.json"
elif ! json_valido "$MKT"; then
  fallo "marketplace.json no es JSON válido"
else
  ok "marketplace.json parsea"
fi

# --- 2 y 3. cada source resuelve y su plugin.json es válido -------------
if [ -f "$MKT" ] && json_valido "$MKT"; then
  while IFS=$'\t' read -r nombre_plugin src; do
    [ -z "$nombre_plugin" ] && [ -z "$src" ] && continue
    if [ -z "$src" ]; then
      fallo "marketplace.json: el plugin '$nombre_plugin' no tiene campo 'source'"
      continue
    fi
    dir="$RAIZ/${src#./}"
    if [ ! -d "$dir" ]; then
      fallo "source no resuelve: $src"
      continue
    fi
    pj="$dir/.claude-plugin/plugin.json"
    if [ ! -f "$pj" ]; then
      fallo "falta plugin.json en $src"
    elif ! json_valido "$pj"; then
      fallo "plugin.json inválido en $src"
    else
      for campo in name version description; do
        if ! python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d.get('$campo') else 1)" "$pj"; then
          fallo "plugin.json de $src sin campo '$campo'"
        fi
      done
      ok "plugin $src"
    fi
  done <<EOF
$(python3 -c "
import json
data = json.load(open('$MKT'))
for i, p in enumerate(data.get('plugins', [])):
    nombre = p.get('name') or ('(sin name, índice %d)' % i)
    fuente = p.get('source', '')
    print(nombre + '\t' + fuente)
" 2>/dev/null)
EOF
fi

# --- 4 a 8. cada SKILL.md ------------------------------------------------
SKILLS="$(find "$RAIZ/plugins" -name SKILL.md 2>/dev/null | sort)"
if [ -z "$SKILLS" ]; then
  fallo "no se encontró ningún SKILL.md bajo plugins/"
fi

while IFS= read -r skill; do
  [ -z "$skill" ] && continue
  dir="$(dirname "$skill")"
  carpeta="$(basename "$dir")"
  fm="$(awk 'NR==1 && $0!="---"{exit} NR>1 && /^---$/{exit} NR>1' "$skill")"
  fallos_previos="$FALLOS"

  if [ -z "$fm" ]; then
    fallo "$skill: sin frontmatter"
    continue
  fi

  nombre="$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d '"' | tr -d "'" | tr -d ' ')"
  if [ -z "$nombre" ]; then
    fallo "$skill: frontmatter sin 'name'"
  elif [ "$nombre" != "$carpeta" ]; then
    fallo "$skill: name '$nombre' no coincide con la carpeta '$carpeta'"
  fi

  if ! printf '%s\n' "$fm" | grep -q '^description:'; then
    fallo "$skill: frontmatter sin 'description'"
  else
    desc="$(printf '%s\n' "$fm" | sed -n '/^description:/,$p' | sed '1s/^description:[[:space:]]*//' | tr '\n' ' ')"
    largo="$(printf '%s' "$desc" | wc -c | tr -d ' ')"
    if [ "$largo" -gt "$LIMITE_DESC" ]; then
      fallo "$skill: description de $largo caracteres (límite $LIMITE_DESC)"
    fi
  fi

  if printf '%s\n' "$fm" | grep -q '^[[:space:]]*#'; then
    fallo "$skill: el frontmatter contiene una línea de comentario"
  fi

  # referencias citadas que no existen.
  # Acepta 'references/x.md' (dentro de la propia skill) y también
  # 'otra-skill/references/x.md' (cita cruzada, ej. normas/references/git.md).
  raiz_skills="$(dirname "$dir")"
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    case "$ref" in
      */references/*|*/assets/*) destino="$raiz_skills/$ref" ;;
      *)                         destino="$dir/$ref" ;;
    esac
    if [ ! -f "$destino" ]; then
      fallo "$skill: cita '$ref' pero no existe $destino"
    fi
  done <<EOF
$(grep -oE '([a-z][a-z-]*/)?(references|assets)/[A-Za-z0-9._-]+\.md' "$skill" | sort -u)
EOF

  [ "$FALLOS" -eq "$fallos_previos" ] && ok "$skill"
done <<EOF
$SKILLS
EOF

if [ "$FALLOS" -gt 0 ]; then
  printf '\n%d fallo(s)\n' "$FALLOS" >&2
  exit 1
fi
printf '\nTodo correcto\n'
