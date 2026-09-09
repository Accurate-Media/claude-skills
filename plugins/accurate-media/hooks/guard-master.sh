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

# Quita de un segmento los caracteres que bash consume al ejecutar de verdad, antes
# de tokenizarlo. Se borran  $ ( ) ' " ` \  y eso neutraliza:
#   - comillas ordinarias:    git push origin 'master' / "master"
#   - paréntesis de subshell: (cd /tmp && git push origin master)
#   - backslash en un token:  git pu\sh / git push origin \master / mas\ter
#   - comillas ANSI-C:        git push origin $'master'
#   - acentos graves:         git push origin `echo master`
# Todos ellos colapsan en bash al mismo comando real, pero sobrevivirían intactos a
# una comparación de texto exacta. Quitar caracteres solo puede acercar un token al
# nombre de una rama protegida, nunca alejarlo: la normalización nunca produce un
# permiso falso. Los dos falsos negativos posibles son inofensivos porque deniegan:
#   - un ref con '$' o '`' literal que al quitarlo quede exactamente en 'master' o
#     'main' (git los admite en un nombre de rama, pero nadie los usa);
#   - una variable sin llaves llamada justo 'main' o 'master', escrita desnuda o
#     entre comillas dobles ('git push origin $main' y 'git push origin "$main"'
#     deniegan las dos). Sus vecinas seguras no se ven afectadas: '${main}',
#     '$main_branch' y '$MAIN' no se confunden con la rama protegida.
normalizar() { printf '%s' "$1" | tr -d "\$()'\"\`\\\\"; }

# Quita del inicio del segmento las palabras que solo envuelven al comando de verdad,
# repetidamente por si se apilan, para que el push siga viéndose como un comando git:
#   - envoltorios:        eval "git push origin master" / sudo git push origin master
#                         nohup / env / xargs / command / time git push origin master
#   - asignación previa:  GIT_DIR=x git push origin master / env FOO=1 git push ...
#   - palabras clave:     if ...; then git push; fi   /   while ...; do git commit; done
#                         if ...; else git push; fi
#   - apertura de grupo:  { git push; }
#   - shell explícito:    bash -c "git push origin master" / sh -exc "..." / bash -lc "..."
#   - ruta al envoltorio: /bin/bash -c "..." / /usr/bin/sudo git push origin master
#                         (se compara el último componente de la ruta)
# Consumida ya una palabra envolvente, las banderas del propio envoltorio dejan de ser
# parte del comando envuelto y se saltan: '-c', '-lc', '-exc', '--', '-i'...
# Para el puñado corto y fijo de banderas que se llevan un valor aparte —y solo para el
# envoltorio que las define: 'sudo -u <user>', 'xargs -n <n>', 'env -u <var>'— se salta
# también el token siguiente. No es un parser de opciones: es una lista literal.
# Queda fuera de esa lista, a propósito, 'env -S' ('--split-string'): a diferencia de
# '-u <var>' o '-n <n>', su valor no es un nombre suelto sino una línea de comando
# completa ('env -S "git push origin master"'), y saltársela como si fuera un valor
# cualquiera escondería el 'git' que el hook busca. Es la misma razón por la que '-c'
# queda fuera de la lista de bash/sh/zsh/dash/ksh.
# '(' no hace falta en esta lista: normalizar() ya lo borra antes de llegar aquí.
# Queda fuera, y es deliberado, el envoltorio que se lleva su propio argumento sin
# bandera que lo anuncie ('timeout 5 git push origin master'): saltarlo exigiría saber
# cuántos argumentos consume cada programa, que es justo el parser que este hook no
# quiere ser.
# Dirección del error: 'git' NO está en la lista, así que un segmento que ya empieza
# por 'git ' rompe el bucle en la primera vuelta y sale intacto. Quitar palabras solo
# puede destapar un comando git que antes quedaba oculto: nunca esconde uno.
quitar_envoltura() {
  local s primer resto envuelto=0 con_valor=""
  s="$(printf '%s' "$1" | sed 's/^[[:space:]]*//')"
  while :; do
    case "$s" in
      *' '*) primer="${s%% *}"; resto="${s#* }" ;;
      *) break ;;
    esac

    # banderas del envoltorio ya consumido
    if [ "$envuelto" -eq 1 ]; then
      case "$primer" in
        -*)
          s="$resto"
          case " $con_valor " in
            *" $primer "*)
              case "$s" in
                *' '*) s="${s#* }" ;;
                *)     s="" ;;
              esac
              ;;
          esac
          continue
          ;;
      esac
    fi

    # prefijo de asignación: se comprueba sobre el token crudo, porque su valor puede
    # ser una ruta ('GIT_DIR=/tmp/x') y quedarse con el último componente lo escondería.
    case "$primer" in
      *=*) envuelto=1; con_valor=""; s="$resto"; continue ;;
    esac

    case "${primer##*/}" in
      eval|command|time)           envuelto=1; con_valor=""; s="$resto" ;;
      nohup)                       envuelto=1; con_valor=""; s="$resto" ;;
      sudo)                        envuelto=1; con_valor="-u -g -p -C -D -R -T -h"; s="$resto" ;;
      env)                         envuelto=1; con_valor="-u -C"; s="$resto" ;;
      xargs)                       envuelto=1; con_valor="-n -I -i -P -d -L -s -E -a"; s="$resto" ;;
      then|do|else|'{')            envuelto=1; con_valor=""; s="$resto" ;;
      bash|sh|zsh|dash|ksh)        envuelto=1; con_valor="-o"; s="$resto" ;;
      *) break ;;
    esac
  done
  printf '%s' "$s"
}

# NOTA DE ALCANCE (leer antes de "arreglar" un bypass).
# Este hook para accidentes y descuidos, no a un dev decidido a esquivarlo. La
# detección es léxica —borrar unos caracteres del segmento y comparar tokens sueltos—,
# no un parser de shell. Por eso estas grafías, que rehacen el nombre de la rama sin
# escribirlo literal, quedan fuera a propósito:
#   - expansión de llaves:        git push origin mas{ter,} / ma{s..s}ter
#   - escapes hexadecimales:      git push origin $'\x6daster' / ma$'\x73'ter
#   - sustitución sin el nombre:  git push origin $(rama_actual) / `rama_actual`
#   - envoltorio que se come su propio argumento: timeout 5 git push origin master
# Ninguna de esas formas se teclea sin intención inequívoca. Perseguirlas una a una
# es una carrera que no se gana dentro de un hook cuyo contrato es degradar
# permitiendo: cada metacarácter nuevo sería otro parche. Y no vale la recíproca:
# escribir 'master' literal tampoco garantiza que se detecte, porque solo se examinan
# los segmentos que, ya normalizados y sin envoltura, empiezan por 'git '.
# En la dirección contraria —denegar de más— el separador de segmentos es tosco a
# propósito: parte por ';', '&' y '|' aunque vengan dentro de una cadena entrecomillada,
# así que 'echo "build & git push origin master"' se deniega sin empujar nada. Es un
# falso rojo raro, visible al instante y fácil de sortear (parte el comando en dos), y
# el intercambio va en la dirección segura.
# La defensa de verdad es la protección de rama de GitHub sobre master; este hook es el
# aviso local rápido que va por delante de ella.

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

# Devuelve los argumentos que siguen al subcomando 'push' en un segmento que ya se sabe
# que es un push. Tokeniza en vez de recortar con '${seg#*push}': ese recorte se queda
# con lo que va tras el PRIMER 'push' literal de la cadena, que puede ser el de una
# bandera global ('git -c push.default=simple push') y dejaba el subcomando de verdad
# contado como si fuera un destino.
args_tras_push() {
  local t saltar=0 visto=0 salida=""
  for t in ${1#git}; do
    if [ "$visto" -eq 1 ]; then salida="$salida $t"; continue; fi
    if [ "$saltar" -eq 1 ]; then saltar=0; continue; fi
    case "$t" in
      -C|-c)   saltar=1 ;;
      -*)      continue ;;
      push)    visto=1 ;;
      *)       break ;;
    esac
  done
  printf '%s' "$salida"
}

# ¿hay un destino explícito, y distinto de la rama actual, tras el remoto?
# (1er token libre = remoto, 2º y siguientes = refspecs)
# 'HEAD' y '@' son sinónimos de "la rama en la que estoy parado": 'git push origin HEAD'
# parado en master empuja master exactamente igual que 'git push' a secas, así que NO
# cuenta como destino explícito y el push cae en la comprobación de rama protegida. Sí
# cuenta 'HEAD:otra-rama', que nombra un destino distinto del actual y es legítimo
# incluso desde master.
destino_explicito() {
  local t dst vistos=0
  for t in $(args_tras_push "$1"); do
    case "$t" in -*) continue ;; esac
    vistos=$((vistos + 1))
    [ "$vistos" -lt 2 ] && continue
    t="${t#+}"
    case "$t" in
      *:*) dst="${t#*:}"; dst="${dst#+}"; dst="${dst#refs/heads/}" ;;
      *)   dst="$t" ;;
    esac
    case "$dst" in
      HEAD|@) continue ;;
      *)      return 0 ;;
    esac
  done
  return 1
}

payload="$(cat)" || exit 0
comando="$(printf '%s' "$payload" | extraer_comando)" || exit 0
[ -z "$comando" ] && exit 0

rama="$(rama_actual)"

# bash trata 'backslash + salto de línea' como continuación de la MISMA línea, no
# como dos comandos. Hay que unirlas ANTES de partir por separadores; si no,
# 'git push origin \' + 'master' se veía como un push sin destino y una palabra
# suelta, y ninguno de los dos segmentos disparaba nada.
# Se une con expansión de parámetros de bash en vez de con sed a propósito: el
# idioma habitual (sed -e :a -e '/\\$/N; s/\\\n//; ta') ejecuta 'N' también en la
# última línea, y el sed de BSD (macOS) ante EOF pendiente aborta SIN imprimir; un
# comando terminado en backslash ('git push origin master \') salía vacío y el hook
# lo permitía. La expansión de bash no puede fallar ni necesita proceso externo.
comando="${comando//\\$'\n'/}"

# Evalúa cada segmento: 'cd x && git push origin master' no se cuela.
# El '&' suelto también separa ('npm run build & git push origin master'). Va DESPUÉS
# de '&&' a propósito: '&&' ya se convirtió en ';' y no queda ningún '&' suyo que
# volver a procesar. Partir de más nunca esconde un token: cada trozo se revisa igual,
# y un '&' dentro de un token es justo donde bash también partiría.
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
      denegar "Bloqueado: estás parado en '$rama', una rama protegida, y ese push la enviaría al remoto ('HEAD' y '@' son la rama actual, no un destino distinto). Usa la skill 'arranque' para mover el trabajo a una rama de funcionalidad."
    fi
  fi
  if es_git_sub "$seg_proc" commit && protegida "$rama"; then
    denegar "Bloqueado: no se commitea sobre '$rama'. Usa la skill 'arranque' para crear una rama <dev>/<tipo>/<issue>-<slug> antes de commitear."
  fi
done <<EOF
$(printf '%s' "$comando" | sed -e 's/&&/;/g' -e 's/&/;/g' -e 's/||/;/g' -e 's/|/;/g' | tr ';\n' '\n\n')
EOF

exit 0
