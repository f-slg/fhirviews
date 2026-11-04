# Apoyo del observador — consultar después del primer intento

Estas soluciones ayudan a contrastar R05 y F04. El participante puede consultar
la documentación durante la tarea. Si el observador entrega esta solución o
interviene directamente antes de completarla, registrarlo como ayuda. Los datos
son ficticios; la tarea consiste también en explicar el resultado, no solo copiar.

## R05 y primera parte de F04

```r
library(fhirviews)
archivo <- system.file("extdata", "caso_clinico.ndjson", package = "fhirviews")
v1 <- vista_crear("Patient", c(sexo = "gender"))
v2 <- vista_crear("Patient", c(sexo = "gender", nacimiento = "birthDate"))
t1 <- vista_ejecutar(archivo, v1)
t2 <- vista_ejecutar(archivo, v2)
print(t1)
print(t2)
# Guardar en la carpeta de evidencias del intento, con nombres nuevos:
# writeLines(vista_json(v1), "vista-pacientes-v1.json")
# writeLines(vista_json(v2), "vista-pacientes-v2.json")
originales <- Filter(function(x) identical(x$resourceType, "Patient"),
                    fhir_recursos(archivo))
cat(jsonlite::toJSON(originales, auto_unbox = TRUE, pretty = TRUE))
stopifnot(identical(t1$id, t2$id), identical(t1$sexo, t2$sexo),
          is.character(t2$nacimiento))
```

`vista_crear()` añade `id` automáticamente. La fecha queda como texto para
admitir fechas FHIR parciales. Contrastar valores con el JSON, no asumir que
cualquier columna de texto contiene una fecha clínicamente válida.

## Expansión de name en F04

```r
v_nombres <- vista_leer(list(resource = "Patient", select = list(
  list(column = list(list(name = "id", path = "getResourceKey()", type = "id"))),
  list(forEach = "name", column = list(
    list(name = "orden", path = "%rowIndex", type = "integer"),
    list(name = "apellido", path = "family", type = "string"),
    list(name = "dados", path = "given", type = "string", collection = TRUE)
  ))
)))
nombres <- vista_ejecutar(archivo, v_nombres)
print(nombres)
stopifnot(nrow(nombres) == sum(vapply(originales, function(x) length(x$name), integer(1))))
```

Cada nombre produce una fila y `given` se conserva como colección dentro de ella.
`first()` seleccionaría el primer elemento y podría descartar otros nombres;
`forEach` los recorre. `forEach` no conserva al paciente si la colección está
vacía; `forEachOrNull` permite conservar ese contexto. `%rowIndex` pertenece a la
expansión, no es una clave global. El participante debe poder explicar esas
consecuencias antes de interpretar una cuenta o unir la tabla con otra.

## Contrato y recuperación

- F05: ejecutar `EJERCICIO-F05.R` después de `library(fhirviews)`. Esperado:
  error de esquema en bloque 2, columna valor y una entrega al consumidor.
- F06: el ejemplo instalado debe informar rollback verificado y cinco filas
  después de dos cargas completas. La transacción envuelve la carga completa;
  un `append` ciego a una salida parcial no equivale a ese patrón.
- F07: el alcance es revisión documental de Bulk Data. No marcar como aprobada
  una exportación del entorno del participante que no se ejecutó.

## Revisión de reportes y notificación

El resumen exportado por el formulario es una ficha humana y no sustituye el
`aceptacion.json` generado por el paquete. Revisar ambos. Una decisión declarada
como aceptada con tareas o incidencias bloqueantes se conserva como
`requiere_revision` en la decisión efectiva de la ficha. Esto es un control de
consistencia del formulario, no un dictamen de aptitud clínica.

Antes de cerrar: revisar evidencias, pedir al participante su interpretación,
registrar intervención y contraste, acordar responsable por incidencia y decidir
qué se debe repetir. No tratar los resultados de CI como resultados de usuarios.
