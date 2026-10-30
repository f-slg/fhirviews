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

Las expresiones FHIRPath se evalúan con la biblioteca `fhirpath.js` a
través del paquete V8.

### Opciones

- `fhirviews.mostrar_consulta`: los mensajes de error muestran la URL de
  la petición sin los valores de la consulta (`identifier=***`), que
  pueden ser datos de pacientes o credenciales y terminar en registros o
  capturas de pantalla; solo se ven los parámetros de control como
  `_count`. Con `TRUE` se muestra la URL completa, útil para depurar.

- `fhirviews.motor`: motor de FHIRPath (hoy solo `"v8"`).

- `fhirviews.sql_profundidad`: niveles que recorre `repeat` en el motor
  DuckDB (12 por defecto).

- `fhirviews.addin_paginas`: páginas que descarga el complemento de
  RStudio (5 por defecto).

### Limitaciones conocidas

- Los decimales de FHIR se leen como números de JavaScript (y de R), así
  que pierden los ceros finales que indican la precisión: `1.10` se lee
  como `1.1`. Esto afecta a
  [`toString()`](https://rdrr.io/r/base/toString.html) y a las
  comparaciones de precisión de FHIRPath, no al valor numérico.

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

- Regenstrief Institute, Inc. (UCUM table bundled in fhirpath.js)
  \[copyright holder\]

- SQL on FHIR project contributors (conformance test suite in
  inst/sof-tests) \[copyright holder\]
