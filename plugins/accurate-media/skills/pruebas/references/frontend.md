# Pruebas — Frontend (Vitest + React Testing Library)

Framework: **Vitest** (encaja nativo con Vite) + **React Testing Library** para lo que toca el DOM.

Requisitos de entorno (ya deberían estar en el proyecto): `vitest`, `@testing-library/react`,
`@testing-library/user-event` y `@testing-library/jest-dom` como dependencias de desarrollo; la
configuración de Vitest con `environment: "jsdom"` y un `setupFiles` que importe
`@testing-library/jest-dom` (para matchers como `toBeInTheDocument`).

Qué probar: casos de uso, hooks, adaptadores y utils — es donde vive la lógica. Los componentes
presentacionales puros casi no necesitan prueba propia; si tienen interacción, se prueba el
comportamiento observable, no la implementación.

A continuación, un ejemplo real y ejecutable por cada tipo.

## Caso de uso

Prueba la regla de negocio y el error que propaga cuando el service falla. El service se mockea con
`vi.mock`.

Implementación (`src/useCases/product/getProductList.js`):

```js
import { fetchProducts } from "../../services/productService";

export const getActiveProducts = async () => {
  try {
    const rawData = await fetchProducts();
    return rawData.filter((product) => product.stock > 0); // regla: solo con stock
  } catch (error) {
    throw new Error("Error al obtener el catálogo");
  }
};
```

Prueba (`src/useCases/product/getProductList.test.js`):

```js
import { describe, it, expect, vi, beforeEach } from "vitest";
import { getActiveProducts } from "./getProductList";
import { fetchProducts } from "../../services/productService";

vi.mock("../../services/productService");

describe("getActiveProducts", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("devuelve solo los productos con stock disponible", async () => {
    fetchProducts.mockResolvedValue([
      { id: 1, name: "Silla", stock: 5 },
      { id: 2, name: "Mesa", stock: 0 },
      { id: 3, name: "Lámpara", stock: 2 },
    ]);

    const result = await getActiveProducts();

    expect(result).toEqual([
      { id: 1, name: "Silla", stock: 5 },
      { id: 3, name: "Lámpara", stock: 2 },
    ]);
  });

  it("propaga un error de dominio cuando el service falla", async () => {
    fetchProducts.mockRejectedValue(new Error("network error"));

    await expect(getActiveProducts()).rejects.toThrow("Error al obtener el catálogo");
  });
});
```

## Hook

Con `renderHook` de React Testing Library, verifica el estado inicial de carga y el estado tras la
resolución del caso de uso. El caso de uso se mockea; el hook no necesita un componente real alrededor.

Implementación (`src/hooks/useCatalog.js`):

```js
import { useState, useEffect } from "react";
import { getActiveProducts } from "../useCases/product/getProductList";

export const useCatalog = () => {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getActiveProducts()
      .then(setProducts)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  return { products, loading };
};
```

Prueba (`src/hooks/useCatalog.test.js`):

```js
import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { useCatalog } from "./useCatalog";
import { getActiveProducts } from "../useCases/product/getProductList";

vi.mock("../useCases/product/getProductList");

describe("useCatalog", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it("empieza en estado de carga y sin productos", () => {
    getActiveProducts.mockReturnValue(new Promise(() => {})); // no resuelve: observamos el estado inicial

    const { result } = renderHook(() => useCatalog());

    expect(result.current.loading).toBe(true);
    expect(result.current.products).toEqual([]);
  });

  it("expone los productos y deja de cargar cuando el caso de uso resuelve", async () => {
    const productos = [{ id: 1, name: "Silla", stock: 5 }];
    getActiveProducts.mockResolvedValue(productos);

    const { result } = renderHook(() => useCatalog());

    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.products).toEqual(productos);
  });
});
```

## Adaptador

Dado un payload crudo de la API, el adaptador devuelve la forma limpia. Incluye el caso defensivo:
un campo `null` cae a su valor por defecto.

Implementación (`src/adapters/productAdapter.js`):

```js
export const productAdapter = (apiResponse) => ({
  id: apiResponse.id_prod,
  name: apiResponse.desc_text || "Sin nombre",
  price: Number(apiResponse.p_val).toFixed(2),
  hasStock: apiResponse.stock_q > 0, // regla defensiva: null o 0 => false
});
```

Prueba (`src/adapters/productAdapter.test.js`):

```js
import { describe, it, expect } from "vitest";
import { productAdapter } from "./productAdapter";

describe("productAdapter", () => {
  it("transforma el payload crudo de la API a la forma limpia", () => {
    const apiResponse = { id_prod: "p-1", desc_text: "Silla de oficina", p_val: "149.9", stock_q: 3 };

    expect(productAdapter(apiResponse)).toEqual({
      id: "p-1",
      name: "Silla de oficina",
      price: "149.90",
      hasStock: true,
    });
  });

  it("aplica valores por defecto cuando los campos vienen nulos", () => {
    const apiResponse = { id_prod: "p-2", desc_text: null, p_val: "0", stock_q: null };

    const result = productAdapter(apiResponse);

    expect(result.name).toBe("Sin nombre");
    expect(result.hasStock).toBe(false);
  });
});
```

## Componente con interacción

`render` + `userEvent` (nunca `fireEvent` a mano salvo casos muy puntuales). Se verifica qué ve y
puede hacer el usuario, no qué props recibió un componente hijo.

Implementación (`src/components/common/AddToCartButton.jsx`):

```jsx
import { useState } from "react";

export const AddToCartButton = ({ productId, onAddToCart }) => {
  const [added, setAdded] = useState(false);

  const handleClick = async () => {
    await onAddToCart(productId);
    setAdded(true);
  };

  if (added) return <span>Agregado al carrito</span>;

  return <button onClick={handleClick}>Agregar al carrito</button>;
};
```

Prueba (`src/components/common/AddToCartButton.test.jsx`):

```jsx
import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { AddToCartButton } from "./AddToCartButton";

describe("AddToCartButton", () => {
  it("muestra la confirmación cuando el usuario agrega el producto al carrito", async () => {
    const user = userEvent.setup();
    const onAddToCart = vi.fn().mockResolvedValue(undefined);

    render(<AddToCartButton productId="p-1" onAddToCart={onAddToCart} />);

    await user.click(screen.getByRole("button", { name: /agregar al carrito/i }));

    expect(await screen.findByText("Agregado al carrito")).toBeInTheDocument();
    expect(onAddToCart).toHaveBeenCalledWith("p-1");
  });
});
```

La prueba no le pregunta al botón qué prop recibió: verifica que, tras el click, el usuario ve el
mensaje de confirmación y que la acción se disparó con el dato correcto.
