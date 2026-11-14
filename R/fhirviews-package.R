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
#' * **SQL a FHIR**: `fhir_mapa()`, `fhir_desde_tabla()` y
#'   `fhir_desde_sql()` construyen Patient y Observation con mapeos
#'   explicitos. `fhir_escribir()` guarda JSON o NDJSON.
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
#' * `fhirviews.mostrar_detalles`: con `TRUE`, incluye el contenido del servidor
#'   en los errores HTTP y respuestas no JSON. Por defecto se omite porque puede
#'   contener datos de pacientes. El OperationOutcome sigue disponible en el
#'   campo `outcome` de la condición de error.
#' * `fhirviews.motor`: motor de FHIRPath (hoy solo `"v8"`).
#' * `fhirviews.sql_profundidad`: niveles que recorre `repeat` en el motor
#'   DuckDB (12 por defecto).
#' * `fhirviews.addin_paginas`: páginas que descarga el complemento de
#'   RStudio (5 por defecto).
#'
#' ## Limitaciones conocidas
#'
#' * La evaluacion y escritura JSON conservan los literales decimales de la
#'   fuente. Los numeros ordinarios de R no conservan escala; modificar las
#'   listas descarta el JSON original. Los limites decimales SQL admiten
#'   rutas estaticas con indices explicitos y escalas de -18 a 8, sin
#'   inferir precision despues de operaciones o iteraciones.
#' * SQL a FHIR admite Patient y Observation, una fila por recurso, sin
#'   agrupacion automatica ni recursos contained. Las comprobaciones locales
#'   no sustituyen la validacion de perfiles con `fhir_validar()`.
#'
#' @keywords internal
"_PACKAGE"

#' @importFrom rlang abort
NULL
