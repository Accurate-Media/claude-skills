# Normas — Backend (Spring Boot + MongoDB + Gradle)

> No existe manual previo de backend. Estas convenciones son una **propuesta** que replica la arquitectura
> limpia del frontend (UI nunca toca la API directo → aquí: el controller nunca toca la base de datos directo).
> Ajústenla en equipo; cuando lo hagan, fijen la decisión en un ADR.

## Principio rector

Separación por capas con dependencias en una sola dirección:

```
Controller (REST)  →  Service (casos de uso / reglas)  →  Repository (Spring Data MongoDB)
       │                        │
   DTO + Mapper            Document (modelo de datos)
```

- El **Controller** no tiene lógica de negocio: valida la entrada, llama al Service, devuelve la respuesta.
- El **Service** tiene las reglas de negocio. No conoce HTTP ni detalles de Mongo más allá del repositorio.
- El **Repository** es la única capa que habla con MongoDB.
- Los **DTO + Mapper** son el equivalente del *Adapter* del frontend: aíslan el modelo interno (`Document`)
  del contrato público de la API. El cliente nunca ve el documento crudo de la base.

## Estructura de paquetes

Paquete raíz `com.accuratemedia.<servicio>`, organizado por **feature** y dentro por capa:

```
com.accuratemedia.marketplace
├── product
│   ├── ProductController.java        # @RestController
│   ├── ProductService.java           # interfaz (caso de uso)
│   ├── ProductServiceImpl.java       # implementación
│   ├── ProductRepository.java        # extends MongoRepository
│   ├── Product.java                  # @Document  (modelo)
│   ├── dto/
│   │   ├── ProductResponse.java      # lo que sale al cliente
│   │   └── CreateProductRequest.java # lo que entra (validado)
│   └── ProductMapper.java            # Document <-> DTO  (el "adaptador")
├── common
│   ├── exception/                    # excepciones de dominio + @ControllerAdvice
│   └── config/                       # configuración (beans, Mongo, seguridad)
└── MarketplaceApplication.java
```

## Convenciones de nombres (Java)

| Elemento | Convención | Ejemplo |
|---|---|---|
| Paquetes | minúsculas, sin guiones | `com.accuratemedia.product` |
| Clases / interfaces | PascalCase descriptivo | `ProductService`, `OrderManager` |
| Métodos | camelCase verbo + sustantivo | `findActiveProducts()`, `calculateTotal()` |
| Variables | camelCase explícito | `selectedProduct`, `userRequest` |
| Constantes (`static final`) | UPPER_SNAKE_CASE | `MAX_RETRY`, `DEFAULT_PAGE_SIZE` |
| Documentos Mongo | sustantivo singular | `Product`, `Order` |
| Colecciones | plural, kebab o snake | `products`, `order_items` |

Sufijos por capa, consistentes: `*Controller`, `*Service`/`*ServiceImpl`, `*Repository`, `*Mapper`,
`*Request`/`*Response` para DTOs.

## Reglas por capa

**Controller**
- Anota con `@RestController` y `@RequestMapping("/api/products")`.
- Valida la entrada con Bean Validation: `@Valid @RequestBody CreateProductRequest req`.
- Devuelve DTOs (`ProductResponse`), **nunca** la entidad `@Document`.
- Sin lógica de negocio ni acceso a repositorios.

**Service**
- Define una **interfaz** (`ProductService`) y su implementación (`ProductServiceImpl`).
- Aquí viven las reglas de negocio (ej. "solo productos con stock > 0").
- Inyección por **constructor** (no `@Autowired` en campos): facilita pruebas y deja claras las dependencias.
- Lanza excepciones de dominio (`ProductNotFoundException`), no `RuntimeException` genéricas.

**Repository**
- `interface ProductRepository extends MongoRepository<Product, String>`.
- Consultas derivadas del nombre (`findByStockGreaterThan(int stock)`) o `@Query` cuando haga falta.
- Única capa que importa tipos de Mongo.

**DTO + Mapper (adaptador)**
```java
// Mapper: aísla el contrato público del modelo interno
public final class ProductMapper {
    public static ProductResponse toResponse(Product p) {
        return new ProductResponse(
            p.getId(),
            p.getName() != null ? p.getName() : "Sin nombre",
            p.getPrice(),
            p.getStock() > 0 // regla defensiva
        );
    }
}
```
Si MongoDB cambia un campo, se ajusta el mapper en un solo lugar y el contrato de la API no se rompe.

## Clean Code (igual que en frontend)

- **Sin números mágicos:** `private static final int MAX_PAGE_SIZE = 50;`
- **Guard clauses / early return:**
  ```java
  public Product activate(Product product) {
      if (product == null || product.getStock() <= 0) {
          throw new ProductNotAvailableException();
      }
      // lógica principal sin nesting
  }
  ```
- **Anidamiento máximo 2 niveles.** Método ≤ ~80–100 líneas; archivo ≤ ~500.
- **Inmutabilidad cuando se pueda:** DTOs como `record`, `final` en campos que no cambian.

## Manejo de errores

- Excepciones de dominio en `common/exception`, con un `@RestControllerAdvice` global que las traduce a
  respuestas HTTP coherentes (`404`, `400`, `409`...) y un cuerpo de error uniforme.
- No tragues excepciones con `catch` vacío. No expongas stack traces al cliente.

## Configuración y secretos

- Nada de credenciales en el repo. Usa variables de entorno / `application-{profile}.yml` y perfiles
  (`dev`, `prod`). El `application.yml` versionado solo lleva valores no sensibles o placeholders.
- Conexión a Mongo y configuración de Docker Swarm vía variables de entorno / secrets del orquestador,
  no hardcodeadas.

## Pruebas (backend)

- **Unitarias:** JUnit 5 + Mockito. Prueba los **Service** mockeando el repositorio. Cubre camino feliz +
  caso de error (no encontrado, stock 0, input inválido).
- **Integración:** Testcontainers con un contenedor de MongoDB real para validar repositorios y el flujo
  controller→service→repo. (No uses Mongo embebido obsoleto.)
- Comando: `./gradlew test`. Las pruebas deben pasar antes de cualquier commit (lo verifica la skill `cierre`).

## Gradle y dependencias

- Antes de añadir una dependencia: ¿ya hay algo en `build.gradle` que lo cubra? ¿Se resuelve con el stdlib
  de Java o un util corto? (Misma política que el frontend.)
- Fija versiones; evita rangos abiertos. Prefiere el BOM de Spring Boot para alinear versiones.