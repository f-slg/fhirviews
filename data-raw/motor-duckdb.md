# Motor DuckDB para fhirviews: informe del prototipo

Rama `motor-duckdb`. Código en `R/sql.R`, pruebas en
`tests/testthat/test-sql.R`, medición en `data-raw/motor-duckdb.R` (resultados
en `data-raw/motor-duckdb.csv`).

## Resumen

* `vista_sql(vista, desde)` traduce un `ViewDefinition` a una sola consulta
  `SELECT` de DuckDB; `vista_ejecutar_duckdb(archivos, vista, con_db, tabla)`
  la ejecuta directamente sobre NDJSON (también `.ndjson.gz`), Parquet o una
  tabla con una columna `json`, sin cargar los recursos en R ni en V8.
* **Conformidad: 133 de 133 pruebas shareable** del banco oficial
  (`vista_conformidad(motor = "duckdb")`), las mismas que el motor V8,
  incluidos `repeat`, `%rowIndex`, `unionAll` anidado y los errores
  esperados. De las 11 experimentales pasan 3 (las de `join()`); fallan las 8
  de `lowBoundary()`/`highBoundary()`, que no se traducen.
* **Rendimiento:** con 50 000 pacientes en NDJSON, 0,6 s frente a 10,8 s de
  `vista_ejecutar()` (17 veces más rápido); con 250 000, 1,3 s frente a 55 s
  (41 veces); con 1 000 000 (271 MB, 1,8 millones de filas), 4,5 s y 1,3 GB
  de memoria máxima del proceso, un volumen que el motor V8 no alcanza en
  este portátil.
* Lo que no se puede traducir da un error de clase `fhirviews_error_sql` que
  nombra la expresión y sugiere `vista_ejecutar()`.
* **Recomendación: incorporarlo** como motor opcional y experimental (DuckDB
  sigue en Suggests), con los matices de la última sección.

## Diseño

**Recursos como JSON sin esquema.** Cada línea del NDJSON se lee con
`read_json_objects()` como un valor `JSON`; Parquet se lee con
`read_parquet()` y cada fila se convierte con `to_json()`. No hace falta un
esquema FHIR ni inferir tipos de estructuras, de modo que funcionan los
elementos de elección (`valueQuantity`, `valueString`...), las extensiones y
los recursos heterogéneos. Es la diferencia principal con FlatQuack (ver más
abajo), que tipa los datos con un esquema FHIR R4.

**Colecciones de FHIRPath como `JSON[]`.** Cada expresión traducida es de una
de tres clases: colección (`JSON[]`, vacía si no hay valores), un valor JSON
(o `NULL`) y un valor de SQL tipado (`BOOLEAN`, `VARCHAR`, `BIGINT`,
`DOUBLE`). La navegación `a.b` es `json_extract` sobre cada elemento, y los
arreglos se aplanan; `where()`, `select()`, `exists(criterio)` y `all()` son
`list_filter`/`list_transform` con una lambda cuyo foco es el elemento. Las
comparaciones convierten al tipo del literal (texto, número, lógico); si
ambos lados son rutas, comparan como números cuando los dos lo son y como
texto en otro caso. Las fechas se comparan como texto ISO 8601.

**Estructura del ViewDefinition como listas de filas.** Cada `select` se
traduce en una expresión que da la lista de filas (`STRUCT` con una clave por
columna) para el foco actual; las partes de un select se combinan con un
producto dentro de cada foco; `forEach` recorre la colección con
`list_transform(..., lambda x, i: ...)` (el índice da `%rowIndex`);
`forEachOrNull` cambia la colección vacía por `[NULL]`; `unionAll` es
`list_concat`; `where` va en el `WHERE`; la consulta final hace
`unnest` de las filas de cada recurso. Todo es una expresión por recurso, sin
`LATERAL` ni subconsultas correlacionadas, lo que deja a DuckDB paralelizar
la lectura y el cálculo por bloques de filas.

**`repeat`** se calcula por niveles hasta una profundidad fija (12 por
defecto, opción `fhirviews.sql_profundidad`). Cada nodo lleva una clave con
las posiciones `(ruta, hijo)` desde el foco y ordenar por esa clave da el
preorden que pide la especificación. Si los datos tienen más niveles, la
consulta falla con un error en lugar de omitir filas. Un primer intento con
lambdas anidadas por nivel tardaba más de dos minutos en el banco: el costo
de enlazado de DuckDB se duplica con cada lambda anidada; con los niveles en
posición de argumento baja a décimas de segundo.

**Tipos de las columnas.** En este orden: el `type` de la columna, la clase
de la expresión (por ejemplo `count()` es entero) y el modelo FHIR R4 (con el
mismo `fhirviews.tipo()` de V8 que ya usa `vista_ejecutar()`; solo se llama
al traducir). Si nada lo determina, la columna queda como `JSON` y
`vista_ejecutar_duckdb()` guarda el resultado en una tabla temporal, mira los
tipos JSON presentes y la convierte. Los objetos FHIR (por ejemplo
`name.first()`) llegan a R como listas, igual que con `vista_ejecutar()`; en
una tabla de DuckDB quedan como `JSON`.

**Errores en tiempo de ejecución.** Una columna sin `collection: true` que
devuelve varios valores y un `where` que no devuelve un lógico llaman a
`error()` de DuckDB, con un mensaje en español; llegan a R como
`fhirviews_error_vista`.

## Cobertura de FHIRPath

| Se traduce | No se traduce (error que sugiere `vista_ejecutar()`) |
|---|---|
| Navegación por campos, `Patient.x`, `name[0]`, `$this`, `%resource` | Polimorfismo sin `ofType()` (`value` a secas sobre `value[x]`) |
| `where`, `select`, `exists`, `all`, `empty`, `hasValue`, `count` | `lowBoundary`, `highBoundary`, `precision` |
| `first`, `last`, `tail`, `skip`, `take`, `single`, `distinct` | `resolve`, `memberOf`, `conformsTo`, `trace`, `children`, `descendants` |
| `not`, `iif`, `and`, `or`, `xor`, `implies` | Cantidades con unidades (`5 'mg'`) y aritmética de fechas |
| `=`, `!=`, `~`, `!~`, `<`, `>`, `<=`, `>=` | `$index`, `$total`, `aggregate`, `repeat()` como función |
| `+`, `-`, `*`, `/`, `div`, `mod`, `&`, `\|`, `in`, `contains` | `ofType()` de tipos complejos fuera de un elemento de elección |
| `ofType` (elemento de elección o filtro de primitivos), `is`, `as` | `toDate`, `toDateTime`, `toQuantity`, `convertsTo*` |
| `extension(url)`, `getResourceKey()`, `getReferenceKey([tipo])` | |
| `join`, `startsWith`, `endsWith`, `contains`, `matches`, `upper`, `lower`, `trim`, `length`, `substring`, `replace`, `toString`, `toInteger`, `toDecimal` | |
| Constantes de todos los tipos de `constant`, `%rowIndex`, literales de fecha | |

Diferencias semánticas conocidas frente a fhirpath.js (no afectan al banco):

* Las fechas y horas se comparan como texto: `birthDate > @1940-01-01` es
  correcto con fechas de la misma precisión, pero `@2020` frente a
  `@2020-05-01` no da vacío como en FHIRPath.
* Los decimales son `DOUBLE` (0.1 + 0.2 no es exactamente 0.3).
* `|` no conserva el orden de los elementos.
* `~` solo ignora mayúsculas y espacios de los extremos.
* Las extensiones de primitivos (`_birthDate`) no se ven.

## Conformidad

```
vista_conformidad(motor = "duckdb")
Banco de pruebas de SQL on FHIR (FHIR/sql-on-fhir.js@6677c20, 2026-07-09)
fhirviews 0.1.0 · motor DuckDB 1.5.6

  experimental     3 de  11 aprobadas
  shareable      133 de 133 aprobadas
  total          136 de 144 aprobadas
```

Pasan todos los archivos shareable: basic (11), collection (4), combinations
(6), constant (8), constant_types (14), fhirpath (9), fhirpath_numbers (1),
fn_empty (1), fn_extension (2), fn_first (2), fn_oftype (2),
fn_reference_keys (3), foreach (13), logic (3), repeat (19), row_index (9),
union (10), validate (5), view_resource (3) y where (8). El motor V8 pasa
7 de las 11 experimentales.

## Rendimiento

`data-raw/motor-duckdb.R`: pacientes sintéticos (dos nombres, una dirección)
en NDJSON, la vista de `data-raw/rendimiento.R` (`where` sobre la fecha,
`forEach` sobre `name`, `%rowIndex`, `join()` y `where().first()`). El tiempo
de V8 incluye leer el archivo con `fhir_recursos()`; el de DuckDB, leerlo y
traer el `data.frame` a R (o crear la tabla en DuckDB). Los dos motores dan
el mismo `data.frame` (comprobado con `all.equal()`).

| Pacientes | NDJSON | Filas | DuckDB, tabla | DuckDB, `data.frame` | V8 (`fhir_recursos()` + `vista_ejecutar()`) |
|---:|---:|---:|---:|---:|---:|
| 50 000 | 13 MB | 89 180 | 0,65 s | 0,64 s | 10,8 s |
| 250 000 | 67 MB | 444 942 | 1,16 s | 1,34 s | 55,4 s |
| 1 000 000 | 271 MB | 1 781 318 | 4,43 s | 4,53 s | no medido |

Equipo: Linux, 8 núcleos, 14 GB de RAM (unos 4 GB libres), R 4.5.2,
duckdb 1.5.6. Una corrida de cada motor; DuckDB después de una de
calentamiento.

* El tiempo de DuckDB crece casi linealmente y usa los 8 núcleos; con
  50 000 recursos la mitad es el arranque y la traducción.
* Memoria: el proceso completo con 1 000 000 de pacientes (generarlos en R,
  ejecutar la vista y traer 1,8 millones de filas a R) llegó a 1,3 GB. Con
  `tabla = "..."` el resultado se queda en DuckDB y la memoria de R no
  depende del número de recursos.
* V8 con 1 000 000 no se midió a propósito: con 250 000 el proceso ya pasaba
  de 2 GB y crece linealmente (unos 8 GB para un millón, más de lo libre en
  este equipo); por el ritmo medido tardaría unos 4 minutos si tuviera la
  memoria.

## Comparación con otras implementaciones

* **FlatQuack** (MIT, JavaScript/Bun) también compila ViewDefinition a SQL de
  DuckDB con plantillas y usa un esquema FHIR R4 para tipar los datos. No se
  copió código: este prototipo usa JSON sin esquema y una traducción por
  expresiones de listas en lugar de uniones generadas.
* **pathling** (CRAN) implementa SQL on FHIR desde R sobre Spark y Java. El
  motor DuckDB da a fhirviews una alternativa sin JVM ni clúster, instalable
  desde CRAN, para volúmenes de millones de recursos en un portátil.

## Limitaciones

* Requiere la extensión `json` de DuckDB, que el paquete duckdb de CRAN no
  trae incorporada: DuckDB la descarga la primera vez (`INSTALL json`). Sin
  internet ese primer uso falla con un mensaje claro. Por eso las pruebas que
  ejecutan SQL se saltan en CRAN.
* Necesita duckdb 1.3.0 o posterior (sintaxis `lambda x: ...`).
* El SQL generado es largo (cada navegación se expande en línea para que la
  consulta funcione sin macros); `vista_sql()` sirve para revisarlo, no para
  editarlo a mano.
* Profundidad fija de `repeat` (error si se supera).

## Recomendación

Incorporarlo como segundo motor, marcado como experimental:

1. Cumple la especificación en el mismo grado que el motor V8 en las pruebas
   shareable y es de 17 a 41 veces más rápido en lo medido, con memoria acotada por
   DuckDB y no por la sesión de R. Es el diferenciador que buscaba el
   paquete: SQL on FHIR para millones de recursos en un portátil, desde CRAN
   y sin Spark.
2. Mantener `vista_ejecutar()` como motor por defecto y de referencia
   (FHIRPath completo); el error de traducción ya dirige a él.
3. Próximos pasos: un argumento `motor = "duckdb"` en `vista_duckdb()`;
   usar el modelo FHIR R4 para resolver elementos de elección sin `ofType()`
   y para comparar fechas con precisión; macros opcionales para un SQL más
   legible; probar con datos de Synthea (Observation, Encounter) y con
   Parquet de otras herramientas.
