---
name: normas
description: Estándares de programación obligatorios de Accurate Media. Úsala siempre que escribas, edites, refactorices o revises código —frontend (React 19 + Vite + Shadcn) o backend (Spring Boot + MongoDB + Gradle)—, aunque el dev no lo pida. Cubre convenciones de nombres, Clean Code (sin números mágicos, guard clauses, responsabilidad única, límites de tamaño), arquitectura por capas, patrón adaptador, política de dependencias y las reglas de Git del equipo. Si vas a generar o cambiar código y no recuerdas la convención exacta, consulta esta skill en vez de improvisar: el código del equipo debe verse como si lo hubiera escrito una sola persona.
---

# Normas de programación — Accurate Media

Aplica estas normas mientras programas, sin que el dev tenga que pedirlo. El objetivo es un código base
**escalable, mantenible y desacoplado**: que cualquier integrante pueda leerlo y extenderlo sin sorpresas.

Primero las reglas universales (aplican a frontend y backend). Luego, según en qué estés trabajando, lee
**una** de las referencias:

- **Frontend** (React, Vite, Shadcn, hooks, componentes): lee `references/frontend.md`.
- **Backend** (Spring Boot, MongoDB, Gradle, Java): lee `references/backend.md`.
- **Git** (ramas, commits, Pull Requests): lee `references/git.md`.

---

## 1. Convenciones de nombres

Nombres explícitos que describan la intención. Evita genéricos como `a`, `b`, `data`, `temp`, `handle`.

| Elemento | Convención | Ejemplo |
|---|---|---|
| Carpetas | kebab-case | `auth`, `user-profile` |
| Componentes (React) | PascalCase | `ProductCard.jsx`, `Navbar.jsx` |
| Clases | PascalCase descriptivo | `UserSession`, `OrderManager` |
| Hooks (React) | `use` + camelCase | `useAuth`, `useCart` |
| Funciones / métodos | camelCase, verbo + sustantivo | `calculateTotal()`, `fetchUser()` |
| Variables | camelCase explícito | `userRequest`, `selectedEntries` |
| Constantes | UPPER_SNAKE_CASE | `API_URL`, `MAX_RETRY` |

(Java añade sus matices —paquetes en minúscula, etc.—; ver `references/backend.md`.)

## 2. Responsabilidad única y límites de tamaño

Cada función o método hace **una sola cosa**. Si hace varias, divídela en unidades menores con nombre propio.
Esto evita el código spaghetti y centraliza las correcciones en un solo lugar.

- **Funciones / métodos: máximo ~80–100 líneas.** Si una crece más, casi siempre está haciendo de más:
  extrae sub-funciones. (Apunta a mucho menos; 80–100 es el techo, no la meta.)
- **Archivos fuente: máximo ~500 líneas** como referencia de cohesión. Un archivo que crece sin parar suele
  estar mezclando responsabilidades que deberían separarse.
- **Anidamiento máximo: 2 niveles.** Más allá de eso, usa guard clauses (ver abajo).

## 3. Clean Code aplicado

**Sin números mágicos.** Da sentido semántico a los literales con constantes nombradas.
```js
// MAL
if (user.age < 18) return false;
// BIEN
const MINIMUM_LEGAL_AGE = 18;
if (user.age < MINIMUM_LEGAL_AGE) return false;
```

**Guard clauses / early return.** Valida errores y salidas al inicio; deja la lógica principal sin anidar.
```js
// MAL
function process(user) {
  if (user) {
    if (user.isActive) { /* ... */ }
  }
}
// BIEN
function process(user) {
  if (!user || !user.isActive) return;
  // lógica principal sin nesting
}
```

**Comentarios de intención.** Comenta el **porqué** de una decisión, no el **qué** (el código bien escrito ya
dice qué hace). Si sientes que necesitas un comentario para explicar qué hace una línea, primero intenta
renombrar variables o extraer una función.

## 4. Patrón Adaptador (crítico para la estabilidad)

El código **nunca** consume la respuesta "cruda" de una API/fuente externa. Pasa siempre por un adaptador que
la transforma a una forma limpia y estable. Así, si el backend renombra un campo (`user_name` → `userName`),
cambias **una** línea en el adaptador en vez de romper la app en muchos archivos.
```js
export const productAdapter = (apiResponse) => ({
  id: apiResponse.id_prod,
  name: apiResponse.desc_text || "Sin nombre",
  price: Number(apiResponse.p_val).toFixed(2),
  hasStock: apiResponse.stock_q > 0, // regla defensiva: null => false
});
```
El detalle por capa (dónde viven los adaptadores, cómo se usan) está en cada referencia.

## 5. Reglas de Git

Trunk-based: `master` es la única rama de larga vida y solo recibe código vía Pull Request. Nunca hagas
commit ni push directamente sobre `master`/`main` — el hook `guard-master` lo bloquea.

La política completa (nombre de rama, formato de commit, título y cuerpo del PR) está en
`references/git.md`. Es la fuente única: no la repitas en ningún otro sitio.

El ciclo lo ejecutan las skills `arranque` (rama + worktree) y `cierre` (commit + PR).

## 6. Política de librerías y dependencias

Antes de `npm install` / añadir una dependencia en Gradle, dos preguntas obligatorias:
1. ¿Ya tenemos una librería en `package.json` / `build.gradle` que haga esto o algo parecido?
2. ¿Se resuelve con lenguaje nativo o una función en `utils` en menos de ~50 líneas?

Solo si ambas respuestas son "no" se justifica una dependencia nueva. Cada dependencia es superficie de
ataque, peso y mantenimiento futuro.

---

## Cómo se usa esto

Mientras generas o editas código, aplica las reglas universales de arriba y carga la referencia del stack
correspondiente para los detalles de arquitectura y patrones. Si detectas que el código existente viola una
norma en la zona donde trabajas, señálalo al dev y propón el arreglo (sin reescribir medio repositorio sin
avisar).