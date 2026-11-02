# claude-skills

Marketplace interno de Claude Code de **Accurate Media**. Empaqueta las normas de programación del
equipo y el ciclo completo de una sesión de trabajo (arranque, scaffolding de features, pruebas y
cierre) como un único plugin, `accurate-media`, instalable en el Claude Code de cualquier persona del
equipo.

## Instalación

> ### ⚠️ Antes de nada: desinstala los plugins v1
>
> Este marketplace publicaba antes dos plugins sueltos, `normas@accurate-media` y
> `cierre@accurate-media`. Ya no están en el catálogo, pero `/plugin marketplace update` **no
> desinstala lo que cada quien ya tenía instalado**: las copias viejas siguen activas en tu sesión.
>
> Si no las quitas acabarás con **dos skills `cierre` que se contradicen**: la vieja abre el Pull
> Request «hacia dev o release (NUNCA hacia master)» y la nueva lo abre hacia `master`. Claude cargará
> una de las dos, y no puedes saber cuál.
>
> ```
> /plugin uninstall normas@accurate-media
> /plugin uninstall cierre@accurate-media
> ```
>
> Si nunca instalaste esos dos plugins, sáltate este paso.

Desde una sesión de Claude Code:

```
/plugin marketplace add Accurate-Media/claude-skills
/plugin install accurate-media@accurate-media
```

Si ya tenías este marketplace añadido de antes, en lugar de `add` refresca el catálogo con
`/plugin marketplace update accurate-media` y luego instala.

Con eso quedan disponibles las cinco skills, los cinco agentes y el hook de protección de `master` descritos abajo.
Comprueba con `/plugin` que en la lista de instalados solo aparece `accurate-media@accurate-media`.

## Catálogo de skills

| Skill | Qué hace | Cuándo se dispara |
|---|---|---|
| `normas` | Estándares de programación obligatorios: convenciones de nombres, Clean Code, arquitectura por capas, patrón adaptador, política de dependencias y las reglas de Git del equipo. | Siempre que se escribe, edita, refactoriza o revisa código — frontend (React 19 + Vite + Shadcn) o backend (Spring Boot + MongoDB + Gradle) —, aunque el dev no lo pida explícitamente. |
| `arranque` | Sincroniza `master`, resuelve el issue en GitHub, crea la rama con la convención del equipo dentro de un worktree aislado para la sesión, y carga el contexto del trabajo. Es la puerta de entrada del ciclo: sin ella no hay rama válida y el hook `guard-master` bloqueará el primer commit. | Cuando el dev va a empezar a trabajar — "arranca", "empecemos", "voy a trabajar en el issue 42", "nueva feature", "prepárame el entorno", "vamos a arreglar el bug X". |
| `feature` | Genera el esqueleto vertical de una feature nueva respetando la arquitectura por capas: en frontend caso de uso, hook, componente y adaptador; en backend controller, service, repository, document, DTOs y mapper, cada uno con su esqueleto de prueba. No inventa lógica de negocio. | Cuando el dev pide "crea la feature X", "necesito un CRUD de Y", "arma la pantalla de Z", "añade el endpoint de W" o "monta el módulo de V". |
| `pruebas` | Fija el estilo de pruebas del equipo: Vitest + React Testing Library en frontend sobre casos de uso, hooks y utils; JUnit 5 + Mockito y Testcontainers con MongoDB real en backend. Define qué se prueba y qué no, exige camino feliz más al menos un caso de borde. | Cuando el dev pide "escribe pruebas", "cubre esto con tests", "faltan pruebas", "añade cobertura", o antes de cerrar cualquier trabajo. |
| `cierre` | Recorre en orden: limpia los archivos de scratch, corre las pruebas, genera la bitácora y el ADR si hubo decisiones, commitea con Conventional Commits enlazando el issue, abre el Pull Request hacia `master` con el nombre del dev en el título, y desmonta el worktree de la sesión. Si hay tests en rojo, trabajo sin documentar o el PR no llegó a abrirse, detiene el cierre antes de borrar nada. | Cuando el dev indica que terminó — "cierra la sesión", "ya terminé", "haz el cierre", "commit y PR", "deja todo listo", "documenta y sube los cambios". |

## El ciclo de una sesión

```
arranque  →  feature  →  (código)  →  pruebas  →  cierre
   │                                                 │
   └── rama + worktree                worktree desmontado + PR
```

`normas` no aparece en el diagrama porque no es un paso: aplica de fondo durante todo el ciclo, cada
vez que se escribe o revisa código.

La política de ramas, commits y Pull Request que estas skills siguen vive en un único lugar:
[`plugins/accurate-media/skills/normas/references/git.md`](plugins/accurate-media/skills/normas/references/git.md).
No se repite aquí.

## Equipo de agentes

El plugin trae cinco subagentes. Quedan disponibles en cualquier repo y en cualquier sesión, así que
puedes tener varias sesiones abiertas a la vez con el equipo completo en cada una.

| Agente | Rol |
|---|---|
| `accurate-media:orquestador` | El master: descompone la tarea, fija los contratos entre capas, delega, encadena los traspasos y no da nada por terminado sin el veredicto de QA. |
| `accurate-media:backend-engineer` | Endpoints, servicios, integraciones, mensajería y seguridad del lado servidor (Spring Boot). |
| `accurate-media:db-engineer` | Esquema, migraciones Flyway sin caída (expandir/contraer), índices y consultas con `EXPLAIN`. |
| `accurate-media:frontend-engineer` | Pantallas, componentes, hooks y llamadas a la API (React 19 + Vite + Shadcn). |
| `accurate-media:qa-agent` | Revisión independiente del diff, pruebas que faltan y veredicto APROBADO / RECHAZADO con evidencia. |

**Cómo se usan entre ellos.** El orquestador es quien encadena: arráncalo como agente principal de la
sesión y él lanza a los demás (en paralelo cuando no dependen entre sí, cada uno en su worktree si
tocan el mismo repo):

```bash
claude --agent accurate-media:orquestador
```

Para que un repo arranque siempre así, pon `"agent": "accurate-media:orquestador"` en su
`.claude/settings.json`. Cada especialista termina su reporte con una sección `Traspaso` (lo que
necesita de otro agente); el orquestador la lee y lanza al siguiente. Fuera del orquestador también
puedes pedir uno directamente: «usa al db-engineer para revisar esta consulta».

**Verlos en Zoetrope.** No hay que configurar nada: [`zoe`](https://github.com/furkankly/zoetrope) lee
el transcript de la sesión y dibuja cada subagente con su nombre. Desde la carpeta del repo, `zoe`
sigue la sesión viva más reciente; `zoe <id>` abre una concreta.

### En Codex (backend y frontend)

`backend-engineer` y `frontend-engineer` también existen como roles de Codex en `codex/agents/`.
Cada quien los instala una vez desde un clon de este repo:

```bash
git clone https://github.com/Accurate-Media/claude-skills ~/REPOS/claude-skills
~/REPOS/claude-skills/scripts/instalar-codex.sh
```

El script registra los roles en `~/.codex/config.toml` (bloque marcado, con respaldo en
`config.toml.bak-accurate-media`; Codex no los descubre solo por carpeta) y enlaza las skills `normas` y
`pruebas` en `~/.codex/skills`. Apunta al clon, así que `git pull` los actualiza. Luego, en Codex:
«usa el agente backend-engineer para …». Se quita con `--desinstalar`.

Los `.toml` **se generan** desde los `.md` de `plugins/accurate-media/agents/`: edita el `.md` y corre
`./scripts/codex-agents.py`. `validate.sh` falla si quedaron desfasados.

## El hook `guard-master`

El plugin instala un hook `PreToolUse` que intercepta comandos `Bash` y deniega los que aterrizarían en
`master` o `main`. Los casos habituales que cubre —**no es la lista completa**, es la muestra de lo que
te vas a encontrar:

- `git commit` directo sobre `master` o `main`.
- `git push` cuyo destino es `master` o `main` (refspec explícito, `HEAD:master`, `+master`, etc.).
- `git push` sin destino explícito estando parado en `master` o `main`. Cuentan como «sin destino»
  `git push origin HEAD` y `git push origin @`: `HEAD` y `@` son la rama actual, no un destino
  distinto. `git push origin HEAD:otra-rama` sí nombra otro destino y se permite.
- `git push --all` y `git push --mirror` **sin importar la rama en la que estés parado**: ambos
  empujan todas las ramas locales al remoto, `master` incluida, incluso desde una rama de feature.
- Las mismas órdenes escondidas tras comillas, subshells, backslashes, `&&`/`;`/`&`, o envoltorios
  como `eval`, `sudo`, `env`, `xargs` y `bash -c`.

Es una red de seguridad rápida y local, no un parser de shell: la detección es léxica (normaliza el
comando y compara tokens), así que cubre los descuidos y los atajos habituales, pero un dev decidido a
evadirlo puede hacerlo. El propio script documenta, en su `NOTA DE ALCANCE`
(`plugins/accurate-media/hooks/guard-master.sh`), qué formas de evasión quedan deliberadamente fuera y
por qué perseguirlas una por una no es una carrera que un hook léxico pueda ganar. También puede
denegar de más en algún caso raro (una cadena que solo *menciona* `git push origin master` dentro de
un `echo`): el intercambio va a propósito en la dirección segura.

Por eso **la defensa real es la protección de rama de GitHub sobre `master`**: es obligatorio
configurarla, exigiendo Pull Request y al menos una revisión antes de mergear. El hook solo protege a
quien tiene el plugin instalado y corriendo; la protección de rama en GitHub protege a todo el equipo,
sin excepción, incluso frente a un push hecho fuera de Claude Code.

## Desarrollo del propio marketplace

Dos suites verifican la integridad del repositorio:

```bash
./scripts/validate.sh
```

Comprueba que `marketplace.json` y cada `plugin.json` son JSON válido, que cada `SKILL.md` tiene
frontmatter correcto (`name` coincidiendo con la carpeta, `description` presente y dentro del límite de
tamaño) y que las referencias que citan existen. Éxito: `Todo correcto`, exit 0.

```bash
./plugins/accurate-media/hooks/test-guard-master.sh
```

Arnés de pruebas adversarial para `guard-master.sh`: comandos que deben denegarse, comandos que deben
permitirse, y los intentos de evasión conocidos (comillas, subshells, backslashes, comillas ANSI-C,
acentos graves, envoltorios como `eval`/`sudo`/`bash -c`, etc.). Éxito: todas las líneas en `ok` y un
resumen final `99 pasadas, 0 falladas`, exit 0 (número correcto a esta fecha; sube cada vez que se
añade un caso nuevo — lo que importa es `0 falladas`, no que el primer número coincida al dígito con lo
que veas).

Corre ambas antes de dar por buena cualquier cambio en `plugins/accurate-media/`.
