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

# Quita comillas y paréntesis de un segmento antes de tokenizarlo. Esto neutraliza
# 'master' / "master" (comillas ordinarias al escribir git) y los paréntesis de un
# subshell ( ... git push origin master) sin tocar el resto del texto.
normalizar() { printf '%s' "$1" | tr -d "()'\""; }

# Quita una palabra envolvente al inicio del segmento (eval/sudo/command/time) para
# que 'eval "git push origin master"' siga viéndose como un comando git.
quitar_envoltura() {
  local s primer resto
  s="$(printf '%s' "$1" | sed 's/^[[:space:]]*//')"
  while :; do
    case "$s" in
      *' '*) primer="${s%% *}"; resto="${s#* }" ;;
      *) break ;;
    esac
    case "$primer" in
      eval|sudo|command|time) s="$resto" ;;
      *) break ;;
    esac
  done
  printf '%s' "$s"
}

# NOTA DE ALCANCE: una sustitución de comando que NO contiene el nombre literal de la
# rama (p.ej. 'git push origin $(rama_actual)') queda deliberadamente sin cubrir.
# Cerrar eso exigiría un parser de shell real dentro de un hook cuyo contrato es
# degradar permitiendo, y requiere esfuerzo deliberado del propio dev al que este
# guardarraíl protege. El backstop para ese caso es la protección de rama en GitHub.

# ¿algún token del segmento (ya tokenizado) es exactamente esta bandera?
tiene_bandera() {
  local t bandera="$2"
  for t in $1; do
    [ "$t" = "$bandera" ] && return 0
  done
  return 1
}

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
# Un '+' al inicio de un token (o del lado destino de un refspec) es el prefijo de
# force-push de git ('+master', 'origen:+refs/heads/master'); se quita antes de
# comparar para que no sirva de disfraz.
apunta_protegida() {
  local t dst
  for t in $1; do
    case "$t" in
      -*) continue ;;
    esac
    t="${t#+}"
    case "$t" in
      *:*)
        dst="${t#*:}"; dst="${dst#refs/heads/}"; dst="${dst#+}"
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
  seg_proc="$(quitar_envoltura "$(normalizar "$seg")")"
  if es_git_sub "$seg_proc" push; then
    if tiene_bandera "$seg_proc" "--all" || tiene_bandera "$seg_proc" "--mirror"; then
      denegar "Bloqueado: 'push --all' y 'push --mirror' empujan todas las ramas locales, incluida master, sin importar en cuál estés parado. Usa un push explícito a la rama que quieras enviar."
    fi
    if apunta_protegida "$seg_proc"; then
      denegar "Bloqueado: ese push aterriza en una rama protegida (master/main). En Accurate Media master solo recibe código via Pull Request. Usa la skill 'arranque' para crear una rama <dev>/<tipo>/<issue>-<slug> y la skill 'cierre' para abrir el PR."
    fi
    if protegida "$rama" && ! destino_explicito "$seg_proc"; then
      denegar "Bloqueado: estás parado en '$rama', una rama protegida, y ese push la enviaría al remoto. Usa la skill 'arranque' para mover el trabajo a una rama de funcionalidad."
    fi
  fi
  if es_git_sub "$seg_proc" commit && protegida "$rama"; then
    denegar "Bloqueado: no se commitea sobre '$rama'. Usa la skill 'arranque' para crear una rama <dev>/<tipo>/<issue>-<slug> antes de commitear."
  fi
done <<EOF
$(printf '%s' "$comando" | sed -e 's/&&/;/g' -e 's/||/;/g' -e 's/|/;/g' | tr ';\n' '\n\n')
EOF

exit 0
