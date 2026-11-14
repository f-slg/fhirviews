# fhirviews

**From FHIR resources to reproducible tables in R, and from SQL to FHIR
through explicit mappings.**

[Español](https://f-slg.github.io/fhirviews/README.md) · **English**

[![R-CMD-check](https://github.com/f-slg/fhirviews/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/f-slg/fhirviews/actions/workflows/R-CMD-check.yaml)
[![Documentation](https://github.com/f-slg/fhirviews/actions/workflows/pkgdown.yaml/badge.svg)](https://f-slg.github.io/fhirviews/)
[![SQL on FHIR:
144/144](https://img.shields.io/badge/SQL%20on%20FHIR-144%2F144-2a78d6.svg)](#conformance-and-tests)
[![FHIR
R4](https://img.shields.io/badge/FHIR-R4-0F2233.svg)](https://hl7.org/fhir/R4/)
[![MIT
license](https://img.shields.io/badge/license-MIT-blue.svg)](https://f-slg.github.io/fhirviews/LICENSE.md)

> **About the language.** This is a translation of the Spanish README.
> The package is aimed at users in Ecuador and Latin America: function
> names, arguments, messages, the reference documentation and the
> vignettes are in Spanish. See the
> [glossary](#glossary-of-function-names) below.

**fhirviews** queries **HL7 FHIR R4** servers and turns their resources
into `data.frame`s using **SQL on FHIR** and **FHIRPath**. Define a view
once, save it as a `ViewDefinition` and reuse it on local files, server
responses or population-level exports.

It also builds **Patient** and **Observation** resources from a
`data.frame` or a SQL query through DBI, with explicit column, constant
and reference mappings. JSON and NDJSON output preserve decimal scale.

It is designed for clinical analysis, research, epidemiological
surveillance and teaching in R. It includes SMART on FHIR
authentication, views for public health and block-wise NDJSON
processing, without installing Java or Spark.

The technical pipeline combines an HTTP client based on `httr2`, a
FHIRPath evaluator using `fhirpath.js` in V8, and an optional SQL
translator for DuckDB. The extraction definition is independent of the
source: the same `ViewDefinition` can be applied to resources fetched
over REST or to local files. Compatibility of the SQL engine is tested
separately.

[Documentation](https://f-slg.github.io/fhirviews/) ·
[Reference](https://f-slg.github.io/fhirviews/reference/) · [What’s new
in 0.5.0](https://f-slg.github.io/fhirviews/NEWS.md) · [Report a
problem](https://github.com/f-slg/fhirviews/issues/new/choose)

![Transformation pipeline: a Patient resource in JSON, columns defined
in a ViewDefinition and the resulting table in
R](reference/figures/README-json-tabla.png)

> **Version 0.5.0 · submitted to CRAN on 7 November 2026, under
> review.** Block-wise processing, export recovery with content
> validation and privacy improvements. The DuckDB SQL engine is still
> **experimental**. Until CRAN publishes it, install it from GitHub.

> **Development version 0.5.0.9000:** adds SQL → FHIR and 144/144
> conformance tests in both engines. These changes belong to the
> development code, not the 0.5.0 candidate previously submitted to
> CRAN.

## Contents

- [Glossary of function names](#glossary-of-function-names)
- [What you can do](#what-you-can-do)
- [Installation](#installation)
- [Quick start: from FHIR to a table](#quick-start-from-fhir-to-a-table)
- [Architecture and processing
  sequence](#architecture-and-processing-sequence)
- [Semantics of a view](#semantics-of-a-view)
- [Choosing how to process the data](#choosing-how-to-process-the-data)
- [Querying a FHIR server](#querying-a-fhir-server)
- [Authentication and bulk export](#authentication-and-bulk-export)
- [Processing files in blocks](#processing-files-in-blocks)
- [Working with DuckDB](#working-with-duckdb)
- [From SQL to FHIR](#from-sql-to-fhir)
- [Public health views and
  terminologies](#public-health-views-and-terminologies)
- [Validation and privacy](#validation-and-privacy)
- [Conformance and tests](#conformance-and-tests)
- [Performance](#performance)
- [Scope and limitations](#scope-and-limitations)
- [Pilot and local documentation](#pilot-and-local-documentation)
- [Guides and reference](#guides-and-reference)
- [Contributing, citation and
  license](#contributing-citation-and-license)

## Glossary of function names

| Spanish | English | Examples |
|----|----|----|
| `vista` | view (`ViewDefinition`) | [`vista_crear()`](https://f-slg.github.io/fhirviews/reference/vista_crear.md) create, [`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md) run, [`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md) read, [`vista_validar()`](https://f-slg.github.io/fhirviews/reference/vista_validar.md) validate |
| `lotes` | blocks / batches | [`vista_ejecutar_lotes()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_lotes.md) run a view block by block |
| `catalogo`, `plantilla` | catalogue, template | [`vista_catalogo()`](https://f-slg.github.io/fhirviews/reference/vista_catalogo.md), [`vista_plantilla()`](https://f-slg.github.io/fhirviews/reference/vista_plantilla.md) |
| `conformidad` | conformance | [`vista_conformidad()`](https://f-slg.github.io/fhirviews/reference/vista_conformidad.md) runs the official test suite |
| `conectar`, `buscar`, `leer` | connect, search, read | [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md), [`fhir_buscar()`](https://f-slg.github.io/fhirviews/reference/fhir_buscar.md), [`fhir_leer()`](https://f-slg.github.io/fhirviews/reference/fhir_leer.md) |
| `crear`, `actualizar`, `borrar` | create, update, delete | [`fhir_crear()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md), [`fhir_actualizar()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md), [`fhir_borrar()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md) |
| `exportar`, `estado` | export, status | [`fhir_exportar()`](https://f-slg.github.io/fhirviews/reference/fhir_exportar.md), [`fhir_exportar_estado()`](https://f-slg.github.io/fhirviews/reference/fhir_exportar.md) |
| `autenticacion` | authentication | [`fhir_auth_backend()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md), [`fhir_auth_cliente()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md), [`fhir_auth_interactiva()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md) |
| `expandir`, `validar_codigo` | expand, validate code | [`tx_expandir()`](https://f-slg.github.io/fhirviews/reference/tx_expandir.md), [`tx_validar_codigo()`](https://f-slg.github.io/fhirviews/reference/tx_validar_codigo.md) |
| `recursos`, `tabla` | resources, table | [`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md), [`fhir_tabla()`](https://f-slg.github.io/fhirviews/reference/fhir_tabla.md) |
| `mapa`, `desde_sql`, `desde_tabla`, `escribir` | mapping, from SQL, from table, write | [`fhir_mapa()`](https://f-slg.github.io/fhirviews/reference/fhir_mapa.md), [`fhir_desde_sql()`](https://f-slg.github.io/fhirviews/reference/fhir_mapa.md), [`fhir_desde_tabla()`](https://f-slg.github.io/fhirviews/reference/fhir_mapa.md), [`fhir_escribir()`](https://f-slg.github.io/fhirviews/reference/fhir_escribir.md) |
| `procesar`, `bloque`, `tamano_lote` | process, block, block size | arguments of [`vista_ejecutar_lotes()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_lotes.md) |
| `diferido`, `estricto` | lazy, strict | arguments of [`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md) and [`vista_ejecutar_lotes()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_lotes.md) |

## What you can do

| Need | Tools |
|----|----|
| Turn JSON, Bundles or R resources into tables | [`vista_crear()`](https://f-slg.github.io/fhirviews/reference/vista_crear.md), [`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md) |
| Query FHIR with automatic paging | [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md), [`fhir_buscar()`](https://f-slg.github.io/fhirviews/reference/fhir_buscar.md), [`fhir_leer()`](https://f-slg.github.io/fhirviews/reference/fhir_leer.md) |
| Access protected servers | [`fhir_auth_cliente()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md), [`fhir_auth_backend()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md), [`fhir_auth_interactiva()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md) |
| Download a population with Bulk Data | [`fhir_exportar()`](https://f-slg.github.io/fhirviews/reference/fhir_exportar.md), [`fhir_exportar_estado()`](https://f-slg.github.io/fhirviews/reference/fhir_exportar.md) |
| Read NDJSON and gzip without holding the whole output in memory | [`vista_ejecutar_lotes()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_lotes.md) |
| Run a SQL-translatable view on NDJSON or Parquet | [`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md) — experimental |
| Query several tables with SQL | [`vista_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_duckdb.md) — views evaluated with V8 and stored in one transaction |
| Build Patient and Observation from SQL queries or tables | [`fhir_mapa()`](https://f-slg.github.io/fhirviews/reference/fhir_mapa.md), [`fhir_desde_tabla()`](https://f-slg.github.io/fhirviews/reference/fhir_mapa.md), [`fhir_desde_sql()`](https://f-slg.github.io/fhirviews/reference/fhir_mapa.md) |
| Save resources preserving original JSON decimals | [`fhir_escribir()`](https://f-slg.github.io/fhirviews/reference/fhir_escribir.md) — JSON or NDJSON |
| Start from public health views | [`vista_catalogo()`](https://f-slg.github.io/fhirviews/reference/vista_catalogo.md), [`vista_plantilla()`](https://f-slg.github.io/fhirviews/reference/vista_plantilla.md) |
| Define cohorts with the codes of a ValueSet | [`tx_expandir()`](https://f-slg.github.io/fhirviews/reference/tx_expandir.md), [`vista_con_valueset()`](https://f-slg.github.io/fhirviews/reference/vista_con_valueset.md) |
| Write and validate resources on the server | [`fhir_crear()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md), [`fhir_actualizar()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md), [`fhir_borrar()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md), [`fhir_validar()`](https://f-slg.github.io/fhirviews/reference/fhir_validar.md) |

A `ViewDefinition` describes the columns, filters and collections to
extract, using FHIRPath expressions. Keeping that definition next to the
analysis makes the transformation decisions explicit and easier to
review.

``` mermaid
flowchart LR
    A["JSON / NDJSON / gzip files"] --> V["ViewDefinition + FHIRPath"]
    B["FHIR R4 server"] --> C["Client and Bulk Data export"]
    C --> V
    V --> D["data.frame in R"]
    V --> E["One table per block"]
    V --> F["DuckDB SQL · experimental"]
    D --> G["Analysis, indicators and dashboards"]
    E --> G
    F --> G
```

## Installation

The client and the V8 engine require **R ≥ 4.1.0**. The repository is
public and you can install from GitHub. If the maintainer gave you a
`.tar.gz` file for the pilot, follow the [local
installation](#pilot-and-local-documentation) instructions.

Install from GitHub:

``` r

install.packages("pak")  # once
pak::pak("f-slg/fhirviews")
```

The main branch keeps receiving changes. To reproduce an analysis,
install a specific commit and keep
[`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html) together
with the view and the data:

``` r

pak::pak("f-slg/fhirviews@<commit-SHA>")
```

FHIRPath is evaluated with
[fhirpath.js](https://github.com/HL7/fhirpath.js), bundled with the
package, through [V8](https://cran.r-project.org/package=V8). On systems
with binaries available, installing V8 needs no extra steps. If you
build from source, see its [installation
instructions](https://github.com/jeroen/V8#installation).

Install the optional dependencies that your workflow needs:

| Feature | Additional packages |
|----|----|
| DuckDB tables and SQL engine | `DBI`, `duckdb` ≥ 1.3.0; the current DuckDB version requires R ≥ 4.2 |
| Lazy queries on DuckDB | The above, plus `dplyr` and `dbplyr` |
| SMART Backend Services, with a signed JWT | `jose`, `openssl` |
| Interactive login, with PKCE | `httpuv` |
| RStudio addins and Connections pane | `rstudioapi` |

``` r

# Example: enable DuckDB
install.packages(c("DBI", "duckdb"))
```

## Quick start: from FHIR to a table

This example uses **fictitious data bundled with the package**. Once
installed, it works offline and needs no optional dependencies.

``` r

library(fhirviews)

archivo <- system.file("extdata", "caso_clinico.ndjson", package = "fhirviews")

signos <- vista_crear(
  "Observation",
  c(fecha  = "effective.ofType(dateTime)",
    medida = "code.text",
    valor  = "value.ofType(Quantity).value",
    unidad = "value.ofType(Quantity).unit"),
  where = "value.ofType(Quantity).exists()"
)

tabla <- vista_ejecutar(archivo, signos)
tabla[, c("id", "medida", "valor", "unidad")]
#>          id                  medida  valor            unidad
#> 1  obs-temp    Temperatura corporal  38.40                °C
#> 2    obs-fr Frecuencia respiratoria  20.00 respiraciones/min
#> 3    obs-fc     Frecuencia cardíaca 102.00       latidos/min
#> 4 obs-tumor        Tamaño del tumor   3.50                cm
#> 5   obs-bsa     Superficie corporal   1.77                m2
```

The view selects `Observation`, keeps those with a `valueQuantity` and
extracts four columns (date, measure, value and unit).
[`vista_crear()`](https://f-slg.github.io/fhirviews/reference/vista_crear.md)
adds the resource key in `id`. You can also start from a view in the
catalogue:

``` r

tabla_catalogo <- vista_ejecutar(archivo, vista_plantilla("signos_vitales"))
head(tabla_catalogo)

# Save the definition as JSON to version or share it
json_vista <- vista_json(signos)
writeLines(json_vista, "signos-vitales.json")
vista_reutilizable <- vista_leer("signos-vitales.json")
```

## Architecture and processing sequence

Responsibilities are split into four layers. The client fetches
resources; the definition declares the extraction; the engines produce
rows; the consumer decides how to store, summarise or query the result.

``` mermaid
flowchart TB
    subgraph EN["1. Input"]
        REST["FHIR R4 server"]
        FILE["JSON, Bundle, NDJSON or gzip"]
        PAR["Parquet"]
    end
    subgraph AC["2. Access and definition"]
        HTTP["httr2: REST, SMART and Bulk Data"]
        RES["fhir_recursos(): lists and source JSON"]
        VIEW["ViewDefinition: resource, where, select and constant"]
        VALID["vista_validar(): structure and expressions"]
    end
    subgraph EX["3. Execution"]
        V8["vista_ejecutar(): fhirpath.js in V8"]
        LOT["vista_ejecutar_lotes(): incremental reading and V8"]
        SQL["vista_ejecutar_duckdb(): experimental SQL translation"]
    end
    subgraph OUT["4. Consumption"]
        DF["Complete data.frame"]
        CB["procesar(tabla, bloque)"]
        DB["DuckDB table or lazy query"]
    end
    REST --> HTTP --> RES
    FILE --> RES --> V8 --> DF
    FILE -->|"NDJSON and gzip only"| LOT --> CB
    HTTP -->|"Exported files"| LOT
    HTTP -->|"Exported files"| SQL
    FILE -->|"NDJSON"| SQL
    PAR --> SQL
    VIEW --> VALID
    VALID --> V8
    VALID --> LOT
    VALID --> SQL
    SQL --> DF
    SQL --> DB
```

To build a reproducible analysis, follow this sequence:

1.  **Identify the input:** server, files and expected FHIR version.
2.  **Define the view:** resource, filters, columns, types and list
    expansion.
3.  **Check a sample:** compare the rows with the original JSON using
    V8.
4.  **Choose the execution:** in-memory table, blocks or SQL over files.
5.  **Control persistence:** a transaction or a temporary destination,
    depending on the consumer.
6.  **Reconcile results:** included and excluded events, references and
    aggregates.
7.  **Keep evidence:** view JSON, input identity, versions and checks.

Batch evaluation in
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
groups V8 calls for resources that are already loaded. Block-wise
reading in
[`vista_ejecutar_lotes()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_lotes.md)
also splits the input file; these are two different levels of
processing.

## Semantics of a view

A `ViewDefinition` describes a declarative transformation. It is not a
SQL query written by the user: its paths are FHIRPath expressions, and
the engine applies them to resources of the type given in `resource`.

| Element | Responsibility | Effect on rows |
|----|----|----|
| `resource` | Choose the input FHIR type | Other types are ignored |
| `where` | Evaluate boolean conditions on the resource | Drops resources that do not match |
| `column` | Evaluate a path and give it a name and type | Adds columns to the current context |
| `forEach` | Iterate over a collection | One row per element; none if empty |
| `forEachOrNull` | Iterate, keeping the context when there are no elements | Keeps one row with missing values |
| `select` | Compose nested extractions | Parts are combined within the same source |
| `unionAll` | Concatenate branches with compatible columns | Keeps the rows of every branch, including duplicates |
| `constant` | Declare parameters used by the expressions | Lets you adjust filters without rewriting paths |
| `repeat` | Traverse nested structures along the declared paths | Expands descendants to extract rows from recursive structures |
| `collection: true` | Keep several values in one column | Produces a list column |

``` mermaid
flowchart TD
    A["Resources of the declared type"] --> B["Evaluate where"]
    B --> C["Walk select"]
    C --> D["column: evaluate paths"]
    C --> E["forEach: expand collection"]
    C --> F["unionAll: run branches"]
    E --> G["Evaluate columns on the child element"]
    D --> H["Combine rows per source resource"]
    G --> H
    F --> H
    H --> I["Apply types and build the data.frame"]
```

A scalar column that returns several values raises an error: declare
`collection: true` to keep them, or use an expression that returns a
single value. Two collections expanded in sibling parts can multiply the
rows of a resource, so check both cardinality and keys before counting
events or joining tables. `%rowIndex` gives the index of the element
within its expansion context; it does not replace the resource key.

## Choosing how to process the data

| Situation | Function | Where the result goes |
|----|----|----|
| Resources and table fit in memory | [`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md) | A complete `data.frame` |
| You want to read NDJSON or gzip in blocks with FHIRPath in V8 | [`vista_ejecutar_lotes()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_lotes.md) | To the `procesar(tabla, bloque)` function you define |
| You have NDJSON or Parquet and a view supported by the SQL translator | [`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md) | In R, a DuckDB table or a lazy query |
| You want to query several views evaluated with V8 together | [`vista_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_duckdb.md) | Tables in a DBI connection |

Block-wise processing limits the input read at each step. Total memory
also depends on the rows produced by the view and on what your function
keeps. In DuckDB, use `tabla` or `diferido = TRUE` to avoid bringing the
whole output into R.

## Querying a FHIR server

The following example uses a public test server and needs an internet
connection:

``` r

con <- fhir_conectar("https://hapi.fhir.org/baseR4")

pacientes <- fhir_buscar(
  con, "Patient", `_count` = 20, max_paginas = 2, progreso = FALSE
)

vista_pacientes <- vista_crear(
  "Patient", c(sexo = "gender", nacimiento = "birthDate")
)
vista_ejecutar(pacientes, vista_pacientes)
```

The search follows the server’s
[`next`](https://rdrr.io/r/base/Control.html) links. `_count` requests
the page size; `max_paginas` limits the number of pages downloaded.
Availability and results of public servers may vary.

``` mermaid
sequenceDiagram
    autonumber
    participant R as R session
    participant C as httr2 client
    participant S as FHIR server
    R->>C: fhir_buscar(con, type, parameters)
    C->>S: GET with search parameters
    S-->>C: Bundle with entry, total and next link
    loop While there is a next link and max_paginas is not reached
        C->>S: GET the next URL
        S-->>C: Next Bundle
    end
    C-->>R: fhir_recursos with resources and source JSON
    R->>R: vista_ejecutar(resources, view)
    Note over C,S: A repeated next link stops paging with a warning
```

Paging follows the link provided by the server; it does not compute page
numbers. The connection’s headers and token are restricted to its FHIR
base URL. Bulk Data files have their own origin and authorisation
policy.

Use `fhir_capacidades(con)` to see the resources and operations the
server supports,
[`fhir_leer()`](https://f-slg.github.io/fhirviews/reference/fhir_leer.md)
to read a specific resource and
[`fhir_everything()`](https://f-slg.github.io/fhirviews/reference/fhir_everything.md)
to request `$everything`. In RStudio, the **Connections** pane lets you
browse resources, and the addins run FHIR requests or views from the
editor.

## Authentication and bulk export

For SMART Backend Services, first register the client and its public key
with the authorisation server. The private key must be RSA with at least
2048 bits, or EC P-384.

``` r

# Replace the URL, the client ID and the key with those of your environment
con <- fhir_conectar(
  "https://fhir.hospital.ejemplo/r4",
  autenticacion = fhir_auth_backend(
    "tablero-vigilancia", "~/.claves/privada.pem",
    alcances = "system/*.rs", kid = "clave-2026"
  )
)

# Start the job and keep its reference before downloading
exp <- fhir_exportar(
  con, "paciente", tipos = c("Patient", "Condition"),
  carpeta = "exportacion", esperar = FALSE
)
exp <- fhir_exportar_estado(exp, esperar = TRUE)
```

The client obtains and renews the token. The export honours
`Retry-After` and checks the NDJSON it receives before recording each
file as complete: JSON content, resource type and count when the
manifest includes it. gzip files are also supported.

If a download is interrupted, run
`exp <- fhir_exportar_estado(exp, esperar = TRUE)` again, keeping the
object and the folder. Complete files from the same job are reused if
their checksum matches; missing or altered files are downloaded again.
Each incomplete file restarts from the beginning. Recovery depends on
the server keeping the job and its download URLs.

``` mermaid
sequenceDiagram
    autonumber
    participant R as R session
    participant A as Authorisation server
    participant F as FHIR server
    participant D as Local files
    R->>A: Request a token with SMART credentials
    A-->>R: access_token and expiry
    R->>F: GET Patient/$export with Prefer respond-async
    F-->>R: 202 and Content-Location
    loop Until finished or max_espera is reached
        R->>F: Poll Content-Location
        F-->>R: 202 with Retry-After, or 200 with manifest
    end
    loop For each ready file in the manifest
        R->>D: Check job identity and checksum
        alt Complete reusable file
            D-->>R: Use local file
        else Missing or altered file
            R->>F: Download output URL as authorised
            F-->>R: NDJSON or gzip
            R->>R: Validate JSON, type and declared count
            R->>D: Publish complete file and checksum record
        end
    end
    Note over R,D: A failed download keeps the previous complete files
```

The manifest is the contract for the download, not a guarantee of
clinical quality. Content validation and the checksum verify different
things: the first checks that the NDJSON is as expected; the second
detects changes to the local file between retries. Recovery works on
whole files, without resuming partial bytes or guaranteeing that the
server’s URLs are still valid.

*Client credentials* with a secret and interactive login with PKCE are
also available. See the [authentication and Bulk Data
guide](https://f-slg.github.io/fhirviews/articles/servidores-y-volumen.html)
(in Spanish).

## Processing files in blocks

This complete example walks through the bundled file and prints a
summary per block. The processing function can write each table to a
database or compute aggregates:

``` r

archivo <- system.file("extdata", "caso_clinico.ndjson", package = "fhirviews")
vista <- vista_crear("Observation", c(medida = "code.text"))

totales <- vista_ejecutar_lotes(
  archivo, vista,
  procesar = function(tabla, bloque) {
    cat("Bloque", bloque, ":", nrow(tabla), "filas\n")
  },
  tamano_lote = 20
)
totales
```

For your own export, replace `archivo` with your NDJSON or `.ndjson.gz`
paths. The return value contains `bloques`, `recursos` and `filas`
(blocks, resources and rows); the results of the `procesar()` function
are discarded.

### Strict contract before writing

Set `estricto = TRUE` and declare `type` in **every** column. The
contract is checked up front and must match across the branches of
`unionAll`:

``` r

vista <- vista_leer(list(
  resource = "Observation",
  where = list(list(path = "value.ofType(Quantity).exists()")),
  select = list(list(column = list(
    list(name = "id", path = "getResourceKey()", type = "id"),
    list(name = "valor", path = "value.ofType(Quantity).value", type = "decimal")
  )))
))

vista_ejecutar_lotes(
  archivo, vista,
  procesar = function(tabla, bloque) {
    cat("Bloque validado:", bloque, "Filas:", nrow(tabla), "\n")
  },
  tamano_lote = 20, estricto = TRUE
)
```

Every value is validated **before** the block is delivered. Numeric
strings are not converted to numbers, nor numbers to strings. Integers
must be finite, integral and representable in R; the ranges of
`positiveInt` and `unsignedInt` are enforced. Non-finite numbers are
rejected in the input and in the results before serialisation could turn
them into missing values. Decimals must be finite. Missing values become
typed `NA`s, and collection elements are checked too. Text types do not
validate the format of dates, URIs or clinical codes here.

An error of class `fhirviews_error_lotes` reports `bloque`, `fase`,
`indice_archivo`, `completados` and, where relevant, `columna`,
`tipo_esperado` and `motivo` (block, phase, file index, completed
blocks, column, expected type and reason). The phase distinguishes
`esquema`, `lectura`, `evaluacion` and `procesar` (schema, reading,
evaluation and processing). Messages omit the values and the original
error from the destination. Block 0 means an incompatible definition
detected before reading.

With `estricto = FALSE`, the usual behaviour applies: types can be
inferred per block, and incompatible conversions may produce warnings
and keep the values unconverted.

``` mermaid
sequenceDiagram
    autonumber
    participant L as NDJSON reader
    participant V as V8 engine
    participant T as Strict contract
    participant P as procesar
    L->>T: Check type and collection before reading
    loop For each block of lines
        L->>L: Parse resources and check finite numbers
        L->>V: Evaluate filters and columns
        V->>T: Validate values before converting
        alt Compatible block
            T-->>V: Columns with declared types
            V-->>L: Table and release of nodes
            L->>P: Deliver table and block number
            P-->>L: Return without error
            L->>L: Update completed counters
        else Incompatible value or cardinality
            T-->>L: Structured error
            Note over L,P: The rejected block is not delivered to the consumer
        end
    end
```

The error stops the run. Upfront validation protects the delivery of the
block; the atomicity of whatever `procesar()` writes depends on the
destination and on the transaction set up by the consumer.

### Recovery and partial writes

[`vista_ejecutar_lotes()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_lotes.md)
stops the load on failure and does not retry writes. The block that
fails in `procesar()` may have been partially written. The `completados`
counters count calls that returned without error; they do not confirm
persistence and are not a safe checkpoint for skipping blocks.

The following example uses fictitious data and a temporary DuckDB
database. It runs a load inside a transaction, forces a failure after
writing, checks the rollback and repeats the full load twice:

``` r

# Requires DBI and duckdb; needs no server and no DuckDB JSON extension
source(system.file("examples", "lotes-transaccion.R", package = "fhirviews"))
```

The strategy replaces the whole result within the same transaction, so a
retry does not add another copy. It does not deduplicate events already
present in the input. To use another database, check its transaction
support and limits. For files or destinations without rollback, write to
a new temporary folder and publish the set only after validating the
full load. Keep the input, its order, the view and the block size; do
not resume with a blind `append` onto partial output.

``` mermaid
sequenceDiagram
    autonumber
    participant R as Load in R
    participant B as Database
    R->>B: BEGIN and replace the result within the transaction
    loop Validated blocks
        R->>B: Insert rows
    end
    alt The whole load succeeds
        R->>B: COMMIT
        B-->>R: New result persisted
    else Reading, evaluation or writing fails
        R->>B: ROLLBACK
        B-->>R: Previous result kept
        R->>R: Fix the cause and repeat the whole load
    end
```

## Working with DuckDB

The **experimental** SQL engine translates a `ViewDefinition` into a
DuckDB query. It is useful when the input is large and the view can be
expressed in the FHIRPath subset that the translator supports:

``` r

archivo <- system.file("extdata", "caso_clinico.ndjson", package = "fhirviews")
vista <- vista_crear("Patient", c(sexo = "gender"))

pacientes_sql <- vista_ejecutar_duckdb(archivo, vista)
vista_sql(vista)  # inspect the generated query
```

Test the view first with
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
on a representative sample. Expressions that the translator does not
support raise an error. For your own NDJSON or Parquet files, use their
paths instead of `archivo`.

The SQL engine needs DuckDB’s `json` extension and may download it the
first time. In offline environments, prepare the extension for the same
DuckDB version and check `LOAD json` before running the process. The
standard vignette build avoids that download; its SQL examples are
enabled explicitly with `FHIRVIEWS_VINETAS_DUCKDB=true`.

To store several views evaluated with the V8 engine and query them with
SQL, use
[`vista_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_duckdb.md).
This function writes the tables in one transaction; it does not use the
experimental translator.

### Choosing the SQL result

| Option | Execution and result | Typical use |
|----|----|----|
| Default | Runs the SQL and collects the result into a `data.frame` | Final tables that fit in R |
| `tabla = "name"` | Materialises the result in DuckDB and returns the connection | Later queries without moving the whole table |
| `diferido = TRUE` | Returns a dbplyr query bound to the connection | Filter or aggregate before `collect()` |

``` mermaid
flowchart TD
    A["Validated ViewDefinition"] --> B["FHIRPath to SQL translator"]
    B --> C{"Supported expressions?"}
    C -->|"No"| X["Error: revise the view or choose V8"]
    C -->|"Yes"| D["DuckDB query over NDJSON or Parquet"]
    D --> E["data.frame in R"]
    D --> F["Table materialised in DuckDB"]
    D --> G["dbplyr lazy query"]
    G --> H["Filter, group and collect"]
```

`tabla` and `diferido = TRUE` are mutually exclusive. There is no
automatic fallback to V8 when translation fails. A lazy query may read
the files again when it runs, so its inputs must remain available. Close
the connections you create when you are done; lazy results depend on
their connection staying open.

## From SQL to FHIR

[`fhir_desde_sql()`](https://f-slg.github.io/fhirviews/reference/fhir_mapa.md)
runs a query through an open **DBI** connection and builds resources
according to a
[`fhir_mapa()`](https://f-slg.github.io/fhirviews/reference/fhir_mapa.md).
[`fhir_desde_tabla()`](https://f-slg.github.io/fhirviews/reference/fhir_mapa.md)
applies the same mapping to a `data.frame`. This first version supports
**Patient and Observation from FHIR R4 4.0.1**.

``` mermaid
flowchart LR
    DB["SQL query / data.frame"] --> M["Explicit fields and R4 types"]
    M --> R["Patient / Observation"]
    R --> J["JSON / NDJSON"]
    R --> V["ViewDefinition → table"]
    R --> C["Profile validation with fhir_validar"]
```

SQL on FHIR defines a tabular **projection**. Rebuilding resources needs
a separate mapping: filters, `first()`, `join()`, aggregation or omitted
columns may discard information. An arbitrary `ViewDefinition` cannot be
automatically reversed, and reconstruction of the original resource is
not guaranteed.

### Complete SQL example

This uses an in-memory SQLite database and fictional data. Install `DBI`
and `RSQLite` if needed. For DuckDB, PostgreSQL or SQL Server, use the
corresponding DBI connection and adapt the query syntax. Function and
argument names remain in Spanish.

``` r

library(fhirviews)
con_db <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")

DBI::dbWriteTable(con_db, "pacientes", data.frame(
  paciente_id = c("p1", "p2"), sexo = c("female", "male"),
  nacimiento = c("1985-03-12", "2001-11-30"),
  apellido = c("Paredes", "Salazar"), nombre = c("Ana", "Jorge")
))
DBI::dbWriteTable(con_db, "resultados", data.frame(
  resultado_id = c("o1", "o2"), paciente_id = c("p1", "p2"),
  valor = c("98.00", "131.0"), unidad = c("mg/dL", "mg/dL")
))

mapa_pacientes <- fhir_mapa("Patient", c(
  id = "paciente_id", gender = "sexo", birthDate = "nacimiento",
  "name[0].family" = "apellido", "name[0].given[0]" = "nombre"
))
pacientes <- fhir_desde_sql(con_db,
  "SELECT * FROM pacientes ORDER BY paciente_id", mapa_pacientes)

mapa_resultados <- fhir_mapa("Observation", c(
  id = "resultado_id", "subject.reference" = "paciente_id",
  "valueQuantity.value" = "valor", "valueQuantity.unit" = "unidad"
), constantes = list(
  status = "final", "code.text" = "Glucosa"
), referencias = c("subject.reference" = "Patient"))
observaciones <- fhir_desde_sql(con_db,
  "SELECT * FROM resultados ORDER BY resultado_id", mapa_resultados)

observaciones[[1]]$subject$reference  # "Patient/p1"
vista_fhirpath(observaciones, "value.ofType(Quantity).value")  # 98, 131

salida <- tempfile(fileext = ".ndjson")
fhir_escribir(c(pacientes, observaciones), salida)
fhir_escribir(observaciones, tempfile(fileext = ".json"), formato = "json")

# Extract fields from the generated resources again
vista <- vista_crear("Observation", c(
  paciente = "subject.getReferenceKey(Patient)",
  valor = "value.ofType(Quantity).value"
))
vista_ejecutar(salida, vista)
#   id paciente valor
# 1 o1       p1    98
# 2 o2       p2   131

# Bind values through the driver instead of interpolating SQL strings
uno <- fhir_desde_sql(con_db,
  "SELECT * FROM pacientes WHERE paciente_id = ?", mapa_pacientes,
  parametros = list("p1"))
DBI::dbDisconnect(con_db)
```

Parameter placeholders depend on the driver: SQLite/DuckDB use `?`,
whereas RPostgres uses `$1`. Joins, filters and code translations belong
in the query or preprocessing. `status = "final"` and the measurement
name are explicit choices for this example, not defaults. Supply the
appropriate code systems, codes and units for your actual data and
profiles.

### Mapping rules

| Element | Behaviour |
|----|----|
| `campos` | Named character vector: names are FHIR JSON destinations, values are source column names. |
| `constantes` | Named list of fixed values. Destinations cannot overlap with `campos`. |
| `referencias` | `.reference` destination → target resource type; the key `p1` becomes `Patient/p1`. Supply keys, not URLs or prefixed references. |
| `name[0].family` | Zero-based indices. Repeating elements require an index. |
| `name[0].given[]` | Primitive collection from a list-column. `[]` is allowed only at the end. |
| Choice elements | Use concrete JSON names such as `valueQuantity.value` and `deceasedBoolean`; mappings do not evaluate FHIRPath. |
| `NA`, `NULL`, `""`, empty collections | Omitted. Empty objects and positions are compacted; indices identify construction positions, not persistent `null` gaps. |
| `id` | Must be mapped, valid and unique in the result. Safe integers are converted to text. |
| Booleans and integers | Require logical or in-range integral values. Strings such as `"false"` are not coerced and `1.7` is not truncated. |
| Dates | Accept valid partial FHIR dates and `Date`. Date-times require a timezone; `POSIXct`/`POSIXlt` become UTC. |
| Errors | Class `fhirviews_error_mapeo`, with `fila` and `campo` when known. |

For multiple given names, prepare one row per patient and a list-column:

``` r

datos <- data.frame(id = "p1")
datos$nombres <- list(c("Ana", "Lucía"))
mapa <- fhir_mapa("Patient", c(id = "id", "name[0].given[]" = "nombres"))
fhir_desde_tabla(datos, mapa)
```

Duplicate resource IDs are rejected rather than grouped or overwritten.
Group multi-row query results before mapping them. A query with no rows
produces zero resources.

### Decimals, validation and output

Decimal destinations accept numbers or **numeric JSON literals supplied
as text**. `"1.00"` is written as the JSON number `1.00`, without
quotes. If a DBI driver converts `DECIMAL(p,s)` to a double, trailing
zeros have already been lost: select it as text using your database’s
`CAST`. Also use text for BIGINT identifiers outside the safe integer
range. `NaN`, numeric infinities and incompatible conversions are
rejected.

[`fhir_escribir()`](https://f-slg.github.io/fhirviews/reference/fhir_escribir.md)
preserves the available original JSON literals and replaces the output
file. NDJSON contains one resource per line; `formato = "json"` contains
an array, not a transaction Bundle. Editing the R resource lists
discards their original source; lost decimal scale cannot be recovered
from ordinary R numbers. Conversion does not send resources to a FHIR
server.

When reading resources back from a server, use the source-preserving
mode. The default read returns an ordinary R list and does not retain
decimal scale:

``` r

# con_fhir is a connection created with fhir_conectar()
originales <- fhir_leer(con_fhir, "Observation", "o1", como_recursos = TRUE)
vista_fhirpath(originales, "value.ofType(Quantity).value.lowBoundary()")
fhir_escribir(originales, tempfile(fileext = ".ndjson"))
```

`como_recursos = TRUE` returns a `fhir_recursos` collection. The default
stays an ordinary list for compatibility. `72.00` cannot be recovered
from a list that has already converted it to `72`.

Local checks cover paths, types, cardinalities, required base elements,
incompatible choice fields, `Patient.gender` and `Observation.status`
codes. **They are not full FHIR validation**: use
`fhir_validar(con, recurso, perfil = "canonical-URL")` to check
profiles, invariants and terminologies with your selected server.

[`fhir_desde_sql()`](https://f-slg.github.io/fhirviews/reference/fhir_mapa.md)
collects the full query result in memory and leaves the connection open
for its caller to close. Automatic row grouping, `contained` resources,
bulk upload and `StructureMap` translation are outside this first
version. An executable example is installed at
`system.file("examples", "sql-a-fhir.R", package = "fhirviews")`.

### Planned support for other resources

The reader and view engine already work with other FHIR resource types.
The **Patient and Observation** restriction currently applies to
construction from SQL or tables. The following resources are planned and
**are not yet enabled** in
[`fhir_mapa()`](https://f-slg.github.io/fhirviews/reference/fhir_mapa.md).

| Proposed order | Resources | Intended workflow |
|----|----|----|
| 1\. Encounters and diagnoses | `Encounter`, `Condition` | Patient → encounter → diagnosis, with references between them. |
| 2\. Vaccination | `Immunization` | Patient → vaccination event, with an explicit vaccine, status and date. |
| 3\. Laboratory | `Specimen`, `DiagnosticReport` | Specimen → observations → report, with several result references. |
| 4\. Medications | `MedicationRequest`, `MedicationDispense` | Prescribing and dispensing, with explicit medication and dosage data. |
| As needed by the source | `Organization`, `Practitioner` | Institutions and professionals referenced by these resources. |

This order prioritizes surveillance and can be adapted to the data
source. The path, type, cardinality and choice-field engine already uses
canonical **FHIR R4 4.0.1** snapshot metadata, so each resource does not
need a separate converter. Expanding the supported list requires:

1.  Extending `data-raw/mapeo_r4.py` with an explicit resource list and
    its dependent types, preserving the schema version and provenance.
    Include ValueSet bindings and allowed `Reference` target types.
2.  Generalizing code validation beyond `Patient.gender` and
    `Observation.status`. Adding a schema alone does not validate its
    statuses, terminology or invariants. Bindings requiring external
    terminology and project profiles need validation against the
    selected server.
3.  Testing each resource’s required fields and choices. For example,
    `Encounter` requires `status` and `class`; `Condition` requires
    `subject`; `Immunization` requires `status`, `vaccineCode`,
    `patient` and one `occurrence[x]` variant. Project profiles may
    impose additional requirements.
4.  Designing collections of objects before offering variable-length
    groups or references. Fixed paths such as `result[0].reference` can
    be built; terminal `[]` currently constructs primitive collections,
    rather than variable-length lists of `Reference` or
    `dosageInstruction` objects.
5.  Requiring valid and invalid cases per resource and a reproducible
    SQL → FHIR → base-profile `$validate` → persist and read → V8/DuckDB
    table round trip. Check references, missing values, invalid codes
    and conflicting choice fields. Add project profiles by canonical URL
    when available, and update documentation and examples for each
    group.

A local schema exploration constructed `Condition`, `Encounter`,
`Immunization`, `DiagnosticReport` and `MedicationRequest` with the
current engine. It also accepted an invalid `Encounter` status: this
identifies a missing check and **does not establish support** for those
resources. The proposed first increment completes these validations and
tests `Encounter` and `Condition` together.

## Public health views and terminologies

The catalogue includes seven views: patients, diagnoses, encounters,
immunisations, medications, vital signs and notifiable diseases. You can
inspect them and adapt their constants:

``` r

vista_catalogo()[, c("nombre", "recurso")]

archivo_dengue <- system.file(
  "extdata", "dengue_2025.ndjson.gz", package = "fhirviews"
)
casos <- vista_ejecutar(archivo_dengue, vista_plantilla("notificacion_obligatoria"))
```

With a terminology server,
[`tx_expandir()`](https://f-slg.github.io/fhirviews/reference/tx_expandir.md)
retrieves the codes of a ValueSet,
[`tx_buscar_codigo()`](https://f-slg.github.io/fhirviews/reference/tx_buscar_codigo.md)
calls `$lookup` and
[`tx_validar_codigo()`](https://f-slg.github.io/fhirviews/reference/tx_validar_codigo.md)
calls `$validate-code`.
[`vista_con_valueset()`](https://f-slg.github.io/fhirviews/reference/vista_con_valueset.md)
embeds the expanded codes in the view so that running it later does not
depend on the network.

### Reproducible surveillance demo

To run a complete workflow with the bundled fictitious data:

``` r

source(system.file("examples", "vigilancia.R", package = "fhirviews"))
```

The script prints the output folder and checks that the summaries match
the selected events. With the bundled data set it starts from 755
events, selects 661 confirmed cases with ICD-10 codes A90/A91 and
excludes 94 refuted ones. It produces:

- Confirmed events and summaries by canton and month of onset, as CSV.
- Count checks to review the transformation.
- The view JSON files, the package version, the input checksum and
  [`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html).
- A `LEEME.txt` file with the definition of the indicator and its
  limits.

These are **counts of fictitious events**, not unique patients or
population rates. Territorial codes must be read as text to keep leading
zeros. To choose another folder, set `FHIRVIEWS_DEMO_SALIDA` before
running the script; the folder must be new, to avoid overwriting files.

To turn cases into territorial indicators, see the [example of rates by
canton with FHIR and
pobecu](https://f-slg.github.io/fhirviews/articles/tasas-pobecu.html)
(in Spanish).

![Example analysis of rates by territory with fictitious FHIR data and
population from pobecu](reference/figures/README-tasas.png)

## Validation and privacy

[`vista_validar()`](https://f-slg.github.io/fhirviews/reference/vista_validar.md)
checks a view definition.
[`fhir_validar()`](https://f-slg.github.io/fhirviews/reference/fhir_validar.md)
asks the **server** to validate a resource with `$validate`; the scope
of that validation depends on the server’s profiles and capabilities.

Since 0.5.0, the `valido` attribute distinguishes three outcomes:

| Value | Meaning |
|----|----|
| `TRUE` | The server returns a complete OperationOutcome with no errors or fatal issues, in a successful HTTP response |
| `FALSE` | The OperationOutcome contains errors or fatal issues, in a successful HTTP response |
| `NA` | The operation fails at the HTTP level, or the response does not allow validity to be determined |

``` r

# Requires a connection and a server that supports $validate
resultado <- fhir_validar(con, list(resourceType = "Patient", gender = "female"))
if (!isTRUE(attr(resultado, "valido"))) {
  stop("El recurso no tiene una validación positiva del servidor.")
}
```

The HTTP status is available in `attr(resultado, "estado")`. A positive
validation does not certify the clinical quality of the data.

By default, HTTP errors omit the server’s response body, which may
contain patient information. Sensitive query values, including `_id`,
are also hidden. For controlled debugging:

``` r

options(fhirviews.mostrar_detalles = TRUE)  # server content in errors
options(fhirviews.mostrar_consulta = TRUE) # full query values

# Back to the default behaviour
options(fhirviews.mostrar_detalles = FALSE, fhirviews.mostrar_consulta = FALSE)
```

Structured details remain available in `error$outcome` when you catch an
HTTP error. These options do not anonymise resources, URL paths or
output files: access to and storage of clinical data are the
responsibility of the environment running the analysis. Tokens are kept
in memory unless disk caching is explicitly requested with
`cache_disco = TRUE`.

## Conformance and tests

The package includes the [official SQL on FHIR test
suite](https://github.com/FHIR/sql-on-fhir.js/tree/main/tests). Both
engines pass **144/144 tests of the included suite**:

| Engine              | Shareable | Experimental |   Total |
|---------------------|----------:|-------------:|--------:|
| V8 / fhirpath.js    |   133/133 |        11/11 | 144/144 |
| DuckDB / native SQL |   133/133 |        11/11 | 144/144 |

The four experimental boundary cases now retain the precision of `1.0`
and complete missing DateTime offsets (`+14:00` for the low boundary,
`-12:00` for the high boundary), preserving explicit offsets. The runner
preserves the original numeric literals without changing expected
outputs. V8 uses a portable JSON reader; DuckDB matches raw numeric
tokens to `json_tree()` paths. Conformance refers to that suite and does
not certify a clinical system.

``` r

vista_conformidad()                   # V8 engine
vista_conformidad(motor = "duckdb")   # requires DuckDB and its json extension
vista_conformidad(descargar = TRUE)  # compare with the current GitHub suite
vista_conformidad(informe = "sof-test-results.json") # public matrix report format
```

144/144 does not imply support for every FHIRPath expression in SQL.
Decimal boundaries in DuckDB support unsigned literals or static
resource paths with explicit indices, scales from -18 to 8, and numbers
representable in `DECIMAL(38,18)`. Negative scales represent positive
exponents. The optional precision argument and scale inference after
operations, filters or iterations are unsupported and produce explicit
errors. For Parquet or previously normalized tables, only their current
JSON representation is available; an earlier lost scale cannot be
reconstructed. Views without decimal boundaries do not incur the token
and path extraction cost.

CI checks the package on Windows, macOS Intel and Linux, plus R-devel
and R 4.1. macOS uses `macos-26-intel` by default; this matrix does not
validate Apple Silicon. The workflow can be run manually, choosing
between macOS 26 Intel and macOS 15 Intel, to retry availability
problems. The selector does not guarantee provider capacity: macOS
remains a required check. On R 4.1 and R-devel, the client and V8 are
checked. The three systems on R release include DuckDB and its SQL
tests. HTTP tests use mocked responses. The write integration is enabled
separately against **your own test server**:

``` sh
FHIRVIEWS_SERVIDOR_ESCRITURA=http://localhost:8080/fhir \
FHIRVIEWS_SOLO_SERVIDOR_PROPIO=true NOT_CRAN=true \
  Rscript -e 'testthat::test_local(filter = "^servidor$")'
```

That server must allow writes; some tests require terminology and Bulk
Data. The suite skips operations the server does not support. See
[`tests/testthat/test-servidor.R`](https://f-slg.github.io/fhirviews/tests/testthat/test-servidor.R)
to set up an isolated HAPI server.

To run the full integration reproducibly from the repository, with
Docker or Podman and the test dependencies installed (in addition to the
package’s required dependencies: `pkgload`, `testthat`, `DBI` and
`duckdb`):

``` sh
bash data-raw/probar-hapi.sh
```

The script uses an image pinned by digest, opens a random port on
localhost only and removes its own container when it finishes, even if
the tests fail. It prints the folder that keeps the logs, the JSON and
CSV summary, the skips and the R environment. The run requires writes,
transactions, basic terminology and Bulk Data and the SQL → FHIR →
server → table round trip; an unexpected skip makes the test fail. The
inline ValueSet variant that HAPI does not support is recorded
separately. The **Integracion HAPI** workflow runs this same script and
keeps the results for 14 days. On its first run it may download the
image and DuckDB’s JSON extension.

### SQL → FHIR validation against R4 profiles

The required `SQL a FHIR, perfiles R4, referencias y retorno a tablas`
group uses a fictional Patient and two Observations from parameterized
DuckDB queries:

1.  Builds and writes the resources, preserving the decimal `72.00`.
2.  Calls `$validate` with the explicit base profiles
    `http://hl7.org/fhir/StructureDefinition/Patient` and
    `http://hl7.org/fhir/StructureDefinition/Observation`.
3.  Persists the test resources and checks that
    `Observation.subject.reference` points to the created Patient.
4.  Supplies an invalid `gender` and requires the validator to report an
    error.
5.  Reads with `fhir_leer(..., como_recursos = TRUE)` and compares
    values, references and decimal boundaries in V8 and native SQL.
6.  Deletes the test resources; the script also removes its own
    container.

The summary records failures, errors, warnings, assertions and skip
reasons. Acceptance fails if this required group is missing. This covers
**base R4 profiles**; clinical or national profiles need explicit checks
against their canonical URLs.

**Local result on 14 November 2026:** integration passed with
digest-pinned HAPI 8.12.0-2, 62 passing assertions and no failures,
errors or warnings. All 16 SQL → FHIR assertions ran. The two expected
skips (public-server reads and inline ValueSet validation) were
recorded, and the container was removed. The [integration
evidence](https://github.com/f-slg/fhirviews/blob/main/data-raw/validacion-0.5.0.9000/sql-fhir-hapi/resumen.json)
records each group; logs and the R environment are kept alongside it.
This is a technical check with fictional data.

### SQL → FHIR with PostgreSQL and SQL Server

In addition to local DuckDB and SQLite tests,
`data-raw/probar-sql-dbi.sh` runs queries against **two real, isolated
databases**. It creates its own PostgreSQL and SQL Server Developer
containers, pinned by digest in `data-raw/postgres-image.txt` and
`data-raw/sqlserver-image.txt`, and removes them on exit. Random ports
are bound to localhost and random, single-use credentials are excluded
from reports. All data is fictional.

Requirements: Docker or Podman, `openssl`, the R packages below and a
**Microsoft ODBC Driver 18 for SQL Server** available to `odbc`.
`RPostgres` needs PostgreSQL libraries; `odbc` needs unixODBC. Running
the script starts SQL Server with `ACCEPT_EULA=Y` and the Developer
edition for development and testing under Microsoft’s image terms.

``` r

install.packages(c("DBI", "RPostgres", "odbc", "duckdb", "pkgload", "testthat"))
```

``` sh
# Run from the repository root; the output directory must be new.
FHIRVIEWS_CONTENEDOR=podman bash data-raw/probar-sql-dbi.sh /tmp/fhirviews-sql-dbi
# FHIRVIEWS_CONTENEDOR=docker is also supported.
```

`FHIRVIEWS_ODBC_DRIVER` can specify another registered driver name or an
absolute library path; the default is `ODBC Driver 18 for SQL Server`.
`FHIRVIEWS_SQL_ESPERA` sets the connection wait in seconds, defaulting
to 120. The test ODBC connection uses encryption and trusts the local
container’s certificate; this setting belongs to the isolated test
environment.

Each database must pass five required groups:

1.  Native `Date` values, booleans, accented text and BIGINT keys above
    `2^53`, read as text without rounding.
2.  Patient construction with names, birth date, active status and
    omitted SQL `NULL` values.
3.  Bound parameters (`$1` for RPostgres; `?` for ODBC), zero rows, text
    containing SQL characters, and rejected duplicate IDs or invalid
    codes.
4.  Observation construction with patient references, UTC timestamps and
    a `DECIMAL(12,2)` read as text to preserve `72.00`. SQL Server
    explicitly converts `DATETIMEOFFSET` to UTC and `DATETIME2` before
    reading it as `POSIXct`.
5.  NDJSON writing and reading and comparison of values and decimal
    boundaries when projecting the resources to tables with V8 and
    DuckDB.

Queries and casts are specific to each database;
[`fhir_desde_sql()`](https://f-slg.github.io/fhirviews/reference/fhir_mapa.md)
runs them through DBI. Base R4 profile validation is covered separately
by the HAPI integration described above.

**Local result on 14 November 2026:** 72 passing assertions with no
failures, errors, warnings or skips. Tested PostgreSQL 17.12 with
RPostgres 1.4.10 and SQL Server 2022 CU27 (16.0.4295.3) with `odbc`
1.7.2 and Microsoft ODBC 18.6.1.1. Both containers were removed. The
[DBI
evidence](https://github.com/f-slg/fhirviews/blob/main/data-raw/validacion-0.5.0.9000/sql-dbi/resumen.json)
records versions and each group’s results; fictional output resources,
logs and the R environment are kept alongside it. Executable queries are
in the repository script.

The **Integracion SQL DBI** workflow runs the same procedure and retains
its results for 14 days. All ten groups are required; any failure,
warning or skip fails acceptance. Check the CI results for the commit
being published to confirm its R coverage on Windows, macOS and Linux as
well.

### Candidate check sequence

The R-CMD-check matrix first tests the package and then installs the
built source archive in a new library. Acceptance runs in a separate R
process and checks the load path, the help, the vignettes and the report
for the requested profile. The full profile adds rollback and
transactional retry.

``` mermaid
flowchart TD
    A["Commit on GitHub"] --> B["R CMD build with vignettes"]
    B --> C["R CMD check and package tests"]
    C --> D["Install the same tar.gz in a new library"]
    D --> E["Separate R process: check package and documentation"]
    E --> F["Basic or full pilot depending on the matrix"]
    F --> G{"Technical result"}
    G -->|"No errors or warnings"| H["Approved for that profile"]
    G -->|"Warnings"| I["Needs review, non-zero exit"]
    G -->|"Error"| J["Not approved, non-zero exit"]
    A --> K["HAPI workflow: isolated integration"]
    A --> L["pkgdown workflow: build documentation"]
    H --> M["User evaluation still pending"]
```

Acceptance reports are stored as `piloto-*` artifacts for 14 days.
Approval of a basic profile does not evaluate recovery with DuckDB; that
check is recorded as `no_evaluado` (not evaluated). The workflows verify
the declared scope, and their result should be checked for the specific
commit being delivered.

## Performance

The measurements below predate the precision changes in 0.5.0.9000 and
have not been repeated with this development version.

The following measurement compares both engines with synthetic patients
and a view that includes `where`, four columns and `forEach` over
`name`.

![Measured times to turn NDJSON into tables: V8 and DuckDB compared by
number of patients](reference/figures/README-rendimiento.png)

|  Patients |      Rows | V8 engine | DuckDB engine | Times faster |
|----------:|----------:|----------:|--------------:|-------------:|
|    10,000 |    17,824 |     2.3 s |        0.22 s |           11 |
|    50,000 |    89,128 |    11.0 s |        0.92 s |           12 |
|   100,000 |   178,062 |    23.2 s |        1.18 s |           20 |
|   250,000 |   444,912 |    58.9 s |        1.56 s |           38 |
| 1,000,000 | 1,780,958 |         — |         5.8 s |            — |

End-to-end time, from the NDJSON file to the `data.frame`, with
synthetic patients and a view with `where`, four columns and `forEach`
over `name` (`data-raw/motor-duckdb.R`; Linux, 8 cores, R 4.5.2, duckdb
1.5.6).

These are results for that machine and that view, not a performance
guarantee. Collection expansion, result size, disk and memory can change
the behaviour. The reproducible script is in
[`data-raw/motor-duckdb.R`](https://f-slg.github.io/fhirviews/data-raw/motor-duckdb.R).

### Comparison with fhircrackr

[fhircrackr](https://CRAN.R-project.org/package=fhircrackr) is the most
widely used CRAN package for flattening FHIR resources in R. It
describes columns with XPath over XML Bundles and expands collections
with `fhir_melt()`. The comparison produces **the same table** with both
packages: a date filter, four columns per patient and one row per name.
Before timing, the script checks that the three results are identical.

| Patients | Rows | fhircrackr 2.4.0 · 1 core | fhircrackr 2.4.0 · 8 cores | fhirviews · V8 | fhirviews · DuckDB |
|---:|---:|---:|---:|---:|---:|
| 1,000 | 1,752 | 0.56 s | 0.35 s | 0.16 s | 0.10 s |
| 10,000 | 17,824 | 4.4 s | 1.6 s | 1.3 s | 0.18 s |
| 50,000 | 89,180 | 25.1 s | 6.9 s | 7.2 s | 0.60 s |
| 100,000 | 178,316 | 48.5 s | 15.8 s | 15.4 s | 1.11 s |

End-to-end time, from the files to the `data.frame`, median of three
runs. Each package reads its natural format: NDJSON in fhirviews and XML
Bundles of 500 resources in fhircrackr. With the data already in memory,
transformation only, the V8 engine is 4 to 5 times faster than
`fhir_crack()` + `fhir_melt()`.

How to read these numbers:

- The V8 engine uses a single core. Compared with fhircrackr on one core
  it is about **3 times faster**; with `ncores = 8`, fhircrackr reaches
  times similar to V8. DuckDB uses all available cores, so its advantage
  combines the engine with parallelism.
- A single, simple synthetic resource type (`Patient`) was used, on a
  single machine (Linux, 12 cores, R 4.5.2, duckdb 2.0.0). With more
  deeply nested resources the result may differ.
- In fhirviews the extraction is a standard, portable `ViewDefinition`.
  In fhircrackr, the date filter and the numbering of names are done in
  R after `fhir_crack()`, because XPath 1.0 cannot compare dates.

The reproducible script is
[`data-raw/benchmark-fhircrackr.R`](https://f-slg.github.io/fhirviews/data-raw/benchmark-fhircrackr.R),
and the results are in
[`data-raw/benchmark-fhircrackr.csv`](https://f-slg.github.io/fhirviews/data-raw/benchmark-fhircrackr.csv)
(one core) and
[`data-raw/benchmark-fhircrackr-ncores8.csv`](https://f-slg.github.io/fhirviews/data-raw/benchmark-fhircrackr-ncores8.csv)
(eight cores).

#### A more nested resource: Observation

The same comparison with 100,000 more complex `Observation` resources:
two codings per resource that must be filtered by system, choice
elements (`effective[x]`, `value[x]`), the patient reference and one row
per blood pressure component (`forEachOrNull`).

| Observations | Rows | fhircrackr · 1 core | fhircrackr · 8 cores | fhirviews · V8 | fhirviews · DuckDB |
|---:|---:|---:|---:|---:|---:|
| 1,000 | 1,274 | 0.44 s | 0.32 s | 0.18 s | 0.07 s |
| 10,000 | 12,639 | 4.1 s | 1.6 s | 1.6 s | 0.18 s |
| 50,000 | 63,059 | 20.8 s | 7.2 s | 8.4 s | 0.72 s |
| 100,000 | 125,578 | 44.0 s | out of memory | 17.6 s | 1.42 s |

The result holds on one core: V8 is about 2.5 times faster than
fhircrackr. With eight cores, fhircrackr matches V8 or is slightly
faster, but each parallel process copies the data: with 100,000
observations the eight processes exceeded the machine’s 14 GB of memory
and the system stopped them. V8 and DuckDB handled that size without
problems.

Script:
[`data-raw/benchmark-fhircrackr-observation.R`](https://f-slg.github.io/fhirviews/data-raw/benchmark-fhircrackr-observation.R).

## Scope and limitations

- **FHIR R4 and JSON.** The bundled model is R4; compatibility with R5
  or with XML resources is not claimed.
- **FHIRPath.** Evaluation happens in V8. Remote resolution with
  `resolve()` is disabled; terminology lookups are done with the `tx_*`
  functions before the view runs.
- **Precision and dates.** Evaluation and JSON/NDJSON output preserve
  decimal literals from the original source. Ordinary R numeric columns
  do not retain their scale; editing resources discards their original
  JSON source. Dates stay as ISO 8601 text to allow partial values such
  as `2025` or `2025-03`.
- **Memory and schema.**
  [`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
  collects the result in memory; block-wise processing requires your
  function to handle the output. Type conversion warnings should be
  reviewed before persisting data.
- **Experimental DuckDB.** The SQL translator covers a subset of
  FHIRPath. Check your views against V8 before running them at scale.
- **Server capabilities.** SMART, `$validate`, terminology and `$export`
  depend on the configuration and permissions of the connected server.

Development priorities include stabilising the DuckDB engine, improving
decimal precision and extending the search and terminology operations.
Proposals and their tracking are in [GitHub
Issues](https://github.com/f-slg/fhirviews/issues).

## Pilot and local documentation

### Download the participant kit

**[Download the pilot kit
(ZIP)](https://github.com/f-slg/fhirviews/raw/refs/heads/main/data-raw/fhirviews-kit-piloto-v1.zip)**

1.  Download and unzip the file.
2.  Open `FORMULARIO-PILOTO.html` in a browser.
3.  Choose the **R** or **FHIR** profile, record the candidate and
    follow the tasks.
4.  Export the JSON to keep both forms and prepare the notice to the
    maintainer. It is sent manually through the agreed channel.

The kit includes detailed protocols, checklists, a log for time and
help, issues, closing criteria and an annex for the observer. The form
works locally and does not transmit any information automatically.
Browser storage does not replace exporting the report. The kit materials
are in Spanish.

You can also read the protocols in the repository:

- [R profile: analyst, researcher or
  epidemiologist](https://github.com/f-slg/fhirviews/blob/main/data-raw/piloto-participantes-v1/PROTOCOLO-PERFIL-R.md).
- [FHIR profile: interoperability and health
  informatics](https://github.com/f-slg/fhirviews/blob/main/data-raw/piloto-participantes-v1/PROTOCOLO-PERFIL-FHIR.md).
- [Kit instructions and
  files](https://github.com/f-slg/fhirviews/blob/main/data-raw/piloto-participantes-v1/LEEME.md).

The ZIP contains the evaluation materials, not the R package. While the
release is still a draft, the maintainer provides the candidate archive
identified in the manifest, so that exactly the same version is
evaluated.

### Install the candidate and run the trial

The pilot uses the bundled fictitious data. Install the dependencies and
the source archive provided by the maintainer:

``` r

install.packages(c("cli", "httr2", "jsonlite", "rlang", "V8"))
install.packages("fhirviews_0.5.0.tar.gz", repos = NULL, type = "source")
```

Restart R, choose a new folder and run:

``` r

Sys.setenv(
  FHIRVIEWS_PILOTO_SALIDA = "piloto-basico-01",
  FHIRVIEWS_PILOTO_PERFIL = "basico"
)
source(system.file("examples", "piloto.R", package = "fhirviews"))
```

Open `piloto-basico-01/aceptacion.csv` to see the checks and
`aceptacion.json` for their diagnostics. The statuses are `aprobado`,
`fallo`, `requiere_revision`, `pendiente` and `no_evaluado` (approved,
failed, needs review, pending and not evaluated). Any warning requires
review and prevents automatic approval; the report records safe codes
without copying the original messages.

The `basico` profile checks the API, the surveillance results and the
strict rejection of an incompatible block. To also check rollback and
retries, install `DBI` and `duckdb`, change the profile to `completo`
and use another new folder. The files stay local; fill in
`experiencia-usuario.txt` with the obstacles, the help you needed and
your assessment. Technical approval leaves that human evaluation pending
and does not validate a server or your own data.

Help and vignettes are available in the installation:

``` r

help(package = "fhirviews")
help("vista_ejecutar_lotes", package = "fhirviews")
browseVignettes("fhirviews")
```

The [maintainer’s
guide](https://f-slg.github.io/fhirviews/inst/examples/PILOTO-MANTENEDOR.md)
(in Spanish) describes how to build and verify the candidate, interpret
the codes and close the pilot. It is also distributed with the package,
in `examples/PILOTO-MANTENEDOR.md`.

## Guides and reference

The source code is available in the public repository. Help and
vignettes can also be read locally, as described in the previous
section, without depending on the website being available. All guides
are in Spanish.

| Guide | Content |
|----|----|
| [Getting started](https://f-slg.github.io/fhirviews/articles/fhirviews.html) | Client, resources and first views with the clinical case |
| [ViewDefinition in detail](https://f-slg.github.io/fhirviews/articles/vistas.html) | Columns, collections, filters, types and SQL |
| [Servers and large volumes](https://f-slg.github.io/fhirviews/articles/servidores-y-volumen.html) | SMART, bulk export and DuckDB |
| [Rates by canton](https://f-slg.github.io/fhirviews/articles/tasas-pobecu.html) | Indicators with FHIR and Ecuador’s population |
| [Architecture](https://f-slg.github.io/fhirviews/articles/arquitectura.html) | Engines, batch evaluation and security |
| [Function reference](https://f-slg.github.io/fhirviews/reference/) | Signatures, arguments and API examples |

Related projects: [pobecu](https://f-slg.github.io/pobecu/) for
Ecuador’s population, [geoecu](https://f-slg.github.io/geoecu/) for
territorial boundaries and
[aprende-fhir](https://github.com/f-slg/aprende-fhir) for teaching with
a fictitious clinical case.

## Contributing, citation and license

For usage questions, join the
[Discussions](https://github.com/f-slg/fhirviews/discussions). For bugs
or proposals, open an
[issue](https://github.com/f-slg/fhirviews/issues/new/choose) with a
minimal reproducible example and fictitious data. Issues and discussions
in English are welcome. See the [contributing
guide](https://f-slg.github.io/fhirviews/CONTRIBUTING.md) and the [code
of conduct](https://f-slg.github.io/fhirviews/CODE_OF_CONDUCT.md).

To cite the package:

``` r

citation("fhirviews")
```

**Author and maintainer:** Ronald Fabricio Salas Guerrero.
[MIT](https://f-slg.github.io/fhirviews/LICENSE.md) license. The
licenses and attributions of the bundled code and data are detailed in
[`inst/COPYRIGHTS`](https://f-slg.github.io/fhirviews/inst/COPYRIGHTS).

fhirviews is an independent project. FHIR® and HL7® are registered
trademarks of Health Level Seven International; their use does not imply
institutional endorsement. All bundled example data are fictitious.
