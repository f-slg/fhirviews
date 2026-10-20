# Ejecutar una petición escrita como texto

Ejecuta una petición escrita como en Postman o en los archivos `.http`
de VS Code: una primera línea con el método y la ruta, líneas opcionales
de cabeceras (`Nombre: valor`) y, tras una línea en blanco, el cuerpo
JSON. Las líneas que empiezan con `#` o `//` son comentarios. Es lo que
hace el addin *Ejecutar petición FHIR* de RStudio con el texto
seleccionado.

## Usage

``` r
fhir_ejecutar_texto(texto, con = fhir_conexion_activa())
```

## Arguments

- texto:

  Texto de la petición, por ejemplo
  `"GET Patient?family=Paredes&_count=5"`. Sin método se usa `GET`.

- con:

  Conexión; por defecto, la activa
  ([`fhir_conexion_activa()`](https://f-slg.github.io/fhirviews/reference/fhir_conexion_activa.md)).

## Value

La respuesta, como
[`fhir_peticion()`](https://f-slg.github.io/fhirviews/reference/fhir_peticion.md).

## Examples

``` r
con <- fhir_conectar("https://hapi.fhir.org/baseR4")
fhir_ejecutar_texto("GET Patient?_summary=count", con)
#> <fhir_respuesta> 200 · Bundle (searchset, total 7248, 0 entradas)
#> {
#>   "resourceType": "Bundle",
#>   "id": "1d67c2b9-4b48-4bc3-ae37-1c9223810227",
#>   "meta": {
#>     "lastUpdated": "2026-10-19T22:23:57.205-04:00",
#>     "tag": [
#>       {
#>         "system": "http://terminology.hl7.org/CodeSystem/v3-ObservationValue",
#>         "code": "SUBSETTED",
#>         "display": "Resource encoded in summary mode"
#>       }
#>     ]
#>   },
#>   "type": "searchset",
#>   "total": 7248
#> }

fhir_ejecutar_texto('
POST Patient/$validate
Prefer: return=OperationOutcome

{"resourceType": "Patient", "gender": "female"}
', con)
#> <fhir_respuesta> 200 · OperationOutcome
#> {
#>   "resourceType": "OperationOutcome",
#>   "text": {
#>     "status": "generated",
#>     "div": "<div xmlns=\"http://www.w3.org/1999/xhtml\"><h1>Operation Outcome<\/h1><table border=\"0\"><tr><td style=\"font-weight: bold;\">WARNING<\/td><td>[Patient, Line[1] Col[48]]<\/td><td>Constraint failed: dom-6: 'A resource should have narrative for robust management' (defined in http://hl7.org/fhir/StructureDefinition/DomainResource) (Best Practice Recommendation)<\/td><\/tr><\/table><\/div>"
#>   },
#>   "issue": [
#>     {
#>       "extension": [
#>         {
#>           "url": "http://hl7.org/fhir/StructureDefinition/operationoutcome-issue-line",
#>           "valueInteger": 1
#>         },
#>         {
#>           "url": "http://hl7.org/fhir/StructureDefinition/operationoutcome-issue-col",
#>           "valueInteger": 48
#>         },
#>         {
#>           "url": "http://hl7.org/fhir/StructureDefinition/operationoutcome-message-id",
#>           "valueString": "http://hl7.org/fhir/StructureDefinition/DomainResource#dom-6"
#>         }
#>       ],
#>       "severity": "warning",
#>       "code": "processing",
#>       "details": {
#>         "coding": [
#>           {
#>             "system": "http://hl7.org/fhir/java-core-messageId",
#>             "code": "http://hl7.org/fhir/StructureDefinition/DomainResource#dom-6"
#>           }
#>         ]
#>       },
#>       "diagnostics": "Constraint failed: dom-6: 'A resource should have narrative for robust management' (defined in http://hl7.org/fhir/StructureDefinition/DomainResource) (Best Practice Recommendation)",
#>       "location": [
#>         "Patient",
#>         "Line[1] Col[48]"
#>       ],
#>       "expression": [
#>         "Patient"
#>       ]
#> ... (3 líneas más)
```
