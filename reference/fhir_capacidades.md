# Capacidades del servidor

Lee el `CapabilityStatement` (`GET [base]/metadata`) y resume qué
recursos admite el servidor y qué se puede hacer con cada uno.

## Usage

``` r
fhir_capacidades(con)
```

## Arguments

- con:

  Conexión creada con
  [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md).

## Value

Un `data.frame` con una fila por tipo de recurso: `recurso`,
`interacciones` (`read`, `search-type`, `create`...) y
`parametros_busqueda`. El `CapabilityStatement` completo queda en el
atributo `capability`.

## Examples

``` r
con <- fhir_conectar("https://hapi.fhir.org/baseR4")
cap <- fhir_capacidades(con)
head(cap)
#>               recurso
#> 1             Account
#> 2  ActivityDefinition
#> 3        AdverseEvent
#> 4  AllergyIntolerance
#> 5         Appointment
#> 6 AppointmentResponse
#>                                                                             interacciones
#> 1 search-type, update, vread, read, patch, history-type, history-instance, delete, create
#> 2 search-type, update, vread, read, patch, history-type, history-instance, delete, create
#> 3 search-type, update, vread, read, patch, history-type, history-instance, delete, create
#> 4 search-type, update, vread, read, patch, history-type, history-instance, delete, create
#> 5 search-type, update, vread, read, patch, history-type, history-instance, delete, create
#> 6 search-type, update, vread, read, patch, history-type, history-instance, delete, create
#>                                                                                                                                                                                                                                                                                                                                      parametros_busqueda
#> 1                                                                                                                                                                                                owner, _language, identifier, period, subject, _lastUpdated, _security, type, _filter, _list, _profile, patient, _tag, _has, name, _source, _id, status
#> 2 date, _language, successor, context-type-value, _lastUpdated, jurisdiction, derived-from, description, context-type, predecessor, composed-of, title, _list, context-quantity, depends-on, effective, context, context-type-quantity, identifier, _security, version, url, _filter, _profile, _tag, _has, name, publisher, topic, _source, _id, status
#> 3                                                                                                                                     date, severity, _language, recorder, study, actuality, subject, _lastUpdated, resultingcondition, substance, _security, _filter, _list, _profile, seriousness, _tag, _has, _source, location, _id, category, event
#> 4                                                                                       date, _language, code, _lastUpdated, verification-status, criticality, clinical-status, type, _list, patient, severity, identifier, manifestation, recorder, _security, onset, _filter, asserter, route, _profile, _tag, _has, _source, _id, category, last-date
#> 5                                                     date, _language, specialty, service-category, _lastUpdated, slot, reason-code, _list, based-on, patient, supporting-info, identifier, practitioner, appointment-type, part-status, service-type, _security, _filter, actor, _profile, _tag, _has, reason-reference, _source, location, _id, status
#> 6                                                                                                                                                                                   _language, identifier, practitioner, part-status, _lastUpdated, _security, appointment, _filter, actor, _list, _profile, patient, _tag, _has, _source, location, _id
```
