# Guía y referencias del observador

**Español** · [English](ANEXO-OBSERVADOR.en.md)

**Protocolo 2.1 · Candidato 0.5.0.9002.** Consultar las soluciones después de
registrar el primer intento. Mostrar una solución, corregir código o dar una
pista conceptual cuenta como intervención. Los resultados esperados de este
anexo proceden de datos ficticios y no son observaciones de participantes.

## Preparar y conducir la observación

Lea [EVALUACION-PILOTO.md](EVALUACION-PILOTO.md). Prepare una ficha vacía por
perfil y confirme las tres elecciones: persona R/FHIR, nivel básico/completo,
alcance núcleo/siete. No precargue estados humanos. Siete requiere completo y
la tarea 09; ejecútela antes del cierre 08. Anote antecedentes, dependencias
preinstaladas, exposición a soluciones y ayuda prevista.

Lea la consigna, deje que la persona intente resolverla y registre la primera
explicación antes de contrastarla. Permita ayuda y pausas cuando se necesiten;
anote su contenido. Una consulta espontánea a la documentación no cuenta como
ayuda del observador. Registre tiempo activo y espera con criterios constantes.
No dé por terminada una tarea solo porque el script termina sin errores.

Al valorar comprensión, revise todas las preguntas de la tarea. Registre la
respuesta y por qué la considera correcta, parcial o incorrecta. Si cambia tras
una pista, conserve ambas respuestas y marque con ayuda. Una interpretación
incorrecta que persiste impide completar la tarea, aunque la tabla coincida.

El formulario no abre ni verifica los archivos citados: el observador debe
comprobar que existen y que respaldan lo escrito. El campo de facilidad es
opcional y no decide la aceptación. La sesión puede aceptarse con ayuda
registrada; una declaración de autonomía necesita repetición manual delimitada.

## Ejemplo de registro de una intervención

Use campos vacíos en las fichas reales. Este ejemplo es únicamente ilustrativo:
«R05, al añadir la segunda variante: orientación a la ayuda de vista_crear;
una intervención; primer intento confundía fecha textual con dateTime;
tras la consulta explicó los NA; completada con ayuda; evidencia: dos vistas
JSON y tabla contrastada». No copiarlo como resultado observado.

## Referencias comunes del ensayo instalado

En CANDIDATO.json y SESION.json comprobar versión, commit y SHA-256. El MD5 del
candidato se contrasta además con aceptacion.json, esquema 2. Los controles
son api_instalada, vigilancia, contrato_estricto, recuperacion y
r4_cinco_recursos. Básico excluye recuperación; completo la exige.

Vigilancia: 755 eventos, 661 confirmados, 94 excluidos y 65 cantones.
den-c0001→den-p0001, residencia 0701 e inicio 2025-02-27; den-c0002 excluido.
Cantones 0701/0702/0704: 55/1/1; enero/febrero/marzo de 2025: 5/73/173.
Son conteos ficticios de eventos. No deducir personas únicas ni tasas.

El control R4 contiene Patient/p1, Encounter/e1, Condition/c1, Observation/o1 e
Immunization/i1/i2. Condition/c1 e Immunization/i1 enlazan Encounter/e1.
i2 conserva textos de fecha/dosis y no tiene encounter ni doseQuantity.
Patient.active es false. Literales 72.00 y 0.50: límites 71.995 y 0.495.

Alergias: tres registros/cinco filas. a1 tiene dos reacciones con dos y una
manifestaciones; a2 y a3 conservan una fila sin reacción. Las categorías son
listas. En a1 se elige clinicalStatus por sistema canónico; en a3 no mezclar
system/code/display de entradas Coding distintas. El conjunto se usa para
contrastar extracción, no como un nuevo constructor ni como certificación de
validez clínica o terminológica.

## Solución de referencia: vista de inmunizaciones

Entregarla solo si la persona solicita ayuda o después de registrar su intento.
No es la única definición admisible: aceptar otra con resultados y semántica
correctos. Guardar la versión inicial y la ampliada.

```r
# Adaptar la ruta al intento del participante.
recursos <- fhir_recursos("sesion-P01-intento01/piloto/r4/recursos-r4.ndjson")
vista <- vista_crear("Immunization", c(
  estado = "status", paciente = "patient.getReferenceKey(Patient)",
  fecha = "occurrence.ofType(dateTime)",
  fecha_texto = "occurrence.ofType(string)"))
tabla <- vista_ejecutar(recursos, vista)
writeLines(vista_json(vista), "vista-inmunizaciones-02.json")
releida <- vista_leer("vista-inmunizaciones-02.json")
isTRUE(all.equal(tabla, vista_ejecutar(recursos, releida)))
```

## Soluciones de referencia: construcción y rechazos locales

Estos casos se pueden ejecutar con el candidato instalado, sin servidor ni
DuckDB. Proporcionarlos antes del intento convierte la tarea correspondiente
en asistida. Usan datos ficticios nuevos; conservar las respuestas y scripts
propios del participante como evidencia principal.

```r
# Cada diagnóstico es un rechazo esperado, no un fallo del piloto.
rechazo_piloto <- function(expr) {
  e <- tryCatch({ force(expr); NULL }, error = identity)
  stopifnot(inherits(e, "fhirviews_error_mapeo"))
  list(clase = class(e), fila = e$fila, campo = e$campo)
}
datos <- data.frame(id = c("prueba-p1", "prueba-p2"),
  sexo = c("female", "male"), activo = c(FALSE, TRUE),
  nacimiento = as.Date(c("2000-02-29", "1990-01-01")))
mapa <- fhir_mapa("Patient", c(id = "id", gender = "sexo",
  active = "activo", birthDate = "nacimiento"))
pacientes <- fhir_desde_tabla(datos, mapa)
stopifnot(length(pacientes) == 2L, identical(pacientes[[1]]$active, FALSE))
duplicados <- datos; duplicados$id[2] <- duplicados$id[1]
rechazo_piloto(fhir_desde_tabla(duplicados, mapa))
sexo_invalido <- datos; sexo_invalido$sexo[1] <- "invalido"
rechazo_piloto(fhir_desde_tabla(sexo_invalido, mapa))
texto_logico <- datos; texto_logico$activo <- c("false", "true")
rechazo_piloto(fhir_desde_tabla(texto_logico, mapa))
fecha_invalida <- datos
fecha_invalida$nacimiento <- c("2025-02-29", "1990-01-01")
rechazo_piloto(fhir_desde_tabla(fecha_invalida, mapa))

vacunas <- data.frame(id = "prueba-i1", paciente = "prueba-p1")
constantes <- list(status = "completed", "vaccineCode.text" = "Vacuna ficticia",
  occurrenceDateTime = "2026-01-14")
mapa_vacuna <- fhir_mapa("Immunization", c(id = "id", "patient.reference" = "paciente"),
  constantes = constantes, referencias = c("patient.reference" = "Patient"))
ambas <- c(constantes, list(occurrenceString = "Fecha desconocida"))
rechazo_piloto(fhir_desde_tabla(vacunas, fhir_mapa("Immunization",
  c(id = "id", "patient.reference" = "paciente"), constantes = ambas,
  referencias = c("patient.reference" = "Patient"))))
rechazo_piloto(fhir_mapa("Immunization",
  c(id = "id", "patient.reference" = "paciente"), constantes = constantes,
  referencias = c("patient.reference" = "Group")))
# El constructor comprueba el destino, pero no la existencia de otro recurso.
sin_paciente <- vacunas; sin_paciente$paciente <- "no-existe"
referencia_no_resuelta <- fhir_desde_tabla(sin_paciente, mapa_vacuna)
stopifnot(identical(referencia_no_resuelta[[1]]$patient$reference, "Patient/no-existe"))

informe <- data.frame(id = "prueba-d1")
rechazo_piloto(fhir_desde_tabla(informe, fhir_mapa("DiagnosticReport", c(id = "id"),
  constantes = list(status = "invalido", "code.text" = "Informe ficticio"))))
rechazo_piloto(fhir_mapa("DiagnosticReport", c(id = "id", "result[0].reference" = "resultado"),
  constantes = list(status = "final", "code.text" = "Informe ficticio"),
  referencias = c("result[0].reference" = "Patient")))
```

Para R04 completo, el participante crea su tabla DBI y selecciona un id mediante
parámetro enlazado. Contrastar la misma selección R y SQL; no basta con que el
SQL termine. Conservar el cierre de la conexión. Un ejemplo de referencia:

```r
# Requiere DBI/DuckDB. Reutiliza datos y mapa del bloque anterior.
args_db <- if ("shared_home" %in% names(formals(duckdb::duckdb)))
  list(shared_home = FALSE) else list()
db <- DBI::dbConnect(do.call(duckdb::duckdb, args_db))
tryCatch({
  # Mantener solo las columnas usadas en este contraste, con tipos nativos.
  DBI::dbWriteTable(db, "pacientes_piloto", datos)
  desde_sql <- fhir_desde_sql(db,
    "SELECT * FROM pacientes_piloto WHERE id = ? ORDER BY id", mapa,
    parametros = list("prueba-p1"))
  desde_r <- fhir_desde_tabla(datos[datos$id == "prueba-p1", ], mapa)
  stopifnot(identical(desde_sql[[1]], desde_r[[1]]))
}, finally = DBI::dbDisconnect(db))
```

## Laboratorio: referencias y salida esperadas

El alcance siete exige R09/F09 completos. El ejemplo produce Patient,
Specimen, dos Observation y DiagnosticReport; las claves por defecto empiezan
por demo-lab-. La vista muestras tiene una fila y volumen 5.00 con límite
4.995; observaciones tiene dos filas con valores 72.00/13.50 y límites
71.995/13.495; resultados tiene dos filas, una por Observation referenciada.
Cada una de las tres tablas debe compararse entre V8 y DuckDB.

```r
source(system.file("examples", "laboratorio-r4.R", package = "fhirviews"))
ejemplo <- laboratorio_r4()
comparaciones <- vapply(names(ejemplo$vistas), function(nombre) {
  isTRUE(all.equal(ejemplo$tablas[[nombre]],
    vista_ejecutar_duckdb(ejemplo$recursos, ejemplo$vistas[[nombre]])))
}, logical(1))
stopifnot(all(comparaciones))
# Guardar NDJSON y las tres vistas en una carpeta nueva acordada.
```

## Matriz de validación de perfiles

Para F07 solicitar una fila por tipo y perfil. Campos mínimos: recurso,
versión FHIR, perfil canónico/versionado, origen del requisito, terminología,
referencias, caso válido, alteración negativa, resultado esperado, responsable,
servidor de pruebas previsto y estado no_evaluado/ejecutado/indeterminado.
Sin servidor, valorar la calidad del plan y dejar perfiles no evaluados.

Si se acordó ejecutar $validate, conservar texto JSON exacto, perfil solicitado,
fecha, servidor/versión no sensible, HTTP y OperationOutcome completo revisado.
Un resultado indeterminado requiere investigación; no usar truthiness de R ni
interpretar NA como válido. Leer un informe HAPI previo es evidencia documental,
no ejecución del participante. No es necesario guardar recursos en el servidor.

## Conclusión de ronda

Revisar denominadores por alcance, resultados por tarea, comprensión, ayuda,
repetición manual, tiempos activos/esperas y facilidad opcional. Separar R de
FHIR, básico de completo y protocolo 2.0 de 2.1. Presentar casos individuales
cuando hay pocas personas. Relacionar las prioridades con incidencias concretas
y registrar qué se repetirá. No fabricar fichas ni completar participantes.

## Referencias por tarea

### R01. Preparar el entorno e identificar la instalación

**Contraste:** Versión 0.5.0.9002, commit y hash del candidato entregado; biblioteca de la sesión. El nivel completo necesita DBI/DuckDB y R ≥ 4.2; el básico R ≥ 4.1. Encontrar por cuenta propia la ayuda no cuenta como intervención del observador.

**Errores a detectar:** Confundir versión con identidad del archivo; cargar otra biblioteca; sumar esperas de red al tiempo de análisis.

**Evidencia:** SESION.json, candidato.txt, ruta revisada de biblioteca, versiones y registro de preparación.


### R02. Interpretar controles e indicadores de vigilancia

**Contraste:** 755 eventos de entrada, 661 confirmados, 94 excluidos y 65 cantones. den-c0001→den-p0001, residencia 0701, inicio 2025-02-27; den-c0002 excluido. Cantón 0701: 55 eventos; febrero: 73. Son conteos ficticios de eventos; una tasa necesita denominador y periodo compatibles. Básico: recuperación no_evaluado; completo: cinco controles aprobados.

**Errores a detectar:** Convertir conteos en tasas; contar eventos como pacientes; tratar no_evaluado como aprobado.

**Evidencia:** Informe original y nota de interpretación con filas o campos contrastados.


### R03. Reconstruir la procedencia de una tabla R4

**Contraste:** Cinco tipos y seis recursos: p1/e1/c1/o1/i1/i2. Condition/c1 e Immunization/i1 apuntan a Encounter/e1; ambos eventos de vacunación apuntan a Patient/p1. active=false es información presente. i2 carece de encuentro y cantidad; conserva fecha y dosis textuales. 72.00 y 0.50 tienen límites inferiores 71.995 y 0.495.

**Errores a detectar:** Confundir false con ausente; perder ceros finales antes del mapeo; fabricar fecha, cantidad o paciente.

**Evidencia:** Tabla local de procedencia, referencias y fragmentos de JSON ficticio revisados.


### R04. Construir recursos nuevos y entender los errores

**Contraste:** Dos Patient válidos conservan sus ids y active=FALSE. Los ids duplicados y gender fuera del binding requerido producen fhirviews_error_mapeo. No se agrupan ni sobrescriben ids. En DBI se usa WHERE id = ? con parametros=list(...), y CAST a texto cuando la precisión del origen lo requiera. El constructor local no acredita validación de perfiles.

**Errores a detectar:** Usar texto "false" como lógico; borrar filas para forzar aprobado sin explicar; interpolar valores en SQL.

**Evidencia:** Script propio, NDJSON válido, diagnóstico de cada caso negativo y comparación DBI si corresponde.


### R05. Diseñar, modificar y reutilizar una vista

**Contraste:** Dos filas i1/i2, con clave de paciente p1. occurrence.ofType(dateTime) y occurrence.ofType(string) deben proyectarse por separado; las ausencias quedan NA. La definición releída produce la misma tabla con sus tipos. Un ViewDefinition puede omitir información y no basta para reconstruir todo el recurso.

**Errores a detectar:** Copiar la solución y declarar autonomía; reemplazar NA; suponer que una proyección es reversible.

**Evidencia:** vista-inmunizaciones-01.json, vista-inmunizaciones-02.json, tablas y explicación propia.


### R06. Analizar alergias conservando la unidad de conteo

**Contraste:** Tres ids y cinco filas: a1 aporta tres manifestaciones en dos reacciones; a2 y a3 una fila cada uno sin reacción. No inferir ausencia clínica de una ausencia documental. Categorías se conservan como listas. criticality y reaction.severity tienen significados distintos.

**Errores a detectar:** Sumar filas como registros; descartar alergias sin reacción; asignar la misma gravedad a todas las manifestaciones.

**Evidencia:** Script de conteo, tabla por id y explicación de unidad de análisis.


### R07. Repetir el análisis y comprobar recuperación

**Contraste:** Los hallazgos coinciden; las rutas y duraciones no tienen que ser iguales. El reintento completo sustituye la carga tras rollback y no acumula duplicados. La autonomía se limita a las tareas manuales realmente repetidas sin ayuda y conserva evidencia del segundo intento.

**Errores a detectar:** Sobrescribir el primer intento; comparar solo totales; declarar autonomía por un script automático.

**Evidencia:** Dos informes, comparación escrita y archivos de repetición manual; si hubo ayuda, describirla.


### R08. Valorar utilidad y acordar el cierre

**Contraste:** La conclusión puede ser repetir tras correcciones, aceptar para el alcance o aceptar con pendientes menores explícitos. No se cierra favorablemente con tareas obligatorias incompletas, comprensión incorrecta o incidencias altas/críticas sin cierre verificado. Se evita convertir esta sesión en aceptación clínica o institucional.

**Errores a detectar:** Confundir satisfacción con exactitud; cerrar una incidencia solo porque se cambió código; omitir limitaciones.

**Evidencia:** Ficha exportada y revisada, experiencia-usuario.txt, incidencias y plan de seguimiento.


### R09. Evaluar el recorrido de laboratorio de siete constructores

**Contraste:** El ejemplo produce cinco recursos de cuatro tipos: Patient, Specimen, dos Observation y DiagnosticReport. Junto al núcleo cubre siete tipos constructores; no son siete recursos en un mismo archivo. Hay una muestra y un informe, dos observaciones y dos filas de resultados. Literales 5.00/72.00/13.50; límites inferiores 4.995/71.995/13.495. Comparar muestras, observaciones y resultados en ambos motores.

**Errores a detectar:** Confundir siete tipos cubiertos entre casos con siete recursos del laboratorio; omitir una vista; suponer perfil validado.

**Evidencia:** NDJSON de laboratorio, tres definiciones JSON, tablas comparadas y explicación propia.


### F01. Fijar el alcance de interoperabilidad y el candidato

**Contraste:** R4 4.0.1, candidato 0.5.0.9002 identificado por commit y SHA-256. La CI HAPI es antecedente técnico del mantenedor; no una ejecución del participante. Un aprobado local o 144/144 del banco de vistas no acredita perfiles nacionales, terminología ni existencia de referencias.

**Errores a detectar:** Usar conformidad de vistas como certificado general FHIR; declarar que el participante ejecutó HAPI al leer un informe.

**Evidencia:** Identidad y entorno, informes consultados y matriz escrita de validado/no evaluado.


### F02. Revisar mapeos, cardinalidades y decisiones semánticas

**Contraste:** El constructor exige id único por fila por contrato. Encounter requiere status/class; Condition requiere subject en la base; Observation status/code; Immunization status/vaccineCode/patient/una variante de occurrence. Invariantes y perfiles pueden exigir más. Las constantes del ejemplo son decisiones explícitas; no inferencias clínicas. Se usan rutas JSON como valueQuantity.value, no FHIRPath en el mapa.

**Errores a detectar:** Confundir contrato de id con cardinalidad base; inventar códigos o estados; considerar un snapshot como todo un perfil.

**Evidencia:** Matriz por recurso con fuente documental/versionada y justificación de decisiones.


### F03. Auditar tipos, elecciones, fechas y precisión

**Contraste:** active="false" no es booleano; 2025-02-29 es inválida; occurrenceDateTime y occurrenceString simultáneos son excluyentes. Se esperan fhirviews_error_mapeo. FALSE permanece presente, las variantes ausentes se omiten/NA y 72.00/0.50 conservan límites 71.995/0.495. Una fecha sin hora no es un instante; issued exige instante con zona.

**Errores a detectar:** Validar precisión solo con impresión R; transformar automáticamente texto en booleano; inventar zona u hora.

**Evidencia:** Matriz de variantes, fragmentos NDJSON, script y diagnósticos de casos negativos.


### F04. Comprobar referencias e integridad del grafo

**Contraste:** Destino Group para Immunization.patient se rechaza. Patient/no-existe puede ser estructuralmente admisible sin existir en el conjunto; el chequeo de existencia es adicional. Condition/c1 e Immunization/i1 enlazan Encounter/e1; i2 no tiene encounter. La procedencia del servidor evita confundir ids iguales entre orígenes.

**Errores a detectar:** Confundir tipo permitido con existencia; resolver por posición; ignorar procedencia de ids.

**Evidencia:** Inventario de enlaces, script de ambos casos y diagnóstico o referencia no resuelta.


### F05. Examinar bindings y fidelidad de Coding

**Contraste:** a1 incluye la traducción activo y el código canónico active; la vista elige por sistema. En a3 no se debe combinar urn:ejemplo:primero con NO-MEZCLAR de otra entrada. Patient.gender inválido se rechaza. Los bindings extensibles no son enumeraciones cerradas; ValueSets externos o filtrados requieren terminología acordada.

**Errores a detectar:** Mezclar system/code/display de entradas distintas; validar por display; aplicar como cerrado un binding extensible.

**Evidencia:** Tabla de Coding contrastados, caso negativo y lista de requisitos terminológicos del proyecto.


### F06. Auditar la proyección y sus pérdidas de información

**Contraste:** Immunization conserva i1/i2 y variantes ausentes como NA; alergias tiene tres registros/cinco filas con manifestaciones vinculadas a su reacción. Una vista puede perder datos. 144/144 corresponde al banco fijado; DuckDB mantiene un subconjunto documentado y no admite cualquier expresión.

**Errores a detectar:** Interpretar la extracción como conversión reversible; ignorar tipos; extrapolar el banco a FHIRPath completo.

**Evidencia:** ViewDefinition propio, tabla de auditoría y comparación de motores o exclusión justificada.


### F07. Diseñar la validación de perfiles del entorno

**Contraste:** La tarea obligatoria se completa al producir y explicar el plan; ejecutar un servidor es una ampliación opcional. No se requiere red ni servidor para el núcleo. $validate con HTTP erróneo o respuesta incompleta es indeterminado; advertencias se revisan. No se guarda ni envía un recurso a producción. Un perfil base aprobado no acredita el perfil nacional.

**Errores a detectar:** Marcar perfiles aprobados por redactar el plan; tratar NA como TRUE; ejecutar contra producción sin acuerdo.

**Evidencia:** Matriz y plan de validación; si hubo ejecución acordada, JSON exacto y OperationOutcome revisado con fecha/perfil/servidor.


### F08. Repetir la auditoría y emitir una conclusión delimitada

**Contraste:** El resultado técnico permanece separado de la decisión humana y de perfiles. Un cierre favorable requiere tareas del alcance completas, comprensión correcta y ausencia de incidencias altas/críticas abiertas. La autonomía se limita a las tareas repetidas con evidencia y sin intervenciones; no se extiende automáticamente al perfil completo.

**Errores a detectar:** Generalizar a otros servidores o perfiles; confundir ayuda en R con defecto FHIR; declarar autonomía global sin repetir cada tarea.

**Evidencia:** Dos intentos, auditoría repetida, ficha exportada y conclusión con alcances pendientes.


### F09. Auditar Specimen y DiagnosticReport de extremo a extremo

**Contraste:** Cinco recursos de cuatro tipos en laboratorio, que amplían a siete los tipos cubiertos junto al núcleo. Specimen puede tener sujeto ambiental y no exige status/subject en la base; DiagnosticReport exige status/code, no subject; issued es instante con zona. El informe referencia dos Observation y un Specimen. Se rechazan status inválido y result hacia Patient. Tres vistas deben coincidir en V8/DuckDB; HAPI/perfil propio siguen separados.

**Errores a detectar:** Exigir siempre Patient a una muestra ambiental; confundir referencia estructural con resolución; declarar perfil validado por comparar tablas.

**Evidencia:** Grafo, matriz de campos, NDJSON, diagnósticos negativos, tres vistas y tablas comparadas.
