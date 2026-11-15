# Traducir un ViewDefinition a SQL de DuckDB (experimental)

**Experimental**, como
[`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md).
Traduce un `ViewDefinition` a una consulta SQL de
[DuckDB](https://duckdb.org/) que lee los recursos FHIR como JSON y
devuelve la tabla de la vista. Es el motor que usa
[`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md);
esta función solo genera el texto, para revisarlo o ejecutarlo en otra
herramienta (por ejemplo la línea de comandos de DuckDB).

## Usage

``` r
vista_sql(vista, desde = "recursos")
```

## Arguments

- vista:

  Un `ViewDefinition` en cualquier forma que acepte
  [`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md).

- desde:

  Origen de los recursos: rutas de archivos NDJSON (también comprimidos
  con gzip) o Parquet, o el nombre de una tabla o vista de DuckDB con
  una columna `json` (un recurso FHIR por fila).

## Value

El texto de la consulta (clase `fhir_sql`).

## Details

El traductor cubre la estructura completa del `ViewDefinition` (`select`
anidados, `column`, `forEach`, `forEachOrNull`, `repeat`, `unionAll`,
`where`, `constant` y `%rowIndex`) y buena parte de FHIRPath: navegación
por campos (los elementos de elección como `value` o `effective` buscan
sus variantes `valueQuantity`, `valueString`...), índices (`name[0]`),
`where()`, `select()`, [`exists()`](https://rdrr.io/r/base/exists.html),
`empty()`, [`all()`](https://rdrr.io/r/base/all.html), `allTrue()` y
afines, `count()`, `first()`, `last()`,
[`tail()`](https://rdrr.io/r/utils/head.html), `skip()`, `take()`,
[`single()`](https://rdrr.io/r/base/double.html), `distinct()`,
`isDistinct()`, [`union()`](https://rdrr.io/r/base/sets.html)/`|`,
`combine()`, [`intersect()`](https://rdrr.io/r/base/sets.html),
`exclude()`, `subsetOf()`, `supersetOf()`, `in`, `contains`, `not()`,
`iif()`, [`trace()`](https://rdrr.io/r/base/trace.html), `is`, `as`,
`ofType()`, `extension(url)`, `getResourceKey()`, `getReferenceKey()`,
funciones de texto (`join()`,
[`startsWith()`](https://rdrr.io/r/base/startsWith.html),
[`endsWith()`](https://rdrr.io/r/base/startsWith.html), `contains()`,
`indexOf()`, [`substring()`](https://rdrr.io/r/base/substr.html),
`upper()`, `lower()`, `trim()`,
[`length()`](https://rdrr.io/r/base/length.html),
[`replace()`](https://rdrr.io/r/base/replace.html), `matches()`,
`replaceMatches()`, [`split()`](https://rdrr.io/r/base/split.html),
`toChars()`), conversiones
([`toString()`](https://rdrr.io/r/base/toString.html), `toInteger()`,
`toDecimal()`, `toBoolean()` y sus `convertsTo...()`), aritmética,
[`abs()`](https://rdrr.io/r/base/MathFun.html),
[`ceiling()`](https://rdrr.io/r/base/Round.html),
[`floor()`](https://rdrr.io/r/base/Round.html),
[`round()`](https://rdrr.io/r/base/Round.html),
[`truncate()`](https://rdrr.io/r/base/seek.html),
[`sqrt()`](https://rdrr.io/r/base/MathFun.html),
[`power()`](https://rdrr.io/r/stats/power.html) exacta, comparaciones de
fechas y horas con su precisión y `lowBoundary()`/`highBoundary()` de
fechas y horas.

La traducción reproduce el resultado de `fhirpath.js`
([`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)).
Si una expresión usa algo que no se puede traducir con certeza, se
produce un error de clase `fhirviews_error_sql` que sugiere usar
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md);
lo que solo se puede decidir con los datos (por ejemplo, comparar una
fecha sin hora con una fecha y hora, que depende de la zona horaria del
equipo, o textos con caracteres que DuckDB y JavaScript pasan a
mayúsculas de forma distinta) da un error al ejecutar la consulta, nunca
un resultado distinto.

Los elementos `repeat` se traducen hasta una profundidad fija (por
defecto 12 niveles; la opción `fhirviews.sql_profundidad` la cambia); si
los datos tienen más niveles, la consulta produce un error en lugar de
omitir filas.

Los tipos de las columnas salen del `type` de cada columna, del tipo de
la expresión o, si no, del modelo FHIR R4. Las columnas cuyo tipo no se
puede deducir quedan como `JSON`;
[`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md)
las convierte después según los valores.

## See also

[`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md)
para ejecutarla.

## Examples

``` r
vista <- vista_crear("Patient", c(sexo = "gender",
                                  apellido = "name.first().family"))
vista_sql(vista, "pacientes.ndjson")
#> SELECT f."id" AS "id", f."sexo" AS "sexo", f."apellido" AS "apellido"
#> FROM (
#>   SELECT unnest([{'id': json_extract_string(r, '$.id'), 'sexo': json_extract_string(list_extract(list_transform([flatten(list_transform([json_extract(r, '$."gender"')], lambda z1: CASE WHEN z1 IS NULL OR CAST(z1 AS VARCHAR) = 'null' THEN []::JSON[] WHEN starts_with(CAST(z1 AS VARCHAR), '[') THEN list_filter(CAST(z1 AS JSON[]), lambda z2: z2 IS NOT NULL AND CAST(z2 AS VARCHAR) <> 'null') ELSE [z1] END))], lambda z3: CASE WHEN len(z3) > 1 THEN error('La columna sexo devolvió varios valores para una fila; usa collection: true o first()') ELSE z3[1] END), 1), '$'), 'apellido': json_extract_string(list_extract(list_transform([flatten(list_transform([json_extract(list_extract(flatten(list_transform([json_extract(r, '$."name"')], lambda z4: CASE WHEN z4 IS NULL OR CAST(z4 AS VARCHAR) = 'null' THEN []::JSON[] WHEN starts_with(CAST(z4 AS VARCHAR), '[') THEN list_filter(CAST(z4 AS JSON[]), lambda z5: z5 IS NOT NULL AND CAST(z5 AS VARCHAR) <> 'null') ELSE [z4] END)), 1), '$."family"')], lambda z6: CASE WHEN z6 IS NULL OR CAST(z6 AS VARCHAR) = 'null' THEN []::JSON[] WHEN starts_with(CAST(z6 AS VARCHAR), '[') THEN list_filter(CAST(z6 AS JSON[]), lambda z7: z7 IS NOT NULL AND CAST(z7 AS VARCHAR) <> 'null') ELSE [z6] END))], lambda z8: CASE WHEN len(z8) > 1 THEN error('La columna apellido devolvió varios valores para una fila; usa collection: true o first()') ELSE z8[1] END), 1), '$')}]) AS f
#>   FROM (SELECT json AS r FROM read_json_objects(['pacientes.ndjson'], format = 'newline_delimited'))
#>   WHERE json_extract_string(r, '$.resourceType') = 'Patient'
#> )
```
