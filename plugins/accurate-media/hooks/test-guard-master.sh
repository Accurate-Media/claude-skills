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

decision() { # $1 = comando -> imprime "deny" o "allow"
  local salida
  salida="$(printf '{"tool_input":{"command":"%s"}}' "$1" | "$GUARD" 2>/dev/null)"
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

# --- degradación segura ----------------------------------------------------
en_rama master
if printf 'no soy json' | "$GUARD" >/dev/null 2>&1; then
  PASADAS=$((PASADAS + 1)); printf 'ok   payload inválido no rompe\n'
else
  FALLADAS=$((FALLADAS + 1)); printf 'FALLO payload inválido devolvió exit != 0\n' >&2
fi

printf '\n%d pasadas, %d falladas\n' "$PASADAS" "$FALLADAS"
[ "$FALLADAS" -eq 0 ]
