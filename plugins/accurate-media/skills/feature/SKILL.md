---
name: feature
description: Genera el esqueleto de una feature nueva respetando la arquitectura por capas de Accurate Media. Úsala cuando el dev pida "crea la feature X", "necesito un CRUD de Y", "arma la pantalla de Z", "añade el endpoint de W" o "monta el módulo de V". En frontend crea el caso de uso, el hook, el componente y el adaptador; en backend, el controller, el service, el repository, el document, los DTOs y el mapper, cada uno con su esqueleto de prueba. No inventa lógica de negocio - deja el andamiaje completo, coherente con las normas del equipo y compilando.
---

# Feature — scaffolding por capas

Esta skill genera el andamiaje vertical completo de una feature nueva, respetando la arquitectura por
capas del equipo. No sustituye el diseño de la lógica de negocio: la deja preparada, marcada y lista
para que el dev la rellene.

## 1. Antes de generar nada

Pregunta:

1. **Nombre de la feature** (para derivar `<f>` en kebab-case y `<F>` en PascalCase).
2. **Alcance**: frontend, backend, o ambos.
3. **Operaciones que necesita** (listar, crear, actualizar, eliminar, o un subconjunto).

Con esas respuestas, **confirma con el dev la lista exacta de archivos que vas a crear antes de
crear ninguno**. Si el dev solo pidió "listar", no generes los archivos de creación/edición que nadie
pidió.

## 2. Regla de oro: el andamiaje no inventa reglas de negocio

Donde iría lógica que el dev no ha especificado —una validación, un filtro, un cálculo—, deja un
`TODO` explícito con el nombre de la regla pendiente:

```js
// TODO: aplicar la regla de negocio "solo mostrar <f> activos" cuando esté definida
```

```java
// TODO: validar la regla de negocio "stock mínimo para publicar" cuando esté definida
```

**Nunca** una implementación inventada que parezca correcta. Un `TODO` visible es honesto; una regla
adivinada que compila y se ve razonable es el peor tipo de deuda técnica, porque nadie la revisa.

## 3. El detalle por stack

- **Frontend** (adaptador, service, caso de uso, hook, componentes, page — en orden de dependencia):
  `references/frontend-scaffold.md`.
- **Backend** (Document, DTOs, Mapper, Repository, Service, Controller): `references/backend-scaffold.md`.

Cada referencia respeta la arquitectura descrita en `normas/references/frontend.md` y
`normas/references/backend.md` respectivamente: no la repitas, ni te desvíes de ella al generar código.

## 4. Al terminar

Las pruebas que este scaffolding genera son **esqueletos**: marcan la forma del test (`describe`/`it`
o `@Test` con el nombre del comportamiento esperado) pero no aserciones de negocio, porque esa lógica
todavía no existe. Recuérdale al dev que la skill `pruebas` tiene el estilo del equipo —ejemplos
completos por tipo de prueba— para completarlas en cuanto la lógica esté definida.
