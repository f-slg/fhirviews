# Construir recursos FHIR R4 desde tablas o consultas SQL

Define un mapeo explicito de columnas a destinos FHIR y construye un
recurso por fila. Admite `Patient`, `Observation`, `Encounter`,
`Condition` e `Immunization`. No intenta invertir un `ViewDefinition`,
que puede haber perdido datos.

## Usage

``` r
fhir_mapa(
  recurso,
  campos = character(),
  constantes = list(),
  referencias = character()
)

fhir_desde_tabla(datos, mapa)

fhir_desde_sql(con_db, sql, mapa, parametros = NULL)
```

## Arguments

- recurso:

  Tipo FHIR: `"Patient"`, `"Observation"`, `"Encounter"`, `"Condition"`
  o `"Immunization"`.

- campos:

  Vector de texto con destinos FHIR como nombres y columnas de origen
  como valores.

- constantes:

  Lista con nombre de valores fijos, con destinos FHIR como nombres. Se
  aplica a cada fila.

- referencias:

  Vector con nombre: destino terminado en `.reference` y tipo de recurso
  al que apunta. Convierte la clave de origen en una referencia
  relativa, por ejemplo `Patient/p1`. Una referencia construida requiere
  `reference`, `identifier` o `display`; `type` solo no identifica un
  destino.

- datos:

  Un `data.frame`; cada fila representa un recurso.

- mapa:

  Mapeo creado con `fhir_mapa()`.

- con_db:

  Conexion DBI abierta (DuckDB, PostgreSQL, SQLite, SQL Server, etc.,
  mediante su controlador DBI).

- sql:

  Consulta que produce una fila por recurso. La consulta se ejecuta tal
  como se recibe; se recomienda usar parametros para valores.

- parametros:

  Lista opcional de parametros enlazados por el controlador DBI, sin
  interpolarlos en el SQL.

## Value

`fhir_mapa()` devuelve un `fhir_mapa`. Las otras funciones devuelven
[`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md),
sin enviar recursos a un servidor FHIR ni crear tablas por su cuenta. La
consulta SQL se ejecuta tal como se recibe. `fhir_desde_sql()` trae el
resultado completo a memoria. Usa
[`fhir_escribir()`](https://f-slg.github.io/fhirviews/reference/fhir_escribir.md)
para guardar JSON o NDJSON conservando decimales.

## Details

Los destinos usan nombres JSON de FHIR, puntos e indices desde cero:
`name[0].family`, `code.coding[0].code`, `valueQuantity.value`. Un
destino terminado en `[]`, como `name[0].given[]`, toma una columna de
listas de valores primitivos. Cada elemento repetido debe declarar su
indice o `[]`; no se evalua FHIRPath ni codigo R en el mapeo.

`NA`, `NULL`, cadenas vacias y listas vacias se omiten. Los indices sin
contenido se compactan; no se escriben objetos vacios ni `null`. Cada
fila debe producir un `id` no vacio y unico. Para agrupar filas del
mismo recurso, prepara primero una fila por recurso en SQL o en R,
usando columnas de listas para las colecciones.

Los tipos y cardinalidades se comprueban con metadatos base de FHIR R4
4.0.1. Se revisan campos obligatorios, elementos de eleccion, fechas,
identificadores, tipos primitivos, destinos de referencias y bindings
requeridos que pueden enumerarse con la terminologia R4 incluida. Para
`Coding` y `CodeableConcept` se comprueba el par `system`/`code`. Los
valores `code` admiten solo espacios simples internos; `uri`, `url` y
`canonical` no admiten espacios ni otros caracteres de separacion. Estos
controles lexicos no comprueban que una URL exista. Se conserva la
restriccion de `SimpleQuantity`: no admite `comparator`, por ejemplo en
`Immunization.doseQuantity`. Una `Quantity` general puede admitirlo. El
estado, la vacuna, el paciente y una variante de `occurrence[x]` son
obligatorios en `Immunization`; si se construye `protocolApplied`, cada
entrada exige una variante de `doseNumber[x]`. Esto no sustituye la
validacion de invariantes, terminologias y perfiles con
[`fhir_validar()`](https://f-slg.github.io/fhirviews/reference/fhir_validar.md).
No se inventan codigos, unidades o estados.

Los destinos decimales aceptan numeros o texto numerico JSON. El texto
conserva la escala (`"1.00"` se escribe como el numero JSON `1.00`).
Para conservar un `DECIMAL(p,s)` de SQL, extraelo como texto en la
consulta; una vez convertido a un numero de R no se recuperan sus ceros.
`Date` se admite como `date` o `dateTime`, conservando precision de
fecha; `POSIXct`/`POSIXlt` se convierten a UTC. Los identificadores
tambien aceptan enteros seguros, convertidos a texto; para BIGINT usa un
CAST a texto en SQL. El resto de textos no admite conversion implicita.

## Examples

``` r
mapa <- fhir_mapa("Patient", c(
  id = "paciente_id", gender = "sexo",
  "name[0].family" = "apellido", "name[0].given[0]" = "nombre"))
datos <- data.frame(paciente_id = "p1", sexo = "female",
                    apellido = "Paredes", nombre = "Ana")
recursos <- fhir_desde_tabla(datos, mapa)
vista_fhirpath(recursos, "name.given")
#> [1] "Ana"
```
