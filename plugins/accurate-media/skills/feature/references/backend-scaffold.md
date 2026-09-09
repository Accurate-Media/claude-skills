# Scaffold — Backend

Para una feature `<f>` (minúsculas, ej. `product`) con entidad `<F>` (PascalCase, ej. `Product`), bajo
`com.accuratemedia.<servicio>.<f>` (`<servicio>` es el nombre del microservicio existente, ej.
`marketplace`).

Archivos:

```
<F>.java                        # @Document
dto/<F>Response.java            # record
dto/Create<F>Request.java       # record con Bean Validation
<F>Mapper.java                  # Document <-> DTO, con valores defensivos
<F>Repository.java              # extends MongoRepository<<F>, String>
<F>Service.java                 # interfaz
<F>ServiceImpl.java             # implementación, inyección por constructor
<F>Controller.java              # @RestController, sin lógica de negocio
```

Y de soporte (necesarios para que `<F>ServiceImpl` compile, siguiendo la regla de `normas` de lanzar
excepciones de dominio en vez de `RuntimeException` genérica):

```
exception/<F>NotFoundException.java
```

Pruebas espejo:

```
<F>MapperTest.java
<F>ServiceImplTest.java         # JUnit 5 + Mockito
<F>RepositoryIT.java            # Testcontainers
```

## `<F>.java`

```java
package com.accuratemedia.<servicio>.<f>;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document("<f>s")
public class <F> {

    @Id
    private String id;
    private String name;

    // TODO: añadir el resto de campos de <F> según el modelo real

    public <F>() {
    }

    public <F>(String id, String name) {
        this.id = id;
        this.name = name;
    }

    public String getId() {
        return id;
    }

    public String getName() {
        return name;
    }
}
```

## `dto/<F>Response.java`

```java
package com.accuratemedia.<servicio>.<f>.dto;

public record <F>Response(String id, String name) {
    // TODO: añadir el resto de campos que debe ver el cliente de la API
}
```

## `dto/Create<F>Request.java`

```java
package com.accuratemedia.<servicio>.<f>.dto;

import jakarta.validation.constraints.NotBlank;

public record Create<F>Request(
        @NotBlank(message = "el nombre de <f> es obligatorio")
        String name
        // TODO: añadir el resto de campos de entrada, cada uno con su validación de Bean Validation
) {
}
```

## `exception/<F>NotFoundException.java`

```java
package com.accuratemedia.<servicio>.<f>.exception;

public class <F>NotFoundException extends RuntimeException {

    public <F>NotFoundException(String id) {
        super("<F> no encontrado: " + id);
    }
}
```

## `<F>Mapper.java`

Con valor defensivo: si `name` viene nulo, se resuelve a un valor por defecto en vez de propagar el
nulo al contrato público.

```java
package com.accuratemedia.<servicio>.<f>;

import com.accuratemedia.<servicio>.<f>.dto.<F>Response;

public final class <F>Mapper {

    private <F>Mapper() {
    }

    public static <F>Response toResponse(<F> entity) {
        return new <F>Response(
                entity.getId(),
                entity.getName() != null ? entity.getName() : "Sin nombre" // regla defensiva
        );
    }
}
```

## `<F>Repository.java`

```java
package com.accuratemedia.<servicio>.<f>;

import org.springframework.data.mongodb.repository.MongoRepository;

public interface <F>Repository extends MongoRepository<<F>, String> {
}
```

## `<F>Service.java`

```java
package com.accuratemedia.<servicio>.<f>;

import com.accuratemedia.<servicio>.<f>.dto.Create<F>Request;

import java.util.List;

public interface <F>Service {

    List<<F>> findAll();

    <F> findById(String id);

    <F> create(Create<F>Request request);
}
```

## `<F>ServiceImpl.java`

Inyección por constructor, nunca `@Autowired` en campo.

```java
package com.accuratemedia.<servicio>.<f>;

import com.accuratemedia.<servicio>.<f>.dto.Create<F>Request;
import com.accuratemedia.<servicio>.<f>.exception.<F>NotFoundException;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class <F>ServiceImpl implements <F>Service {

    private final <F>Repository <f>Repository;

    public <F>ServiceImpl(<F>Repository <f>Repository) {
        this.<f>Repository = <f>Repository;
    }

    @Override
    public List<<F>> findAll() {
        // TODO: aplicar la regla de negocio de filtrado/orden de <f> cuando esté definida
        return <f>Repository.findAll();
    }

    @Override
    public <F> findById(String id) {
        return <f>Repository.findById(id)
                .orElseThrow(() -> new <F>NotFoundException(id));
    }

    @Override
    public <F> create(Create<F>Request request) {
        // TODO: aplicar las reglas de negocio de creación de <f> cuando estén definidas
        <F> entity = new <F>(null, request.name());
        return <f>Repository.save(entity);
    }
}
```

## `<F>Controller.java`

Sin lógica de negocio: valida la entrada, llama al service, devuelve DTOs — nunca la entidad.

```java
package com.accuratemedia.<servicio>.<f>;

import com.accuratemedia.<servicio>.<f>.dto.Create<F>Request;
import com.accuratemedia.<servicio>.<f>.dto.<F>Response;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/<f>s")
public class <F>Controller {

    private final <F>Service <f>Service;

    public <F>Controller(<F>Service <f>Service) {
        this.<f>Service = <f>Service;
    }

    @GetMapping
    public List<<F>Response> findAll() {
        return <f>Service.findAll().stream().map(<F>Mapper::toResponse).toList();
    }

    @GetMapping("/{id}")
    public <F>Response findById(@PathVariable String id) {
        return <F>Mapper.toResponse(<f>Service.findById(id));
    }

    @PostMapping
    public ResponseEntity<<F>Response> create(@Valid @RequestBody Create<F>Request request) {
        <F> created = <f>Service.create(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(<F>Mapper.toResponse(created));
    }
}
```

## Pruebas espejo

`<F>MapperTest.java` — prueba pura, sin Spring:

```java
package com.accuratemedia.<servicio>.<f>;

import com.accuratemedia.<servicio>.<f>.dto.<F>Response;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class <F>MapperTest {

    @Test
    void mapeaUn<F>CompletoASuRespuesta() {
        <F> entity = new <F>("id-1", "ejemplo");

        <F>Response response = <F>Mapper.toResponse(entity);

        assertThat(response.id()).isEqualTo("id-1");
        assertThat(response.name()).isEqualTo("ejemplo");
    }

    @Test
    void aplicaElNombrePorDefectoCuandoNoTieneNombre() {
        <F> entity = new <F>("id-2", null);

        <F>Response response = <F>Mapper.toResponse(entity);

        assertThat(response.name()).isEqualTo("Sin nombre");
    }
}
```

`<F>ServiceImplTest.java` — JUnit 5 + Mockito, cubre solo el andamiaje generado (búsqueda y su
excepción de dominio); las reglas de negocio que falten quedan como `TODO`:

```java
package com.accuratemedia.<servicio>.<f>;

import com.accuratemedia.<servicio>.<f>.exception.<F>NotFoundException;
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
class <F>ServiceImplTest {

    @Mock
    private <F>Repository <f>Repository;

    @InjectMocks
    private <F>ServiceImpl <f>Service;

    @Test
    void devuelveEl<F>CuandoExiste() {
        <F> entity = new <F>("id-1", "ejemplo");
        when(<f>Repository.findById("id-1")).thenReturn(Optional.of(entity));

        <F> result = <f>Service.findById("id-1");

        assertThat(result.getId()).isEqualTo("id-1");
    }

    @Test
    void lanza<F>NotFoundExceptionCuandoNoExiste() {
        when(<f>Repository.findById("no-existe")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> <f>Service.findById("no-existe"))
                .isInstanceOf(<F>NotFoundException.class);
    }

    // TODO: añadir aquí las pruebas de las reglas de negocio de <f> cuando estén definidas
}
```

`<F>RepositoryIT.java` — Testcontainers con MongoDB real, nunca Mongo embebido.

**Requiere Docker corriendo** en la máquina (y en CI) que ejecute `./gradlew test`, más las
dependencias `org.testcontainers:mongodb` y `org.testcontainers:junit-jupiter` en `build.gradle`. Sin
Docker esta prueba falla por entorno, no por código; díselo al dev al generarla para que no se lo
encuentre en el cierre. Detalle en `../../pruebas/references/backend.md`.

```java
package com.accuratemedia.<servicio>.<f>;

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
class <F>RepositoryIT {

    @Container
    static MongoDBContainer mongoDBContainer =
            new MongoDBContainer(DockerImageName.parse("mongo:7.0"));

    @DynamicPropertySource
    static void mongoProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.data.mongodb.uri", mongoDBContainer::getReplicaSetUrl);
    }

    @Autowired
    private <F>Repository <f>Repository;

    @Test
    void guardaYRecupera<F>PorId() {
        <F> entity = new <F>(null, "ejemplo");
        <F> guardado = <f>Repository.save(entity);

        Optional<<F>> recuperado = <f>Repository.findById(guardado.getId());

        assertThat(recuperado).isPresent();
    }
}
```
