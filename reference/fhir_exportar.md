# Exportación masiva de datos (FHIR Bulk Data, `$export`)

Pide al servidor una exportación masiva según la especificación [FHIR
Bulk Data Access](https://hl7.org/fhir/uv/bulkdata/): el servidor
prepara archivos NDJSON (un recurso por línea) en segundo plano y, al
terminar, `fhir_exportar()` los descarga a una carpeta local. Es la
forma adecuada de reunir datos de toda una población (vigilancia
epidemiológica, indicadores), y el NDJSON es justo el formato que
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
procesa más rápido.

## Usage

``` r
fhir_exportar(
  con,
  nivel = c("sistema", "paciente", "grupo"),
  grupo = NULL,
  tipos = NULL,
  desde = NULL,
  filtros = NULL,
  carpeta = tempfile("fhir_export_"),
  esperar = TRUE,
  intervalo = NULL,
  max_espera = 3600,
  progreso = interactive()
)

fhir_exportar_estado(
  x,
  esperar = FALSE,
  descargar = TRUE,
  intervalo = NULL,
  max_espera = 3600,
  progreso = interactive()
)

fhir_exportar_cancelar(x)
```

## Arguments

- con:

  Conexión creada con
  [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md).

- nivel:

  Qué exportar: `"sistema"` (todos los datos del servidor,
  `[base]/$export`), `"paciente"` (todos los pacientes y sus datos,
  `Patient/$export`) o `"grupo"` (los pacientes de un `Group`,
  `Group/[id]/$export`). Si se da `grupo`, por defecto es `"grupo"`.

- grupo:

  Id del recurso `Group`, para `nivel = "grupo"`.

- tipos:

  Vector de tipos de recurso a exportar (parámetro `_type`), por ejemplo
  `c("Patient", "Condition")`. Por defecto, todos.

- desde:

  Exportar solo los recursos modificados desde ese momento (parámetro
  `_since`): un `Date`, un `POSIXct` o un texto en formato FHIR
  `instant` (`"2025-01-01T00:00:00Z"`).

- filtros:

  Vector de filtros de búsqueda por tipo (parámetro `_typeFilter`), por
  ejemplo `"Condition?code=http://hl7.org/fhir/sid/icd-10|A90"`.

- carpeta:

  Carpeta donde se guardan los archivos NDJSON. Se crea si no existe.

- esperar:

  Si es `TRUE` (por defecto), espera a que el servidor termine y
  descarga los archivos. Si es `FALSE`, devuelve la exportación en
  curso.

- intervalo:

  Segundos entre consultas de estado. Por defecto se usa `Retry-After`;
  si se da, nunca se consulta antes de lo que pide el servidor.

- max_espera:

  Segundos máximos de espera. Si se agotan, se avisa y se devuelve la
  exportación en curso, que se puede seguir consultando con
  `fhir_exportar_estado()`.

- progreso:

  Si es `TRUE`, muestra el avance (por defecto, en sesiones
  interactivas).

- x:

  Exportación devuelta por `fhir_exportar()` o por
  `fhir_exportar_estado()`.

- descargar:

  Si es `TRUE` (por defecto), descarga los archivos cuando la
  exportación está lista.

## Value

Un objeto de clase `fhir_exportacion`, una lista con:

- `estado`: `"en_curso"`, `"completada"` o `"cancelada"`;

- `archivos`: lista con nombre por tipo de recurso, con las rutas de los
  archivos descargados (se pasan tal cual a
  [`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md)
  o
  [`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md));

- `errores`: rutas de los archivos de `OperationOutcome` con los
  problemas que el servidor informó durante la exportación;

- `manifiesto`: el manifiesto del servidor como lista de R;

- `url_estado`, `carpeta`, `nivel` y `progreso` (último `X-Progress`).

## Details

El proceso tiene tres pasos:

1.  *Inicio*: `GET [base]/$export` (o `Patient/$export`, o
    `Group/[id]/$export`) con `Prefer: respond-async`. El servidor
    responde `202 Accepted` y una dirección de estado en
    `Content-Location`.

2.  *Espera*: se consulta la dirección de estado; mientras responde
    `202` se espera lo que indica `Retry-After` (o, si no lo indica,
    cada vez más tiempo, hasta un minuto) y se muestra el avance de
    `X-Progress`. Cuando responde `200`, el cuerpo es el manifiesto con
    la lista de archivos.

3.  *Descarga*: cada archivo del manifiesto se guarda en `carpeta`. Si
    el manifiesto indica `requiresAccessToken`, se envía el token de la
    conexión, pero solo a archivos del mismo servidor.

Con `esperar = FALSE`, `fhir_exportar()` devuelve la exportación en
curso justo después del inicio; luego se consulta con
`fhir_exportar_estado()` (que la descarga cuando está lista) o se
cancela con `fhir_exportar_cancelar()` (`DELETE` a la dirección de
estado).

`fhir_exportar_estado()` consulta el estado una vez (o, con
`esperar = TRUE`, hasta que termine) y devuelve la exportación
actualizada: hay que guardarla de nuevo,
`trabajo <- fhir_exportar_estado(trabajo)`.

`fhir_exportar_cancelar()` envía `DELETE` a la dirección de estado; el
servidor deja de preparar los archivos (o borra los ya preparados).
Devuelve, de forma invisible, la exportación con `estado = "cancelada"`.

## See also

[`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md),
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md),
[`fhir_buscar()`](https://f-slg.github.io/fhirviews/reference/fhir_buscar.md)
para consultas pequeñas.

## Examples

``` r
if (FALSE) { # interactive() && fhir_disponible("https://bulk-data.smarthealthit.org/fhir")
# Servidor de referencia de SMART (datos sintéticos, sin autenticación)
con <- fhir_conectar("https://bulk-data.smarthealthit.org/fhir")
exp <- fhir_exportar(con, "paciente", tipos = c("Patient", "Condition"))
exp
pacientes <- vista_ejecutar(exp$archivos$Patient,
                            vista_crear("Patient", c(sexo = "gender")))
table(pacientes$sexo)

# Sin esperar: consultar más tarde o cancelar
trabajo <- fhir_exportar(con, "sistema", esperar = FALSE)
trabajo <- fhir_exportar_estado(trabajo)
fhir_exportar_cancelar(trabajo)
}
```
