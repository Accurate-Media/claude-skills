---
name: pruebas
description: Cómo se prueban las cosas en Accurate Media. Úsala cuando el dev pida "escribe pruebas", "cubre esto con tests", "faltan pruebas", "añade cobertura", o antes de cerrar cualquier trabajo. Frontend: Vitest + React Testing Library sobre casos de uso, hooks y utils. Backend: JUnit 5 + Mockito para services y Testcontainers con la base de datos real del repo para repositorios. Define qué se prueba y qué no, exige camino feliz más al menos un caso de borde, da los comandos de cada stack, y explica cómo correr una suite que no cabe en un tirón (sharding, Docker) y cómo tratar los rojos preexistentes de master. Consúltala en vez de improvisar el estilo de las pruebas.
---

# Pruebas — Accurate Media

Esta skill fija el estilo de pruebas del equipo, para frontend y backend. El objetivo es que las
pruebas de cualquier persona se vean como si las hubiera escrito la misma.

## 1. Qué se prueba y qué no

**Sí se prueba** — la lógica de negocio:

- Frontend: **casos de uso**, **hooks**, **adaptadores** y **utilidades**.
- Backend: **Services** (las reglas de negocio), **Mappers** (la transformación modelo ↔ DTO) y
  **Repositories** en su integración contra una base de datos real.

Lo que fija la regla es el **papel** de la pieza, no su ruta. Las rutas de ejemplo de esta skill
(`src/useCases/`, `src/adapters/`…) son las de un proyecto nuevo; un repo con historia puede colocar
los mismos papeles en otro sitio, y entonces manda el repo. Antes de escribir la primera prueba,
**localiza el papel en el árbol real** en vez de dar la ruta por sentada:

| papel | ruta de referencia | ejemplo de una variante real (CRM) |
|---|---|---|
| Caso de uso / lógica pura | `src/useCases/` | `src/domain/<entidad>/` |
| Hook | `src/hooks/` | `src/ui/hooks/` |
| Adaptador | `src/adapters/` | `src/infrastructure/repositories/` |
| Utilidad | `src/utils/` | `src/ui/lib/` |

Igual con el motor de base de datos: los ejemplos usan MongoDB, pero un repo sobre Postgres se prueba
contra Postgres. Compruébalo en `build.gradle` y en las migraciones antes de levantar un contenedor
(ver `references/backend.md`).

**No se prueba** — UI puramente presentacional y configuración:

- Componentes "tontos" que solo reciben props y pintan (sin estado ni lógica) casi nunca necesitan
  prueba unitaria propia; su comportamiento ya queda cubierto al probar el hook o caso de uso que
  consumen.
- Archivos de configuración (`vite.config.js`, `application.yml`, `router/`, beans de Spring sin lógica).

Si un componente **sí** tiene interacción (un click dispara una acción, un formulario valida), se
prueba el comportamiento que ve el usuario — no los props internos que recibe un hijo ni los detalles
de implementación.

## 2. La regla mínima

Toda prueba nueva cubre:

1. El **camino feliz**: el caso que funciona como se espera.
2. **Al menos un caso de error o borde**: input nulo, lista vacía, valor fuera de rango, recurso no
   encontrado.

Una prueba que solo cubre el camino feliz no está completa.

## 3. Nombres de las pruebas

El nombre de una prueba describe el **comportamiento esperado**, no el método que invoca.

```
// MAL
test("testGetActiveProducts")
void findByIdTest()

// BIEN
it("devuelve solo los productos con stock disponible")
void lanzaProductNotFoundExceptionCuandoNoExiste()
```

Si al leer el nombre de la prueba no queda claro qué garantiza, el nombre está mal.

## 4. Comandos

| Stack | Comando |
|---|---|
| Frontend (Vitest) | `npm run test` |
| Backend (Gradle) | `./gradlew test` |

Todas las pruebas en verde antes de cualquier commit. La skill `cierre` lo verifica al cerrar la sesión.

### Cuando la suite no cabe en una corrida

En un repo grande la suite completa puede no terminar de un tirón (se agota la memoria, el runner se
cuelga, o simplemente tarda demasiado). Ahí se corre **por lotes**, y el veredicto es la unión de los
lotes, no el primero que pase:

```bash
# Frontend: vitest lo trae de fábrica
for i in 1 2 3 4; do npx vitest run --shard=$i/4; done

# Backend: si el build.gradle del repo define un sharding propio, úsalo
for i in 1 2 3 4 5 6 7 8; do ./gradlew test -PtestShard=$i/8; done
```

Un `| tail` o un `| head` sobre la salida de Gradle puede matar el proceso por SIGPIPE y hacerte creer
que la corrida terminó: redirige a un archivo y luego lee el archivo.

**Las pruebas de integración necesitan Docker** (Testcontainers). Sin el demonio arriba fallan en masa
con `initializationError`, que **no** es un fallo de tu cambio: arranca Docker y vuelve a correr antes
de diagnosticar nada.

### Verde relativo: la línea base

«Todas en verde» significa *ninguna que tu cambio haya roto*, no *ninguna roja en el repo*. Un repo con
historia puede tener rojos preexistentes en `master`. Si te encuentras alguno:

1. Antes de empezar, corre la suite sobre `origin/master` limpio y **guarda la lista de rojos**.
2. Al cerrar, compara: los que ya estaban no son tuyos y no bloquean el cierre.
3. Dilo en la bitácora y en el cuerpo del PR, para que quien revise no los cuente contra ti.

Lo que **sí** bloquea el cierre es un rojo nuevo, o un rojo preexistente en la zona que tocaste — ahí
ya no puedes saber de quién es, y hay que resolverlo.

## 5. El detalle por stack

- **Frontend** (casos de uso, hooks, adaptadores, componentes con interacción): `references/frontend.md`.
- **Backend** (services, repositorios con Testcontainers, mappers): `references/backend.md`.

Consulta la referencia de tu stack antes de escribir la primera línea de una prueba nueva.
