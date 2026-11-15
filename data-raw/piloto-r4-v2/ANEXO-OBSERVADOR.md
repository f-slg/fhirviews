# Contraste para el observador

Este anexo se utiliza después del primer intento. Si se proporciona una
solución antes de completarlo, registra la intervención y la tarea con ayuda.
Las referencias siguientes corresponden a datos ficticios, no a resultados
observados de participantes.

## Identidad y controles

Consultar `CANDIDATO.json` y el SHA-256 del archivo antes de instalar. En el
informe técnico deben coincidir versión 0.5.0.9002, MD5 y esquema 2. Los cinco
controles son `api_instalada`, `vigilancia`, `contrato_estricto`, `recuperacion`
y `r4_cinco_recursos`. Básico excluye recuperación; completo la exige.

La vigilancia incluida parte de 755 eventos: 661 confirmados, 94 excluidos y
65 cantones. Cuenta eventos, no pacientes únicos ni tasas. Las referencias del
ensayo instalado y su informe permiten revisar los totales y el control negativo.

## Seis recursos del control historico

`piloto/r4/recursos-r4.ndjson` tiene Patient/p1, Encounter/e1, Condition/c1,
Observation/o1 e Immunization/i1/i2. Las referencias al paciente se conservan;
Condition/c1 e Immunization/i1 apuntan a Encounter/e1. La segunda inmunización
no tiene encuentro ni cantidad de dosis. Patient/p1 conserva `active = false`.

Los literales son `72.00` y `0.50`; sus límites inferiores son `71.995` y
`0.495`. La tabla numérica puede mostrarlos como 72 y 0.5. La segunda
inmunización usa texto para fecha y número de dosis; no deben inventarse fechas.

## Vista que debe construir el participante

```r
recursos <- fhir_recursos("sesion-P01-intento01/piloto/r4/recursos-r4.ndjson")
vista <- vista_crear("Immunization", c(estado = "status",
  paciente = "patient.getReferenceKey(Patient)",
  fecha = "occurrence.ofType(dateTime)", fecha_texto = "occurrence.ofType(string)"))
vista_ejecutar(recursos, vista)
writeLines(vista_json(vista), "vista-inmunizaciones-r4.json")
```

La clave debe conservarse, ambas inmunizaciones deben aparecer y cada variante
ausente debe quedar como `NA`. El observador contrasta la definición antes y
después de modificarla y registra si la persona necesitó la solución.

## Alergias

```r
entrada <- system.file("extdata", "alergias_r4.ndjson", package = "fhirviews")
tabla <- vista_ejecutar(entrada, vista_plantilla("alergias"))
tabla[, c("id", "estado_clinico", "gravedad_reaccion", "reaccion_codigo")]
length(unique(tabla$id))
```

Son tres registros y cinco filas: a1 tiene dos reacciones con dos y una
manifestaciones; a2 y a3 conservan una fila cada uno sin reacción. Las categorías
son listas. Criticidad y gravedad son conceptos distintos y los ausentes no se
rellenan. Los estados se eligen por sistema canónico; no se mezclan código y
sistema de dos Coding distintos. Esta vista no habilita construir alergias
mediante `fhir_mapa()`.

## Revisión final

Contrastar los hallazgos de dos intentos, no sus tiempos ni rutas. Mantener por
separado el resultado técnico y la decisión humana. Para el perfil completo,
revisar recuperación y el regreso a tablas V8/DuckDB; un perfil básico no los
acredita. Registrar los hallazgos y responsables antes de decidir el cierre.

## Specimen y DiagnosticReport del candidato actual

En el perfil completo se puede ejecutar `laboratorio_r4()` desde el ejemplo
instalado. Produce un paciente, una muestra, dos observaciones y un informe;
el informe enlaza las dos observaciones y la muestra. Las tablas `muestras`,
`observaciones` y `resultados` deben coincidir entre V8 y DuckDB. Son datos
ficticios; esta tarea opcional no evalua perfiles nacionales ni instala Rust.
