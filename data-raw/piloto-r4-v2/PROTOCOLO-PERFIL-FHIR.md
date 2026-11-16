# Perfil FHIR: semántica e interoperabilidad R4

**Español** · [English](PROTOCOLO-PERFIL-FHIR.en.md)

Protocolo **2.1**, candidato **0.5.0.9002**, datos ficticios.

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

## F01. Fijar el alcance de interoperabilidad y el candidato

**Objetivo:** Delimitar qué afirmaciones puede respaldar la sesión y preparar un entorno reproducible.

**Alcance:** Obligatoria en núcleo y siete.

### Consigna y pasos

1. Acordar perfil FHIR, nivel técnico, alcance núcleo/siete y preguntas de interoperabilidad. Registrar experiencia en FHIR, R, SQL, perfiles y terminología por separado.
2. Contrastar identidad del candidato y abrir la biblioteca aislada siguiendo LEEME.md; registrar la ayuda de R necesaria sin confundirla con un fallo de semántica.
3. Leer los cinco controles y separar construcción local, comparación de tablas, validación de perfiles y evaluación humana. Anotar DBI/recuperación no evaluados en básico.
4. Identificar qué perfiles base y evidencia HAPI se proporcionan como antecedentes y qué validaciones del entorno propio quedan fuera de esta sesión.

### Preguntas de comprensión

- ¿Qué acredita aquí el constructor local y qué requiere un validador de perfiles o terminología?
- ¿Qué evidencias pedirías para afirmar interoperabilidad con un sistema específico?

### Criterios observables

- Identidad, entorno, nivel y alcance acordados quedaron registrados.
- La instalación se verificó y la ayuda recibida quedó descrita.
- Se distinguieron las capas de comprobación y sus evidencias.
- Los perfiles y servidores no evaluados se declararon explícitamente.

**Evidencia a conservar:** Identidad y entorno, informes consultados y matriz escrita de validado/no evaluado.

### Preparación operativa

Adapte identificador, carpeta y nivel al acuerdo. Los ejemplos no sustituyen su explicación.

```r
source("INICIAR.R")
iniciar_piloto("completo", "sesion-P02-intento01")
abrir_sesion("sesion-P02-intento01")
packageVersion("fhirviews")
find.package("fhirviews")
help("fhir_mapa", package = "fhirviews")
browseVignettes("fhirviews")
```

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.

## F02. Revisar mapeos, cardinalidades y decisiones semánticas

**Objetivo:** Distinguir reglas del modelo base, contrato del constructor y decisiones de la fuente.

**Alcance:** Obligatoria en núcleo y siete.

### Consigna y pasos

1. Revisar los mapas del ejemplo r4-estabilidad.R y sus recursos producidos. Relacionar columnas, constantes y referencias con destinos JSON concretos.
2. Elaborar para Patient, Encounter, Condition, Observation e Immunization una matriz: campo, origen/constante, obligatoriedad base o del constructor y decisión pendiente del proyecto.
3. Contrastar al menos status/class de Encounter, subject de Condition, status/code de Observation y patient/vaccineCode/occurrence de Immunization usando la ayuda y el modelo R4 acordado.
4. Explicar una constante que no se podría trasladar automáticamente a otra fuente y por qué un ViewDefinition no constituye un mapa inverso completo.

### Preguntas de comprensión

- ¿Por qué exigir id para construir no significa que todos los recursos FHIR deban traerlo antes de crearse?
- ¿Es válido asumir status=final para toda fuente solo porque el ejemplo lo usa?

### Criterios observables

- La matriz distingue columna, constante y referencia.
- Se separaron requisitos base, invariantes/perfiles y contrato local.
- Se identificaron decisiones semánticas que requieren acuerdo del proyecto.
- La limitación de reconstruir desde una proyección tabular quedó explicada.

**Evidencia a conservar:** Matriz por recurso con fuente documental/versionada y justificación de decisiones.

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.

## F03. Auditar tipos, elecciones, fechas y precisión

**Objetivo:** Comprobar que la transformación conserva significado y rechaza alternativas incompatibles.

**Alcance:** Obligatoria en núcleo y siete.

### Consigna y pasos

1. Contrastar FALSE, ausencia y textos de i1/i2 con el NDJSON y las vistas. Identificar occurrence[x] y doseNumber[x] por sus nombres JSON y tipos.
2. Revisar 72.00 y 0.50 como literales JSON y los límites calculados; explicar el riesgo de DECIMAL SQL→double antes de mapear.
3. En un script ficticio separado, intentar Patient.active="false", fecha imposible y una Immunization que incluya las dos variantes de occurrence. Registrar rechazos con clase y campo cuando se conozca.
4. Explicar el tratamiento de fecha parcial/Date frente a instante con zona y por qué no deben completarse horas, cantidades o campos ausentes por conveniencia.

### Preguntas de comprensión

- ¿Tienen la misma evidencia de precisión los literales 72 y 72.00?
- ¿Qué daño semántico podría producir convertir una fecha desconocida en una fecha inventada?

### Criterios observables

- Se contrastaron valores presentes y ausencias sin conversiones inventadas.
- Las alternativas de elección y la escala se verificaron en la fuente exacta.
- Los tres casos inválidos se rechazaron y sus diagnósticos se conservaron.
- La persona explicó fechas y precisión con sus límites.

**Evidencia a conservar:** Matriz de variantes, fragmentos NDJSON, script y diagnósticos de casos negativos.

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.

## F04. Comprobar referencias e integridad del grafo

**Objetivo:** Diferenciar destino permitido, clave construida y existencia del recurso referenciado.

**Alcance:** Obligatoria en núcleo y siete.

### Consigna y pasos

1. Dibujar o tabular los enlaces de los seis recursos del control. Identificar tipo/id, referencia al paciente y relaciones con el encuentro.
2. Comprobar que cada referencia local del caso resuelve al recurso esperado, por tipo e id; registrar enlaces opcionales ausentes.
3. Construir un caso negativo con destino Group para Immunization.patient y otro con id de paciente sintácticamente válido pero inexistente en el conjunto. Comparar el comportamiento.
4. Explicar cómo tratarías ids repetidos entre servidores, referencias absolutas, URN y dependencias al guardar; señalar qué no comprueba el constructor local.

### Preguntas de comprensión

- ¿Una referencia Patient/inexistente puede pasar el constructor? ¿Qué falta comprobar?
- ¿Basta el id p1 para unir recursos obtenidos de dos servidores distintos?

### Criterios observables

- Los enlaces del caso se verificaron por tipo e id.
- Las ausencias opcionales se conservaron y explicaron.
- Se contrastaron rechazo de destino incompatible y referencia no resuelta.
- Se distinguieron validación estructural y existencia/resolución.

**Evidencia a conservar:** Inventario de enlaces, script de ambos casos y diagnóstico o referencia no resuelta.

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.

## F05. Examinar bindings y fidelidad de Coding

**Objetivo:** Comprobar selección de vocabularios sin convertir etiquetas o listas parciales en validación completa.

**Alcance:** Obligatoria en núcleo y siete.

### Consigna y pasos

1. Revisar los Coding de clinicalStatus y verificationStatus del ejemplo de alergias. Identificar sistema canónico, código, display y traducciones adicionales.
2. Contrastar qué Coding elige la vista y comprobar que sistema, código y display provienen de la misma entrada. Revisar el caso con Coding sin código.
3. Crear dos Patient ficticios en intentos separados: gender válido e inválido. Registrar el rechazo del binding requerido enumerable y explicar por qué no valida cualquier terminología clínica.
4. Preparar una lista de sistemas/ValueSets/versiones que exigiría el entorno propio, distinguiendo required/extensible y datos de ejemplo. La consulta a un servidor queda fuera si no se acordó.

### Preguntas de comprensión

- ¿Puede usarse display como identificador estable de un concepto?
- ¿Por qué una lista parcial de códigos o code.text no acredita un binding requerido completo?

### Criterios observables

- Los Coding se revisaron como pares system/code coherentes.
- Se contrastaron estados canónicos y traducciones sin mezclarlos.
- El binding requerido enumerable rechazó el código inválido.
- Las terminologías externas y perfiles propios quedaron como requisitos explícitos.

**Evidencia a conservar:** Tabla de Coding contrastados, caso negativo y lista de requisitos terminológicos del proyecto.

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.

## F06. Auditar la proyección y sus pérdidas de información

**Objetivo:** Evaluar si las vistas conservan relaciones suficientes para el uso declarado.

**Alcance:** Obligatoria en núcleo y siete.

### Consigna y pasos

1. Crear y guardar una vista de Immunization con paciente y ambas variantes de occurrence; justificar claves, tipos y columnas omitidas.
2. Ejecutar la vista de alergias y contrastar relación reacción/manifestación, categorías como listas y conservación de registros sin reacción.
3. Comparar filas, ids distintos y significado de cada fila; identificar una extracción que podría producir una asociación falsa o un sobreconteo.
4. En completo, comparar tablas equivalentes V8/DuckDB por claves, valores y tipos. En básico, dejar comparación entre motores como no evaluada; explicar alcance del banco de conformidad.

### Preguntas de comprensión

- ¿Qué información necesitarías además de esta vista para reconstruir el recurso original?
- ¿Pasar el banco de pruebas implica que cualquier FHIRPath podrá traducirse a SQL?

### Criterios observables

- La definición guardada y sus pérdidas fueron explicadas.
- La relación reacción/manifestación y filas sin reacción se verificaron.
- Se distinguieron filas y recursos sin asociación artificial.
- La comparación de motores se documentó según el nivel técnico.

**Evidencia a conservar:** ViewDefinition propio, tabla de auditoría y comparación de motores o exclusión justificada.

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.

## F07. Diseñar la validación de perfiles del entorno

**Objetivo:** Producir un plan revisable de interoperabilidad sin atribuir ejecuciones no realizadas.

**Alcance:** Obligatoria en núcleo y siete.

### Consigna y pasos

1. Inventariar, para los recursos del alcance, perfil base, perfil del proyecto si existe, versión FHIR, terminología y referencias que habrá que resolver.
2. Revisar la evidencia HAPI entregada como antecedente del mantenedor y distinguirla de una ejecución propia. Registrar qué invariantes y requisitos del proyecto siguen pendientes.
3. Definir un ensayo futuro o, solo si se acordó un servidor de pruebas, ejecutar $validate sobre el JSON exacto conservando perfil canónico, servidor/versión, fecha, estado HTTP y OperationOutcome.
4. Incluir en el plan un recurso válido y uno alterado que deba rechazarse. Si se ejecutó el servidor, clasificar válido/rechazado/indeterminado y revisar advertencias; si no, dejar la validación de perfiles no_evaluada.

### Preguntas de comprensión

- ¿Qué significa valido=NA o un OperationOutcome incompleto?
- ¿Por qué declarar meta.profile no prueba por sí mismo el cumplimiento de ese perfil?

### Criterios observables

- Existe una matriz de perfiles, versiones y requisitos por recurso.
- Se separaron antecedentes del mantenedor y ejecución del participante.
- El plan incluye casos positivo/negativo y criterio de interpretación.
- El estado de validación externa se registró sin aprobar lo no ejecutado.

**Evidencia a conservar:** Matriz y plan de validación; si hubo ejecución acordada, JSON exacto y OperationOutcome revisado con fecha/perfil/servidor.

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.

## F08. Repetir la auditoría y emitir una conclusión delimitada

**Objetivo:** Comprobar repetición, revisar hallazgos y decidir qué interoperabilidad se evaluó.

**Alcance:** Obligatoria en núcleo y siete.

### Consigna y pasos

1. Repetir el ensayo instalado en carpeta nueva y una auditoría manual de referencias, Coding y elecciones sin pistas; identificar las tareas repetidas y conservar ambas evidencias.
2. Comparar hallazgos y registrar discrepancias de datos, tipos o interpretación separadas de diferencias de entorno. Corregir y repetir cualquier incidencia crítica/alta antes de cerrar favorablemente.
3. Responder la entrevista: decisión de mapeo más difícil, información faltante para un entorno propio, confianza en revisar resultados y hasta tres mejoras prioritarias.
4. Revisar con participante y mantenedor la matriz de alcance, perfiles no ejecutados, ayudas, responsables y decisión humana; exportar fichas y revisar adjuntos.

### Preguntas de comprensión

- ¿Qué afirmación de interoperabilidad puedes sostener con esta sesión y cuál requiere otra prueba?
- ¿Recomendarías este flujo para una prueba de integración? ¿Con qué condiciones concretas?

### Criterios observables

- Se conservó el segundo intento y se delimitó la repetición manual.
- Los hallazgos se compararon y las discrepancias quedaron registradas.
- La conclusión distingue estructura, semántica, perfiles y utilidad.
- La ficha exportada, prioridades y seguimiento fueron revisados por ambas personas.

**Evidencia a conservar:** Dos intentos, auditoría repetida, ficha exportada y conclusión con alcances pendientes.

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.

## F09. Auditar Specimen y DiagnosticReport de extremo a extremo

**Objetivo:** Completar la revisión semántica de los dos constructores adicionales en alcance siete.

**Alcance:** Obligatoria en siete; excluida con justificación en núcleo.

### Consigna y pasos

1. Confirmar nivel completo y ejecutar el ejemplo laboratorio-r4.R con datos ficticios. Identificar mapas, consultas, tipos y recursos generados.
2. Auditar el grafo Patient→Specimen/Observation/DiagnosticReport y las colecciones result[].reference/specimen[].reference; comprobar todas las referencias del caso por tipo e id.
3. Contrastar status/code obligatorios de DiagnosticReport, opcionalidad base de subject y de status/subject de Specimen, issued con zona y precisión de cantidades. Probar por separado status inválido y result apuntando al tipo incorrecto.
4. Guardar las tres vistas, el NDJSON exacto y comparaciones V8/DuckDB; añadir estos tipos al plan F07. En núcleo, justificar no_evaluada sin afirmar revisión de siete tipos.

### Preguntas de comprensión

- ¿Todo Specimen debe tener Patient como subject en la base R4?
- ¿Qué impide que una referencia válida en estructura se resuelva a un resultado equivocado en otra fuente?

### Criterios observables

- Los mapas y el grafo del laboratorio se auditaron con todos sus enlaces.
- Se distinguieron cardinalidades base y exigencias del proyecto.
- Los dos casos inválidos se rechazaron y la precisión se contrastó.
- Las tres vistas/motores y requisitos de perfiles quedaron documentados.

**Evidencia a conservar:** Grafo, matriz de campos, NDJSON, diagnósticos negativos, tres vistas y tablas comparadas.

**Registro:** estado; minutos activos/espera; intervenciones y ayuda;
comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.
