# Piloto externo del alcance R4

Este protocolo acompaña al desarrollo 0.5.0.9000. Registra el archivo candidato,
su versión y checksum antes de empezar. Los materiales del kit v1 corresponden
al candidato anterior 0.5.0; su aprobación no se transfiere a este ensayo.

## Alcance y preparación

Se construyen seis recursos ficticios de cinco tipos: Patient, Encounter,
Condition, Observation y dos Immunization. No se contacta ningún servidor en
el ensayo local. El perfil básico usa tablas R y V8; el completo añade consultas
parametrizadas DBI/DuckDB y compara las cinco vistas con ambos motores.

El mantenedor entrega el mismo archivo fuente que comprobó y su manifiesto.
Anota sistema operativo, versión de R, identificador del participante, perfil,
fecha, dependencias ya instaladas, tiempo e intervenciones de ayuda. Una persona
ajena al desarrollo realiza las tareas y conserva sus intentos por separado.

## Ejecutar el ensayo instalado

Instala las dependencias obligatorias y el candidato proporcionado:

```r
install.packages(c("cli", "httr2", "jsonlite", "rlang", "V8"))
install.packages("fhirviews_0.5.0.9000.tar.gz", repos = NULL, type = "source")
# Para el perfil completo:
# install.packages(c("DBI", "duckdb"))
```

Reinicia R y elige una carpeta nueva:

```r
library(fhirviews)
Sys.setenv(FHIRVIEWS_PILOTO_SALIDA = "piloto-r4-basico-01",
           FHIRVIEWS_PILOTO_PERFIL = "basico")
source(system.file("examples", "piloto.R", package = "fhirviews"))
```

Para el completo cambia el perfil a `completo` y elige otra carpeta. El control
`r4_cinco_recursos` debe aprobarse en ambos; `recuperacion` queda `no_evaluado`
en el básico. Abre `aceptacion.json`, `aceptacion.csv`, `experiencia-usuario.txt`
y el subdirectorio `r4/`. El formato actual del informe es `esquema_informe = 2`.

## Tareas del participante

1. Instalar y abrir la ayuda de `fhir_mapa`, `fhir_desde_sql` y `fhir_escribir`.
   Registrar cualquier ayuda necesaria y comprobar la versión cargada.
2. Ejecutar el perfil acordado y explicar cada estado del informe. Diferenciar
   una aprobación técnica, una validación de perfiles y una evaluación humana.
3. Abrir `r4/recursos-r4.ndjson` y localizar los seis recursos. Comprobar que
   Encounter/e1, Condition/c1, Observation/o1 e Immunization/i1/i2 apuntan al
   paciente p1, y que Condition/c1 e Immunization/i1 enlazan al encuentro e1.
4. Contrastar Observation/o1 (`72.00`, límite inferior `71.995`) e
   Immunization/i1 (`0.50`, límite inferior `0.495`). Comprobar los literales
   en el archivo; una tabla numérica R puede mostrarlos como 72 y 0.5.
5. Explicar las dos Immunization: i1 tiene fecha con hora, número de dosis
   entero y encuentro; i2 tiene fecha y dosis ordinal textuales, `primarySource`
   falso y ausencia de `encounter` y `doseQuantity`. Patient/p1 conserva `active`
   falso y la fecha válida 2000-02-29.
6. Crear y guardar un ViewDefinition para Immunization con id, estado, paciente
   y fecha. Añadir después las dos variantes de `occurrence` y contrastar la
   tabla con ambas líneas NDJSON. Las columnas de variantes ausentes deben ser
   `NA`, sin sustituirlas por fechas inventadas.
7. Repetir en otra carpeta, contrastar los resultados y registrar minutos,
   obstáculos, ayuda, tarea completada/con ayuda/incompleta y conclusión del
   participante. Completar `experiencia-usuario.txt` y revisarlo con el mantenedor.

Referencia para comprobar el trabajo después de la tarea 6:

```r
recursos <- fhir_recursos("piloto-r4-basico-01/r4/recursos-r4.ndjson")
vista <- vista_crear("Immunization", c(estado = "status",
  paciente = "patient.getReferenceKey(Patient)",
  fecha = "occurrence.ofType(dateTime)", fecha_texto = "occurrence.ofType(string)"))
vista_ejecutar(recursos, vista)
writeLines(vista_json(vista), "vista-inmunizaciones-r4.json")
```

El observador registra si fue necesario proporcionar esta solución. Para evaluar
autonomía se repiten las tareas acordadas sin intervención del mantenedor.

## Perfiles de un entorno de pruebas

La aprobación local deja `validacion_perfiles = no_evaluada_sin_servidor`.
La CI HAPI valida por separado estos seis JSON contra los cinco perfiles base
R4 e incluye un recurso alterado que debe rechazarse. El perfil del proyecto,
su terminología y la existencia de referencias requieren otro entorno acordado.

Para un servidor R4 propio, consulta sus capacidades y valida el texto exacto
que conserva los decimales. Reemplaza la URL y los perfiles por los acordados:

```r
con <- fhir_conectar("https://servidor-de-pruebas.example/fhir", panel = FALSE)
textos <- readLines("piloto-r4-basico-01/r4/recursos-r4.ndjson", encoding = "UTF-8")
for (texto in textos) {
  tipo <- jsonlite::fromJSON(texto)$resourceType
  perfil <- paste0("http://hl7.org/fhir/StructureDefinition/", tipo)
  resultado <- fhir_validar(con, texto, perfil = perfil)
  print(resultado)
}
```

`$validate` puede devolver advertencias, rechazos o un resultado indeterminado;
registra y revisa esos resultados. Este protocolo no carga recursos en el servidor.
Los informes quedan locales y no se envían automáticamente.

## Cierre

El mantenedor y el participante revisan exactitud, ayuda necesaria, repetición,
comprensión y pendientes. Registran el candidato exacto y la conclusión. Los
informes automáticos mantienen `validacion_usuario_externo = pendiente`; una
sesión humana se registra aparte y nunca se fabrica modificando ese indicador.
La versión estable se prepara después de resolver los hallazgos aceptados.
