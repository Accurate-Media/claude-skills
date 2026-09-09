---
name: pruebas
description: Cómo se prueban las cosas en Accurate Media. Úsala cuando el dev pida "escribe pruebas", "cubre esto con tests", "faltan pruebas", "añade cobertura", o antes de cerrar cualquier trabajo. Frontend: Vitest + React Testing Library sobre casos de uso, hooks y utils. Backend: JUnit 5 + Mockito para services y Testcontainers con MongoDB real para repositorios. Define qué se prueba y qué no, exige camino feliz más al menos un caso de borde, y da los comandos de cada stack. Consúltala en vez de improvisar el estilo de las pruebas.
---

# Pruebas — Accurate Media

Esta skill fija el estilo de pruebas del equipo, para frontend y backend. El objetivo es que las
pruebas de cualquier persona se vean como si las hubiera escrito la misma.

## 1. Qué se prueba y qué no

**Sí se prueba** — la lógica de negocio:

- Frontend: casos de uso (`src/useCases/`), hooks (`src/hooks/`), adaptadores (`src/adapters/`) y
  utilidades (`src/utils/`).
- Backend: **Services** (las reglas de negocio), **Mappers** (la transformación Document ↔ DTO) y
  **Repositories** en su integración real con MongoDB.

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

## 5. El detalle por stack

- **Frontend** (casos de uso, hooks, adaptadores, componentes con interacción): `references/frontend.md`.
- **Backend** (services, repositorios con Testcontainers, mappers): `references/backend.md`.

Consulta la referencia de tu stack antes de escribir la primera línea de una prueba nueva.
