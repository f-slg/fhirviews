# fhirviews: FHIR desde R y vistas tabulares con SQL on FHIR

Cliente para servidores HL7 FHIR R4 y motor que convierte recursos FHIR
en tablas siguiendo la especificación SQL on FHIR (`ViewDefinition`).

## Details

### Partes del paquete

- **Cliente FHIR** (funciones `fhir_*`): conectarse a un servidor,
  buscar con paginación automática, leer, crear, actualizar, borrar y
  ejecutar las operaciones `$everything`, `$validate` y `$export` (Bulk
  Data).

- **Terminología** (funciones `tx_*`): `$expand`, `$lookup` y
  `$validate-code`.

- **Vistas** (funciones `vista_*`): ejecutar un `ViewDefinition` sobre
  una lista de recursos, un Bundle o un archivo NDJSON y obtener un
  `data.frame`, con fhirpath.js o con DuckDB.

- **SQL a FHIR**:
  [`fhir_mapa()`](https://f-slg.github.io/fhirviews/reference/fhir_mapa.md),
  [`fhir_desde_tabla()`](https://f-slg.github.io/fhirviews/reference/fhir_mapa.md)
  y
  [`fhir_desde_sql()`](https://f-slg.github.io/fhirviews/reference/fhir_mapa.md)
  construyen Patient, Observation, Encounter, Condition Immunization,
  Specimen y DiagnosticReport con mapeos explicitos.
  [`fhir_escribir()`](https://f-slg.github.io/fhirviews/reference/fhir_escribir.md)
  guarda JSON o NDJSON.

Las expresiones FHIRPath se evalúan con la biblioteca `fhirpath.js` a
través del paquete V8.

### Opciones

- `fhirviews.mostrar_consulta`: los mensajes de error muestran la URL de
  la petición sin los valores de la consulta (`identifier=***`), que
  pueden ser datos de pacientes o credenciales y terminar en registros o
  capturas de pantalla; solo se ven los parámetros de control como
  `_count`. Con `TRUE` se muestra la URL completa, útil para depurar.

- `fhirviews.mostrar_detalles`: con `TRUE`, incluye el contenido del
  servidor en los errores HTTP y respuestas no JSON. Por defecto se
  omite porque puede contener datos de pacientes. El OperationOutcome
  sigue disponible en el campo `outcome` de la condición de error.

- `fhirviews.motor`: motor de FHIRPath (hoy solo `"v8"`).

- `fhirviews.sql_profundidad`: niveles que recorre `repeat` en el motor
  DuckDB (12 por defecto).

- `fhirviews.addin_paginas`: páginas que descarga el complemento de
  RStudio (5 por defecto).

### Limitaciones conocidas

- La evaluacion y escritura JSON conservan los literales decimales de la
  fuente. Los numeros ordinarios de R no conservan escala; modificar las
  listas descarta el JSON original. Los limites decimales SQL admiten
  rutas estaticas con indices explicitos y escalas de -18 a 8, sin
  inferir precision despues de operaciones o iteraciones.

- SQL a FHIR admite Patient, Observation, Encounter, Condition,
  Immunization, Specimen y DiagnosticReport, una fila por recurso, sin
  agrupacion automatica ni recursos contained. Las comprobaciones
  locales no sustituyen la validacion de perfiles con
  [`fhir_validar()`](https://f-slg.github.io/fhirviews/reference/fhir_validar.md).

## See also

Useful links:

- <https://f-slg.github.io/fhirviews/>

- <https://github.com/f-slg/fhirviews>

- Report bugs at <https://github.com/f-slg/fhirviews/issues>

## Author

**Maintainer**: Ronald Fabricio Salas Guerrero
<fabriciosalasguerrero@gmail.com>
([ORCID](https://orcid.org/0000-0001-5077-1522)) \[copyright holder\]

Authors:

- Ronald Fabricio Salas Guerrero <fabriciosalasguerrero@gmail.com>
  ([ORCID](https://orcid.org/0000-0001-5077-1522)) \[copyright holder\]

Other contributors:

- National Library of Medicine (fhirpath.js and ucum-lhc libraries in
  inst/js) \[copyright holder\]

- Health Samurai (fhirpath.js library in inst/js) \[copyright holder\]

- The ANTLR Project (antlr4 runtime bundled in fhirpath.js) \[copyright
  holder\]

- Sasha Koss (date-fns library bundled in fhirpath.js) \[copyright
  holder\]

- Michael Mclaughlin (decimal.js library bundled in fhirpath.js)
  \[copyright holder\]

- Jos de Jong (lossless-json library in inst/js) \[copyright holder\]

- Health Level Seven International (FHIR R4 mapping metadata in
  inst/schema) \[copyright holder\]

- Regenstrief Institute, Inc. (UCUM table bundled in fhirpath.js)
  \[copyright holder\]

- SQL on FHIR project contributors (conformance test suite in
  inst/sof-tests) \[copyright holder\]
