#' fhirviews: FHIR desde R y vistas tabulares con SQL on FHIR
#'
#' Cliente para servidores HL7 FHIR R4 y motor que convierte recursos FHIR en
#' tablas siguiendo la especificación SQL on FHIR (`ViewDefinition`).
#'
#' ## Partes del paquete
#'
#' * **Cliente FHIR** (funciones `fhir_*`): conectarse a un servidor, buscar
#'   con paginación automática, leer, crear, actualizar, borrar y ejecutar
#'   las operaciones `$everything` y `$validate`.
#' * **Vistas** (funciones `vista_*`): ejecutar un `ViewDefinition` sobre una
#'   lista de recursos, un Bundle o un archivo NDJSON y obtener un
#'   `data.frame`.
#'
#' Las expresiones FHIRPath se evalúan con la biblioteca `fhirpath.js` a
#' través del paquete V8.
#'
#' @keywords internal
"_PACKAGE"
