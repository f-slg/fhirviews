# fhirviews

**fhirviews** permite trabajar con **HL7 FHIR R4** desde R y RStudio
como si fuera Postman, y convertir los recursos FHIR en **tablas** con
el estándar **[SQL on FHIR](https://sql-on-fhir.org/)**
(`ViewDefinition`). Es la primera implementación de SQL on FHIR en R.

- **Cliente FHIR** (`fhir_*`): buscar con paginación automática, leer,
  crear, actualizar, borrar, `$everything` y `$validate`, con errores
  legibles a partir del `OperationOutcome`.
- **Vistas SQL on FHIR** (`vista_*`): un `ViewDefinition` aplicado a una
  lista de recursos, un Bundle o un archivo NDJSON da un `data.frame`.
  Pasa **todas las pruebas *shareable*** del banco oficial de
  conformidad.
- **DuckDB**: las vistas se guardan como tablas para consultarlas con
  SQL.
- **RStudio**: el servidor aparece en el panel *Connections*, y dos
  addins ejecutan una petición o un `ViewDefinition` con un clic.

> **Nota:** fhirviews es un paquete independiente, desarrollado a título
> personal. No es un producto de HL7 ni de ninguna otra institución.

## Instalación

Versión de desarrollo desde GitHub:

``` r

# install.packages("pak")
pak::pak("f-slg/fhirviews")
```

fhirviews usa el paquete [V8](https://cran.r-project.org/package=V8)
para evaluar FHIRPath. En Linux, V8 se instala sin pasos adicionales
(descarga una versión estática del motor si no encuentra `libv8` en el
sistema).

## De un servidor FHIR a una tabla

``` r

library(fhirviews)

con <- fhir_conectar("https://hapi.fhir.org/baseR4")
con
#> <fhir_conexion> https://hapi.fhir.org/baseR4
#>   Servidor:     HAPI FHIR Server 8.13.10-SNAPSHOT/6bd250944e/2026-09-25
#>   Versión FHIR: 4.0.1

# Busca y sigue los enlaces "next" de cada página
pacientes <- fhir_buscar(con, "Patient", gender = "female", `_count` = 50,
                         max_paginas = 3)
pacientes
#> <fhir_recursos> 150 recursos
#>   Patient: 150

# Una vista: una columna por expresión FHIRPath
vista <- vista_crear("Patient", c(
  apellido = "name.first().family",
  nacimiento = "birthDate",
  ciudad = "address.first().city"
))
vista_ejecutar(pacientes, vista)
```

(Los datos del servidor público cambian constantemente; la salida
depende del momento.)

Leer, escribir y otras operaciones:

``` r

paciente <- fhir_leer(con, "Patient", "123")
nuevo <- fhir_crear(con, "paciente.json")     # lista de R, texto JSON o archivo
nuevo <- fhir_actualizar(con, nuevo)
fhir_borrar(con, nuevo)
todo <- fhir_everything(con, "Patient", "123")
fhir_validar(con, list(resourceType = "Patient", gender = "mujer"))
#> No válido: 1 error y 0 advertencias.
#>   severidad codigo     ubicacion mensaje
#> 1 error     processing <NA>      HAPI-0450: Failed to parse request body as
#>   JSON resource. ... Unknown AdministrativeGender code 'mujer'

# Cualquier otra petición, como en Postman o en un archivo .http
fhir_ejecutar_texto("GET Patient/123/_history")
```

Los errores muestran lo que dice el servidor:

``` r

fhir_leer(con, "Patient", "no-existe")
#> Error:
#> ! El servidor respondió 404 Not Found.
#> ✖ GET https://hapi.fhir.org/baseR4/Patient/no-existe
#> • [error] HAPI-2001: Resource Patient/no-existe is not known
```

## ViewDefinition

Las vistas se escriben en el JSON estándar de SQL on FHIR, así que se
pueden compartir con otras implementaciones (Pathling, Aidbox, Google
FHIR Data Pipes…). Con el caso clínico ficticio del taller
[aprende-fhir](https://github.com/f-slg/aprende-fhir), incluido en el
paquete:

``` r

caso <- fhir_recursos(system.file("extdata", "caso_clinico.ndjson",
                                  package = "fhirviews"))

valores <- vista_leer(r"-({
  "resourceType": "ViewDefinition",
  "name": "valores",
  "resource": "Observation",
  "select": [
    {"column": [
      {"name": "id", "path": "getResourceKey()"},
      {"name": "medida", "path": "code.text"}
    ]},
    {"unionAll": [
      {"forEach": "value.ofType(Quantity)", "column": [
        {"name": "valor", "path": "value.toString() + ' ' + unit"}]},
      {"forEach": "value.ofType(CodeableConcept)", "column": [
        {"name": "valor", "path": "text"}]},
      {"forEach": "value.ofType(Ratio)", "column": [
        {"name": "valor", "path": "numerator.value.toString() + ':' + denominator.value.toString()"}]}
    ]}
  ]
})-")
vista_ejecutar(caso, valores)[, c("medida", "valor")]
#>                                              medida                valor
#> 1                              Temperatura corporal              38.4 °C
#> 2                           Frecuencia respiratoria 20 respiraciones/min
#> 3                               Frecuencia cardíaca      102 latidos/min
#> 4                            Sangre oculta en heces             Positivo
#> 5 Salmonella typhi O, anticuerpos (título) en suero                1:160
#> 6                                  Tamaño del tumor               3.5 cm
#> 7                             Receptor de estrógeno             Positivo
#> 8                               Superficie corporal              1.77 m2
```

Se admiten todos los elementos de la especificación: `select` anidados,
`column` (con `type` y `collection`), `forEach`, `forEachOrNull`,
`repeat`, `unionAll`, `where`, `constant` y `%rowIndex`, con las
funciones FHIRPath del perfil *shareable* (`getResourceKey()`,
`getReferenceKey()`, `ofType()`, `extension()`, `join()`, `first()`,
[`exists()`](https://rdrr.io/r/base/exists.html), `empty()`…).

Para explorar los datos y probar expresiones:

``` r

fhir_tabla(caso, tipo = "Patient")          # tabla rápida, sin vista
vista_fhirpath(caso[1], "name.where(use = 'official').text")
#> [1] "Luis Alberto Paredes Cevallos"
```

## Conformidad

El paquete incluye el [banco oficial de
pruebas](https://github.com/FHIR/sql-on-fhir.js/tree/main/tests) de SQL
on FHIR y lo ejecuta en cada comprobación:

``` r

vista_conformidad()
#> Banco de pruebas de SQL on FHIR (FHIR/sql-on-fhir.js@6677c20, 2026-07-09)
#> fhirviews 0.1.0 · fhirpath.js 5.2.1
#>
#>   experimental     7 de  11 aprobadas
#>   shareable      133 de 133 aprobadas
#>   total          140 de 144 aprobadas
```

Las cuatro experimentales que fallan son de `lowBoundary()` y
`highBoundary()` (precisión decimal y zona horaria). Con
`vista_conformidad(descargar = TRUE)` se usa la versión más reciente del
banco, y con `informe = "informe.json"` se genera el informe en el
formato oficial de la [página de
implementaciones](https://sql-on-fhir.org/extra/impls.html).

## SQL con DuckDB

``` r

db <- vista_duckdb(caso, list(
  paciente = vista_crear("Patient", c(nombre = "name.where(use = 'official').text")),
  encuentro = vista_crear("Encounter", c(
    paciente = "subject.getReferenceKey(Patient)", tipo = "serviceType.text")),
  valores = valores
))
DBI::dbGetQuery(db, "
  SELECT p.nombre, e.tipo, v.medida, v.valor
  FROM valores v
  JOIN encuentro e ON v.encuentro = e.id
  JOIN paciente p ON e.paciente = p.id")
```

(Para esta consulta, la vista `valores` necesita además la columna
`encuentro` = `encounter.getReferenceKey(Encounter)`; la viñeta
[*ViewDefinition en
detalle*](https://f-slg.github.io/fhirviews/articles/vistas.html) tiene
el ejemplo completo.)

## Tasas con pobecu

Las vistas se unen con la población oficial del INEC del paquete
[pobecu](https://f-slg.github.io/pobecu/) para calcular tasas por
cantón. La viñeta [*Tasas por cantón con FHIR y
pobecu*](https://f-slg.github.io/fhirviews/articles/tasas-pobecu.html)
lo hace con 755 casos ficticios de dengue:

![Barras horizontales con las tasas ficticias de dengue por 100 000
habitantes de los 15 cantones con tasas más altas de El Oro, Guayas, Los
Ríos y Manabí](reference/figures/README-tasas.png)

## RStudio

- [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md)
  registra el servidor en el panel **Connections**: tipos de recurso,
  columnas y vista previa de los datos. También está en el diálogo *New
  Connection*.
- Addins **Ejecutar petición FHIR** (selecciona
  `GET Patient?family=Paredes`, con cabeceras y cuerpo JSON opcionales)
  y **Ejecutar ViewDefinition** (selecciona un ViewDefinition o abre su
  archivo JSON).

## Cómo funciona

FHIRPath se evalúa con [fhirpath.js](https://github.com/HL7/fhirpath.js)
5.2.1, la biblioteca de la Biblioteca Nacional de Medicina de EE. UU.
(NLM) y Health Samurai, incluida sin modificar en el paquete y ejecutada
con V8. El motor de vistas está escrito en R y evalúa cada expresión
sobre todos los recursos a la vez: una sola llamada a FHIRPath por
expresión y nivel. Los recursos que llegan como JSON (de un servidor o
un archivo NDJSON) pasan a V8 sin volver a convertirse. La capa de
FHIRPath está separada, de modo que en el futuro se podrá cambiar por un
motor escrito en R.

## Más información

- [Primeros
  pasos](https://f-slg.github.io/fhirviews/articles/fhirviews.html)
- [ViewDefinition en
  detalle](https://f-slg.github.io/fhirviews/articles/vistas.html)
- [Tasas por cantón con FHIR y
  pobecu](https://f-slg.github.io/fhirviews/articles/tasas-pobecu.html)
- [Referencia de
  funciones](https://f-slg.github.io/fhirviews/reference/)

## Paquetes relacionados

- [pobecu](https://f-slg.github.io/pobecu/): población del Ecuador por
  provincia, cantón y parroquia.
- [geoecu](https://f-slg.github.io/geoecu/): límites territoriales del
  Ecuador.
- [aprende-fhir](https://github.com/f-slg/aprende-fhir): taller de HL7
  FHIR con un caso clínico ecuatoriano ficticio.
- [fhircrackr](https://cran.r-project.org/package=fhircrackr): otro
  cliente FHIR para R, que aplana recursos con XPath.

## Contribuir

Las preguntas van en
[Discussions](https://github.com/f-slg/fhirviews/discussions) y los
errores o propuestas en
[issues](https://github.com/f-slg/fhirviews/issues/new/choose). Revisa
la [guía de
contribución](https://github.com/f-slg/fhirviews/blob/main/.github/CONTRIBUTING.md).
Este proyecto sigue un [código de
conducta](https://github.com/f-slg/fhirviews/blob/main/.github/CODE_OF_CONDUCT.md);
al participar, te comprometes a respetarlo.

## Licencia

MIT © Ronald Fabricio Salas Guerrero. El paquete incluye fhirpath.js y
el banco de pruebas de SQL on FHIR con sus propias licencias (ver
[`inst/COPYRIGHTS`](https://github.com/f-slg/fhirviews/blob/main/inst/COPYRIGHTS)).

FHIR® y HL7® son marcas registradas de Health Level Seven International;
su uso no implica respaldo de HL7.
