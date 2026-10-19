# fhirviews <img src="man/figures/logo.png" align="right" height="139" alt="logo de fhirviews" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/f-slg/fhirviews/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/f-slg/fhirviews/actions/workflows/R-CMD-check.yaml)
[![Licencia: MIT](https://img.shields.io/badge/licencia-MIT-blue.svg)](https://github.com/f-slg/fhirviews/blob/main/LICENSE.md)
[![Estado: en desarrollo](https://img.shields.io/badge/estado-en%20desarrollo-F2B705.svg)](https://github.com/f-slg/fhirviews)
<!-- badges: end -->

**fhirviews** permite trabajar con **HL7 FHIR R4** desde R y RStudio como si
fuera Postman, y convertir los recursos FHIR en **tablas** con el estándar
**[SQL on FHIR](https://sql-on-fhir.org/)** (`ViewDefinition`). Es la primera
implementación de SQL on FHIR en R.

> **Estado:** paquete en desarrollo. Esta página describe lo que tendrá la
> versión 0.1.0; las funciones se agregan por etapas.

## ¿Qué hará?

- **Cliente FHIR** (`fhir_*`): conectarse a un servidor, buscar con
  paginación automática, leer, crear, actualizar y borrar recursos, y
  ejecutar `$everything` y `$validate`, con mensajes de error legibles a
  partir del `OperationOutcome`.
- **Vistas SQL on FHIR** (`vista_*`): ejecutar un `ViewDefinition` sobre una
  lista de recursos, un Bundle o un archivo NDJSON y obtener un `data.frame`.
  Las expresiones FHIRPath se evalúan con
  [fhirpath.js](https://github.com/HL7/fhirpath.js) a través del paquete V8.
- **Conformidad**: el banco oficial de pruebas de SQL on FHIR se ejecuta con
  testthat; la meta es pasar todas las pruebas del perfil *shareable*.
- **DuckDB** (opcional): guardar las vistas para consultarlas con SQL.
- **RStudio**: el servidor FHIR como conexión en el panel *Connections* y
  addins para ejecutar una petición o un `ViewDefinition` con un clic.

## Instalación

Versión de desarrollo desde GitHub:

```r
# install.packages("pak")
pak::pak("f-slg/fhirviews")
```

## Paquetes relacionados

- [pobecu](https://f-slg.github.io/pobecu/): población del Ecuador por
  provincia, cantón y parroquia, para calcular tasas con datos clínicos.
- [geoecu](https://f-slg.github.io/geoecu/): límites territoriales del
  Ecuador.
- [aprende-fhir](https://github.com/f-slg/aprende-fhir): taller de HL7 FHIR
  con un caso clínico ecuatoriano ficticio.

## Contribuir

Las preguntas van en
[Discussions](https://github.com/f-slg/fhirviews/discussions) y los errores
o propuestas en [issues](https://github.com/f-slg/fhirviews/issues/new/choose).
Revisa la [guía de contribución](.github/CONTRIBUTING.md). Este proyecto
sigue un [código de conducta](.github/CODE_OF_CONDUCT.md); al participar, te
comprometes a respetarlo.

## Licencia

MIT © Ronald Fabricio Salas Guerrero.

FHIR® y HL7® son marcas registradas de Health Level Seven International;
su uso no implica respaldo de HL7. fhirviews es un paquete independiente.
