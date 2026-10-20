# Ejecutar un ViewDefinition con DuckDB (experimental)

**Experimental.** Este motor es un prototipo: su interfaz y el
subconjunto de FHIRPath que admite pueden cambiar. Para resultados de
referencia usa
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md).

## Usage

``` r
vista_ejecutar_duckdb(
  archivos,
  vista,
  con_db = NULL,
  tabla = NULL,
  diferido = FALSE
)
```

## Arguments

- archivos:

  Rutas de archivos `.ndjson`, `.ndjson.gz` o `.parquet` (se pueden usar
  comodines como `"datos/*.ndjson"`), el nombre de una tabla de `con_db`
  con una columna `json`, o recursos en cualquier forma que acepte
  [`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md)
  (que se escriben antes en un archivo temporal).

- vista:

  Un `ViewDefinition` en cualquier forma que acepte
  [`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md).

- con_db:

  Conexión DBI a DuckDB. Si es `NULL` (por defecto), se usa una base en
  memoria.

- tabla:

  Nombre opcional de una tabla de `con_db` donde guardar el resultado en
  lugar de traerlo a R; útil con resultados muy grandes.

- diferido:

  Si es `TRUE`, no ejecuta la vista: devuelve una tabla diferida de
  dplyr (`tbl_dbi` de dbplyr) sobre la consulta, para filtrar, agrupar y
  resumir con dplyr dentro de DuckDB y traer a R solo el resultado con
  `dplyr::collect()`. Requiere los paquetes dplyr y dbplyr. Cada vez que
  se usa la tabla, DuckDB vuelve a leer los archivos.

## Value

Un `data.frame` como el de
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md);
si se indica `tabla`, la conexión DBI de forma invisible; con
`diferido = TRUE`, una tabla diferida de dbplyr.

## Details

Traduce el `ViewDefinition` a SQL con
[`vista_sql()`](https://f-slg.github.io/fhirviews/reference/vista_sql.md)
y lo ejecuta en [DuckDB](https://duckdb.org/) directamente sobre
archivos NDJSON o Parquet, sin cargar los recursos en R ni en el motor
de FHIRPath. DuckDB lee los archivos en paralelo y por partes, de modo
que se pueden procesar millones de recursos con poca memoria.

Es un motor alternativo a
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md),
que evalúa FHIRPath completo con `fhirpath.js`. Este motor admite un
subconjunto de FHIRPath (ver
[`vista_sql()`](https://f-slg.github.io/fhirviews/reference/vista_sql.md));
si la vista usa algo que no se puede traducir, el error lo indica y
sugiere usar
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md).

Requiere los paquetes DBI y duckdb (versión 1.3.0 o posterior) y la
extensión `json` de DuckDB, que el paquete duckdb no trae incorporada:
DuckDB la descarga la primera vez que se usa en cada sesión de R (hace
falta conexión a internet). La conexión que crea esta función guarda las
extensiones en la carpeta temporal de la sesión, no en `~/.duckdb`.

Con `diferido = TRUE` la tabla queda unida a la conexión: si `con_db` es
`NULL` se crea una que sigue abierta mientras exista la tabla (ciérrala
con `DBI::dbDisconnect(dbplyr::remote_con(tabla))` al terminar), y si
`archivos` son recursos de R, el archivo temporal se borra al cerrar la
sesión de R. Las columnas sin tipo deducible se convierten según los
valores, lo que obliga a recorrer los datos una vez al crear la tabla.
Al traer los datos con `dplyr::collect()`, los elementos complejos (como
`name.first()`) llegan como texto JSON y las colecciones como listas de
DuckDB, no como las listas de R de
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md).

## Examples

``` r
if (FALSE) { # requireNamespace("duckdb", quietly = TRUE) && interactive()
archivo <- system.file("extdata", "caso_clinico.ndjson",
                       package = "fhirviews")
vista <- vista_crear("Patient", c(sexo = "gender", nacimiento = "birthDate"))
vista_ejecutar_duckdb(archivo, vista)
}
if (FALSE) { # requireNamespace("duckdb", quietly = TRUE) && requireNamespace("dbplyr", quietly = TRUE) && interactive()
# Resultado diferido: el resumen se calcula en DuckDB
pacientes <- vista_ejecutar_duckdb(archivo, vista, diferido = TRUE)
dplyr::count(pacientes, sexo) |> dplyr::collect()
DBI::dbDisconnect(dbplyr::remote_con(pacientes))
}
```
