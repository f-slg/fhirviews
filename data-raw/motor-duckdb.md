# Motor DuckDB para fhirviews: informe

Código en `R/sql.R` (estructura del `ViewDefinition` y ejecución) y
`R/sql-fhirpath.R` (traductor de FHIRPath), pruebas en
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
  esperados, y **7 de las 11 experimentales**, también las mismas que V8
  (fallan las de `lowBoundary()`/`highBoundary()` de decimales y de fechas y
  horas con precisión de día; ver más abajo).
* **FHIRPath:** traduce todo lo que exige el perfil shareable y la mayor
  parte de FHIRPath N1 (inventario abajo), con la semántica de fhirpath.js.
  Una prueba diferencial compara los dos motores con unas 110 expresiones con
  casos límite (fechas parciales y zonas horarias, Unicode, tipos mezclados) y
  con las vistas de todas las viñetas, y otras 19 comprueban que lo dudoso da
  error.
* **Rendimiento:** con 250 000 pacientes en NDJSON, 1,6 s frente a 59 s de
  `vista_ejecutar()` (38 veces más rápido); con 1 000 000 (271 MB,
  1,8 millones de filas), 5,8 s, un volumen que el motor V8 no alcanza en
  este portátil.
* **Resultado diferido:** `vista_ejecutar_duckdb(..., diferido = TRUE)`
  devuelve una tabla de dplyr sobre DuckDB.
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
comparaciones miran el tipo de cada lado (del literal, del modelo FHIR o del
valor JSON) y siguen las reglas de fhirpath.js descritas en
[Semántica](#semántica-cómo-se-asegura-el-mismo-resultado-que-fhirpathjs).

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

## Inventario de FHIRPath

Funciones y operadores de la especificación
[FHIRPath N1 (2.0.0)](https://hl7.org/fhirpath/N1/), las que agrega FHIR R4
y SQL on FHIR, y las de FHIRPath 3.0 que usa el banco (`lowBoundary()`,
`highBoundary()`). La columna *shareable* marca lo que el perfil
[*Shareable View Definition*](https://sql-on-fhir.org/ig/latest/StructureDefinition-ShareableViewDefinition.html)
exige a toda implementación (literales, `=`, `!=`, `<`, `<=`, `>`, `>=`,
`and`, `or`, `not()`, aritmética, `[]`, `exists()`, `empty()`,
`extension()`, `first()`, `join()`, `lowBoundary()`, `highBoundary()`,
`ofType()`, `where()`, `getResourceKey()` y `getReferenceKey()`).

Sí: se traduce y da lo mismo que fhirpath.js. Parcial: se traduce en los
casos indicados y en los demás da error (nunca otro resultado). No: error
`fhirviews_error_sql` al traducir.

| Sección | Función u operador | Shareable | DuckDB |
|---|---|:-:|---|
| 5.1 Existencia | `empty()`, `exists([criterio])`, `count()` | sí | Sí |
| | `all()`, `allTrue()`, `anyTrue()`, `allFalse()`, `anyFalse()` | | Sí |
| | `subsetOf()`, `supersetOf()`, `distinct()`, `isDistinct()` | | Sí (los elementos complejos no se comparan: error) |
| 5.2 Filtros | `where()` | sí | Sí |
| | `select()` | | Sí |
| | `ofType()` | sí | Parcial: elementos de elección, tipos del modelo y `boolean` |
| | `repeat()` (función) | | No (el `repeat` del ViewDefinition sí) |
| 5.3 Subconjuntos | `[i]` | sí | Sí |
| | `first()` | sí | Sí |
| | `single()`, `last()`, `tail()` | | Sí |
| | `skip()`, `take()` | | Sí (número negativo: error, fhirpath.js usa `slice()`) |
| | `intersect()`, `exclude()` | | Sí |
| 5.4 Combinación | `union()`, `\|`, `combine()` | | Sí, conservando el orden |
| 5.5 Conversión | `iif()` | | Sí |
| | `toBoolean()`, `toInteger()`, `toDecimal()`, `toString()` y sus `convertsTo...()` | | Sí (`toString()` de elementos complejos: error) |
| | `toDate()`, `toDateTime()`, `toTime()`, `toQuantity()` y sus `convertsTo...()` | | No |
| 5.6 Texto | `startsWith()`, `endsWith()`, `contains()`, `substring()`, `indexOf()`, `length()`, `toChars()` | | Sí (caracteres fuera del plano básico: error) |
| | `upper()`, `lower()` | | Sí (los ~500 caracteres que DuckDB convierte distinto, como `ß`: error) |
| | `replace()` | | Sí (`$` en el reemplazo: error) |
| | `matches()`, `replaceMatches()` | | Parcial: expresión regular literal sin construcciones que JavaScript y RE2 lean distinto (`\s`, grupos con nombre, referencias...) |
| | `trim()`, `split()`, `join()` | sí (`join`) | Sí |
| 5.7 Matemática | `abs()`, `ceiling()`, `floor()`, `round()`, `truncate()`, `sqrt()` | | Sí |
| | `power()` | | Parcial: enteros con resultado exacto |
| | `exp()`, `ln()`, `log()` | | No (libm y V8 pueden diferir en el último bit) |
| 5.8 Árbol | `children()`, `descendants()` | | No |
| 5.9 Utilidad | `trace()` | | Sí (no escribe nada) |
| | `now()`, `today()`, `timeOfDay()` | | No |
| 6.1 Igualdad | `=`, `!=` | sí | Sí (elementos complejos: error) |
| | `~`, `!~` | | Sí con textos, lógicos y fechas; con números, no |
| 6.2 Comparación | `<`, `<=`, `>`, `>=` | sí | Sí, con la regla de precisión de fechas y horas |
| 6.3 Tipos | `is`, `as`, `is()`, `as()` | | Como `ofType()` |
| 6.4 Colecciones | `in`, `contains` | | Sí |
| 6.5 Lógica | `and`, `or`, `not()` | sí | Sí |
| | `xor`, `implies` | | Sí |
| 6.6 Aritmética | `+`, `-`, `*`, `/`, `div`, `mod` | sí | Sí con números y textos (`+`) |
| | `&` | | Sí |
| 6.6 Fechas | `fecha + cantidad` | | No |
| Literales | texto, entero, decimal, lógico, `{}` | sí | Sí |
| | `@fecha`, `@fechaThora`, `@Thora` | sí | Sí |
| | cantidades (`5 'mg'`) | | No |
| 7 Agregados | `aggregate()`, `$index`, `$total` | | No |
| FHIR | `extension(url)` | sí | Sí |
| | `hasValue()` | | Sí |
| | `resolve()`, `memberOf()`, `conformsTo()`, `htmlChecks()` | | No |
| SQL on FHIR | `getResourceKey()`, `getReferenceKey([tipo])` | sí | Sí |
| FHIRPath 3.0 | `lowBoundary()`, `highBoundary()` | sí | Parcial: fechas, horas y fechas y horas con hora y zona; decimales y fechas y horas con precisión de día, no |
| | `precision()` | | No |
| Variables | `%resource`, `%rootResource`, `%rowIndex`, constantes | sí | Sí |

Antes de esta versión el motor no traducía los conjuntos (`union()`,
`intersect()`...), `allTrue()` y afines, `indexOf()`, `replaceMatches()`,
`split()`, `toChars()`, `toBoolean()`, `convertsTo...()`, las funciones
matemáticas ni `lowBoundary()`/`highBoundary()`; y varias de las que sí (`toInteger()`, `substring()`, `replace()`, `|`, `iif()`, las
comparaciones de fechas y entre tipos distintos) daban en casos límite un
resultado distinto del de fhirpath.js sin avisar. La prueba diferencial
nueva los encontró y se corrigieron.

## Semántica: cómo se asegura el mismo resultado que fhirpath.js

**Tipos del modelo FHIR.** Cada expresión traducida lleva el tipo FHIR que da
el modelo R4 de fhirpath.js (`path2Type`, `choiceTypePaths`...), seguido al
navegar como lo hace `fhirviews.tipo()`. Con él se eligen solo las variantes
posibles de cada elemento de elección (`Observation.value` busca 11 campos,
no los 50 de todos los recursos) y se sabe si un texto es un `string`, una
fecha o una hora. Si el tipo no se conoce (por ejemplo, `extension.value`
sin `ofType()`) y un texto parece una fecha, la consulta da error.

**Igualdad y orden.** Como en fhirpath.js: valores de tipos distintos no son
iguales (`'1' = 1` y `birthDate = '1970-06-15'` son falsos) y no se pueden
ordenar (error); los números se comparan redondeados a 8 decimales
(`0.1 + 0.2 = 0.3` es verdadero) y los enteros, como enteros; `~` entre
textos pasa a mayúsculas y cambia los espacios de Unicode por espacios; los
elementos complejos no se comparan (error).

**Fechas y horas.** Se compara la forma canónica de cada valor (en UTC si
tiene zona horaria) en la precisión común: si difieren, decide el orden; si
coinciden y tienen la misma precisión, son iguales; si no, el resultado es
vacío (`@2024 < @2024-06` no es verdadero ni falso). Segundos y milisegundos
son la misma precisión, como en fhirpath.js, y otros números de decimales dan
error. Dos casos dependen en fhirpath.js de la zona horaria del equipo y por
eso solo se traducen si el resultado sería el mismo en cualquier zona (de
−12 a +14 horas): una fecha con hora sin zona frente a una con zona, y una
fecha sin hora frente a una fecha y hora. Así,
`effective.ofType(dateTime) > @2024-03-01` da error con las observaciones
cercanas a la medianoche de ese día; la forma segura es
`effective.ofType(dateTime) > @2024-03-01T00:00:00Z`.

**Conjuntos.** `|`, `union()`, `distinct()`, `intersect()`, `in`... usan una
clave de igualdad por elemento (tipo y valor; números redondeados como en la
igualdad; fechas con hora en UTC) y conservan el orden de la primera
aparición, como fhirpath.js. Dos elementos complejos distintos no se pueden
comparar con certeza (fhirpath.js los compara campo a campo): error.

**Texto.** JavaScript cuenta los caracteres fuera del plano básico (emojis)
como dos, así que `length()`, `substring()`, `indexOf()` y `toChars()` dan
error con ellos. `upper()`, `lower()` y `~` dan error con los caracteres que
DuckDB convierte distinto (`data-raw/mayusculas.R` los calcula recorriendo
Unicode; una prueba revisa el plano básico hasta U+2FFF). `trim()` quita los
mismos espacios que JavaScript. `matches()` y `replaceMatches()` traducen la
expresión regular (con las banderas `su` de fhirpath.js) solo si usa
construcciones que significan lo mismo en RE2; `\d`, `\w` y `\b` son ASCII
en los dos.

**Números.** Los decimales son `DOUBLE`, como los números de JavaScript.
`toString()` escribe los números como JavaScript (`3.0` es `"3"`, salvo un
literal decimal, que conserva su texto como en fhirpath.js). `round()`
redondea las mitades hacia +∞ como `Math.round()`. Una columna sin tipo cuyos
valores son todos enteros llega a R como entero, como en `vista_ejecutar()`.

## Resultado diferido

`vista_ejecutar_duckdb(archivos, vista, diferido = TRUE)` devuelve
`dplyr::tbl(con, dplyr::sql(consulta))` (dplyr y dbplyr en Suggests): los
filtros, agrupaciones y resúmenes de dplyr se traducen a SQL y se calculan en
DuckDB sobre los archivos, sin traer las filas a R.

```r
casos <- vista_ejecutar_duckdb("exportacion/*.ndjson", vista, diferido = TRUE)
casos |> dplyr::filter(sexo == "female") |> dplyr::count(canton) |> dplyr::collect()
DBI::dbDisconnect(dbplyr::remote_con(casos))
```

Las columnas sin tipo deducible se resuelven al crear la tabla (una lectura
de los datos); la conexión queda abierta mientras se use la tabla. Al hacer
`collect()`, los elementos complejos llegan como texto JSON y las colecciones
como listas de DuckDB.

## Conformidad

```
vista_conformidad(motor = "duckdb")
Banco de pruebas de SQL on FHIR (FHIR/sql-on-fhir.js@6677c20, 2026-07-09)
fhirviews 0.2.0.9000 · motor DuckDB 1.5.6

  experimental     7 de  11 aprobadas
  shareable      133 de 133 aprobadas
  total          140 de 144 aprobadas
```

Pasan todos los archivos shareable: basic (11), collection (4), combinations
(6), constant (8), constant_types (14), fhirpath (9), fhirpath_numbers (1),
fn_empty (1), fn_extension (2), fn_first (2), fn_oftype (2),
fn_reference_keys (3), foreach (13), logic (3), repeat (19), row_index (9),
union (10), validate (5), view_resource (3) y where (8). De las
experimentales pasan las 3 de `join()` y 4 de `fn_boundary.json` (fecha y
hora), las mismas que el motor V8. Las otras 4 esperan lo que fhirpath.js no
da: `1.0.lowBoundary()` = 0.95 (la precisión del decimal se pierde al leer el
JSON en los dos motores) y la zona +14:00/−12:00 en los límites de una fecha
y hora con precisión de día (fhirpath.js no la agrega); el motor DuckDB da
error en esos casos en lugar de copiar el resultado de fhirpath.js.

## Rendimiento

`data-raw/motor-duckdb.R`: pacientes sintéticos (dos nombres, una dirección)
en NDJSON, la vista de `data-raw/rendimiento.R` (`where` sobre la fecha,
`forEach` sobre `name`, `%rowIndex`, `join()` y `where().first()`). El tiempo
de V8 incluye leer el archivo con `fhir_recursos()`; el de DuckDB, leerlo y
traer el `data.frame` a R (o crear la tabla en DuckDB). Los dos motores dan
el mismo `data.frame` (comprobado con `all.equal()`).

| Pacientes | NDJSON | Filas | DuckDB, tabla | DuckDB, `data.frame` | V8 (`fhir_recursos()` + `vista_ejecutar()`) |
|---:|---:|---:|---:|---:|---:|
| 10 000 | 3 MB | 17 824 | 0,42 s | 0,22 s | 2,3 s |
| 50 000 | 13 MB | 89 128 | 0,89 s | 0,92 s | 11,0 s |
| 100 000 | 27 MB | 178 062 | 1,18 s | 1,18 s | 23,2 s |
| 250 000 | 67 MB | 444 912 | 1,63 s | 1,56 s | 58,9 s |
| 1 000 000 | 271 MB | 1 780 958 | 5,71 s | 5,85 s | no medido |

Medición de la versión 0.2.0.9000 (`Rscript data-raw/motor-duckdb.R
10000,50000,100000,250000,1000000 250000`). Frente a la 0.2.0 (5,5 s con un
millón), las comparaciones de fechas con su precisión y la conversión de
tipos cuestan unas décimas de segundo; con 10 000 recursos pesa más la carga
del modelo FHIR, que se hace una vez por sesión.

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

## Revisión y prueba diferencial

Una revisión comparó los dos motores con 8 vistas reales sobre
`inst/extdata` y encontró dos columnas que DuckDB devolvía como `NA` sin
error: `answer.value.first().toString()` en un `repeat` de
QuestionnaireResponse y `address.extension(%dpa).value.first()` en los
pacientes de dengue. En ambos casos la causa era `value` sin `ofType()`, que
el prototipo trataba como un campo normal. Se corrigió con la navegación a
elementos de elección descrita arriba y con un `ofType()` estricto. Las 8
vistas coinciden ahora en valores y tipos.

Para que esta clase de errores no vuelva, `tests/testthat/test-sql.R`
incluye una prueba diferencial: busca en las viñetas (`fhirviews.Rmd`,
`vistas.Rmd` y `tasas-pobecu.Rmd`) las llamadas a `vista_crear()`,
`vista_leer()` y `vista_ejecutar(recursos, "json")` (hoy 17 vistas), las
ejecuta con los dos motores sobre `inst/extdata` y exige tablas idénticas
(`identical()` de las columnas) o que fallen los dos. Para lograr tablas
idénticas, las colecciones vacías sin `type` se devuelven como `logical()`,
como en `vista_ejecutar()`.

En la versión 0.2.0.9000 la prueba diferencial se amplió con unas 110
expresiones de FHIRPath sobre recursos con casos límite (fechas de distinta
precisión y zona, decimales, textos con `ñ`, `ß`, `Σ` y emojis, valores de
tipos mezclados) y 19 casos que deben dar error. Al escribirla aparecieron
divergencias silenciosas en funciones que el motor ya traducía, por ejemplo:
`'0901'.toInteger()` daba vacío (fhirpath.js: 901) y `1.5.toInteger()` daba 2
(vacío); `substring(10)` daba `""` (vacío); `name.given | name.family`
cambiaba el orden; `birthDate = '1970-06-15'` daba verdadero (falso: fecha
frente a texto); `@2024-03-01 = effective` con `"2024-03-01T10:15:00Z"` daba
falso (vacío por la precisión); `iif('a', 1, 2)` daba 1 (2). Todas siguen ahora
a fhirpath.js o dan error.

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
  trae incorporada: DuckDB la descarga con `INSTALL json`. Para no escribir
  en `~/.duckdb` (CRAN no lo permite), la conexión se crea con
  `conectar_duckdb()` (`shared_home = FALSE`), así que las extensiones van a
  la carpeta temporal y la descarga se repite en cada sesión de R. Sin
  internet falla con un mensaje claro. Por eso las pruebas que ejecutan SQL
  se saltan en CRAN.
* Necesita duckdb 1.3.0 o posterior (sintaxis `lambda x: ...`).
* El SQL generado es largo (cada navegación se expande en línea para que la
  consulta funcione sin macros); `vista_sql()` sirve para revisarlo, no para
  editarlo a mano.
* Profundidad fija de `repeat` (error si se supera).

## Recomendación

Incorporarlo como segundo motor, marcado como experimental:

1. Cumple la especificación en el mismo grado que el motor V8 en las pruebas
   shareable y experimentales y es de 11 a 38 veces más rápido en lo medido, con memoria acotada por
   DuckDB y no por la sesión de R. Es el diferenciador que buscaba el
   paquete: SQL on FHIR para millones de recursos en un portátil, desde CRAN
   y sin Spark.
2. Mantener `vista_ejecutar()` como motor por defecto y de referencia
   (FHIRPath completo); el error de traducción ya dirige a él.
3. Próximos pasos: un argumento `motor = "duckdb"` en `vista_duckdb()`;
   distinguir el tipo de los elementos de elección por el campo JSON del que
   salen (para comparar `extension.value` sin `ofType()`); `toDate()`,
   `toDateTime()`, `today()` y aritmética de fechas con cantidades; macros
   opcionales para un SQL más legible; probar con datos de Synthea
   (Observation, Encounter) y con Parquet de otras herramientas.
