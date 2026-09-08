# Marketplace `accurate-media` — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidar los dos plugins del marketplace en un único plugin `accurate-media` con cinco skills, y convertir la regla "nunca push a master" en un hook que la aplique de forma determinista.

**Architecture:** Un plugin (`plugins/accurate-media/`) con cinco skills que se citan entre sí, `normas/references/git.md` como fuente única de la política de ramas, y un hook `PreToolUse` sobre Bash que deniega los comandos que aterrizarían en `master`. La verificación se apoya en dos scripts de bash: `scripts/validate.sh` (integridad estructural del marketplace) y `plugins/accurate-media/hooks/test-guard-master.sh` (comportamiento del hook).

**Tech Stack:** Bash (POSIX-ish, compatible con bash 3.2 de macOS), JSON, Markdown con frontmatter YAML. Sin dependencias nuevas: `jq` y `python3` son opcionales y el hook degrada sin ellos.

**Spec:** `docs/superpowers/specs/2026-09-08-marketplace-accurate-media-design.md`

## Global Constraints

- **Ramas protegidas:** `master` y `main`. Nunca commit ni push directo sobre ellas.
- **Convención de rama:** `<dev>/<tipo>/<issue>-<slug>` — ej. `noel/feat/42-calculo-impuestos`. Sin issue: `<dev>/<tipo>/<slug>`.
- **Tipos válidos:** `feat | fix | docs | style | refactor | test | chore`.
- **Identidad del dev:** `git config --global accuratemedia.dev`. Nunca derivada de `user.name`.
- **Título de PR:** `<tipo>(<alcance>): <descripción> — <dev>`. El sufijo va al final para no romper el parseo Conventional del squash.
- **Base de todo PR:** `master`. No existen `dev` ni `release`.
- **Idioma:** todo el contenido de las skills en español. Nombres de archivo y código en inglés salvo los ya establecidos.
- **Sin dependencias nuevas:** ni npm, ni gradle, ni herramientas de test de bash (nada de `bats`).
- **Degradación del hook:** ante cualquier error interno, permitir. Un guardarraíl que rompe la sesión se acaba desinstalando.
- **`description` de cada SKILL.md:** ≤ 1024 caracteres, sin comentarios YAML sueltos en el frontmatter.
- **Historial:** los movimientos de archivos se hacen con `git mv` para preservarlo.

---

### Task 1: Estructura del repo y script de validación

Aplana el doble anidamiento, fusiona los dos plugins en uno y crea el script que verificará la integridad estructural durante todo el resto del plan.

**Files:**
- Create: `scripts/validate.sh`
- Create: `.gitignore`
- Create: `plugins/accurate-media/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Move: `accurate-media-marketplace/plugins/normas/skills/normas/` → `plugins/accurate-media/skills/normas/`
- Move: `accurate-media-marketplace/plugins/cierre/skills/cierre/` → `plugins/accurate-media/skills/cierre/`
- Delete: `accurate-media-marketplace/` (incluidos los dos `plugin.json` antiguos)

**Interfaces:**
- Consumes: nada.
- Produces: `scripts/validate.sh`, ejecutable, exit 0 si todo está bien y exit 1 listando los fallos. Todas las tareas siguientes terminan corriéndolo. Comprueba: (1) `marketplace.json` parsea, (2) cada `source` existe y contiene `.claude-plugin/plugin.json`, (3) cada `plugin.json` parsea y tiene `name`/`version`/`description`, (4) cada `skills/*/SKILL.md` tiene frontmatter con `name` y `description`, (5) el `name` del frontmatter coincide con el nombre de su carpeta, (6) la `description` mide ≤ 1024 caracteres, (7) todo `references/*.md` y `assets/*.md` citado en un SKILL.md existe en disco, (8) el frontmatter no contiene líneas de comentario.

- [ ] **Step 1: Escribir el script de validación**

Create `scripts/validate.sh`:

```bash
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
  while IFS= read -r src; do
    [ -z "$src" ] && continue
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
$(python3 -c "import json; print('\n'.join(p['source'] for p in json.load(open('$MKT'))['plugins']))" 2>/dev/null)
EOF
fi

# --- 4 a 8. cada SKILL.md ------------------------------------------------
while IFS= read -r skill; do
  [ -z "$skill" ] && continue
  dir="$(dirname "$skill")"
  carpeta="$(basename "$dir")"
  fm="$(awk 'NR==1 && $0!="---"{exit} NR>1 && /^---$/{exit} NR>1' "$skill")"

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

  [ "$FALLOS" -eq 0 ] && ok "$skill"
done <<EOF
$(find "$RAIZ/plugins" -name SKILL.md 2>/dev/null | sort)
EOF

if [ "$FALLOS" -gt 0 ]; then
  printf '\n%d fallo(s)\n' "$FALLOS" >&2
  exit 1
fi
printf '\nTodo correcto\n'
```

- [ ] **Step 2: Correr la validación y verificar que falla**

```bash
chmod +x scripts/validate.sh && ./scripts/validate.sh
```

Esperado: FALLA. `find "$RAIZ/plugins"` no encuentra nada (la carpeta `plugins/` aún no existe) y los `source` de `marketplace.json` apuntan a `./accurate-media-marketplace/...`, que sí resuelven de momento. El fallo concreto que debe aparecer es que no hay ningún SKILL.md bajo `plugins/`. Si el script pasa en verde, está mal escrito: arréglalo antes de seguir.

- [ ] **Step 3: Mover las skills a la estructura nueva**

```bash
mkdir -p plugins/accurate-media/.claude-plugin plugins/accurate-media/skills
git mv accurate-media-marketplace/plugins/normas/skills/normas plugins/accurate-media/skills/normas
git mv accurate-media-marketplace/plugins/cierre/skills/cierre plugins/accurate-media/skills/cierre
git rm -r --quiet accurate-media-marketplace
```

- [ ] **Step 4: Crear el plugin.json fusionado**

Create `plugins/accurate-media/.claude-plugin/plugin.json`:

```json
{
  "name": "accurate-media",
  "displayName": "Accurate Media — normas y flujo de trabajo",
  "version": "2.0.0",
  "description": "Estándares de programación y ciclo completo de sesión de Accurate Media: normas de código para frontend (React 19 + Vite + Shadcn) y backend (Spring Boot + MongoDB + Gradle), arranque de sesión con worktree aislado, scaffolding de features por capas, pruebas, y cierre con documentación, commit y Pull Request a master. Incluye un hook que bloquea commits y pushes directos sobre master.",
  "author": {
    "name": "Accurate Media",
    "email": "diana.ruiz@acmedia.com.mx"
  },
  "repository": "https://github.com/Accurate-Media/claude-skills",
  "license": "UNLICENSED",
  "keywords": [
    "estandares",
    "clean-code",
    "convenciones",
    "react",
    "spring-boot",
    "git",
    "conventional-commits",
    "worktree",
    "accurate-media"
  ]
}
```

- [ ] **Step 5: Reescribir marketplace.json con una sola entrada**

Replace `.claude-plugin/marketplace.json`:

```json
{
  "name": "accurate-media",
  "owner": {
    "name": "Accurate Media",
    "email": "diana.ruiz@acmedia.com.mx"
  },
  "metadata": {
    "description": "Marketplace interno de plugins de Claude Code de Accurate Media. Distribuye las skills oficiales del equipo a todos los desarrolladores de la organización.",
    "version": "2.0.0"
  },
  "plugins": [
    {
      "name": "accurate-media",
      "source": "./plugins/accurate-media",
      "description": "Normas de programación y ciclo completo de sesión de trabajo: arranque con worktree aislado, scaffolding por capas, pruebas, y cierre con documentación, commit y PR a master. Incluye un hook que bloquea commits y pushes directos sobre master.",
      "version": "2.0.0",
      "author": {
        "name": "Accurate Media",
        "email": "diana.ruiz@acmedia.com.mx"
      },
      "category": "workflow",
      "keywords": [
        "estandares",
        "clean-code",
        "convenciones",
        "react",
        "spring-boot",
        "git",
        "worktree"
      ]
    }
  ]
}
```

- [ ] **Step 6: Crear el .gitignore**

Create `.gitignore`:

```
.DS_Store
*-worktrees/
```

- [ ] **Step 7: Correr la validación y verificar que pasa**

```bash
./scripts/validate.sh
```

Esperado: **exactamente un fallo**, y que sea este:

```
FALLO: .../skills/normas/SKILL.md: el frontmatter contiene una línea de comentario
```

Es el `#prettier-ignore` que `normas/SKILL.md` todavía arrastra. Es un fallo **legítimo y esperado en esta tarea**: no lo arregles aquí, lo limpia la Task 3. Todo lo demás debe salir en verde. Si aparece cualquier otro fallo, arréglalo antes de commitear.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor(marketplace): consolida los dos plugins en 'accurate-media'" \
  -m "Aplana el doble anidamiento de rutas, fusiona los manifiestos y añade scripts/validate.sh para verificar la integridad estructural del marketplace."
```

---

### Task 2: Hook `guard-master`

La regla crítica del equipo deja de ser prosa. Esta tarea es TDD estricto: el test se escribe primero y define el contrato.

**Files:**
- Create: `plugins/accurate-media/hooks/guard-master.sh`
- Create: `plugins/accurate-media/hooks/test-guard-master.sh`
- Create: `plugins/accurate-media/hooks/hooks.json`

**Interfaces:**
- Consumes: la estructura `plugins/accurate-media/` de la Task 1.
- Produces: un hook `PreToolUse` registrado sobre `Bash`. `guard-master.sh` lee un payload JSON por stdin, saca `.tool_input.command`, y escribe en stdout un JSON con `hookSpecificOutput.permissionDecision = "deny"` cuando el comando aterrizaría en `master`/`main`. Sale con código 0 siempre. Las skills `arranque` y `cierre` mencionan este hook por su nombre.

- [ ] **Step 1: Escribir el test que falla**

Create `plugins/accurate-media/hooks/test-guard-master.sh`:

```bash
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
```

- [ ] **Step 2: Correr el test y verificar que falla**

```bash
chmod +x plugins/accurate-media/hooks/test-guard-master.sh
./plugins/accurate-media/hooks/test-guard-master.sh
```

Esperado: FALLA inmediatamente — `guard-master.sh` no existe, así que todas las llamadas devuelven `allow` y los 12 casos de `deny` fallan.

- [ ] **Step 3: Implementar el hook**

Create `plugins/accurate-media/hooks/guard-master.sh`:

```bash
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
```

- [ ] **Step 4: Correr el test y verificar que pasa**

```bash
chmod +x plugins/accurate-media/hooks/guard-master.sh
./plugins/accurate-media/hooks/test-guard-master.sh
```

Esperado: `22 pasadas, 0 falladas`, exit 0.

Si algún caso falla, arregla el **script**, no el test. El test es el contrato acordado en el spec §5.

- [ ] **Step 5: Registrar el hook**

Create `plugins/accurate-media/hooks/hooks.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/guard-master.sh"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 6: Validar y commitear**

```bash
python3 -m json.tool plugins/accurate-media/hooks/hooks.json >/dev/null && echo "hooks.json ok"
./scripts/validate.sh
git add plugins/accurate-media/hooks
git commit -m "feat(hooks): bloquea commits y pushes directos sobre master" \
  -m "PreToolUse sobre Bash. Evalua cada segmento del comando para que un 'cd x && git push origin master' no se cuele. Degrada permitiendo ante cualquier error interno."
```

---

### Task 3: `normas` — fuente única de Git y limpieza

Extrae la política de Git a su propia referencia y deja el resto de `normas` limpio.

**Files:**
- Create: `plugins/accurate-media/skills/normas/references/git.md`
- Modify: `plugins/accurate-media/skills/normas/SKILL.md`
- Modify: `plugins/accurate-media/skills/normas/references/backend.md`
- Modify: `plugins/accurate-media/skills/normas/references/frontend.md`

**Interfaces:**
- Consumes: la estructura de la Task 1, el nombre del hook de la Task 2.
- Produces: `references/git.md` — **la** fuente de la política de ramas. Las skills `arranque`, `feature`, `pruebas` y `cierre` la citan por esta ruta exacta y **nunca** repiten su contenido.

- [ ] **Step 1: Crear la referencia de Git**

Create `plugins/accurate-media/skills/normas/references/git.md`:

````markdown
# Normas — Git y flujo de trabajo

Fuente única de la política de ramas del equipo. Las skills `normas`, `arranque`, `feature`, `pruebas`
y `cierre` citan este archivo. **No repitas estas reglas en ningún otro sitio**: si cambian, cambian aquí.

## Modelo de ramas: trunk-based

`master` es la única rama de larga vida. Ahí vive el código que el cliente tiene desplegado en producción.

```
master ──●────────●────────●──
          ↖        ↖        ↖
       PR │     PR │     PR │
     feat/42   fix/51   feat/60
```

No existen `dev` ni `release`. Toda rama de funcionalidad sale de `origin/master` y vuelve a `master`
por Pull Request.

## Prohibiciones

- **PROHIBIDO el commit directo sobre `master` (y `main`).**
- **PROHIBIDO el push directo a `master` (y `main`).**

El hook `guard-master` del plugin `accurate-media` deniega ambos comandos automáticamente. El hook es
la primera línea de defensa, no la única: configura también *branch protection* en GitHub sobre
`master` exigiendo Pull Request y al menos una revisión.

## Nombre de la rama

```
<dev>/<tipo>/<issue>-<slug>
```

- `<dev>`: tu identificador de equipo. Sale de `git config --global accuratemedia.dev`. Si no está
  configurado, la skill `arranque` te lo pregunta una vez y lo guarda.
- `<tipo>`: `feat | fix | docs | style | refactor | test | chore`.
- `<issue>`: número del issue de GitHub. Si el trabajo no tiene issue, se omite junto con su guion.
- `<slug>`: descripción en kebab-case, cuatro palabras como mucho.

```
noel/feat/42-calculo-impuestos
diana/fix/51-refresh-token
noel/refactor/extraer-adaptadores      # sin issue
```

## Commits: Conventional Commits

```
<tipo>(<alcance>): <descripción breve en imperativo>

<cuerpo opcional explicando el porqué>

fix #<issue>
```

Tipos: `feat | fix | docs | style | refactor | test | chore`.

Las palabras clave de cierre (`fix #N`, `close #N`, `resolves #N`) hacen que GitHub cierre el issue al
mergear el PR. Úsalas cuando el trabajo completa el issue; si solo avanza, referencia con `#N` a secas.

## Pull Request

- **Base: siempre `master`.**
- **Título:** `<tipo>(<alcance>): <descripción> — <dev>`

  ```
  feat(cart): agrega cálculo de impuestos por región — noel
  ```

  El nombre del dev va como **sufijo** a propósito: así el prefijo Conventional sobrevive al
  squash-merge y el commit que aterriza en `master` sigue parseando para commitlint y changelogs.
- **Cuerpo:** resumen, issue enlazado, qué cambió, cómo se probó, checklist. La skill `cierre` lo
  construye a partir de su plantilla.

## Quién hace qué

| Momento | Skill |
|---|---|
| Crear la rama y el worktree de la sesión | `arranque` |
| Commit, push y apertura del PR | `cierre` |
````

- [ ] **Step 2: Limpiar el frontmatter y la sección 5 de normas/SKILL.md**

En `plugins/accurate-media/skills/normas/SKILL.md`:

1. Reemplaza el frontmatter completo por:

```yaml
---
name: normas
description: Estándares de programación obligatorios de Accurate Media. Úsala siempre que escribas, edites, refactorices o revises código —frontend (React 19 + Vite + Shadcn) o backend (Spring Boot + MongoDB + Gradle)—, aunque el dev no lo pida. Cubre convenciones de nombres, Clean Code (sin números mágicos, guard clauses, responsabilidad única, límites de tamaño), arquitectura por capas, patrón adaptador, política de dependencias y las reglas de Git del equipo. Si vas a generar o cambiar código y no recuerdas la convención exacta, consulta esta skill en vez de improvisar: el código del equipo debe verse como si lo hubiera escrito una sola persona.
---
```

   Sin la línea `#prettier-ignore` y sin comillas envolviendo el valor.

2. En el bloque de "lee **una** de las referencias" del encabezado, añade una tercera entrada:

```markdown
- **Git** (ramas, commits, Pull Requests): lee `references/git.md`.
```

3. Reemplaza **toda** la sección `## 5. Reglas de Git` por:

```markdown
## 5. Reglas de Git

Trunk-based: `master` es la única rama de larga vida y solo recibe código vía Pull Request. Nunca
commitees ni pushees directamente sobre `master`/`main` — el hook `guard-master` lo bloquea.

La política completa (nombre de rama, formato de commit, título y cuerpo del PR) está en
`references/git.md`. Es la fuente única: no la repitas en ningún otro sitio.

El ciclo lo ejecutan las skills `arranque` (rama + worktree) y `cierre` (commit + PR).
```

4. En la sección `## 2` y siguientes, elimina cualquier mención a `dev` o `release` como ramas destino.

- [ ] **Step 3: Quitar la nota provisional de backend.md**

En `plugins/accurate-media/skills/normas/references/backend.md`, borra el bloque de cita de las líneas 3-5:

```
> No existe manual previo de backend. Estas convenciones son una **propuesta** que replica la arquitectura
> limpia del frontend (UI nunca toca la API directo → aquí: el controller nunca toca la base de datos directo).
> Ajústenla en equipo; cuando lo hagan, fijen la decisión en un ADR.
```

Sustitúyelo por una sola línea:

```markdown
Arquitectura limpia equivalente a la del frontend: igual que la UI nunca toca la API directamente, aquí
el controller nunca toca la base de datos directamente.
```

- [ ] **Step 4: Retirar las secciones de pruebas de las referencias**

En `references/frontend.md` reemplaza la sección `## Pruebas (frontend)` completa por:

```markdown
## Pruebas

Cómo se prueba el frontend está en la skill `pruebas`. Consúltala antes de escribir tests.
```

En `references/backend.md` reemplaza la sección `## Pruebas (backend)` completa por:

```markdown
## Pruebas

Cómo se prueba el backend está en la skill `pruebas`. Consúltala antes de escribir tests.
```

(La skill `pruebas` se crea en la Task 4. Hacer el corte aquí evita dejar el contenido duplicado
temporalmente; la Task 4 lo recoge de inmediato.)

- [ ] **Step 5: Correr la validación y verificar que pasa**

```bash
./scripts/validate.sh
```

Esperado: PASA. En particular, el fallo de "el frontmatter contiene una línea de comentario" que
aparecía al final de la Task 1 debe haber desaparecido, y `references/git.md` debe aparecer como
referencia existente.

- [ ] **Step 6: Commit**

```bash
git add plugins/accurate-media/skills/normas
git commit -m "refactor(normas): extrae la política de Git a una fuente única" \
  -m "Crea references/git.md con el modelo trunk-based, la convención de rama <dev>/<tipo>/<issue>-<slug> y el título de PR con sufijo del dev. Limpia el frontmatter, retira la nota provisional de backend y delega las pruebas a la skill 'pruebas'."
```

---

### Task 4: Skill `pruebas`

Recoge el contenido de testing que las tareas anteriores dejaron huérfano.

**Files:**
- Create: `plugins/accurate-media/skills/pruebas/SKILL.md`
- Create: `plugins/accurate-media/skills/pruebas/references/frontend.md`
- Create: `plugins/accurate-media/skills/pruebas/references/backend.md`

**Interfaces:**
- Consumes: `normas/references/git.md` (Task 3) para no repetir política de ramas.
- Produces: la skill `pruebas`. Las skills `feature` y `cierre` la citan por nombre para el detalle de testing; ninguna de las dos repite comandos ni frameworks.

- [ ] **Step 1: Escribir el SKILL.md**

Create `plugins/accurate-media/skills/pruebas/SKILL.md` con este frontmatter exacto:

```yaml
---
name: pruebas
description: Cómo se prueban las cosas en Accurate Media. Úsala cuando el dev pida "escribe pruebas", "cubre esto con tests", "faltan pruebas", "añade cobertura", o antes de cerrar cualquier trabajo. Frontend: Vitest + React Testing Library sobre casos de uso, hooks y utils. Backend: JUnit 5 + Mockito para services y Testcontainers con MongoDB real para repositorios. Define qué se prueba y qué no, exige camino feliz más al menos un caso de borde, y da los comandos de cada stack. Consúltala en vez de improvisar el estilo de las pruebas.
---
```

El cuerpo debe cubrir, en este orden:

1. **Qué se prueba y qué no.** Lógica de negocio (casos de uso, hooks, services, utils) **sí**. UI puramente presentacional y configuración **no**. Si un componente tiene interacción, se prueba el comportamiento, no la implementación.
2. **La regla mínima:** toda prueba nueva cubre el camino feliz **y al menos un caso de error o borde** (input nulo, lista vacía, valor fuera de rango, recurso no encontrado).
3. **Nombres de las pruebas:** describen el comportamiento esperado, no el nombre del método.
4. **Comandos:** frontend `npm run test`; backend `./gradlew test`. Todas en verde antes de cualquier commit — lo verifica la skill `cierre`.
5. **Punteros a las referencias:** `references/frontend.md` y `references/backend.md`.

- [ ] **Step 2: Escribir la referencia de frontend**

Create `plugins/accurate-media/skills/pruebas/references/frontend.md`.

Migra el contenido de la antigua sección "Pruebas (frontend)" de `normas/references/frontend.md` y amplíalo con un ejemplo real por cada tipo:

- **Caso de uso** (función pura async): test con `vi.mock` del service, verificando la regla de negocio (ej. `getActiveProducts` filtra `stock > 0`) y el caso de error (el service lanza → el caso de uso propaga un error de dominio).
- **Hook**: `renderHook` de React Testing Library, verificando el estado inicial de carga y el estado tras la resolución.
- **Adaptador**: dado un payload crudo de la API, el adaptador devuelve la forma limpia; incluye el caso defensivo (campo `null` → valor por defecto).
- **Componente con interacción**: `render` + `userEvent`, verificando qué ve el usuario, no qué props recibió el hijo.

Cada ejemplo debe ser código completo y ejecutable, no un esqueleto.

- [ ] **Step 3: Escribir la referencia de backend**

Create `plugins/accurate-media/skills/pruebas/references/backend.md`.

Migra el contenido de la antigua sección "Pruebas (backend)" de `normas/references/backend.md` y amplíalo:

- **Service unitario**: JUnit 5 + Mockito, `@ExtendWith(MockitoExtension.class)`, repositorio mockeado. Camino feliz y excepción de dominio (`ProductNotFoundException`).
- **Repository de integración**: Testcontainers con un contenedor real de MongoDB, `@DataMongoTest` + `@Testcontainers`. Explícitamente: **no** usar Mongo embebido, está obsoleto.
- **Mapper**: prueba pura, sin Spring, incluyendo el caso defensivo (campo nulo → valor por defecto).

Cada ejemplo debe ser código Java completo y compilable, no un esqueleto.

- [ ] **Step 4: Correr la validación y verificar que pasa**

```bash
./scripts/validate.sh
```

Esperado: PASA, ahora con `plugins/accurate-media/skills/pruebas/SKILL.md` en la lista de `ok:`.

- [ ] **Step 5: Commit**

```bash
git add plugins/accurate-media/skills/pruebas
git commit -m "feat(pruebas): añade la skill de testing del equipo" \
  -m "Consolida en un solo sitio el contenido de pruebas que estaba disperso entre las referencias de normas y el paso 3 de cierre."
```

---

### Task 5: Skill `arranque`

**Files:**
- Create: `plugins/accurate-media/skills/arranque/SKILL.md`

**Interfaces:**
- Consumes: `normas/references/git.md` (Task 3) para la convención de rama; el hook de la Task 2 se menciona como red de seguridad.
- Produces: la skill `arranque`. Deja al dev dentro de un worktree en `../<repo>-worktrees/<dev>-<tipo>-<slug>` sobre la rama `<dev>/<tipo>/<issue>-<slug>`. La skill `cierre` asume esa ubicación para desmontarlo.

- [ ] **Step 1: Escribir el SKILL.md**

Create `plugins/accurate-media/skills/arranque/SKILL.md` con este frontmatter exacto:

```yaml
---
name: arranque
description: Ritual de inicio de sesión de trabajo en Accurate Media. Úsala cuando el dev vaya a empezar a trabajar - "arranca", "empecemos", "voy a trabajar en el issue 42", "nueva feature", "prepárame el entorno", "vamos a arreglar el bug X". Sincroniza master, resuelve el issue en GitHub, crea la rama con la convención del equipo (dev/tipo/issue-slug) dentro de un worktree aislado para la sesión, y carga el contexto del trabajo. Es la puerta de entrada del ciclo - sin ella no hay rama válida y el hook guard-master bloqueará el primer commit.
---
```

El cuerpo debe recorrer estos pasos **en orden**, cada uno con sus comandos exactos:

**Paso 1 — Estado limpio.** `git status`. Si hay cambios sin commitear, para: pregunta al dev si los guarda (`git stash`) o los descarta. No arranques encima de trabajo a medias.

**Paso 2 — Sincronizar.** `git fetch origin` y actualizar la referencia local de `master`. La rama nueva sale de `origin/master`, no del `master` local, que puede estar atrasado.

**Paso 3 — Resolver el issue.** `gh issue list --limit 20` para mostrar los abiertos; `gh issue view <n>` para leer el elegido. Si `gh` no está autenticado, pide al dev el número del issue y su título. Si el trabajo no tiene issue, dilo explícitamente y sigue sin él (la rama omite el número).

**Paso 4 — Resolver la identidad del dev.**

```bash
git config --global accuratemedia.dev
```

Si está vacío, pregunta al dev su identificador (minúsculas, sin espacios, ej. `noel`) y guárdalo:

```bash
git config --global accuratemedia.dev <valor>
```

No lo derives de `git config user.name`: valores como `NOEL318` producen nombres de rama pobres.

**Paso 5 — Componer el nombre de la rama.** `<dev>/<tipo>/<issue>-<slug>` según `normas/references/git.md`. Confirma el nombre propuesto con el dev antes de crear nada.

**Paso 6 — Crear el worktree y la rama.** Prefiere el soporte nativo de worktrees del harness si está disponible. Fallback:

```bash
git worktree add ../<repo>-worktrees/<dev>-<tipo>-<slug> -b <dev>/<tipo>/<issue>-<slug> origin/master
```

El worktree es **hermano** del repositorio, no va dentro: así no ensucia búsquedas ni necesita entradas en `.gitignore` del árbol de trabajo.

**Paso 7 — Cargar contexto.** Lee el cuerpo del issue, localiza los archivos que probablemente se toquen, y carga la skill `normas`. Si el trabajo es una feature nueva, sugiere la skill `feature`.

**Paso 8 — Reportar en una línea:** rama creada, ruta del worktree, issue enlazado.

Cierra el cuerpo con una sección **Resumen del flujo**:

```
estado limpio → fetch → issue → identidad del dev → nombre de rama → worktree + rama → contexto → reporte
```

Y una nota: al terminar la sesión, la skill `cierre` desmonta este worktree.

- [ ] **Step 2: Correr la validación y verificar que pasa**

```bash
./scripts/validate.sh
```

Esperado: PASA, con `arranque/SKILL.md` en la lista.

- [ ] **Step 3: Commit**

```bash
git add plugins/accurate-media/skills/arranque
git commit -m "feat(arranque): añade la skill de inicio de sesión" \
  -m "Sincroniza master, resuelve el issue, persiste la identidad del dev en git config y crea la rama dentro de un worktree aislado hermano del repo."
```

---

### Task 6: Skill `feature`

**Files:**
- Create: `plugins/accurate-media/skills/feature/SKILL.md`
- Create: `plugins/accurate-media/skills/feature/references/frontend-scaffold.md`
- Create: `plugins/accurate-media/skills/feature/references/backend-scaffold.md`

**Interfaces:**
- Consumes: la arquitectura por capas de `normas/references/{frontend,backend}.md`; los estilos de test de la skill `pruebas` (Task 4).
- Produces: la skill `feature`. No define artefactos que otras skills consuman.

- [ ] **Step 1: Escribir el SKILL.md**

Create `plugins/accurate-media/skills/feature/SKILL.md` con este frontmatter exacto:

```yaml
---
name: feature
description: Genera el esqueleto de una feature nueva respetando la arquitectura por capas de Accurate Media. Úsala cuando el dev pida "crea la feature X", "necesito un CRUD de Y", "arma la pantalla de Z", "añade el endpoint de W" o "monta el módulo de V". En frontend crea el caso de uso, el hook, el componente y el adaptador; en backend, el controller, el service, el repository, el document, los DTOs y el mapper, cada uno con su esqueleto de prueba. No inventa lógica de negocio - deja el andamiaje completo, coherente con las normas del equipo y compilando.
---
```

El cuerpo debe cubrir:

1. **Antes de generar nada:** pregunta el nombre de la feature, si es frontend, backend o ambos, y qué operaciones necesita. Confirma la lista de archivos que vas a crear **antes** de crearlos.
2. **Regla de oro:** el andamiaje no inventa reglas de negocio. Donde vaya lógica que el dev no ha especificado, deja un `TODO` explícito con el nombre de la regla pendiente — nunca una implementación inventada que parezca correcta.
3. **Punteros:** `references/frontend-scaffold.md` y `references/backend-scaffold.md`.
4. **Al terminar:** recuerda al dev que las pruebas generadas son esqueletos y que la skill `pruebas` tiene el estilo del equipo para completarlas.

- [ ] **Step 2: Escribir el scaffold de frontend**

Create `plugins/accurate-media/skills/feature/references/frontend-scaffold.md`.

Para una feature `<f>` (kebab-case) con entidad `<F>` (PascalCase), lista los archivos en orden de dependencia y da el contenido completo de cada plantilla:

```
src/adapters/<f>Adapter.js          # cruda → limpia, con valores defensivos
src/services/<f>Service.js          # llamadas HTTP, sin lógica
src/useCases/<f>/get<F>List.js      # orquesta service + adapter, aplica reglas
src/hooks/use<F>.js                 # estado reactivo sobre el caso de uso
src/components/common/<F>Card.jsx   # presentacional, solo props
src/components/common/<F>List.jsx   # presentacional, con guard clause de carga
src/pages/<F>Page.jsx               # conecta hook y componentes
```

Y sus pruebas espejo:

```
src/adapters/<f>Adapter.test.js
src/useCases/<f>/get<F>List.test.js
src/hooks/use<F>.test.js
```

Cada plantilla debe respetar lo que ya exige `normas/references/frontend.md`: guard clauses, sin números mágicos, componentes tontos sin lógica de negocio, adaptador con reglas defensivas.

- [ ] **Step 3: Escribir el scaffold de backend**

Create `plugins/accurate-media/skills/feature/references/backend-scaffold.md`.

Para una feature `<f>` (minúsculas) con entidad `<F>` (PascalCase), bajo `com.accuratemedia.<servicio>.<f>`:

```
<F>.java                        # @Document
dto/<F>Response.java            # record
dto/Create<F>Request.java       # record con Bean Validation
<F>Mapper.java                  # Document <-> DTO, con valores defensivos
<F>Repository.java              # extends MongoRepository<<F>, String>
<F>Service.java                 # interfaz
<F>ServiceImpl.java             # implementación, inyección por constructor
<F>Controller.java              # @RestController, sin lógica de negocio
```

Y sus pruebas espejo:

```
<F>MapperTest.java
<F>ServiceImplTest.java         # JUnit 5 + Mockito
<F>RepositoryIT.java            # Testcontainers
```

Cada plantilla debe respetar `normas/references/backend.md`: inyección por constructor (nunca `@Autowired` en campo), excepciones de dominio, el controller devuelve DTOs y nunca la entidad.

- [ ] **Step 4: Correr la validación y verificar que pasa**

```bash
./scripts/validate.sh
```

Esperado: PASA, con `feature/SKILL.md` y sus dos referencias resolviendo.

- [ ] **Step 5: Commit**

```bash
git add plugins/accurate-media/skills/feature
git commit -m "feat(feature): añade la skill de scaffolding por capas" \
  -m "Genera el andamiaje vertical completo de una feature (front y back) con su esqueleto de pruebas, sin inventar lógica de negocio."
```

---

### Task 7: Reescribir `cierre`

**Files:**
- Modify: `plugins/accurate-media/skills/cierre/SKILL.md`
- Modify: `plugins/accurate-media/skills/cierre/assets/plantilla-pr.md`
- Modify: `plugins/accurate-media/skills/cierre/assets/plantilla-bitacora.md`

**Interfaces:**
- Consumes: `normas/references/git.md` (Task 3), la skill `pruebas` (Task 4), la ubicación del worktree que fija `arranque` (Task 5), el hook de la Task 2.
- Produces: el cierre del ciclo. No define artefactos que otras skills consuman.

- [ ] **Step 1: Reescribir el frontmatter**

Reemplaza el frontmatter de `plugins/accurate-media/skills/cierre/SKILL.md` por:

```yaml
---
name: cierre
description: Ritual de cierre de sesión de trabajo en Accurate Media. Úsala cuando el dev indique que terminó - "cierra la sesión", "ya terminé", "haz el cierre", "commit y PR", "deja todo listo", "documenta y sube los cambios". Recorre en orden - limpiar los archivos de scratch, correr las pruebas, generar la bitácora y el ADR si hubo decisiones, commitear con Conventional Commits enlazando el issue, abrir el Pull Request hacia master con el nombre del dev en el título, y desmontar el worktree de la sesión. Si hay tests en rojo, trabajo sin documentar o el PR no llegó a abrirse, detiene el cierre antes de borrar nada.
---
```

- [ ] **Step 2: Reescribir el cuerpo con la nueva secuencia de siete pasos**

La estructura queda así. Elimina la sección "Regla de oro" actual (su contenido vive ahora en `normas/references/git.md`) y sustitúyela por un puntero de tres líneas.

**Paso 1 — Contexto.** `git status`, `git diff --stat`, revisar la conversación, confirmar el issue. Como el contexto de sesiones largas puede haberse comprimido, **no dependas solo de la conversación**: reconstruye con `git log origin/master..HEAD --oneline` y el diff. Si no hay cambios, avisa: no hay nada que cerrar.

**Paso 2 — Limpiar el scratch.** Va **antes** del commit para que no se cuele nada.

- Identifica los `.md` sueltos y reportes que Claude generó durante la sesión y que no pertenecen a `docs/bitacora/` ni `docs/adr/`.
- **Lístaselos al dev y pide confirmación antes de borrar.** Nunca borres un archivo que el dev escribió.
- Solo entonces elimínalos.

**Paso 3 — Verificar la rama.** `git rev-parse --abbrev-ref HEAD`. Debe seguir la convención de `normas/references/git.md`. Si es `master`/`main`, para: el hook `guard-master` va a denegar el commit de todos modos. Ayuda al dev a mover el trabajo con la skill `arranque`.

**Paso 4 — Pruebas.** Delega el detalle a la skill `pruebas`: qué se prueba, cómo se escribe, qué comandos. Aquí solo la exigencia: identificar la lógica nueva o modificada, escribir lo que falte, correr la suite, **todo en verde**. No avances con tests en rojo. Reporta cuántas corrieron y qué cubren las nuevas.

**Paso 5 — Documentación.**
- **5a. Bitácora (siempre):** `docs/bitacora/AAAA-MM-DD-<rama-aplanada>.md`, usando `assets/plantilla-bitacora.md`. **Un archivo por sesión, no por día**: varios devs cerrando el mismo día en ramas distintas generarían conflictos de merge constantes sobre un archivo compartido.
- **5b. ADR (solo si hubo decisión arquitectónica):** `docs/adr/NNNN-titulo-corto.md` con `assets/plantilla-adr.md`.
- **5c. Documentación viva afectada:** README, contratos de API, variables de entorno, pasos de instalación.

**Paso 6 — Commit, push y PR.** Formato del commit, título y cuerpo del PR: todo según `normas/references/git.md`. No repitas aquí el formato.

```bash
git add <archivos>
git commit -m "<tipo>(<alcance>): <descripción>" -m "<porqué>" -m "fix #<issue>"
git push -u origin <rama-actual>
gh pr create --base master --head <rama-actual> \
  --title "<tipo>(<alcance>): <descripción> — <dev>" --body-file <archivo-pr>
```

Devuelve al dev la URL del PR. Si `gh` no está autenticado o instalado, entrégale el título y el cuerpo ya redactados para que abra el PR a mano con base `master`. **Tú no cambias permisos ni configuración de la cuenta.**

**Paso 7 — Desmontar el worktree.** Solo si se cumplen **las tres** condiciones:

1. el push terminó con éxito, **y**
2. `gh pr create` devolvió una URL de PR, **y**
3. el dev confirma que quiere cerrar (puede querer seguir trabajando).

Si falta cualquiera, **conserva el worktree** y avísale. Perder trabajo por limpiar demasiado pronto es el peor fallo posible de esta skill.

```bash
cd <ruta-del-repo-principal>          # el cwd no puede estar dentro del worktree
git worktree remove <ruta-del-worktree>
```

**No borres la rama local sin confirmación explícita**: ya vive en el remoto, pero el dev puede quererla.

Cierra el cuerpo con el resumen del flujo actualizado:

```
contexto → scratch limpio → rama válida → tests en verde → docs (bitácora + ADR)
→ commit → push → PR a master → worktree desmontado → enlace al dev
```

- [ ] **Step 3: Actualizar plantilla-pr.md**

En `plugins/accurate-media/skills/cierre/assets/plantilla-pr.md`:

1. Añade un campo de dev justo bajo el título de la sección de issue:

```markdown
**Dev:** {dev}
```

2. Reemplaza la primera línea del checklist:

```markdown
- [ ] La rama destino es `dev` o `release` (NO `master`)
```

por:

```markdown
- [ ] La rama destino es `master` y llega por Pull Request (nunca push directo)
- [ ] El nombre de la rama sigue `<dev>/<tipo>/<issue>-<slug>`
```

- [ ] **Step 4: Actualizar plantilla-bitacora.md**

En `plugins/accurate-media/skills/cierre/assets/plantilla-bitacora.md`, cambia el encabezado para reflejar que el archivo es por sesión y no por día:

```markdown
# Bitácora — {AAAA-MM-DD} · {rama}

## {hora inicio}–{hora fin} · {Nombre del dev}
```

- [ ] **Step 5: Verificar que no queda ninguna referencia a dev/release**

```bash
grep -rn --include='*.md' -E '\b(dev|release)\b' plugins/accurate-media/skills/ | grep -viE '<dev>|\{dev\}|(el|del|al|un|los|cada|ese|tu) dev|accuratemedia\.dev|dev/tipo|/dev/|dev\)'
```

Esperado: **sin resultados**. Cualquier línea que salga es una referencia al modelo de ramas viejo; corrígela.

- [ ] **Step 6: Correr la validación y verificar que pasa**

```bash
./scripts/validate.sh
```

Esperado: PASA.

- [ ] **Step 7: Commit**

```bash
git add plugins/accurate-media/skills/cierre
git commit -m "refactor(cierre): adapta el cierre a trunk-based y worktrees" \
  -m "PR hacia master con el nombre del dev en el título, limpieza de scratch antes del commit, bitácora por sesión en vez de por día, y desmontaje del worktree solo con push, PR y confirmación del dev."
```

---

### Task 8: README y verificación end-to-end

**Files:**
- Create: `README.md`
- Test: ejecución completa de `scripts/validate.sh` y `test-guard-master.sh`

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: el punto de entrada del repositorio para el resto del equipo.

- [ ] **Step 1: Escribir el README**

Create `README.md` cubriendo, en este orden:

1. **Qué es esto:** el marketplace interno de Claude Code de Accurate Media.
2. **Instalación**, con los comandos exactos:

```
/plugin marketplace add Accurate-Media/claude-skills
/plugin install accurate-media@accurate-media
```

3. **Catálogo de skills**, una tabla con las cinco: `normas`, `arranque`, `feature`, `pruebas`, `cierre`, cada una con una línea de qué hace y cuándo se dispara.
4. **El ciclo de una sesión**, en un diagrama de texto:

```
arranque  →  feature  →  (código)  →  pruebas  →  cierre
   │                                                 │
   └── rama + worktree                worktree desmontado + PR
```

5. **El hook `guard-master`:** qué bloquea, y la recomendación explícita de configurar **branch protection en GitHub** sobre `master` exigiendo Pull Request y al menos una revisión. El hook solo protege a quien instala el plugin; la branch protection protege a todos.
6. **Desarrollo del propio marketplace:** cómo correr `./scripts/validate.sh` y `./plugins/accurate-media/hooks/test-guard-master.sh`.

- [ ] **Step 2: Correr la suite completa**

```bash
./scripts/validate.sh && ./plugins/accurate-media/hooks/test-guard-master.sh
```

Esperado: ambos en verde. `Todo correcto` y `22 pasadas, 0 falladas`.

- [ ] **Step 3: Prueba de humo de instalación**

Instala el marketplace desde la copia local y comprueba a mano:

1. Las cinco skills aparecen en el listado de skills disponibles.
2. En un repositorio de prueba parado en `master`, un `git commit` es **denegado** por el hook con el mensaje que apunta a la skill `arranque`.
3. En ese mismo repositorio, sobre una rama `prueba/feat/1-x`, un `git commit` es **permitido**.

Si el punto 2 no bloquea, el hook no se está cargando: revisa que `hooks/hooks.json` esté en la raíz del plugin y que `guard-master.sh` tenga permiso de ejecución en el commit (`git ls-files -s` debe mostrar modo `100755`).

- [ ] **Step 4: Verificar los modos de ejecución en git**

```bash
git ls-files -s scripts/validate.sh plugins/accurate-media/hooks/*.sh
```

Esperado: los tres con modo `100755`. Si alguno está en `100644`:

```bash
git update-index --chmod=+x <archivo>
```

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: añade el README de instalación y catálogo del marketplace"
```

---

## Notas para quien ejecute

- **El orden importa.** La Task 3 crea `normas/references/git.md`, que las tareas 4 a 7 citan. La Task 4 crea la skill `pruebas`, que las tareas 6 y 7 citan. No las reordenes.
- **Duplicación cero.** Si al escribir una skill te descubres explicando el formato del commit, el nombre de la rama o el título del PR: para. Eso vive en `normas/references/git.md` y se cita, no se repite. El grep del paso 5 de la Task 7 existe para atrapar esto.
- **El test del hook es el contrato.** Si un caso falla, arregla `guard-master.sh`, no el test. Los 22 casos salen del spec §5.
- **Todo el contenido de las skills va en español.** Es el idioma en el que el equipo dispara las skills.
