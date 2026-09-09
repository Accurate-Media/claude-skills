# Scaffold — Frontend

Para una feature `<f>` (kebab-case, ej. `product`) con entidad `<F>` (PascalCase, ej. `Product`).
Si `<f>` es multi-palabra (`order-item`), usa camelCase en identificadores de código (`orderItem`) y
kebab-case solo donde la convención de carpetas de `normas/references/frontend.md` lo pida.

Archivos, en orden de dependencia (cada capa solo depende de la anterior):

```
src/adapters/<f>Adapter.js          # cruda → limpia, con valores defensivos
src/services/<f>Service.js          # llamadas HTTP, sin lógica
src/useCases/<f>/get<F>List.js      # orquesta service + adapter, aplica reglas
src/hooks/use<F>.js                 # estado reactivo sobre el caso de uso
src/components/common/<F>Card.jsx   # presentacional, solo props
src/components/common/<F>List.jsx   # presentacional, con guard clause de carga
src/pages/<F>Page.jsx               # conecta hook y componentes
```

Y sus pruebas espejo (esqueletos — completarlas con el estilo de la skill `pruebas`):

```
src/adapters/<f>Adapter.test.js
src/useCases/<f>/get<F>List.test.js
src/hooks/use<F>.test.js
```

## `src/adapters/<f>Adapter.js`

```js
export const <f>Adapter = (apiResponse) => ({
  id: apiResponse.id ?? null,
  name: apiResponse.name || "Sin nombre", // valor por defecto: nunca undefined en la UI
  // TODO: mapear el resto de campos crudos de <f> según el contrato real de la API
});
```

## `src/services/<f>Service.js`

Solo llamadas HTTP: sin filtrar, ordenar ni transformar nada aquí — eso es trabajo del caso de uso y
del adaptador.

```js
const BASE_URL = `${import.meta.env.VITE_API_URL}/<f>s`;

export const fetch<F>List = async () => {
  const response = await fetch(BASE_URL);
  if (!response.ok) throw new Error(`Error al obtener <f>s: ${response.status}`);
  return response.json();
};

export const fetch<F>ById = async (id) => {
  const response = await fetch(`${BASE_URL}/${id}`);
  if (!response.ok) throw new Error(`Error al obtener <f> ${id}: ${response.status}`);
  return response.json();
};

export const create<F> = async (payload) => {
  const response = await fetch(BASE_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(`Error al crear <f>: ${response.status}`);
  return response.json();
};
```

## `src/useCases/<f>/get<F>List.js`

```js
import { fetch<F>List } from "../../services/<f>Service";
import { <f>Adapter } from "../../adapters/<f>Adapter";

export const get<F>List = async () => {
  const rawData = await fetch<F>List();
  const items = rawData.map(<f>Adapter);
  // TODO: aplicar aquí la regla de negocio de filtrado/orden de <f> cuando esté definida
  return items;
};
```

## `src/hooks/use<F>.js`

```js
import { useState, useEffect } from "react";
import { get<F>List } from "../useCases/<f>/get<F>List";

export const use<F> = () => {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    get<F>List()
      .then(setItems)
      .catch(setError)
      .finally(() => setLoading(false));
  }, []);

  return { items, loading, error };
};
```

## `src/components/common/<F>Card.jsx`

Presentacional: solo recibe props, sin estado ni llamadas propias.

```jsx
import { Card } from "../ui/card";

export const <F>Card = ({ item }) => (
  <Card className="p-4">
    <h3>{item.name}</h3>
    {/* TODO: completar el detalle visible de <F> cuando el diseño esté definido */}
  </Card>
);
```

## `src/components/common/<F>List.jsx`

Presentacional, con guard clauses de carga y de lista vacía.

```jsx
import { <F>Card } from "./<F>Card";

export const <F>List = ({ items, isLoading }) => {
  if (isLoading) return <div>Cargando...</div>; // guard clause

  if (items.length === 0) return <div>No hay <f>s todavía.</div>; // guard clause

  return (
    <div className="grid grid-cols-4 gap-4">
      {items.map((item) => (
        <<F>Card key={item.id} item={item} />
      ))}
    </div>
  );
};
```

## `src/pages/<F>Page.jsx`

Conecta el hook con los componentes; punto de entrada de la ruta.

```jsx
import { use<F> } from "../hooks/use<F>";
import { <F>List } from "../components/common/<F>List";
import { MainLayout } from "../components/layouts/MainLayout";

const <F>Page = () => {
  const { items, loading, error } = use<F>();

  if (error) return <div>Ocurrió un error al cargar <f>s.</div>; // guard clause

  return (
    <MainLayout title="<F>">
      <<F>List items={items} isLoading={loading} />
    </MainLayout>
  );
};

export default <F>Page;
```

## Pruebas espejo (esqueletos)

Marcan la forma y el comportamiento esperado con `it.todo`, sin asertar lógica de negocio que aún no
existe. Complétalas con la skill `pruebas` en cuanto la regla esté definida.

`src/adapters/<f>Adapter.test.js`:

```js
import { describe, it } from "vitest";

describe("<f>Adapter", () => {
  it.todo("transforma el payload crudo de la API a la forma limpia");
  it.todo("aplica valores por defecto cuando los campos vienen nulos");
});
```

`src/useCases/<f>/get<F>List.test.js`:

```js
import { describe, it } from "vitest";

describe("get<F>List", () => {
  it.todo("aplica la regla de negocio de <f> pendiente de definir");
  it.todo("propaga un error de dominio cuando el service falla");
});
```

`src/hooks/use<F>.test.js`:

```js
import { describe, it } from "vitest";

describe("use<F>", () => {
  it.todo("empieza en estado de carga y sin items");
  it.todo("expone los items y deja de cargar cuando el caso de uso resuelve");
});
```
