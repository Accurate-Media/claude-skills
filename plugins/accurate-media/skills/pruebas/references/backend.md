# Pruebas — Backend (JUnit 5 + Mockito + Testcontainers)

- **Unitarias:** JUnit 5 + Mockito. Prueba los **Service** mockeando el repositorio. Cubre camino
  feliz + caso de error (no encontrado, stock 0, input inválido).
- **Integración:** Testcontainers con un contenedor de la **base de datos real del repo** para validar
  repositorios y el flujo controller→service→repo. Nunca una base embebida o en memoria: no reproduce
  el comportamiento del motor de verdad.
- **Mapper:** prueba pura, sin Spring, incluyendo el caso defensivo (campo nulo → valor por defecto).
- Comando: `./gradlew test`. Las pruebas deben pasar antes de cualquier commit (lo verifica la skill
  `cierre`).

> **El contenedor lo dicta el repo, no esta referencia.** Los ejemplos de abajo usan MongoDB porque es
> el stack del proyecto de referencia. Antes de escribir un IT, mira `build.gradle` y la carpeta de
> migraciones para saber contra qué te vas a conectar de verdad:
>
> | motor del repo | anotación | contenedor | nota |
> |---|---|---|---|
> | MongoDB | `@DataMongoTest` | `MongoDBContainer` | el ejemplo de abajo |
> | Postgres (Flyway/JPA) | `@DataJpaTest` o `@SpringBootTest` | `PostgreSQLContainer` | deja que Flyway aplique las migraciones sobre el contenedor; así el IT prueba el esquema real, incluidas las FK y los CHECK |
>
> Un repo puede tener los dos a la vez si está a medio migrar: entonces cada IT usa el motor de la
> tabla o colección que prueba, no el que sea más cómodo.

Y recuerda: **sin Docker arriba, los IT fallan en masa con `initializationError`** y no es culpa de tu
cambio (ver la sección de comandos de la skill `pruebas`).

A continuación, un ejemplo real y compilable por cada tipo, sobre la feature `product` (ver la
estructura de paquetes en `../../normas/references/backend.md`).

## Service unitario

`@ExtendWith(MockitoExtension.class)`, repositorio mockeado con `@Mock`, la clase bajo prueba
inyectada con `@InjectMocks`. Camino feliz y excepción de dominio.

Clases de producción sobre las que corre la prueba:

```java
// src/main/java/com/accuratemedia/marketplace/product/Product.java
package com.accuratemedia.marketplace.product;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("products")
public class Product {

    @Id
    private String id;
    private String name;
    private double price;
    private int stock;

    public Product() {
    }

    public Product(String id, String name, double price, int stock) {
        this.id = id;
        this.name = name;
        this.price = price;
        this.stock = stock;
    }

    public String getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public double getPrice() {
        return price;
    }

    public int getStock() {
        return stock;
    }
}
```

```java
// src/main/java/com/accuratemedia/marketplace/product/exception/ProductNotFoundException.java
package com.accuratemedia.marketplace.product.exception;

public class ProductNotFoundException extends RuntimeException {

    public ProductNotFoundException(String productId) {
        super("Producto no encontrado: " + productId);
    }
}
```

```java
// src/main/java/com/accuratemedia/marketplace/product/ProductRepository.java
package com.accuratemedia.marketplace.product;

import org.springframework.data.mongodb.repository.MongoRepository;

public interface ProductRepository extends MongoRepository<Product, String> {
}
```

```java
// src/main/java/com/accuratemedia/marketplace/product/ProductService.java
package com.accuratemedia.marketplace.product;

public interface ProductService {
    Product findById(String id);
}
```

```java
// src/main/java/com/accuratemedia/marketplace/product/ProductServiceImpl.java
package com.accuratemedia.marketplace.product;

import com.accuratemedia.marketplace.product.exception.ProductNotFoundException;
import org.springframework.stereotype.Service;

@Service
public class ProductServiceImpl implements ProductService {

    private final ProductRepository productRepository;

    public ProductServiceImpl(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }

    @Override
    public Product findById(String id) {
        return productRepository.findById(id)
                .orElseThrow(() -> new ProductNotFoundException(id));
    }
}
```

La prueba:

```java
// src/test/java/com/accuratemedia/marketplace/product/ProductServiceImplTest.java
package com.accuratemedia.marketplace.product;

import com.accuratemedia.marketplace.product.exception.ProductNotFoundException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ProductServiceImplTest {

    @Mock
    private ProductRepository productRepository;

    @InjectMocks
    private ProductServiceImpl productService;

    @Test
    void devuelveElProductoCuandoExiste() {
        Product product = new Product("p-1", "Silla", 149.90, 5);
        when(productRepository.findById("p-1")).thenReturn(Optional.of(product));

        Product result = productService.findById("p-1");

        assertThat(result.getId()).isEqualTo("p-1");
        assertThat(result.getName()).isEqualTo("Silla");
    }

    @Test
    void lanzaProductNotFoundExceptionCuandoNoExiste() {
        when(productRepository.findById("no-existe")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> productService.findById("no-existe"))
                .isInstanceOf(ProductNotFoundException.class);
    }
}
```

## Repository de integración

`@DataMongoTest` + `@Testcontainers`, con un `MongoDBContainer` real registrado como
`@Container` y sus propiedades inyectadas vía `@DynamicPropertySource`. **No** se usa Mongo embebido.

```java
// src/test/java/com/accuratemedia/marketplace/product/ProductRepositoryIT.java
package com.accuratemedia.marketplace.product;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.data.mongo.DataMongoTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.MongoDBContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;

@DataMongoTest
@Testcontainers
class ProductRepositoryIT {

    @Container
    static MongoDBContainer mongoDBContainer =
            new MongoDBContainer(DockerImageName.parse("mongo:7.0"));

    @DynamicPropertySource
    static void mongoProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.data.mongodb.uri", mongoDBContainer::getReplicaSetUrl);
    }

    @Autowired
    private ProductRepository productRepository;

    @Test
    void guardaYRecuperaUnProductoPorId() {
        Product product = new Product(null, "Silla", 149.90, 5);
        Product guardado = productRepository.save(product);

        Optional<Product> recuperado = productRepository.findById(guardado.getId());

        assertThat(recuperado).isPresent();
        assertThat(recuperado.get().getName()).isEqualTo("Silla");
    }

    @Test
    void devuelveVacioCuandoElIdNoExiste() {
        Optional<Product> recuperado = productRepository.findById("no-existe");

        assertThat(recuperado).isEmpty();
    }
}
```

Requiere Docker disponible en la máquina/CI que corre `./gradlew test`, y las dependencias
`org.testcontainers:mongodb` y `org.testcontainers:junit-jupiter` en `build.gradle`.

## Mapper

Prueba pura, sin `@SpringBootTest` ni contexto de Spring: el mapper es una función, se prueba como tal.
Incluye el caso defensivo.

```java
// src/main/java/com/accuratemedia/marketplace/product/dto/ProductResponse.java
package com.accuratemedia.marketplace.product.dto;

public record ProductResponse(String id, String name, double price, boolean hasStock) {
}
```

```java
// src/main/java/com/accuratemedia/marketplace/product/ProductMapper.java
package com.accuratemedia.marketplace.product;

import com.accuratemedia.marketplace.product.dto.ProductResponse;

public final class ProductMapper {

    private ProductMapper() {
    }

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

```java
// src/test/java/com/accuratemedia/marketplace/product/ProductMapperTest.java
package com.accuratemedia.marketplace.product;

import com.accuratemedia.marketplace.product.dto.ProductResponse;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class ProductMapperTest {

    @Test
    void mapeaUnProductoCompletoASuRespuesta() {
        Product product = new Product("p-1", "Silla", 149.90, 5);

        ProductResponse response = ProductMapper.toResponse(product);

        assertThat(response.id()).isEqualTo("p-1");
        assertThat(response.name()).isEqualTo("Silla");
        assertThat(response.price()).isEqualTo(149.90);
        assertThat(response.hasStock()).isTrue();
    }

    @Test
    void aplicaElNombrePorDefectoCuandoElProductoNoTieneNombre() {
        Product product = new Product("p-2", null, 0, 0);

        ProductResponse response = ProductMapper.toResponse(product);

        assertThat(response.name()).isEqualTo("Sin nombre");
        assertThat(response.hasStock()).isFalse();
    }
}
```
