# Changelog

## fhirviews 0.1.0

- Primera versión.

### Cliente FHIR

- [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md),
  [`fhir_buscar()`](https://f-slg.github.io/fhirviews/reference/fhir_buscar.md)
  (paginación automática por los enlaces
  [`next`](https://rdrr.io/r/base/Control.html)),
  [`fhir_leer()`](https://f-slg.github.io/fhirviews/reference/fhir_leer.md),
  [`fhir_crear()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md),
  [`fhir_actualizar()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md),
  [`fhir_borrar()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md),
  [`fhir_everything()`](https://f-slg.github.io/fhirviews/reference/fhir_everything.md),
  [`fhir_validar()`](https://f-slg.github.io/fhirviews/reference/fhir_validar.md),
  [`fhir_capacidades()`](https://f-slg.github.io/fhirviews/reference/fhir_capacidades.md),
  [`fhir_peticion()`](https://f-slg.github.io/fhirviews/reference/fhir_peticion.md),
  [`fhir_ejecutar_texto()`](https://f-slg.github.io/fhirviews/reference/fhir_ejecutar_texto.md)
  y
  [`fhir_disponible()`](https://f-slg.github.io/fhirviews/reference/fhir_disponible.md),
  con httr2.
- `application/fhir+json`, token *bearer* (solo se envía al servidor de
  la conexión), reintentos ante 429/503 y errores legibles a partir del
  `OperationOutcome`, con una clase por código HTTP.
- [`fhir_peticion()`](https://f-slg.github.io/fhirviews/reference/fhir_peticion.md)
  devuelve un objeto `fhir_respuesta` que se imprime con el estado y el
  JSON con sangría, como Postman.

### Vistas SQL on FHIR

- [`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
  aplica un `ViewDefinition` a recursos (listas, Bundles, JSON, NDJSON o
  archivos `.ndjson.gz`) y devuelve un `data.frame`. Admite `select`
  anidados, `column` (`type`, `collection`), `forEach`, `forEachOrNull`,
  `repeat`, `unionAll`, `where`, `constant` y `%rowIndex`. Evalúa por
  lotes, con una llamada a FHIRPath por expresión y nivel.
- [`vista_validar()`](https://f-slg.github.io/fhirviews/reference/vista_validar.md),
  [`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md),
  [`vista_crear()`](https://f-slg.github.io/fhirviews/reference/vista_crear.md),
  [`vista_json()`](https://f-slg.github.io/fhirviews/reference/vista_json.md),
  [`vista_fhirpath()`](https://f-slg.github.io/fhirviews/reference/vista_fhirpath.md),
  [`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md),
  [`fhir_tabla()`](https://f-slg.github.io/fhirviews/reference/fhir_tabla.md)
  y
  [`fhir_vista()`](https://f-slg.github.io/fhirviews/reference/fhir_vista.md)
  (descargar del servidor y aplicar la vista en un paso).
- FHIRPath con fhirpath.js 5.2.1 (HL7/fhirpath.js) en V8, con
  `getResourceKey()` y `getReferenceKey()`. La capa de FHIRPath está
  separada
  ([`fhirviews_motor()`](https://f-slg.github.io/fhirviews/reference/fhirviews_motor.md))
  para poder sustituirla por un motor en R.
- [`vista_conformidad()`](https://f-slg.github.io/fhirviews/reference/vista_conformidad.md)
  ejecuta el banco oficial de pruebas de SQL on FHIR (incluido; o el más
  reciente con `descargar = TRUE`) y genera el informe en el formato
  oficial. Pasan las 133 pruebas *shareable* y 7 de las 11
  experimentales.
- [`vista_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_duckdb.md)
  guarda vistas como tablas de DuckDB (o de otra conexión DBI) para
  consultarlas con SQL.

### RStudio

- El servidor se registra en el panel *Connections* (tipos de recurso,
  columnas, vista previa) y aparece en el diálogo *New Connection*.
- Addins *Ejecutar petición FHIR* y *Ejecutar ViewDefinition*.

### Datos y documentación

- Caso clínico ficticio del taller aprende-fhir
  (`inst/extdata/caso_clinico.ndjson`) y casos ficticios de dengue 2025
  por cantón (`inst/extdata/dengue_2025.ndjson.gz`).
- Viñetas *Primeros pasos con fhirviews*, *ViewDefinition en detalle* y
  *Tasas por cantón con FHIR y pobecu*.
