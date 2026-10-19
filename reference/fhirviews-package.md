# fhirviews: FHIR desde R y vistas tabulares con SQL on FHIR

Cliente para servidores HL7 FHIR R4 y motor que convierte recursos FHIR
en tablas siguiendo la especificación SQL on FHIR (`ViewDefinition`).

## Details

### Partes del paquete

- **Cliente FHIR** (funciones `fhir_*`): conectarse a un servidor,
  buscar con paginación automática, leer, crear, actualizar, borrar y
  ejecutar las operaciones `$everything` y `$validate`.

- **Vistas** (funciones `vista_*`): ejecutar un `ViewDefinition` sobre
  una lista de recursos, un Bundle o un archivo NDJSON y obtener un
  `data.frame`.

Las expresiones FHIRPath se evalúan con la biblioteca `fhirpath.js` a
través del paquete V8.

## See also

Useful links:

- <https://f-slg.github.io/fhirviews/>

- <https://github.com/f-slg/fhirviews>

- Report bugs at <https://github.com/f-slg/fhirviews/issues>

## Author

**Maintainer**: Ronald Fabricio Salas Guerrero
<fabriciosalasguerrero@gmail.com> \[copyright holder\]

Authors:

- Ronald Fabricio Salas Guerrero <fabriciosalasguerrero@gmail.com>
  \[copyright holder\]
