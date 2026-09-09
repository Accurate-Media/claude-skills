#!/usr/bin/env bash
# Pruebas de guard-master.sh. Sin dependencias: bash y git.
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
GUARD="$AQUI/guard-master.sh"
PASADAS=0
FALLADAS=0

# Repo temporal donde controlamos la rama actual
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP" || exit 1
git init -q -b master .
git config user.email t@t.t
git config user.name t
git commit -q --allow-empty -m init

en_rama() {
  git switch -q "$1" 2>/dev/null || git switch -q -c "$1"
}

# El payload se arma con un codificador JSON de verdad. Con printf, un comando que
# contuviera " o \ producía JSON inválido: el hook no extraía nada, salía temprano y
# el caso reportaba "allow" sin haber ejercitado ninguna lógica. Los casos de prueba
# llevan la cadena de shell tal cual, sin escapes JSON a mano.
# python3 solo es dependencia de este arnés de desarrollo; el hook sigue sin exigirlo.
json_encode() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"; }

payload_de() { printf '{"tool_input":{"command":%s}}' "$(json_encode "$1")"; }

# Misma extracción que hace el hook, para poder comprobar el viaje de ida y vuelta.
decodificar() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.tool_input.command // empty' 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null
  fi
}

decision() { # $1 = comando -> imprime "deny" o "allow"
  local salida
  salida="$(payload_de "$1" | "$GUARD" 2>/dev/null)"
  case "$salida" in
    *'"deny"'*) printf 'deny' ;;
    *)          printf 'allow' ;;
  esac
}

verificar() { # $1 = esperado, $2 = rama, $3 = comando
  en_rama "$2"
  local real
  real="$(decision "$3")"
  if [ "$real" = "$1" ]; then
    PASADAS=$((PASADAS + 1))
    printf 'ok   [%s] %s :: %s\n' "$2" "$3" "$1"
  else
    FALLADAS=$((FALLADAS + 1))
    printf 'FALLO [%s] %s :: esperado %s, obtenido %s\n' "$2" "$3" "$1" "$real" >&2
  fi
}

# Autocomprobación del arnés: lo que el hook acaba leyendo tiene que ser byte a byte
# la cadena que el caso pretendía probar. Sin esto, un fallo de codificación puede
# hacer que toda la suite pruebe en silencio una cadena distinta de la que dice.
autoverificar() { # $1 = cadena representativa
  local obtenido
  obtenido="$(payload_de "$1" | decodificar)"
  if [ "$obtenido" = "$1" ]; then
    PASADAS=$((PASADAS + 1))
    printf 'ok   arnés: el comando llega intacto al hook\n'
  else
    FALLADAS=$((FALLADAS + 1))
    printf 'FALLO arnés: se pretendía [%s] pero el hook leería [%s]\n' "$1" "$obtenido" >&2
  fi
}

# Comilla doble, comilla simple, backslash, paréntesis y $ en una sola cadena.
autoverificar 'git commit -m "fix(cart): don'"'"'t crash \ ni $HOME"'

# Continuación de línea real: bash la une, no son dos comandos.
CONTINUACION="$(printf 'git push origin \\\nmaster')"
autoverificar "$CONTINUACION"

# --- deniega ---------------------------------------------------------------
verificar deny  master               'git push'
verificar deny  main                 'git push'
verificar deny  noel/feat/42-x       'git push origin master'
verificar deny  noel/feat/42-x       'git push origin main'
verificar deny  noel/feat/42-x       'git push origin HEAD:master'
verificar deny  noel/feat/42-x       'git push origin HEAD:refs/heads/master'
verificar deny  noel/feat/42-x       'git push -u origin master'
verificar deny  noel/feat/42-x       'git push --set-upstream origin main'
verificar deny  master               'git commit -m algo'
verificar deny  main                 'git commit --amend'
verificar deny  noel/feat/42-x       'cd /tmp && git push origin master'
verificar deny  master               'git status ; git push'

# --- permite ---------------------------------------------------------------
verificar allow noel/feat/42-x       'git push -u origin noel/feat/42-x'
verificar allow noel/feat/42-x       'git push'
verificar allow noel/feat/42-x       'git commit -m algo'
verificar allow master               'git switch noel/feat/42-x'
verificar allow master               'git fetch origin'
verificar allow master               'git log master --oneline'
verificar allow master               'git diff master'
verificar allow master               'ls -la'
verificar allow master               'npm run test'

# --- deniega: bypasses cerrados (revisión adversarial) ---------------------
verificar deny  master               'git push origin '\''master'\'''
verificar deny  master               'git push origin "master"'
verificar deny  master               'git push origin +master'
verificar deny  noel/feat/42-x       'git push origin +master'
verificar deny  noel/feat/42-x       'git push --all origin'
verificar deny  noel/feat/42-x       'git push --mirror origin'
verificar deny  noel/feat/42-x       '(cd /tmp && git push origin master)'
verificar deny  noel/feat/42-x       'eval "git push origin master"'
verificar deny  noel/feat/42-x       'git push origin $(echo master)'
verificar deny  noel/feat/42-x       'sudo git push origin master'
verificar deny  master               'git pu\sh origin master'
verificar deny  noel/feat/42-x       'git push origin \master'
verificar deny  noel/feat/42-x       'git push origin mas\ter'
verificar deny  master               "git push origin \$'master'"
verificar deny  noel/feat/42-x       "git push origin \$'master'"
verificar deny  master               'git push origin `echo master`'
verificar deny  noel/feat/42-x       'git push origin `echo master`'
verificar deny  noel/feat/42-x       "$CONTINUACION"
verificar deny  master               "$CONTINUACION"
verificar deny  noel/feat/42-x       'git push origin master \'

# --- deniega: el push escondido tras una construcción compuesta -------------
verificar deny  master               'if git diff --quiet; then git push; fi'
verificar deny  master               'if true; then git push origin master; fi'
verificar deny  noel/feat/42-x       'if true; then git push origin master; fi'
verificar deny  master               'while true; do git commit -m x; done'
verificar deny  master               '{ git push; }'
verificar deny  master               'git fetch && { git push; }'
verificar deny  noel/feat/42-x       'npm run build & git push origin master'
verificar deny  noel/feat/42-x       'git status & git push origin master'
verificar deny  noel/feat/42-x       'bash -c "git push origin master"'
verificar deny  noel/feat/42-x       'nohup git push origin master'
verificar deny  noel/feat/42-x       'GIT_DIR=x git push origin master'
verificar deny  noel/feat/42-x       'env FOO=1 git push origin master'

# --- deniega: 'HEAD'/'@' NO son un destino explícito (parado en protegida) --
# 'git push origin HEAD' es una de las grafías más habituales del push diario y
# empuja master igual que 'git push' a secas: no puede contar como destino explícito.
verificar deny  master               'git push origin HEAD'
verificar deny  main                 'git push origin HEAD'
verificar deny  master               'git push -u origin HEAD'
verificar deny  master               'git push origin @'
verificar deny  master               'git push origin +HEAD'
verificar deny  master               'git push --force origin HEAD'
verificar deny  master               'git push origin HEAD HEAD'

# --- deniega: el subcomando 'push' no se busca por texto suelto -------------
# '-c push.default=simple' contiene la palabra 'push' antes que el subcomando.
verificar deny  master               'git -c push.default=simple push'
verificar deny  master               'git -c push.default=current push origin HEAD'
verificar deny  noel/feat/42-x       'git -c push.default=simple push origin master'

# --- deniega: envoltorios con opciones --------------------------------------
verificar deny  noel/feat/42-x       'bash -lc "git push origin master"'
verificar deny  noel/feat/42-x       '/bin/bash -c "git push origin master"'
verificar deny  noel/feat/42-x       'sh -exc "git push origin master"'
verificar deny  noel/feat/42-x       'bash -c -- "git push origin master"'
verificar deny  noel/feat/42-x       'sudo -u noel git push origin master'
verificar deny  noel/feat/42-x       '/usr/bin/sudo git push origin master'
verificar deny  noel/feat/42-x       'env -i git push origin master'
verificar deny  noel/feat/42-x       'xargs -n 1 git push origin master'
verificar deny  master               'bash -lc "git push"'

# --- permite: contra el sobrebloqueo de la normalización --------------------
verificar allow noel/feat/42-x       'git push origin '\''noel/feat/42-x'\'''
verificar allow master               'git log --all --oneline'
verificar allow master               'git push origin +noel/feat/42-x'
verificar allow noel/feat/42-x       "git push origin \$'noel/feat/42-x'"
verificar allow noel/feat/42-x       'git push origin `echo noel/feat/42-x`'
verificar allow noel/feat/42-x       'git commit -m "fix(cart): don'"'"'t crash"'
verificar allow noel/feat/42-x       'if git diff --quiet; then git push -u origin noel/feat/42-x; fi'
verificar allow noel/feat/42-x       'while true; do git commit -m x; done'
verificar allow master               'if git diff --quiet; then echo limpio; fi'
verificar allow master               'npm run build & npm run watch'
verificar allow master               'git log --oneline & true'
verificar allow master               'bash -c "npm test"'
verificar allow master               'command -v git'
verificar allow master               'nohup npm run watch'
verificar allow master               'GIT_PAGER=cat git log --oneline'
verificar allow noel/feat/42-x       'git push origin HEAD'
verificar allow noel/feat/42-x       'git push origin HEAD:otra-rama'
verificar allow master               'git push origin HEAD:otra-rama'
verificar allow master               'git push origin HEAD:refs/heads/otra-rama'
verificar allow noel/feat/42-x       'git -c push.default=simple push'
verificar allow master               'git -c push.default=simple log --oneline'
verificar allow master               'bash -lc "npm test"'
verificar allow master               'sudo -u noel npm run build'
verificar allow master               'xargs -n 1 echo hola'

# --- degradación segura ----------------------------------------------------
en_rama master
if printf 'no soy json' | "$GUARD" >/dev/null 2>&1; then
  PASADAS=$((PASADAS + 1)); printf 'ok   payload inválido no rompe\n'
else
  FALLADAS=$((FALLADAS + 1)); printf 'FALLO payload inválido devolvió exit != 0\n' >&2
fi

printf '\n%d pasadas, %d falladas\n' "$PASADAS" "$FALLADAS"
[ "$FALLADAS" -eq 0 ]
