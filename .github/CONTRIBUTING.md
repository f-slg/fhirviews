# Cómo contribuir a fhirviews

¡Gracias por tu interés! Toda ayuda es bienvenida, desde avisar de un error
hasta proponer una función nueva.

## Preguntas

Si tienes una duda de uso ("¿cómo calculo...?", "¿qué significa...?"),
pregunta en [Discussions › Q&A](https://github.com/f-slg/fhirviews/discussions/categories/q-a).
Así la respuesta queda disponible para todos.

## Reportar un problema

Abre un [issue](https://github.com/f-slg/fhirviews/issues/new/choose) y elige la
plantilla que corresponda:

- **Reportar un error:** una función falla o da un resultado incorrecto.
  Incluye un ejemplo mínimo que se pueda copiar y ejecutar.
- **Conformidad con SQL on FHIR:** una vista da un resultado distinto al
  que exige la especificación o al de otra implementación. Incluye el
  `ViewDefinition` y los recursos de ejemplo.
- **Proponer una mejora:** cuéntanos qué necesitas hacer.

## Enviar cambios

1. Haz un *fork* y crea una rama para tu cambio.
2. Si cambias funciones, actualiza la documentación con
   `roxygen2::roxygenise()` y agrega o ajusta tests en `tests/testthat/`.
3. Verifica que el paquete pase `R CMD check` sin errores ni advertencias.
4. Abre un *pull request* explicando qué cambia y por qué.

La biblioteca `fhirpath.js` y el banco oficial de pruebas de SQL on FHIR se
incluyen sin modificar en `inst/`; los scripts de
[`data-raw/`](https://github.com/f-slg/fhirviews/tree/main/data-raw/) los
actualizan. No edites esos archivos a mano.

La documentación y los mensajes del paquete están en español.

## Código de conducta

Este proyecto sigue un [código de conducta](https://github.com/f-slg/fhirviews/blob/main/.github/CODE_OF_CONDUCT.md)
(Contributor Covenant 2.1). Al participar, te comprometes a respetarlo.
