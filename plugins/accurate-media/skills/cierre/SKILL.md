---
name: cierre
description: Ritual de cierre de sesión de trabajo en Accurate Media. Úsala cuando el dev indique que terminó - "cierra la sesión", "ya terminé", "haz el cierre", "commit y PR", "deja todo listo", "documenta y sube los cambios". Recorre en orden - limpiar los archivos de scratch, correr las pruebas, generar la bitácora y el ADR si hubo decisiones, commitear con Conventional Commits enlazando el issue, abrir el Pull Request hacia master con el nombre del dev en el título, y desmontar el worktree de la sesión. Si hay tests en rojo, trabajo sin documentar o el PR no llegó a abrirse, detiene el cierre antes de borrar nada.
---

# Cierre de sesión

Esta skill cierra una sesión de trabajo dejando todo trazado: qué se hizo, por qué, probado, commiteado
y en un Pull Request listo para revisión. El objetivo es que cualquier persona del equipo pueda
reconstruir la historia del proyecto sin preguntarle a nadie.

Ejecuta los pasos **en orden**. No saltes pasos ni los hagas en paralelo: cada uno depende del anterior.
Si un paso no puede completarse (tests rojos, rama incorrecta, trabajo sin documentar), **detente y
resuélvelo con el dev antes de continuar**. Nunca subas código a medias.

La política de ramas, commits y Pull Request vive en `../normas/references/git.md`. Esta skill la cita en
cada paso donde aplica; no la repite.

---

## Paso 1 — Reunir el contexto de la sesión

Antes de tocar nada, entiende qué pasó en esta sesión.

1. Ejecuta `git status` y `git diff --stat` para ver qué archivos cambiaron.
2. Revisa el historial de la conversación: qué tarea se trabajó, qué decisiones se tomaron y por qué,
   qué problemas surgieron. Pero el contexto de una sesión larga puede haberse comprimido: **no
   dependas solo de la conversación**. Reconstrúyelo con `git log origin/master..HEAD --oneline` y el
   diff completo de la rama.
3. Pregunta al dev (si no está claro) **a qué issue corresponde** este trabajo. Necesitas el número
   (ej. `#42`) para enlazarlo en el commit y el PR.

Si no hay cambios (`git status` limpio y sin commits por delante de `origin/master`), avísale al dev:
no hay nada que cerrar.

## Paso 2 — Limpiar el scratch

Va **antes** del commit para que no se cuele nada en él.

1. Identifica los archivos `.md` sueltos y los reportes que Claude haya generado durante la sesión (por
   ejemplo en un directorio de scratch o en la raíz del repo) que **no** pertenezcan a `docs/bitacora/`
   ni a `docs/adr/`.
2. **Lístaselos al dev y pide confirmación explícita antes de borrar nada.** Nunca borres un archivo
   que el dev haya escrito él mismo — ante la duda, pregúntale de quién es.
3. Solo entonces elimina los que confirmó.

## Paso 3 — Verificar la rama

```bash
git rev-parse --abbrev-ref HEAD
```

Debe ser una rama de funcionalidad que siga la convención de `../normas/references/git.md`. Si devuelve
`master` o `main`, **detente**: el hook `guard-master` va a denegar el commit de todos modos, aunque no
es una garantía —ver sus límites como defensa en `../normas/references/git.md`.

Y entonces **recupera el trabajo aquí mismo, sin mandarlo a empezar de cero**. Como el hook impide
commitear sobre `master`, estar parado aquí significa por construcción tener cambios *sin commitear*:
la skill `arranque` no sirve para esto —exige un árbol limpio y crea un worktree nuevo y vacío desde
`origin/master`, no mueve nada—. Acuerda con el dev el nombre de la rama según la convención de
`../normas/references/git.md` y aplica una de las dos salidas:

**a) Mover la rama en el sitio** (lo habitual: los cambios sin commitear viajan con el cambio de rama):

```bash
git switch -c <rama-nueva>
```

Si además hay commits ya hechos sobre el `master` local (`git log origin/master..master --oneline`),
la rama nueva se los lleva consigo, pero el `master` local se queda apuntando a ellos: devuélvelo a su
sitio con `git branch -f master origin/master` desde fuera de esa rama, y **confírmalo con el dev
antes de tocarlo**.

**b) Guardar, arrancar y recuperar** (si el dev quiere además el worktree aislado de la sesión):

```bash
git stash push -u -m "cierre: trabajo pendiente en master"
```

Con el árbol ya limpio, la skill `arranque` crea la rama y el worktree; una vez dentro del worktree
nuevo, el stash se recupera ahí (el stash es del repositorio, no del worktree):

```bash
git stash pop
```

Si además hay commits ya hechos sobre el `master` local (`git log origin/master..master --oneline`),
el stash y el worktree nuevo no se los llevan: siguen apuntados desde el `master` local. Devuélvelo a
su sitio con `git branch -f master origin/master` desde fuera del worktree, y **confírmalo con el dev
antes de tocarlo**.

No sigas al Paso 4 hasta que `git rev-parse --abbrev-ref HEAD` devuelva la rama de funcionalidad y
`git status` muestre los cambios donde deben estar.

## Paso 4 — Pruebas

El código no se cierra sin pruebas que demuestren que funciona. El detalle de qué se prueba, cómo se
escribe y qué comandos correr vive en la skill `pruebas`; aquí solo la exigencia:

1. Identifica la lógica nueva o modificada en esta sesión.
2. Escribe las pruebas que falten.
3. Corre la suite completa. **Todas las pruebas deben pasar.** No avances al commit con tests en rojo:
   arregla el código o la prueba y vuelve a correr.
4. **Una suite de solo `it.todo` no es una suite en verde.** Los esqueletos que genera la skill
   `feature` pasan sin ejercitar nada; si la lógica nueva solo tiene `todo`s, faltan pruebas de verdad
   (vuelve al punto 2).

Reporta brevemente al dev: cuántas pruebas corrieron y qué cubren las nuevas.

## Paso 5 — Documentación

Genera la documentación de la sesión. Hay tres piezas; usa las que apliquen.

### 5a. Bitácora de sesión (siempre)

Crea `docs/bitacora/AAAA-MM-DD-<rama-aplanada>.md` usando `assets/plantilla-bitacora.md`. **Un archivo
por sesión, no por día**: varios devs cerrando el mismo día en ramas distintas generarían conflictos de
merge constantes sobre un archivo compartido. Rellénala con lo reunido en el Paso 1; en "Decisiones"
escribe **por qué**, no solo qué.

### 5b. ADR — Architecture Decision Record (solo si hubo una decisión arquitectónica)

Si en la sesión se eligió entre alternativas con impacto duradero, crea un ADR en
`docs/adr/NNNN-titulo-corto.md` usando `assets/plantilla-adr.md`. Numéralos correlativos.

### 5c. Documentación viva afectada (si aplica)

Si los cambios alteran un README, un contrato de API, variables de entorno o pasos de instalación,
actualiza esos documentos en el mismo cierre.

## Paso 6 — Commit, push y PR

Formato del commit, título y cuerpo del PR: todo según `../normas/references/git.md`. No lo repitas aquí.

```bash
git add <archivos>
git commit -m "<tipo>(<alcance>): <descripción>" -m "<porqué>" -m "fix #<issue>"
git push -u origin <rama-actual>
gh pr create --base master --head <rama-actual> \
  --title "<tipo>(<alcance>): <descripción> — <dev>" --body-file <archivo-pr>
```

Si el trabajo no tiene issue asociado, omite el `-m "fix #<issue>"` del commit.

Construye el cuerpo del PR a partir de `assets/plantilla-pr.md`. Devuélvele al dev la URL del PR que
imprime `gh`.

Si `gh` no está autenticado o no está instalado, entrégale al dev el título y el cuerpo ya redactados
para que abra el PR a mano con base `master`. **Tú no cambias permisos ni configuración de la cuenta.**

## Paso 7 — Desmontar el worktree

Solo si se cumplen **las tres** condiciones:

1. el push terminó con éxito, **y**
2. `gh pr create` devolvió una URL de PR, **y**
3. el dev confirma que quiere cerrar (puede querer seguir trabajando en el mismo worktree).

Si falta cualquiera, **conserva el worktree** y avísale por qué. Perder trabajo por limpiar demasiado
pronto es el peor fallo posible de esta skill.

No asumas la ruta: la skill `arranque` prefiere el soporte nativo de worktrees del harness, que puede
colocarlo en otro sitio. Derívala del propio Git.

```bash
git rev-parse --show-toplevel        # ruta del worktree actual
git worktree list                    # todos los worktrees; el principal es el primero
```

```bash
cd <ruta-del-repo-principal>          # el cwd no puede estar dentro del worktree
git worktree remove <ruta-del-worktree-de-la-sesión>
```

Si el worktree lo creó el soporte nativo del harness, desmóntalo por esa misma vía; `git worktree
remove` es el camino solo cuando lo creó Git.

**No borres la rama local sin confirmación explícita**: ya vive en el remoto, pero el dev puede
quererla para seguir trabajando.

---

## Resumen del flujo

```
contexto → scratch limpio → rama válida → tests en verde → docs (bitácora + ADR)
→ commit → push → PR a master → worktree desmontado → enlace al dev
```

Cierra confirmando en una línea: rama, # de tests que pasan, archivos de doc generados, y el enlace del PR.
