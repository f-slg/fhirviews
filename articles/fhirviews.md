# Primeros pasos con fhirviews

fhirviews tiene dos partes que se usan juntas:

1.  un **cliente FHIR** (`fhir_*`) para hablar con un servidor HL7 FHIR
    R4 desde R, como harías con Postman;
2.  un **motor de vistas** (`vista_*`) que convierte recursos FHIR en
    tablas con el estándar [SQL on FHIR](https://sql-on-fhir.org/)
    (`ViewDefinition`).

Esta viñeta recorre las dos con el caso clínico ficticio del taller
[aprende-fhir](https://github.com/f-slg/aprende-fhir): Luis Alberto
Paredes Cevallos, nacido en Riobamba y residente en Quito, que consulta
por una intoxicación alimentaria y luego es diagnosticado y tratado por
un cáncer de mama.

``` r

library(fhirviews)
```

## 1. Conectarse a un servidor

Los ejemplos que necesitan un servidor no se ejecutan al construir esta
viñeta; puedes probarlos con el servidor público de HAPI o con uno local
(por ejemplo el del taller, que se levanta con Podman o Docker en
`http://localhost:8080/fhir`).

``` r

con <- fhir_conectar("https://hapi.fhir.org/baseR4")
con
#> <fhir_conexion> https://hapi.fhir.org/baseR4
#>   Servidor:     HAPI FHIR Server 8.x
#>   Versión FHIR: 4.0.1

# Buscar: sigue sola los enlaces "next" de cada página
pacientes <- fhir_buscar(con, "Patient", family = "Paredes", `_count` = 50)

# Leer, crear, actualizar, borrar
paciente <- fhir_leer(con, "Patient", "123")
nuevo <- fhir_crear(con, "paciente.json")
nuevo$telecom <- list(list(system = "phone", value = "0990000000"))
nuevo <- fhir_actualizar(con, nuevo)
fhir_borrar(con, nuevo)

# Operaciones
todo <- fhir_everything(con, "Patient", "123")
fhir_validar(con, "paciente.json")

# Cualquier otra petición, como en Postman
fhir_peticion(con, "GET", "Patient/123/_history")
fhir_ejecutar_texto("GET Observation?code=http://loinc.org|85354-9&_count=5")
```

Si el servidor responde con un error, el mensaje muestra el
`OperationOutcome`:

``` r

fhir_leer(con, "Patient", "no-existe")
#> Error:
#> ! El servidor respondió 404 Not Found.
#> ✖ GET https://hapi.fhir.org/baseR4/Patient/no-existe
#> • [error] HAPI-2001: Resource Patient/no-existe is not known
```

En RStudio,
[`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md)
agrega además el servidor al panel *Connections*, y el menú *Addins*
tiene *Ejecutar petición FHIR* y *Ejecutar ViewDefinition* para lanzar
con un clic el texto seleccionado.

## 2. Los datos del caso clínico

El paquete incluye el caso del taller (60 recursos) en formato NDJSON,
un recurso por línea, como lo exporta la operación `$export` de FHIR.
Con
[`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md)
se lee igual que un Bundle, un archivo JSON o la respuesta de
[`fhir_buscar()`](https://f-slg.github.io/fhirviews/reference/fhir_buscar.md):

``` r

caso <- fhir_recursos(system.file("extdata", "caso_clinico.ndjson",
                                  package = "fhirviews"))
caso
#> <fhir_recursos> 60 recursos
#>   AllergyIntolerance: 1
#>   Appointment: 2
#>   AppointmentResponse: 1
#>   BodyStructure: 1
#>   CarePlan: 1
#>   CareTeam: 1
#>   Condition: 2
#>   Consent: 1
#>   DiagnosticReport: 2
#>   Encounter: 3
#>   FamilyMemberHistory: 2
#>   Goal: 2
#>   Immunization: 3
#>   Location: 2
#>   MedicationAdministration: 2
#>   MedicationRequest: 2
#>   MedicationStatement: 1
#>   Observation: 12
#>   Organization: 2
#>   Patient: 1
#>   Practitioner: 3
#>   PractitionerRole: 2
#>   Procedure: 1
#>   Questionnaire: 1
#>   QuestionnaireResponse: 2
#>   Schedule: 1
#>   ServiceRequest: 3
#>   Slot: 2
#>   Specimen: 1
```

[`fhir_tabla()`](https://f-slg.github.io/fhirviews/reference/fhir_tabla.md)
da un primer vistazo rápido, una columna por elemento:

``` r

fhir_tabla(caso, tipo = "Patient")[, c("id", "active", "gender", "birthDate")]
#>        id active gender  birthDate
#> 1 patient   TRUE   male 1979-03-12
```

## 3. Probar expresiones FHIRPath

Las columnas de una vista son expresiones
[FHIRPath](https://hl7.org/fhirpath/). Con
[`vista_fhirpath()`](https://f-slg.github.io/fhirviews/reference/vista_fhirpath.md)
se prueban antes de usarlas:

``` r

paciente <- caso[1]
vista_fhirpath(paciente, "name.where(use = 'official').text")
#> [1] "Luis Alberto Paredes Cevallos"
vista_fhirpath(paciente, "telecom.where(system = 'email').value")
#> [1] "luis.paredes@correo.invalid"
vista_fhirpath(paciente, "identifier.where(type.text = 'Cédula de identidad').value")
#> [1] "9900000017"
vista_fhirpath(paciente, "name.family.extension('http://hl7.org/fhir/StructureDefinition/humanname-mothers-family').value")
#> [1] "Cevallos"
```

## 4. Una vista sencilla

[`vista_crear()`](https://f-slg.github.io/fhirviews/reference/vista_crear.md)
arma un `ViewDefinition` a partir de un vector con nombre: cada nombre
es una columna y cada valor, su expresión. Por defecto agrega la clave
del recurso en la columna `id`.

``` r

v_paciente <- vista_crear("Patient", c(
  nombre = "name.where(use = 'official').text",
  sexo = "gender",
  nacimiento = "birthDate",
  ciudad = "address.where(use = 'home').city"
))
v_paciente
#> <ViewDefinition> 
#>   Recurso: Patient
#>   Columnas (5): id, nombre, sexo, nacimiento, ciudad
vista_ejecutar(caso, v_paciente)
#>        id                        nombre sexo nacimiento ciudad
#> 1 patient Luis Alberto Paredes Cevallos male 1979-03-12  Quito
```

Con `por_cada` (el `forEach` de SQL on FHIR) se obtiene una fila por
cada elemento de una lista, por ejemplo los medios de contacto:

``` r

vista_ejecutar(caso, vista_crear(
  "Patient", c(medio = "system", valor = "value", uso = "use"),
  por_cada = "telecom"
))
#>        id medio                       valor    uso
#> 1 patient phone            +593 99 000 0000 mobile
#> 2 patient email luis.paredes@correo.invalid   home
```

## 5. Signos vitales con un ViewDefinition en JSON

Para vistas más ricas se escribe el `ViewDefinition` en JSON, igual que
en cualquier otra implementación de SQL on FHIR. Esta vista toma las
observaciones con valor numérico y, gracias a `unionAll`, también los
componentes de la presión arterial (sistólica y diastólica):

``` r

signos <- vista_leer(r"-({
  "resourceType": "ViewDefinition",
  "name": "signos_vitales",
  "resource": "Observation",
  "select": [
    {"column": [
      {"name": "id", "path": "getResourceKey()"},
      {"name": "paciente", "path": "subject.getReferenceKey(Patient)"},
      {"name": "encuentro", "path": "encounter.getReferenceKey(Encounter)"},
      {"name": "fecha", "path": "effective.ofType(dateTime)", "type": "dateTime"}
    ]},
    {"unionAll": [
      {"column": [
        {"name": "medida", "path": "code.text"},
        {"name": "loinc", "path": "code.coding.where(system = 'http://loinc.org').code.first()"},
        {"name": "valor", "path": "value.ofType(Quantity).value", "type": "decimal"},
        {"name": "unidad", "path": "value.ofType(Quantity).unit"}
      ]},
      {"forEach": "component", "column": [
        {"name": "medida", "path": "code.text"},
        {"name": "loinc", "path": "code.coding.where(system = 'http://loinc.org').code.first()"},
        {"name": "valor", "path": "value.ofType(Quantity).value", "type": "decimal"},
        {"name": "unidad", "path": "value.ofType(Quantity).unit"}
      ]}
    ]}
  ],
  "where": [{"path": "category.coding.where(code = 'vital-signs').exists()"}]
})-")
sv <- vista_ejecutar(caso, signos)
sv[!is.na(sv$valor), c("medida", "loinc", "valor", "unidad", "fecha")]
#>                    medida  loinc  valor            unidad
#> 2       Presión sistólica 8480-6 128.00              mmHg
#> 3      Presión diastólica 8462-4  84.00              mmHg
#> 4    Temperatura corporal 8310-5  38.40                °C
#> 5 Frecuencia respiratoria 9279-1  20.00 respiraciones/min
#> 6     Frecuencia cardíaca 8867-4 102.00       latidos/min
#> 7     Superficie corporal 8277-6   1.77                m2
#>                       fecha
#> 2 2025-03-20T07:30:00-05:00
#> 3 2025-03-20T07:30:00-05:00
#> 4 2025-03-20T07:30:00-05:00
#> 5 2025-03-20T07:30:00-05:00
#> 6 2025-03-20T07:30:00-05:00
#> 7                2025-07-01
```

## 6. Tratamientos y vacunas

``` r

vista_ejecutar(caso, vista_crear("MedicationRequest", c(
  medicamento = "medication.ofType(CodeableConcept).text",
  estado = "status",
  fecha = "authoredOn",
  motivo = "reasonReference.display.first()"
)))
#>              id   medicamento  estado      fecha
#> 1  med-req-doxo Doxorrubicina  active 2025-07-01
#> 2 med-req-tamox    Tamoxifeno stopped 2025-10-15
#>                                           motivo
#> 1 Carcinoma ductal infiltrante de mama izquierda
#> 2 Carcinoma ductal infiltrante de mama izquierda

vista_ejecutar(caso, vista_crear("Immunization", c(
  vacuna = "vaccineCode.text",
  estado = "status",
  fecha = "occurrence.ofType(dateTime)",
  razon_no_aplicada = "statusReason.text"
)))
#>                          id                           vacuna    estado
#> 1 08a-immunization-diferida             Influenza estacional  not-done
#> 2          flu-immunization             Influenza estacional completed
#> 3       08e-immunization-td Td (tétanos y difteria, adultos) completed
#>                       fecha                              razon_no_aplicada
#> 1 2025-03-20T08:00:00-05:00 Precaución médica: enfermedad aguda con fiebre
#> 2 2025-04-03T10:10:00-05:00                                           <NA>
#> 3 2025-04-03T10:10:00-05:00                                           <NA>
```

## 7. Vistas listas para usar

No hace falta escribir cada vista desde cero: el paquete trae un
catálogo de `ViewDefinition` para las tablas más comunes en vigilancia y
salud pública. Todas usan `getResourceKey()` en la columna `id` y
`getReferenceKey()` en las claves de otros recursos (`paciente`,
`encuentro`…), así que las tablas se unen entre sí, y dan lo mismo con
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
que con el motor DuckDB.

``` r

vista_catalogo()[, c("nombre", "recurso", "titulo")]
#>                     nombre           recurso
#> 1             diagnosticos         Condition
#> 2               encuentros         Encounter
#> 3           inmunizaciones      Immunization
#> 4             medicamentos MedicationRequest
#> 5 notificacion_obligatoria         Condition
#> 6                pacientes           Patient
#> 7           signos_vitales       Observation
#>                                     titulo
#> 1                             Diagnósticos
#> 2                               Encuentros
#> 3                           Inmunizaciones
#> 4           Prescripciones de medicamentos
#> 5 Enfermedades de notificación obligatoria
#> 6                                Pacientes
#> 7                           Signos vitales
```

[`vista_plantilla()`](https://f-slg.github.io/fhirviews/reference/vista_plantilla.md)
devuelve una de ellas, lista para ejecutar:

``` r

vista_ejecutar(caso, vista_plantilla("signos_vitales"))[
  , c("id", "codigo", "descripcion", "valor", "unidad")]
#>         id codigo             descripcion  valor            unidad
#> 1   obs-pa 8480-6       Presión sistólica 128.00              mmHg
#> 2   obs-pa 8462-4      Presión diastólica  84.00              mmHg
#> 3 obs-temp 8310-5    Temperatura corporal  38.40                °C
#> 4   obs-fr 9279-1 Frecuencia respiratoria  20.00 respiraciones/min
#> 5   obs-fc 8867-4     Frecuencia cardíaca 102.00       latidos/min
#> 6  obs-bsa 8277-6     Superficie corporal   1.77                m2
```

La presión arterial se registra como un panel con dos componentes; la
vista `signos_vitales` los separa con `unionAll` en una fila para la
sistólica (8480-6) y otra para la diastólica (8462-4).

La vista `notificacion_obligatoria` filtra los diagnósticos con una
lista de categorías CIE-10 guardada en la constante `codigos` (por
defecto dengue, malaria y tuberculosis). Con los 755 casos de dengue
simulados de 2025 y la vista `pacientes`, que trae el cantón y la
provincia de residencia, se arma la tabla de casos por provincia:

``` r

dengue <- system.file("extdata", "dengue_2025.ndjson.gz",
                      package = "fhirviews")
casos <- vista_ejecutar(dengue, vista_plantilla("notificacion_obligatoria"))
pacientes <- vista_ejecutar(dengue, vista_plantilla("pacientes"))
casos <- merge(casos, pacientes, by.x = "paciente", by.y = "id")
sort(table(casos$provincia), decreasing = TRUE)
#> 
#>   Guayas   Manabí Los Ríos   El Oro 
#>      371      159      130       95
```

Para otras enfermedades se cambia la constante, y
[`vista_json()`](https://f-slg.github.io/fhirviews/reference/vista_json.md)
muestra el JSON de cualquier vista para copiarlo y adaptarlo:

``` r

solo_a91 <- vista_plantilla("notificacion_obligatoria",
                            constantes = list(codigos = "A91"))
nrow(vista_ejecutar(dengue, solo_a91))
#> [1] 54
```

## 8. Del servidor a la tabla en un paso

Con un servidor,
[`fhir_vista()`](https://f-slg.github.io/fhirviews/reference/fhir_vista.md)
busca los recursos del tipo de la vista y la aplica; los parámetros de
búsqueda filtran en el servidor:

``` r

fhir_vista(con, signos, subject = "Patient/123", category = "vital-signs")
```

Y
[`vista_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_duckdb.md)
guarda varias vistas en DuckDB para unirlas con SQL; se explica en la
viñeta *ViewDefinition en detalle*.

## 9. Exportación masiva para análisis poblacional

Para una población entera (vigilancia epidemiológica, indicadores)
buscar página a página es lento. Los servidores que implementan [FHIR
Bulk Data](https://hl7.org/fhir/uv/bulkdata/) ofrecen la operación
`$export`: preparan en segundo plano un archivo NDJSON por tipo de
recurso y
[`fhir_exportar()`](https://f-slg.github.io/fhirviews/reference/fhir_exportar.md)
espera (respetando `Retry-After` y mostrando el avance) y los descarga a
una carpeta. El NDJSON es justo el formato que
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
procesa más rápido:

``` r

# Servidor de referencia de SMART, con datos sintéticos
bulk <- fhir_conectar("https://bulk-data.smarthealthit.org/fhir")
exp <- fhir_exportar(bulk, "paciente", tipos = c("Patient", "Condition"),
                     desde = as.Date("2024-01-01"))
exp
#> <fhir_exportacion> completada (nivel paciente)
#>   Carpeta: /tmp/RtmpkBV5Xn/fhir_export_17a757190dee2
#>   Condition                1 archivo, 639 recursos
#>   Patient                  1 archivo, 100 recursos

diagnosticos <- vista_ejecutar(exp$archivos$Condition, vista_crear(
  "Condition",
  c(paciente = "subject.getReferenceKey(Patient)",
    codigo = "code.coding.first().code")
))
```

`nivel` elige qué exportar: todo el servidor (`"sistema"`), todos los
pacientes (`"paciente"`) o los de un `Group` (`grupo = "id"`); `filtros`
pasa búsquedas por tipo (`_typeFilter`). Si la exportación tarda, se
puede lanzar sin esperar y volver más tarde:

``` r

trabajo <- fhir_exportar(bulk, grupo = "brote-dengue", esperar = FALSE)
trabajo <- fhir_exportar_estado(trabajo)   # consulta una vez
trabajo <- fhir_exportar_estado(trabajo, esperar = TRUE)
fhir_exportar_cancelar(trabajo)            # o cancelarla
```

## 10. Subir el caso a un servidor

Los recursos se pueden cargar en un servidor propio (no en el público)
para practicar con el taller. Como los ids son fijos,
[`fhir_actualizar()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md)
los crea con ese id en un servidor HAPI:

``` r

local <- fhir_conectar("http://localhost:8080/fhir")
for (r in caso) fhir_actualizar(local, r)
fhir_everything(local, "Patient", "patient")
```
