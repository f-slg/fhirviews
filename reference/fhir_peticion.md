# Hacer una petición FHIR cualquiera

Envía una petición HTTP al servidor, al estilo de Postman, y devuelve el
cuerpo de la respuesta como lista de R. Las demás funciones `fhir_*`
cubren los casos habituales; esta sirve para todo lo demás (operaciones
`$`, historial, `_history`, peticiones condicionales, etc.).

## Usage

``` r
fhir_peticion(
  con,
  metodo = "GET",
  ruta = "",
  cuerpo = NULL,
  parametros = list(),
  cabeceras = list()
)
```

## Arguments

- con:

  Conexión creada con
  [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md).

- metodo:

  Método HTTP: `"GET"`, `"POST"`, `"PUT"`, `"PATCH"` o `"DELETE"`.

- ruta:

  Ruta relativa a la base (por ejemplo `"Patient/123/_history"` o
  `"Patient?family=Paredes"`) o URL completa.

- cuerpo:

  Cuerpo de la petición: lista de R, texto JSON o ruta a un archivo
  JSON.

- parametros:

  Lista con nombre de parámetros de consulta. Un vector repite el
  parámetro (equivale a un *Y* en búsquedas FHIR).

- cabeceras:

  Lista con nombre de cabeceras adicionales.

## Value

El cuerpo de la respuesta como lista de R de clase `fhir_respuesta`
(vacía si el servidor no devolvió cuerpo), con los atributos `estado`
(código HTTP) y `cabeceras`. Al imprimirla muestra el estado y el JSON
con sangría, como Postman. Si es un Bundle, se puede pasar a
[`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md),
[`fhir_tabla()`](https://f-slg.github.io/fhirviews/reference/fhir_tabla.md)
o
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md).

## Examples

``` r
con <- fhir_conectar("https://hapi.fhir.org/baseR4")
r <- fhir_peticion(con, "GET", "Patient", parametros = list(`_count` = 1,
                                                          `_summary` = "count"))
r$total
#> [1] 6697
```
