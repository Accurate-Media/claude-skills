# Normas — Frontend (React 19 + Vite + Shadcn)

Arquitectura limpia adaptada al frontend: la UI nunca toca la API directamente; el flujo de datos es
unidireccional y pasa por Hooks y Casos de Uso.

```
Page (Vista) → Custom Hook → Use Case (lógica) → Service (API)
   │
   └─ Components → UI (Shadcn)        Context (estado global)
```

## Estructura de carpetas (`src/`)

```
src/
├── assets/        # imágenes, fuentes, iconos SVG estáticos
├── auth/          # lógica de autenticación (Guards, AuthProvider)
├── components/
│   ├── ui/        # base de Shadcn (Button, Input, Card)
│   ├── common/    # propios (NavBar, Footer, ProductCard)
│   └── layouts/   # estructuras de página (MainLayout, AuthLayout)
├── context/       # estados globales (Carrito, Tema)
├── hooks/         # lógica reutilizable (custom hooks)
├── pages/         # vistas principales (Home, Login, Marketplace, Checkout)
├── router/        # configuración de rutas
├── services/      # comunicación con APIs (Axios, Fetch)
├── useCases/      # lógica de negocio pura (orquestación)
├── adapters/      # adaptadores de respuestas de API
├── utils/         # funciones auxiliares puras (formatters, validators)
├── App.jsx
└── main.jsx
```

## Las capas, en orden

**1. Use Cases** — lógica de negocio agnóstica de la UI. Orquestan servicios y aplican reglas.
```js
import { fetchProducts } from "../../services/api";

export const getActiveProducts = async () => {
  try {
    const rawData = await fetchProducts();
    return rawData.filter((product) => product.stock > 0); // regla: solo con stock
  } catch (error) {
    throw new Error("Error al obtener el catálogo");
  }
};
```

**2. Hooks** — consumen casos de uso y exponen datos reactivos a los componentes.
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

**3. Components (UI)** — presentacionales ("tontos"): solo reciben props y renderizan. Sin lógica de negocio.
```jsx
import { Card } from "../ui/card";

export const ProductGrid = ({ items, isLoading }) => {
  if (isLoading) return <div>Cargando catálogo...</div>; // guard clause
  return (
    <div className="grid grid-cols-4 gap-4">
      {items.map((product) => (
        <Card key={product.id} className="p-4">
          <h3>{product.name}</h3>
          <p>${product.price}</p>
        </Card>
      ))}
    </div>
  );
};
```

**4. Pages** — conectan hooks con componentes; punto de entrada de la ruta.
```jsx
import { useCatalog } from "../hooks/useCatalog";
import { ProductGrid } from "../components/common/ProductGrid";
import { MainLayout } from "../components/layouts/MainLayout";

const MarketplacePage = () => {
  const { products, loading } = useCatalog();
  return (
    <MainLayout title="Nuestros Productos">
      <ProductGrid items={products} isLoading={loading} />
    </MainLayout>
  );
};
export default MarketplacePage;
```

## Patrones de diseño

**Container / Presentational (Smart vs Dumb).** Separa lógica de vista. El Container gestiona estado y
datos (hooks/use cases) y pasa props; el Presentational solo recibe props y pinta.
```jsx
const UserListContainer = () => {
  const { users, loading } = useGetUsers();
  if (loading) return <Spinner />;
  return <UserListView users={users} onSelect={handleSelect} />;
};
const UserListView = ({ users, onSelect }) => (
  <div className="grid gap-4">
    {users.map((u) => (
      <Card key={u.id} onClick={() => onSelect(u.id)}><Text>{u.fullName}</Text></Card>
    ))}
  </div>
);
```

**Composition vs Prop Drilling.** En vez de pasar props por componentes intermedios que no las usan, usa
`children` o pasa componentes completos como props (slots).
```jsx
const DashboardLayout = ({ headerSlot, contentSlot }) => (
  <div className="layout">
    <header>{headerSlot}</header>
    <main>{contentSlot}</main>
  </div>
);
// uso:
<DashboardLayout headerSlot={<Avatar user={user} />} contentSlot={<ProductList />} />
```

**Observer (reactivo).** Intrínseco en React: los componentes se "suscriben" a datos y se re-renderizan
cuando el sujeto cambia.
```js
useEffect(() => {
  syncCartWithServer(cartId); // se ejecuta cuando cartId cambia
}, [cartId]);
```

**Adapter.** El componente solo conoce la forma limpia (`product.name`), nunca la cruda (`product.desc_text`).
Los adaptadores viven en `src/adapters/`. (Ejemplo en la skill `normas`, sección 4.)

## Estado y enrutamiento

- **Estado global:** Context API para estado global **simple** (tema, sesión, carrito básico) + hooks
  personalizados. Si el estado se vuelve complejo o sufre de renders excesivos, evalúa una librería ligera
  (registra la decisión en un ADR antes de adoptarla).
- **Enrutamiento:** React Router DOM, configurado en `src/router/`.

## Pruebas (frontend)

- Framework recomendado: **Vitest** + React Testing Library (encaja nativo con Vite).
- Qué probar: casos de uso, hooks y utils (la lógica). Los componentes presentacionales puros casi no
  necesitan prueba unitaria; si tienen interacción, prueba el comportamiento, no la implementación.