#' fhirviews: FHIR desde R y vistas tabulares con SQL on FHIR
#'
#' Cliente para servidores HL7 FHIR R4 y motor que convierte recursos FHIR en
#' tablas siguiendo la especificación SQL on FHIR (`ViewDefinition`).
#'
#' ## Partes del paquete
#'
#' * **Cliente FHIR** (funciones `fhir_*`): conectarse a un servidor, buscar
#'   con paginación automática, leer, crear, actualizar, borrar y ejecutar
#'   las operaciones `$everything`, `$validate` y `$export` (Bulk Data).
#' * **Terminología** (funciones `tx_*`): `$expand`, `$lookup` y
#'   `$validate-code`.
#' * **Vistas** (funciones `vista_*`): ejecutar un `ViewDefinition` sobre una
#'   lista de recursos, un Bundle o un archivo NDJSON y obtener un
#'   `data.frame`, con fhirpath.js o con DuckDB.
#'
#' Las expresiones FHIRPath se evalúan con la biblioteca `fhirpath.js` a
#' través del paquete V8.
#'
#' ## Opciones
#'
#' * `fhirviews.mostrar_consulta`: los mensajes de error muestran la URL de
#'   la petición sin los valores de la consulta (`identifier=***`), que
#'   pueden ser datos de pacientes o credenciales y terminar en registros o
#'   capturas de pantalla; solo se ven los parámetros de control como
#'   `_count`. Con `TRUE` se muestra la URL completa, útil para depurar.
#' * `fhirviews.motor`: motor de FHIRPath (hoy solo `"v8"`).
#' * `fhirviews.sql_profundidad`: niveles que recorre `repeat` en el motor
#'   DuckDB (12 por defecto).
#' * `fhirviews.addin_paginas`: páginas que descarga el complemento de
#'   RStudio (5 por defecto).
#'
#' ## Limitaciones conocidas
#'
#' * Los decimales de FHIR se leen como números de JavaScript (y de R), así
#'   que pierden los ceros finales que indican la precisión: `1.10` se lee
#'   como `1.1`. Esto afecta a `toString()` y a las comparaciones de
#'   precisión de FHIRPath, no al valor numérico.
#'
#' @keywords internal
"_PACKAGE"

#' @importFrom rlang abort
NULL
