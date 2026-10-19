# fhirviews 0.0.0.9000

* Esqueleto del paquete: licencia MIT, integración continua en Windows,
  macOS y Ubuntu, sitio pkgdown, plantillas de issues, guía de contribución,
  código de conducta y logo.
* Capa de FHIRPath: fhirpath.js 5.2.1 (HL7/fhirpath.js) incluido sin
  modificar en `inst/js/` y ejecutado con V8. Licencias de la biblioteca y de
  sus dependencias empaquetadas en `inst/COPYRIGHTS`.
* `vista_fhirpath()` evalúa expresiones FHIRPath, con las funciones
  `getResourceKey()` y `getReferenceKey()` de SQL on FHIR y variables
  (incluidas fechas).
* `fhir_recursos()` reúne recursos desde listas, Bundles, JSON, NDJSON o
  archivos.
* `fhirviews_motor()` y `fhirviews_version_fhirpath()` informan del motor de
  FHIRPath. El motor de vistas usa una interfaz que permitirá sustituir
  fhirpath.js por un motor escrito en R.
* Motor de ViewDefinition: `vista_ejecutar()` admite `select` anidados,
  `column` (con `collection` y `type`), `forEach`, `forEachOrNull`, `repeat`,
  `unionAll`, `where`, `constant` y `%rowIndex`. Evalúa por lotes: una
  llamada a FHIRPath por expresión y nivel. Pasa las 133 pruebas del perfil
  *shareable* del banco oficial de SQL on FHIR (y 7 de las 11
  experimentales).
* `vista_validar()` revisa la estructura, los nombres de columnas, las
  constantes, las ramas de `unionAll` y las expresiones FHIRPath, y lista
  todos los problemas encontrados.
* `vista_leer()`, `vista_crear()` y `vista_json()` para leer, armar y
  exportar vistas.
* Los recursos leídos de JSON o NDJSON conservan el texto original y se pasan
  a V8 sin volver a convertirlos, lo que acelera mucho las vistas grandes.
* Corregido: en Windows fallaba la carga de fhirpath.js, que contiene bytes
  0x1A (Ctrl-Z); ahora los archivos JavaScript se leen en binario.
* `vista_conformidad()` ejecuta el banco oficial de pruebas de SQL on FHIR
  (copia incluida en `inst/sof-tests/`, de FHIR/sql-on-fhir.js; o la versión
  más reciente con `descargar = TRUE`), resume los resultados por perfil y
  puede guardar el informe en el formato oficial para la página de
  implementaciones. Las pruebas del paquete exigen todas las *shareable*.
* Cliente FHIR con httr2: `fhir_conectar()`, `fhir_buscar()` (sigue los
  enlaces `next` de los Bundles), `fhir_leer()`, `fhir_crear()`,
  `fhir_actualizar()`, `fhir_borrar()`, `fhir_everything()`,
  `fhir_validar()`, `fhir_capacidades()`, `fhir_peticion()` y
  `fhir_disponible()`. Usa `application/fhir+json`, admite token *bearer*,
  reintenta ante 429/503 y convierte el `OperationOutcome` de los errores en
  mensajes legibles. Los resultados de búsqueda conservan el JSON original
  para ejecutar vistas rápidamente.
* `vista_duckdb()` guarda una o varias vistas como tablas en DuckDB (o en
  otra conexión DBI) para consultarlas y unirlas con SQL; las columnas
  `collection` se guardan como listas de DuckDB. DBI y duckdb van en
  Suggests.
* Integración con RStudio: `fhir_conectar()` registra el servidor en el panel
  *Connections* (tipos de recurso, columnas, vista previa y acciones) y lo
  deja como conexión activa (`fhir_conexion_activa()`,
  `fhir_desconectar()`); el diálogo *New Connection* ofrece FHIR; addins
  *Ejecutar petición FHIR* y *Ejecutar ViewDefinition*.
* `fhir_ejecutar_texto()` ejecuta peticiones escritas como en Postman o en
  archivos `.http`; `fhir_vista()` descarga del servidor y aplica una vista
  en un paso; `fhir_tabla()` da una tabla rápida sin ViewDefinition.
* `fhir_peticion()` devuelve un objeto `fhir_respuesta` que se imprime con el
  estado HTTP y el JSON con sangría.
* El token de acceso solo se envía a URL del servidor de la conexión.
