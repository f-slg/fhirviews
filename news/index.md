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
