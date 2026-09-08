#!/usr/bin/env bash
# PreToolUse sobre Bash: deniega commits y pushes que aterrizarían en master/main.
# Ante cualquier error interno PERMITE: un guardarraíl que rompe la sesión se desinstala.
set -uo pipefail

PROTEGIDAS='^(master|main)$'

denegar() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}' "$1"
  exit 0
}

extraer_comando() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.tool_input.command // empty' 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null
  fi
}

rama_actual() { git rev-parse --abbrev-ref HEAD 2>/dev/null; }

protegida() { printf '%s' "$1" | grep -qE "$PROTEGIDAS"; }

# ¿el segmento es 'git <sub>'? tolera flags globales y -C/-c con argumento
es_git_sub() {
  local seg="$1" sub="$2" t saltar=0
  seg="$(printf '%s' "$seg" | sed 's/^[[:space:]]*//')"
  case "$seg" in git\ *) ;; *) return 1 ;; esac
  for t in ${seg#git}; do
    if [ "$saltar" -eq 1 ]; then saltar=0; continue; fi
    case "$t" in
      -C|-c)   saltar=1; continue ;;
      -*)      continue ;;
      "$sub")  return 0 ;;
      *)       return 1 ;;
    esac
  done
  return 1
}

# ¿algún token nombra explícitamente una rama protegida?
apunta_protegida() {
  local t dst
  for t in $1; do
    case "$t" in
      -*) continue ;;
      *:*)
        dst="${t#*:}"; dst="${dst#refs/heads/}"
        protegida "$dst" && return 0
        ;;
      master|main|refs/heads/master|refs/heads/main) return 0 ;;
    esac
  done
  return 1
}

# ¿hay un refspec explícito tras el remoto? (1er token libre = remoto, 2º+ = refspec)
destino_explicito() {
  local t vistos=0
  for t in ${1#*push}; do
    case "$t" in -*) continue ;; esac
    vistos=$((vistos + 1))
    [ "$vistos" -ge 2 ] && return 0
  done
  return 1
}

payload="$(cat)" || exit 0
comando="$(printf '%s' "$payload" | extraer_comando)" || exit 0
[ -z "$comando" ] && exit 0

rama="$(rama_actual)"

# Evalúa cada segmento: 'cd x && git push origin master' no se cuela.
# Se parte con un heredoc (no una tubería) para que el while NO corra en un subshell:
# 'denegar' necesita poder terminar el script entero.
while IFS= read -r seg; do
  [ -z "$seg" ] && continue
  if es_git_sub "$seg" push; then
    if apunta_protegida "$seg"; then
      denegar "Bloqueado: ese push aterriza en una rama protegida (master/main). En Accurate Media master solo recibe codigo via Pull Request. Usa la skill 'arranque' para crear una rama <dev>/<tipo>/<issue>-<slug> y la skill 'cierre' para abrir el PR."
    fi
    if protegida "$rama" && ! destino_explicito "$seg"; then
      denegar "Bloqueado: estas parado en '$rama', una rama protegida, y ese push la enviaria al remoto. Usa la skill 'arranque' para mover el trabajo a una rama de funcionalidad."
    fi
  fi
  if es_git_sub "$seg" commit && protegida "$rama"; then
    denegar "Bloqueado: no se commitea sobre '$rama'. Usa la skill 'arranque' para crear una rama <dev>/<tipo>/<issue>-<slug> antes de commitear."
  fi
done <<EOF
$(printf '%s' "$comando" | sed -e 's/&&/;/g' -e 's/||/;/g' -e 's/|/;/g' | tr ';\n' '\n\n')
EOF

exit 0
