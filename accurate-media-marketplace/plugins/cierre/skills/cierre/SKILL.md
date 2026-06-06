---
name: cierre
description: >-
  Ritual de cierre de sesión de trabajo para desarrolladores de Accurate Media en Claude Code.
  Úsala SIEMPRE que el dev indique que terminó o quiere cerrar: "cierra la sesión", "ya terminé",
  "haz el cierre", "documenta y sube los cambios", "deja todo listo", "commit y PR", o al final de
  cualquier jornada de trabajo sobre el repositorio. Recorre en orden: reunir el contexto de la sesión,
  verificar que NO se está en master/main, crear y correr pruebas unitarias, generar la documentación
  (bitácora + ADR si hubo decisiones), hacer el commit con Conventional Commits enlazando el issue, y
  abrir el Pull Request hacia dev o release (NUNCA hacia master). Si los cambios no están documentados,
  probados o están en la rama equivocada, esta skill lo detiene antes de subir nada.
---

# Cierre de sesión

Esta skill cierra una sesión de trabajo dejando todo trazado: qué se hizo, por qué, probado, commiteado
y en un Pull Request listo para revisión. El objetivo es que cualquier persona del equipo pueda
reconstruir la historia del proyecto sin preguntarle a nadie.

Ejecuta los pasos **en orden**. No saltes pasos ni los hagas en paralelo: cada uno depende del anterior.
Si un paso no puede completarse (tests rojos, rama incorrecta), **detente y resuélvelo con el dev antes
de continuar**. Nunca subas código a medias.

## Regla de oro (la más importante)

**JAMÁS se hace commit ni push ni PR directo a `master` (ni a `main`).** En `master` vive el código que
el cliente tiene desplegado en producción. Romperla es romperle el servicio al cliente.

- El destino de un Pull Request es `dev` o `release`, nunca `master`.
- Si al verificar la rama detectas que el dev está parado en `master`/`main`, **detente inmediatamente**,
  avísale, y ayúdale a mover su trabajo a una rama de funcionalidad antes de seguir.
- Esta skill complementa, pero no reemplaza, la *branch protection* de GitHub. Si master no está
  protegida a nivel de GitHub, recomiéndalo (ver más abajo).

---

## Paso 1 — Reunir el contexto de la sesión

Antes de tocar nada, entiende qué pasó en esta sesión.

1. Ejecuta `git status` y `git diff --stat` para ver qué archivos cambiaron.
2. Revisa el historial de la conversación: qué tarea se trabajó, qué decisiones se tomaron y por qué,
   qué problemas surgieron.
3. Pregunta al dev (si no está claro) **a qué issue corresponde** este trabajo. Los issues viven en un
   proyecto de GitHub. Necesitas el número (ej. `#42`) para enlazarlo en el commit y el PR.

Si no hay cambios sin commitear (`git status` limpio), avísale al dev: no hay nada que cerrar.

## Paso 2 — Verificar la rama (CRÍTICO)

```bash
git rev-parse --abbrev-ref HEAD
```

- Si devuelve `master` o `main`: **NO continúes**. Dile al dev que está en una rama protegida y ayúdale:
  crear una rama de funcionalidad (`git switch -c feat/<descripcion-corta>`) que llevará sus cambios, o
  mover el trabajo según prefiera. Solo continúa cuando esté en una rama de funcionalidad.
- Si está en una rama de funcionalidad correcta: anótala, la usarás para el push y el PR.

Convención de nombres de rama sugerida: `feat/<issue>-<descripcion>`, `fix/<issue>-<descripcion>`,
`refactor/<descripcion>`. Ej: `feat/42-calculo-impuestos`.

## Paso 3 — Pruebas unitarias

El código no se cierra sin pruebas que demuestren que funciona.

1. Identifica la lógica nueva o modificada en esta sesión (casos de uso, hooks, servicios, funciones de
   utilidad, services de backend). La UI puramente presentacional y la configuración no requieren prueba
   unitaria; la lógica de negocio **sí**.
2. Revisa si ya existen pruebas para ese código. Si faltan, **escríbelas**.
3. Cubre el camino feliz y al menos un caso de error o borde (input nulo, lista vacía, valor fuera de rango).
4. Ejecuta la suite:
   - Frontend (Vite): `npm run test` (Vitest) o el script definido en `package.json`.
   - Backend (Spring Boot + Gradle): `./gradlew test`.
5. **Todas las pruebas deben pasar.** Si alguna falla, arregla el código o la prueba y vuelve a correr.
   No avances al commit con tests en rojo.

Reporta brevemente al dev: cuántas pruebas corrieron, qué cubren las nuevas.

## Paso 4 — Documentación

Genera la documentación de la sesión. Hay tres piezas; usa las que apliquen:

### 4a. Bitácora de sesión (siempre)

Crea o anexa una entrada en `docs/bitacora/AAAA-MM-DD.md` (un archivo por día; varias entradas si hay
varias sesiones). Usa la plantilla `assets/plantilla-bitacora.md`. Rellénala con lo que reuniste en el
Paso 1. Sé concreto: en "Decisiones" escribe **por qué**, no solo qué.

### 4b. ADR — Architecture Decision Record (solo si hubo una decisión arquitectónica)

Si en la sesión se eligió entre alternativas con impacto duradero (cambiar de Context API a otra
solución de estado, introducir una librería nueva, cambiar la forma de un contrato de API, una decisión
de modelado en MongoDB), crea un ADR en `docs/adr/NNNN-titulo-corto.md` usando la plantilla
`assets/plantilla-adr.md`. Numéralos correlativos. Un ADR captura: contexto, decisión, alternativas
consideradas y consecuencias. Es lo que evita la pregunta "¿por qué hicimos esto así?" seis meses después.

### 4c. Documentación viva afectada (si aplica)

Si los cambios alteran un README, un contrato de API, variables de entorno o pasos de instalación,
actualiza esos documentos en el mismo cierre. La documentación que se desactualiza es peor que no tenerla.

## Paso 5 — Commit (Conventional Commits)

Construye uno o varios commits atómicos. Mensaje en formato Conventional Commits, enlazando el issue:

```
<tipo>(<alcance>): <descripción breve en imperativo>

<cuerpo opcional explicando el porqué>

fix #<issue>
```

Tipos permitidos: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`.

Ejemplo:
```bash
git add <archivos>
git commit -m "feat(cart): agrega cálculo de impuestos por región" -m "Centraliza la lógica fiscal en un caso de uso para reutilizarla en checkout y carrito." -m "fix #42"
```

Palabras clave de cierre de issue (`fix #N`, `close #N`, `resolves #N`) hacen que GitHub cierre el issue
al mergear el PR. Úsalas cuando el trabajo de hecho completa el issue; si solo avanza, referencia con
`#N` sin palabra de cierre.

## Paso 6 — Push y Pull Request

1. **Re-verifica la rama** (`git rev-parse --abbrev-ref HEAD`). Última oportunidad de atrapar un error:
   si por cualquier razón es `master`/`main`, **aborta**.
2. Push a la rama de funcionalidad:
   ```bash
   git push -u origin <rama-actual>
   ```
3. Abre el PR con `gh` (GitHub CLI). **La rama base es `dev` o `release`** según corresponda el trabajo
   —pregúntale al dev si no es obvio—, **nunca `master`**:
   ```bash
   gh pr create --base dev --head <rama-actual> --title "<tipo>(<alcance>): <título>" --body-file <archivo-pr>
   ```
   Construye el cuerpo del PR a partir de `assets/plantilla-pr.md`: resumen, issue enlazado, qué cambió,
   cómo se probó, y checklist. El PR es la unidad de revisión; que el cuerpo cuente la historia completa.
4. Devuélvele al dev el enlace del PR que imprime `gh`.

Si `gh` no está autenticado o no está instalado, dile al dev que abra el PR manualmente con base `dev`/`release`
y dale el título y el cuerpo ya redactados para que los pegue. **Tú no cambias permisos ni configuración de
la cuenta.**

---

## Resumen del flujo

contexto → verificar rama (≠ master) → tests (verde) → docs (bitácora + ADR) → commit (Conventional + issue)
→ push → PR a dev/release (nunca master) → enlace al dev.

Cierra confirmando en una línea: rama, # de tests que pasan, archivos de doc generados, y el enlace del PR.
