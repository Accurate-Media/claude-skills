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
Si el trabajo no tiene issue asociado, la línea de cierre se omite por completo.

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
