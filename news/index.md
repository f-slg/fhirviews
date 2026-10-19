# Changelog

## fhirviews 0.0.0.9000

- Esqueleto del paquete: licencia MIT, integración continua en Windows,
  macOS y Ubuntu, sitio pkgdown, plantillas de issues, guía de
  contribución, código de conducta y logo.
- Capa de FHIRPath: fhirpath.js 5.2.1 (HL7/fhirpath.js) incluido sin
  modificar en `inst/js/` y ejecutado con V8. Licencias de la biblioteca
  y de sus dependencias empaquetadas en `inst/COPYRIGHTS`.
- [`vista_fhirpath()`](https://f-slg.github.io/fhirviews/reference/vista_fhirpath.md)
  evalúa expresiones FHIRPath, con las funciones `getResourceKey()` y
  `getReferenceKey()` de SQL on FHIR y variables (incluidas fechas).
- [`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md)
  reúne recursos desde listas, Bundles, JSON, NDJSON o archivos.
- [`fhirviews_motor()`](https://f-slg.github.io/fhirviews/reference/fhirviews_motor.md)
  y
  [`fhirviews_version_fhirpath()`](https://f-slg.github.io/fhirviews/reference/fhirviews_motor.md)
  informan del motor de FHIRPath. El motor de vistas usa una interfaz
  que permitirá sustituir fhirpath.js por un motor escrito en R.
- Motor de ViewDefinition:
  [`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
  admite `select` anidados, `column` (con `collection` y `type`),
  `forEach`, `forEachOrNull`, `repeat`, `unionAll`, `where`, `constant`
  y `%rowIndex`. Evalúa por lotes: una llamada a FHIRPath por expresión
  y nivel. Pasa las 133 pruebas del perfil *shareable* del banco oficial
  de SQL on FHIR (y 7 de las 11 experimentales).
- [`vista_validar()`](https://f-slg.github.io/fhirviews/reference/vista_validar.md)
  revisa la estructura, los nombres de columnas, las constantes, las
  ramas de `unionAll` y las expresiones FHIRPath, y lista todos los
  problemas encontrados.
- [`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md),
  [`vista_crear()`](https://f-slg.github.io/fhirviews/reference/vista_crear.md)
  y
  [`vista_json()`](https://f-slg.github.io/fhirviews/reference/vista_json.md)
  para leer, armar y exportar vistas.
- Los recursos leídos de JSON o NDJSON conservan el texto original y se
  pasan a V8 sin volver a convertirlos, lo que acelera mucho las vistas
  grandes.
- Corregido: en Windows fallaba la carga de fhirpath.js, que contiene
  bytes 0x1A (Ctrl-Z); ahora los archivos JavaScript se leen en binario.
- [`vista_conformidad()`](https://f-slg.github.io/fhirviews/reference/vista_conformidad.md)
  ejecuta el banco oficial de pruebas de SQL on FHIR (copia incluida en
  `inst/sof-tests/`, de FHIR/sql-on-fhir.js; o la versión más reciente
  con `descargar = TRUE`), resume los resultados por perfil y puede
  guardar el informe en el formato oficial para la página de
  implementaciones. Las pruebas del paquete exigen todas las
  *shareable*.
