# Motor de FHIRPath y versión de fhirpath.js

fhirviews evalúa FHIRPath con un *motor*. Por ahora el único es `"v8"`:
la biblioteca [fhirpath.js](https://github.com/HL7/fhirpath.js)
ejecutada en el paquete V8. La opción `fhirviews.motor` queda reservada
para elegir otros motores en el futuro.

## Usage

``` r
fhirviews_motor()

fhirviews_version_fhirpath()
```

## Value

`fhirviews_motor()` devuelve, de forma invisible, una lista con el
motor, la versión de fhirpath.js y la del motor de JavaScript.
`fhirviews_version_fhirpath()` devuelve la versión de fhirpath.js
incluida en el paquete, sin iniciar V8.

## Examples

``` r
fhirviews_version_fhirpath()
#> [1] "5.2.1"
fhirviews_motor()
#> Motor de FHIRPath: v8
#> fhirpath.js:       5.2.1
#> V8:                12.4.254.21
```
