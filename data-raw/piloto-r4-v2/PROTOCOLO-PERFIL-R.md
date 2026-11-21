# Perfil R: análisis, autonomía y utilidad

**Español** · [English](PROTOCOLO-PERFIL-R.en.md)

Protocolo **2.1**, candidato **0.5.0.9003**, datos ficticios.

Lea [la evaluación](EVALUACION-PILOTO.md) y
[la preparación técnica](LEEME.md). Registre perfil de persona, nivel
básico/completo y alcance núcleo/siete como tres elecciones distintas.

Las tareas 01–08 son obligatorias. La 09 es obligatoria en alcance
**siete** y requiere completo; en núcleo se excluye expresamente.
Realice 09 antes del cierre 08. Responda con sus palabras;
consultar documentación por iniciativa propia está permitido.

El observador registra estado, tiempo activo/esperas, intervenciones,
comprensión, respuestas, documentos consultados, evidencia y repetición.
No consulte soluciones antes del primer intento. No se exige memorizar comandos.

## R01. Preparar el entorno e identificar la instalación

**Objetivo:** Comprobar que otra persona puede preparar y abrir el candidato entregado siguiendo la documentación.

**Alcance:** Obligatoria en núcleo y siete.

### Consigna y pasos

1. Acordar perfil R, nivel básico/completo y alcance núcleo de cinco tipos o siete constructores. Registrar experiencia previa en R, SQL y FHIR, dependencias presentes y ayudas previstas.
2. Verificar el ZIP y CANDIDATO.json. Registrar versión, commit y SHA-256 del paquete, sistema, arquitectura y R. Separar tiempo de dependencias del tiempo de instalación del candidato.
3. Ejecutar INICIAR.R en una carpeta nueva y abrir_sesion() en una sesión R limpia. Contrastar packageVersion(), find.package(), ayuda y viñetas.
4. Conservar SESION.json y el registro original; describir cada bloqueo y la documentación usada.

### Preguntas de comprensión

- ¿Cómo comprobarías que R está usando este candidato y no otra copia instalada?
- ¿Qué pasos necesitan red y cuáles deberían funcionar después de preparar las dependencias?

### Criterios observables

- La identidad entregada y la instalación cargada se contrastaron.
- Se registraron entorno, nivel técnico y alcance antes de ejecutar tareas.
- La ayuda y las viñetas se pudieron localizar, o se documentó el bloqueo.
- Los tiempos de preparación y las intervenciones quedaron separados.

**Evidencia a conservar:** SESION.json, candidato.txt, ruta revisada de biblioteca, versiones y registro de preparación.

### Preparación operativa

Adapte identificador, carpeta y nivel al acuerdo. Los ejemplos no sustituyen su explicación.

```r
source("INICIAR.R")
iniciar_piloto("basico", "sesion-P01-intento01")
abrir_sesion("sesion-P01-intento01")
packageVersion("fhirviews")
find.package("fhirviews")
help("fhir_mapa", package = "fhirviews")
browseVignettes("fhirviews")
```

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.

## R02. Interpretar controles e indicadores de vigilancia

**Objetivo:** Explicar qué mide el ensayo y detectar una interpretación epidemiológica incorrecta.

**Alcance:** Obligatoria en núcleo y siete.

### Consigna y pasos

1. Abrir aceptacion.json y aceptacion.csv. Localizar identidad, esquema, controles, advertencias y hallazgos sin modificar los informes.
2. Explicar qué acredita cada control y qué queda sin evaluar en el nivel elegido. Contrastar los totales y la exclusión de eventos con los archivos ficticios.
3. Seguir den-c0001 hasta su paciente y residencia; comprobar que den-c0002 no integra los confirmados. Revisar al menos un conteo territorial y uno mensual en los archivos del ejemplo.
4. Describir la unidad de análisis y qué información adicional haría falta para contar personas únicas o calcular una tasa poblacional.

### Preguntas de comprensión

- ¿Puede interpretarse cada fila de la salida como una persona distinta? ¿Por qué?
- ¿Un aprobado automático acredita que otra persona usó el paquete sin ayuda o que se validó un perfil nacional?

### Criterios observables

- Los cinco controles se interpretaron con sus omisiones y advertencias.
- Se contrastaron totales, un evento incluido y uno excluido con evidencia.
- Se revisó una agregación territorial y otra mensual.
- Se distinguieron eventos, personas y tasas; las limitaciones quedaron escritas.

**Evidencia a conservar:** Informe original y nota de interpretación con filas o campos contrastados.

### Preparación operativa

Adapte identificador, carpeta y nivel al acuerdo. Los ejemplos no sustituyen su explicación.

```r
informe <- jsonlite::read_json("sesion-P01-intento01/piloto/aceptacion.json")
informe[c("version_fhirviews", "candidato_md5", "esquema_informe", "resultado_tecnico")]
read.csv("sesion-P01-intento01/piloto/aceptacion.csv")
```

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.

## R03. Reconstruir la procedencia de una tabla R4

**Objetivo:** Relacionar las tablas con sus recursos y explicar claves, ausencias y precisión.

**Alcance:** Obligatoria en núcleo y siete.

### Consigna y pasos

1. Abrir los seis recursos de piloto/r4/recursos-r4.ndjson y elaborar una tabla local tipo/id/referencias relevantes.
2. Seguir Patient, Encounter, Condition, Observation e Immunization; contrastar al menos una fila tabular con su línea NDJSON.
3. Comparar false, campo ausente y NA; localizar las variantes de fecha y número de dosis de ambas inmunizaciones.
4. Revisar los literales decimales en el archivo y explicar qué se pierde si la fuente SQL los entrega como double.

### Preguntas de comprensión

- ¿Por qué una tabla que imprime 72 no demuestra que se conservó el literal 72.00?
- ¿Qué riesgo tiene completar una fecha desconocida o unir tablas solo por el orden de las filas?

### Criterios observables

- Se distinguieron número de tipos, número de recursos y filas de salida.
- Las claves y referencias de la fila elegida se siguieron hasta la fuente.
- FALSE, ausencia y NA se explicaron sin rellenar datos.
- La escala se contrastó en el JSON, además de la tabla R.

**Evidencia a conservar:** Tabla local de procedencia, referencias y fragmentos de JSON ficticio revisados.

### Preparación operativa

Adapte identificador, carpeta y nivel al acuerdo. Los ejemplos no sustituyen su explicación.

```r
recursos <- fhir_recursos("sesion-P01-intento01/piloto/r4/recursos-r4.ndjson")
print(recursos)
```

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.

## R04. Construir recursos nuevos y entender los errores

**Objetivo:** Crear un mapeo pequeño con datos ficticios y resolver un fallo usando la ayuda.

**Alcance:** Obligatoria en núcleo y siete.

### Consigna y pasos

1. Crear en un script dos Patient ficticios nuevos: id distintos, gender válido, birthDate y active lógico, incluyendo FALSE. Consultar fhir_mapa(), fhir_desde_tabla() y fhir_escribir().
2. Construir los recursos con un mapa explícito; escribir NDJSON y volver a leerlo. Contrastar ambos registros y conservar script, mapa y salida.
3. En copias separadas de los datos, repetir un id y usar un gender inválido. Capturar cada rechazo y explicar cómo corregir el origen sin ocultar el error.
4. En nivel completo, repetir el caso válido con una tabla DuckDB y una consulta parametrizada que seleccione un id. Comparar la salida y cerrar la conexión. En básico, anotar que DBI no se evaluó.

### Preguntas de comprensión

- ¿Qué significa una fila de entrada en este constructor y cómo prepararías dos filas con el mismo id?
- ¿Cuándo usarías parámetros SQL y qué harías si un identificador grande llega redondeado?

### Criterios observables

- El caso válido se construyó, guardó y releyó con sus valores explícitos.
- Las dos entradas inválidas se rechazaron y se conservó el diagnóstico.
- La corrección se hizo en una copia nueva del origen y quedó explicada.
- El recorrido DBI se comprobó en completo o quedó excluido explícitamente en básico.

**Evidencia a conservar:** Script propio, NDJSON válido, diagnóstico de cada caso negativo y comparación DBI si corresponde.

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.

## R05. Diseñar, modificar y reutilizar una vista

**Objetivo:** Resolver una extracción nueva con la documentación y verificar su significado.

**Alcance:** Obligatoria en núcleo y siete.

### Consigna y pasos

1. Crear una vista Immunization con estado, paciente y fecha a partir del NDJSON del ensayo; conservar la definición antes de ampliarla.
2. Añadir columnas para ambas variantes de occurrence y guardar una segunda definición JSON. Ejecutarla y explicar cada NA con el recurso original.
3. Leer la definición guardada con vista_leer() y repetir la extracción; comprobar claves, valores, tipos y conteo, sin exigir orden salvo que se haya acordado.
4. Describir una modificación para una necesidad de análisis propia usando solo los datos ficticios. Registrar documentos consultados y cualquier solución proporcionada.

### Preguntas de comprensión

- ¿Qué debes guardar para que otra persona pueda reproducir esta extracción?
- ¿Qué información del recurso original deja fuera tu vista y podría necesitar otro análisis?

### Criterios observables

- Se conservaron dos versiones JSON y se reutilizó la segunda.
- Las dos inmunizaciones permanecieron identificadas correctamente.
- Las variantes ausentes y tipos se contrastaron con NDJSON.
- La persona explicó su vista y la ayuda necesaria, además de ejecutarla.

**Evidencia a conservar:** vista-inmunizaciones-01.json, vista-inmunizaciones-02.json, tablas y explicación propia.

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.

## R06. Analizar alergias conservando la unidad de conteo

**Objetivo:** Evitar sobrecontar registros al desplegar reacciones y manifestaciones.

**Alcance:** Obligatoria en núcleo y siete.

### Consigna y pasos

1. Localizar el NDJSON de alergias y ejecutar la vista de catálogo. Comparar nrow() con el número de ids distintos.
2. Agrupar las filas por id y reconstruir la relación alergia→reacción→manifestación para un registro con más de una fila.
3. Contrastar una alergia sin reacción y sus ausencias. Identificar categorías múltiples y diferenciar criticidad de gravedad por reacción.
4. Explicar qué conteo usarías para informar alergias registradas y cómo cambiaría si el objetivo fueran manifestaciones. Conservar el código y la justificación.

### Preguntas de comprensión

- ¿Qué error produciría usar nrow(tabla) como número de alergias?
- ¿Una alergia sin reacción documentada significa que no hubo reacción?

### Criterios observables

- Los conteos de filas e ids se calcularon por separado.
- Las manifestaciones conservaron su reacción y gravedad.
- Las alergias sin reacción no desaparecieron del análisis.
- Se justificó la unidad contada y el tratamiento de ausencias y listas.

**Evidencia a conservar:** Script de conteo, tabla por id y explicación de unidad de análisis.

### Preparación operativa

Adapte identificador, carpeta y nivel al acuerdo. Los ejemplos no sustituyen su explicación.

```r
archivo <- system.file("extdata", "alergias_r4.ndjson", package = "fhirviews")
alergias <- vista_ejecutar(archivo, vista_plantilla("alergias"))
alergias[, c("id", "estado_clinico", "gravedad_reaccion", "reaccion_codigo")]
length(unique(alergias$id))
```

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.

## R07. Repetir el análisis y comprobar recuperación

**Objetivo:** Comprobar repetibilidad y documentar qué tareas pueden repetirse sin intervención.

**Alcance:** Obligatoria en núcleo y siete.

### Consigna y pasos

1. Ejecutar de nuevo el nivel acordado en otra carpeta, conservando ambos informes y el mismo candidato.
2. Comparar hallazgos y estados; separar diferencias de rutas y tiempos de diferencias de datos o tipos.
3. Repetir la creación/reutilización de la vista y el conteo de alergias sin pistas del observador. Registrar exactamente qué tareas y archivos respaldan la repetición.
4. En completo, revisar el control de recuperación y explicar rollback/reintento sin duplicados. En básico, conservar no_evaluado y limitar la conclusión.

### Preguntas de comprensión

- ¿Por qué repetir solo el comando automático no demuestra que sabes modificar una vista?
- ¿Qué comprobarías antes de reintentar una carga que falló a mitad?

### Criterios observables

- Los dos intentos y el candidato utilizado quedaron identificados.
- Se compararon datos, estados y tipos, con diferencias explicadas.
- La repetición manual registró alcance, resultado e intervenciones.
- La recuperación se interpretó según el nivel técnico.

**Evidencia a conservar:** Dos informes, comparación escrita y archivos de repetición manual; si hubo ayuda, describirla.

### Preparación operativa

Adapte identificador, carpeta y nivel al acuerdo. Los ejemplos no sustituyen su explicación.

```r
iniciar_piloto("basico", "sesion-P01-intento02")
a <- jsonlite::read_json("sesion-P01-intento01/piloto/aceptacion.json")
b <- jsonlite::read_json("sesion-P01-intento02/piloto/aceptacion.json")
identical(a$hallazgos, b$hallazgos)
```

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.

## R08. Valorar utilidad y acordar el cierre

**Objetivo:** Decidir qué uso quedó demostrado y qué mejoras necesitan seguimiento.

**Alcance:** Obligatoria en núcleo y siete.

### Consigna y pasos

1. Revisar las tareas R01–R07 y R09 si corresponde; registrar los bloqueos y errores de interpretación como incidencias con esperado, observado y evidencia.
2. Responder la entrevista de cierre: utilidad para una tarea propia, paso más confuso, confianza en interpretar las salidas y hasta tres mejoras prioritarias. Distinguir opinión de medición.
3. Revisar participante y mantenedor la decisión para el alcance exacto, las tareas no evaluadas, responsables y siguiente comprobación. Incidencias críticas/altas requieren corrección y repetición.
4. Exportar JSON, CSV y texto; comprobar que se pueden reabrir las fichas y que los adjuntos acordados son legibles y no contienen datos personales.

### Preguntas de comprensión

- ¿Qué tarea real intentarías después con esta herramienta y qué te impide hacerlo hoy?
- ¿Qué necesitarías comprobar antes de recomendarla a un colega?

### Criterios observables

- La utilidad se vinculó a una tarea concreta y sus límites.
- Incidencias y prioridades tienen evidencia y responsable.
- La decisión humana y los alcances no evaluados quedaron explícitos.
- Se revisaron y conservaron las exportaciones y anexos acordados.

**Evidencia a conservar:** Ficha exportada y revisada, experiencia-usuario.txt, incidencias y plan de seguimiento.

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.

## R09. Evaluar el recorrido de laboratorio de siete constructores

**Objetivo:** Completar SQL→laboratorio R4→tablas cuando se evalúe el alcance de siete tipos.

**Alcance:** Obligatoria en siete; excluida con justificación en núcleo.

### Consigna y pasos

1. Confirmar alcance siete y nivel completo; abrir el ejemplo laboratorio-r4.R instalado, leer entradas, mapas y consultas antes de ejecutarlo.
2. Ejecutar laboratorio_r4() y escribir sus recursos en un NDJSON nuevo. Identificar tipos, ids y enlaces entre paciente, muestra, observaciones e informe.
3. Guardar las tres vistas y comparar tablas V8/DuckDB por claves, valores y tipos. Revisar escala de volumen y resultados en el NDJSON.
4. Explicar cómo obtendrías una fila por resultado y cómo evitarías contar un informe dos veces. En alcance núcleo, marcar no_evaluada y justificar la exclusión; no afirmar evaluación de los siete tipos.

### Preguntas de comprensión

- ¿Por qué la tabla de referencias del informe tiene más filas que informes?
- ¿Qué partes de este caso necesitarían decisiones nuevas para adaptarlo a otra fuente SQL?

### Criterios observables

- Se ejecutó desde la instalación comprobada con DBI/DuckDB.
- Las referencias y literales de muestra, resultados e informe se contrastaron.
- Las tres vistas se guardaron y las tablas se compararon en ambos motores.
- La interpretación distingue muestra, observación, informe y filas de la vista.

**Evidencia a conservar:** NDJSON de laboratorio, tres definiciones JSON, tablas comparadas y explicación propia.

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.
