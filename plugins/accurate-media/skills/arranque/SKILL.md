---
name: arranque
description: Ritual de inicio de sesión de trabajo en Accurate Media. Úsala cuando el dev vaya a empezar a trabajar - "arranca", "empecemos", "voy a trabajar en el issue 42", "nueva feature", "prepárame el entorno", "vamos a arreglar el bug X". Sincroniza master, resuelve el issue en GitHub, crea la rama con la convención del equipo (dev/tipo/issue-slug) dentro de un worktree aislado para la sesión, y carga el contexto del trabajo. Es la puerta de entrada del ciclo - sin ella no hay rama válida y el hook guard-master bloqueará el primer commit.
---

# Arranque de sesión

Esta skill prepara el terreno antes de escribir una sola línea de código: repositorio sincronizado,
issue identificado, identidad del dev resuelta, rama con el nombre correcto y un worktree aislado
donde trabajar la sesión.

Ejecuta los pasos **en orden**. Cada uno depende del anterior.

## Paso 1 — Estado limpio

```bash
git status
```

Si hay cambios sin commitear, **para**: pregunta al dev si los guarda (`git stash`) o los descarta. No
arranques una sesión nueva encima de trabajo a medias.

## Paso 2 — Sincronizar

```bash
git fetch origin
```

Actualiza la referencia local de `master`. La rama nueva sale de `origin/master`, no del `master`
local, que puede estar atrasado.

## Paso 3 — Resolver el issue

```bash
gh issue list --limit 20
```

para mostrar los abiertos, y

```bash
gh issue view <n>
```

para leer el elegido. Si `gh` no está autenticado, pide al dev el número del issue y su título
directamente. Si el trabajo no tiene issue asociado, dilo explícitamente y sigue sin él — la rama
omite el número.

## Paso 4 — Resolver la identidad del dev

```bash
git config --global accuratemedia.dev
```

Si está vacío, pregunta al dev su identificador (minúsculas, sin espacios, ej. `noel`) y guárdalo:

```bash
git config --global accuratemedia.dev <valor>
```

No lo derives de `git config user.name`: valores como `NOEL318` producen nombres de rama pobres.

## Paso 5 — Componer el nombre de la rama

```
<dev>/<tipo>/<issue>-<slug>
```

según la convención de `../normas/references/git.md`. Confirma el nombre propuesto con el dev antes de
crear nada.

## Paso 6 — Crear el worktree y la rama

Prefiere el soporte nativo de worktrees del harness si está disponible. Si no, usa Git directamente:

```bash
git worktree add ../<repo>-worktrees/<dev>-<tipo>-<slug> -b <dev>/<tipo>/<issue>-<slug> origin/master
```

El worktree es **hermano** del repositorio, no va dentro: así no ensucia búsquedas ni necesita
entradas en `.gitignore` del árbol de trabajo.

### Si el proyecto son varios repos dentro de una carpeta

Algunos proyectos son una carpeta que es **a su vez un repo git** y contiene otros repos
independientes anidados (backend, frontend, gateway…). Ahí «hermano del repositorio» se vuelve
ambiguo: un hermano del subrepo cae **dentro** del repo contenedor, que es justo lo que la regla
evita. En ese caso el worktree va hermano de la **carpeta raíz**:

```bash
# proyecto en ~/REPOS/PROY, con ~/REPOS/PROY/back y ~/REPOS/PROY/front dentro
git -C ~/REPOS/PROY/back worktree add \
    ~/REPOS/PROY-wt/back-<dev>-<tipo>-<slug> \
    -b <dev>/<tipo>/<issue>-<slug> origin/master
```

**Y arranca la sesión en la carpeta raíz, no dentro de un worktree.** Una sesión que empieza dentro de
un worktree queda aislada a él: el harness le deniega toda operación git sobre cualquier otro repo
—`git -C`, `cd` y hasta desactivar el sandbox— así que no podrá crear ni leer el worktree del otro
repo, y un trabajo que toque backend y frontend se queda a medias. Desde la raíz sí funciona, porque
los subrepos cuentan como anidados.

Si el trabajo abarca dos repos, son **dos ramas y dos Pull Requests**, uno por repo, y hay que decidir
el orden de despliegue: normalmente el backend primero, o el frontend queda hablando con una API que
todavía no existe.

Nota sobre el hook `guard-master`: bloquea el commit y el push directos sobre `master`, y por eso
importa arrancar siempre con una rama de funcionalidad ya creada. Su detección es léxica —un dev
decidido a saltársela puede evadirla—; la defensa real es la *branch protection* de GitHub sobre
`master`, no este hook.

## Paso 7 — Cargar contexto

Lee el cuerpo del issue, localiza los archivos que probablemente se toquen, y carga la skill `normas`.
Si el trabajo es una feature nueva, sugiere la skill `feature` para el andamiaje.

## Paso 8 — Reportar

Confirma al dev en una línea: rama creada, ruta del worktree, issue enlazado.

---

## Resumen del flujo

```
estado limpio → fetch → issue → identidad del dev → nombre de rama → worktree + rama → contexto → reporte
```

Al terminar la sesión, la skill `cierre` desmonta el worktree creado aquí.
