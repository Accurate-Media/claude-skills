# Diseño — Reestructuración del marketplace `accurate-media`

- **Fecha:** 2026-09-08
- **Estado:** Aprobado (pendiente de plan de implementación)
- **Repositorio:** `Accurate-Media/claude-skills`

## 1. Contexto

El marketplace hoy distribuye dos plugins (`normas`, `cierre`) con una skill cada uno. El contenido es
sólido, pero el análisis previo detectó cinco problemas:

1. **Duplicación de la política de Git** entre `normas §5` y `cierre`. Dos fuentes para la misma regla:
   se desincronizan al primer cambio.
2. **La regla crítica vive solo en prosa.** "JAMÁS push a master" depende de que el modelo obedezca una
   instrucción en lenguaje natural. No hay nada determinista que lo impida.
3. **Doble anidamiento redundante** en las rutas (`accurate-media-marketplace/plugins/X/skills/X/`).
4. **Sin README ni `.gitignore`.** Nadie del equipo sabe cómo instalar el marketplace.
5. **Ningún plugin usa `hooks/`, `commands/` ni `agents/`.** Se aprovecha un tercio de lo que un plugin puede hacer.

Además, el equipo cambia de modelo de ramas y quiere tres skills nuevas.

## 2. Objetivo

Un único plugin instalable en un comando que cubra el ciclo completo de una sesión de trabajo
—arranque, desarrollo, pruebas, cierre— con la política de ramas como fuente única y aplicada por un
hook, no por prosa.

## 3. Decisiones tomadas

| # | Decisión | Por qué |
|---|---|---|
| D1 | **Un solo plugin** `accurate-media` con las 5 skills | Es la única forma de tener `git.md` como fuente única: ningún plugin puede leer con fiabilidad archivos de otro. Marketplace interno donde todos instalan todo, así que la granularidad no aporta. |
| D2 | **Trunk-based:** rama de funcionalidad → PR → `master` | Decisión del equipo. Desaparecen `dev` y `release`. |
| D3 | **Push directo a master bloqueado por hook** `PreToolUse` | Determinista. La prosa se puede racionalizar; un exit code no. |
| D4 | **Rama:** `<dev>/<tipo>/<issue>-<slug>` | El equipo quiere identificar al autor desde el nombre de la rama. |
| D5 | **Título del PR:** `<tipo>(<alcance>): <descripción> — <dev>` | El dev pidió su nombre también en el PR. Se coloca como **sufijo** para que el prefijo Conventional sobreviva al squash-merge: el commit que aterriza en `master` sigue parseando para commitlint y changelogs. |
| D6 | **Un worktree por sesión**, hermano del repo | Aísla sesiones concurrentes. Fuera del árbol de trabajo para no ensuciar búsquedas ni requerir gitignore interno. |
| D7 | **Solo el scratch es efímero** | `docs/bitacora/` y `docs/adr/` se commitean: son la memoria del equipo. Se borran únicamente reportes y `.md` sueltos generados por Claude durante la sesión. |
| D8 | **JavaScript/JSX, sin TypeScript** | Es lo que reflejan las referencias actuales. No se introduce una migración que nadie pidió. |

## 4. Estructura destino

```
claude-skills/
├── .claude-plugin/marketplace.json      # una sola entrada de plugin
├── .gitignore                            # .DS_Store, *-worktrees/
├── README.md                             # instalación y catálogo de skills
└── plugins/
    └── accurate-media/
        ├── .claude-plugin/plugin.json
        ├── hooks/
        │   ├── hooks.json
        │   └── guard-master.sh
        └── skills/
            ├── normas/
            │   ├── SKILL.md
            │   └── references/{frontend.md, backend.md, git.md}
            ├── arranque/
            │   └── SKILL.md
            ├── feature/
            │   ├── SKILL.md
            │   └── references/{frontend-scaffold.md, backend-scaffold.md}
            ├── pruebas/
            │   ├── SKILL.md
            │   └── references/{frontend.md, backend.md}
            └── cierre/
                ├── SKILL.md
                └── assets/{plantilla-bitacora.md, plantilla-adr.md, plantilla-pr.md}
```

Migración de rutas: `accurate-media-marketplace/plugins/<X>/skills/<X>/` → `plugins/accurate-media/skills/<X>/`.
Se usa `git mv` para preservar el historial.

## 5. Componente: hook `guard-master`

### Registro

`hooks/hooks.json` registra un `PreToolUse` con matcher `Bash` que ejecuta
`${CLAUDE_PLUGIN_ROOT}/hooks/guard-master.sh`.

### Contrato

- **Entrada:** JSON por stdin; el comando está en `.tool_input.command`.
- **Salida al denegar:** JSON en stdout con
  `hookSpecificOutput.permissionDecision = "deny"` y un `permissionDecisionReason` que explique la
  regla y la salida (invocar `arranque` para crear una rama de funcionalidad).
- **Salida al permitir:** exit 0 sin salida.
- **Ante cualquier error interno** (git no disponible, JSON malformado, `jq` ausente): **permitir**
  y no romper la sesión. Un guardarraíl que rompe el flujo se acaba desactivando.

### Reglas

| Comando | Veredicto |
|---|---|
| `git push` con `HEAD` en `master`/`main` | denegar |
| `git push origin master` / `git push origin main` | denegar |
| `git push origin HEAD:master` / `... HEAD:refs/heads/master` | denegar |
| `git push -u origin master` / `--set-upstream origin main` | denegar |
| `git commit …` con `HEAD` en `master`/`main` | denegar |
| `git push -u origin noel/feat/42-impuestos` | permitir |
| `git switch master`, `git fetch`, `git log master`, `git diff master` | permitir |
| Cualquier comando que no sea `git push` / `git commit` | permitir |

Notas de implementación:

- La detección debe partir el comando por `&&`, `;` y `|` y evaluar **cada** segmento: un
  `cd x && git push origin master` no puede colarse.
- La rama actual se obtiene con `git rev-parse --abbrev-ref HEAD` ejecutado en el directorio de trabajo
  de la sesión.
- No se bloquea `git merge` local ni `--force` sobre ramas propias: fuera de alcance, la branch
  protection de GitHub es la segunda línea de defensa y el README la recomienda explícitamente.

## 6. Componente: convención de nombres

**Identidad del dev.** Se lee de `git config --global accuratemedia.dev`. Si no existe, `arranque` la
pregunta una vez y la persiste con `git config --global`. No se deriva de `user.name` porque valores
como `NOEL318` producen nombres de rama pobres.

**Rama:** `<dev>/<tipo>/<issue>-<slug>`
- `<tipo>` ∈ `feat | fix | docs | style | refactor | test | chore` (los de Conventional Commits)
- `<slug>`: descripción en kebab-case, ~4 palabras máximo
- Ejemplo: `noel/feat/42-calculo-impuestos`
- Si no hay issue asociado, se omite el número: `noel/refactor/extraer-adaptadores`

**Commit:** Conventional Commits sin cambios respecto a hoy, enlazando el issue en el cuerpo.

**Título del PR:** `<tipo>(<alcance>): <descripción> — <dev>`
- Ejemplo: `feat(cart): agrega cálculo de impuestos por región — noel`

**Cuerpo del PR:** la plantilla añade un campo `**Dev:** <dev>` y su checklist se actualiza a
trunk-based (la línea "la rama destino es dev o release" pasa a "la rama destino es `master` vía PR").

## 7. Componente: ciclo de vida del worktree

### Creación (`arranque`)

1. Verificar que se está dentro del repositorio y que el árbol está limpio.
2. `git fetch origin` y sincronizar la referencia local de `master`.
3. Resolver el issue: `gh issue list` / `gh issue view <n>`. Si el dev no lo sabe, ayudarle a elegirlo.
4. Resolver `<dev>` (ver §6); preguntarlo y persistirlo si falta.
5. Crear worktree y rama en un paso, desde `origin/master`:
   - Preferir el soporte nativo del harness cuando esté disponible.
   - Fallback: `git worktree add ../<repo>-worktrees/<dev>-<tipo>-<slug> -b <dev>/<tipo>/<issue>-<slug> origin/master`
6. Cargar contexto: cuerpo del issue, archivos relacionados, y la skill `normas`.
7. Reportar en una línea: rama, ruta del worktree, issue.

### Destrucción (`cierre`, paso final)

Se ejecuta **solo** cuando se cumplen todas estas condiciones:

- el push terminó con éxito, y
- `gh pr create` devolvió una URL de PR, y
- el dev confirma que quiere cerrar (puede querer seguir trabajando).

Secuencia: salir del worktree (el cwd no puede estar dentro) → `git worktree remove <path>` →
reportar. **La rama local no se borra sin confirmación explícita**; ya vive en el remoto.

Si el push o el PR fallaron, el worktree **se conserva** y se avisa al dev. Perder trabajo por limpiar
demasiado pronto es el peor fallo posible de esta skill.

## 8. Las cinco skills

| Skill | Responsabilidad | Disparadores |
|---|---|---|
| `normas` | **Qué** escribir: nombres, Clean Code, capas, adaptador, dependencias | Siempre que se escriba, edite o revise código |
| `arranque` | Abrir sesión: issue, sincronización, rama, worktree, contexto | "empecemos", "voy a trabajar en el issue N", "arranca" |
| `feature` | Esqueleto de una feature respetando las capas | "crea la feature X", "necesito un CRUD de Y" |
| `pruebas` | Cómo probar: Vitest + RTL, JUnit 5 + Mockito + Testcontainers | "escribe pruebas", "cubre esto con tests" |
| `cierre` | Cerrar sesión: scratch, tests, docs, commit, PR, worktree | "ya terminé", "cierra la sesión", "commit y PR" |

Cada `SKILL.md` lleva un frontmatter mínimo (`name` + `description`), sin comentarios YAML sueltos, y
con la `description` recortada respecto a las actuales (786 y 798 caracteres) manteniendo los
disparadores en español que hoy funcionan.

### Contenido de `feature`

Genera el esqueleto completo de una capa vertical y lo deja compilando, sin lógica inventada:

- **Frontend:** `useCases/<f>/<accion>.js` → `hooks/use<F>.js` → `components/common/<F>*.jsx` →
  `adapters/<f>Adapter.js` → entrada en `pages/` si aplica.
- **Backend:** `<F>Controller` → `<F>Service` + `<F>ServiceImpl` → `<F>Repository` → `<F>` (`@Document`)
  → `dto/{<F>Response, Create<F>Request}` → `<F>Mapper`.

Cada archivo generado incluye el esqueleto de su prueba correspondiente, delegando el detalle a `pruebas`.

### Contenido de `pruebas`

Absorbe lo que hoy está disperso: la sección "Pruebas" de `normas/references/frontend.md`, la de
`backend.md`, y el paso 3 de `cierre`. Cubre qué se prueba y qué no (lógica sí, UI presentacional pura
no), la exigencia de camino feliz + al menos un caso de borde, y los comandos (`npm run test`,
`./gradlew test`).

## 9. Migración del contenido existente

| Contenido | Origen | Destino |
|---|---|---|
| Política de ramas / commits / PR | `normas/SKILL.md §5` **y** `cierre/SKILL.md` (duplicado) | `normas/references/git.md` — fuente única; ambas skills la citan |
| Secciones "Pruebas" | `references/frontend.md`, `references/backend.md`, `cierre` paso 3 | skill `pruebas` |
| Nota "no existe manual previo de backend, es una propuesta" | `backend.md:3` | **eliminada**: las convenciones quedan vigentes |
| `#prettier-ignore` en el frontmatter | `normas/SKILL.md` | eliminado |
| Referencias a `dev` / `release` | `normas §5`, `cierre` pasos 2 y 6, `plantilla-pr.md` | reescritas a trunk-based (`master` vía PR) |

Todo el contenido técnico sustantivo (tablas de convenciones, ejemplos de código, arquitectura por
capas, patrón adaptador) se conserva sin cambios de fondo.

## 10. Verificación

1. **Tests del hook.** Un archivo de pruebas en bash con un caso por fila de la tabla de §5,
   alimentando el script con payloads JSON de ejemplo y comprobando la decisión. Incluye los casos de
   comando compuesto (`cd x && git push origin master`) y el de degradación segura (sin `jq` → permite).
2. **Validación de manifiestos.** `marketplace.json` y `plugin.json` parsean y las rutas `source`
   resuelven.
3. **Prueba de humo.** Instalar el marketplace desde la copia local, comprobar que las cinco skills
   aparecen y que el hook deniega un `git push` sobre master de verdad.
4. **Revisión de disparadores.** Cada `description` se contrasta con las frases reales que el equipo usa.

## 11. Fuera de alcance

Decidido explícitamente, no es un olvido:

- Paso de lint/format (ESLint/Prettier, Spotless) en `cierre`.
- Skill `revision` para revisar PRs contra las normas.
- Migración a TypeScript.
- Bloqueo de `git merge` local o de `--force`.

## 12. Riesgos

| Riesgo | Mitigación |
|---|---|
| El hook borra o bloquea trabajo legítimo | Degradación segura ante cualquier error; la lista de comandos permitidos se prueba explícitamente |
| `cierre` elimina un worktree con trabajo sin subir | Tres condiciones obligatorias antes de borrar; si algo falla, se conserva y se avisa |
| La limpieza de scratch borra un `.md` que sí importaba | Solo alcanza archivos generados en la sesión y fuera de `docs/`; se lista al dev qué se va a borrar antes de hacerlo |
| El hook solo protege a quien instala el plugin | El README recomienda branch protection en GitHub como línea de defensa real |
