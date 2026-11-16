# Evaluación detallada del piloto externo R4

**Español** · [English](EVALUACION-PILOTO.en.md)

**Protocolo 2.1 · Candidato 0.5.0.9002 · Datos ficticios.** Este documento
define cómo observar, interpretar y cerrar la evaluación. [LEEME.md](LEEME.md)
explica la instalación; los protocolos [R](PROTOCOLO-PERFIL-R.md) y
[FHIR](PROTOCOLO-PERFIL-FHIR.md) contienen las consignas; el
[anexo del observador](ANEXO-OBSERVADOR.md) contiene las referencias de contraste.

## 1. Objetivo y preguntas de evaluación

Determinar si personas ajenas al desarrollo pueden preparar el candidato,
ejecutar y modificar un recorrido R4, explicar sus resultados y conservar
evidencia reproducible. El objetivo es encontrar problemas y decidir mejoras
para una entrega delimitada. La sesión no representa una evaluación clínica
ni una certificación de interoperabilidad con cualquier sistema.

| Dimensión | Pregunta | Evidencia que responde |
|---|---|---|
| Preparación | ¿Puede instalar y abrir la copia correcta? | Identidad, biblioteca cargada, entorno, tiempos y ayuda. |
| Exactitud | ¿Las salidas concuerdan con la fuente y los controles? | Recursos, vistas, tablas y diagnósticos contrastados. |
| Comprensión | ¿Puede explicar claves, filas, ausencias y límites? | Respuestas propias y evaluación justificada del observador. |
| Autonomía | ¿Puede resolver y repetir tareas sin intervención? | Estado por tarea, intervenciones y evidencia de repetición manual. |
| Semántica | ¿Las decisiones de mapeo y extracción son defendibles? | Matrices de campos, Coding, referencias y pérdidas de información. |
| Reproducibilidad | ¿Otro intento conserva resultados y decisiones? | Candidato fijo, dos carpetas, scripts, vistas y comparación. |
| Utilidad | ¿Resuelve una necesidad reconocible para el participante? | Ejemplo de uso propio, limitaciones y prioridades declaradas. |

Un control automático, la opinión favorable de una persona y una tarea
completada son evidencias diferentes. Conservarlas por separado permite
entender tanto un fallo como un resultado favorable.

## 2. Tres decisiones antes de comenzar

| Decisión | Opciones | Consecuencia |
|---|---|---|
| Perfil de la persona | R / FHIR | R evalúa análisis y uso; FHIR audita semántica e interoperabilidad. |
| Nivel técnico | Básico / completo | Completo añade DBI/DuckDB y recuperación; básico no los evalúa. |
| Alcance humano | Núcleo de cinco tipos / siete constructores | Siete exige completo y la tarea R09/F09 terminada. |

**Núcleo:** Patient, Encounter, Condition, Observation e Immunization. El
control instalado construye seis recursos de estos cinco tipos. La lectura de
AllergyIntolerance evalúa extracción y conteo, sin añadir un constructor.

**Siete:** núcleo más Specimen y DiagnosticReport mediante el caso de
laboratorio. El laboratorio contiene cinco recursos de cuatro tipos, que
amplían la cobertura conjunta a siete tipos. No son siete recursos en un solo
archivo. Para recomendar una entrega con ese alcance, obtener evidencia de
laboratorio en ambos perfiles; una única ficha R no responde la revisión FHIR.

La tarea 09 no se puede excluir y a la vez declarar evaluados siete tipos. Si
un bloqueo impide ejecutarla, conservar el alcance siete con resultado pendiente
o repetir en otra sesión con alcance núcleo expresamente acordado. No reducir
el alcance después del fallo para ocultarlo. Registrar ambos intentos.

Rust y un servidor FHIR son ampliaciones separadas. No se requieren para el
ensayo local. Una prueba de `$validate` se acuerda aparte sobre un servidor de
pruebas, perfiles canónicos y datos ficticios. No se escriben recursos en un
servidor como parte de esta evaluación.

## 3. Participantes, preparación y distribución del material

Incluir inicialmente una persona que use R y una con experiencia FHIR.
Registrar su experiencia en R, SQL, FHIR, perfiles y herramientas habituales;
no asumir que domina R quien conoce FHIR. Identificar participantes con un ID
acordado. Si una persona realiza ambos perfiles, conservar fichas separadas,
orden de realización y exposición previa: la segunda sesión tiene aprendizaje.

El mantenedor entrega el mismo ZIP, hash, candidato y protocolo a todas las
personas de una ronda. Registrar fecha de entrega y si alguna persona ya
utilizó materiales anteriores. Los resultados de protocolos distintos se
analizan como rondas distintas; el formulario rechaza importar otra identidad
de candidato o tareas. No trasladar casillas de aprobado a tareas modificadas.

El observador prepara navegador, R, carpeta y dependencias; comprueba el kit
antes de la cita. Si las instala por el participante, esa preparación debe
quedar documentada y no acredita instalación autónoma. Si se quiere evaluar
instalación desde cero, reservar ese bloque y registrar su tiempo por separado.

Acuerden duración disponible, pausas, canal de entrega y posibilidad de detener
la sesión. No hay un tiempo de aprobación predefinido: las primeras sesiones
establecen una línea base. Si se agota el tiempo, registrar la tarea bloqueada
o pendiente y programar continuación; no calificarla como fallo técnico por
duración. Se pueden usar varias citas conservando el mismo identificador de
ronda y nuevos intentos cuando se repite el ensayo.

## 4. Guion de la sesión

1. **Apertura.** Explicar el objetivo: evaluar la herramienta y la documentación.
   Registrar perfil, nivel, alcance, entorno, experiencia y material previamente
   consultado. Acordar cómo se registrarán observaciones. No grabar por defecto.
2. **Preparación.** Ejecutar R01/F01; separar dependencias, instalación y apertura.
   Comprobar identidad y conservar mensajes originales revisados.
3. **Primer intento.** Leer la consigna de cada tarea, solicitar que explique lo
   que intenta hacer y permitir documentación por iniciativa propia. Evitar
   enseñar resultados esperados o corregir respuestas antes de registrarlas.
4. **Observación.** Tomar tiempo activo y esperas, anotar ayudas, evidencias y
   explicaciones. Formular las preguntas de comprensión de la tarea sin sugerir
   su respuesta. Anotar literalmente una frase breve si ayuda a entender el error.
5. **Laboratorio.** Ejecutar R09/F09 antes del cierre cuando el alcance sea siete.
   Verificar las tres vistas, referencias y decimales; no basta con abrir el ejemplo.
6. **Repetición.** R07/F08 incluye otro ensayo y tareas manuales identificadas.
   Conservar el primer intento, registrar ayuda nueva y el efecto de lo aprendido.
7. **Cierre.** R08/F08: entrevista, revisión de incidencias, decisión humana y
   exportación. Confirmar con la persona que la conclusión representa lo observado.

Orden sugerido R: 01–06, 09 si corresponde, 07, 08. Orden FHIR: 01–07,
09 si corresponde, 08. Consultar el anexo de contraste después de registrar
el primer intento. No es necesario memorizar sintaxis para demostrar comprensión.

## 5. Cómo registrar ayuda y resultados

| Estado | Regla de registro |
|---|---|
| Pendiente | No se ha iniciado o aún no hay evidencia suficiente. |
| Completada sin ayuda | Se cumplieron criterios y explicación; cero intervenciones del observador. Puede usar documentación por su cuenta. |
| Completada con ayuda | Se cumplieron criterios tras una o más intervenciones registradas. |
| Bloqueada | No puede continuar por herramienta, entorno, documentación o tiempo disponible; describir la causa. |
| Falló | Se intentó y el resultado o interpretación no cumple lo esperado. |
| No evaluada | Se excluyó expresamente del alcance; escribir por qué. No equivale a aprobado. |

Registrar cada intervención: tarea, momento, tipo y contenido. Tipos útiles:
aclaración de consigna, orientación a documentación, pista conceptual, corrección
de código o solución completa. Una explicación del observador que cambia cómo
resolver la tarea cuenta como ayuda. Resolver un problema de red también se
registra, indicando que fue de entorno. No contar pulsaciones de teclado como
intervenciones distintas; contar episodios de ayuda identificables.

Registrar **minutos activos** y **minutos de espera** por separado. El activo
incluye búsqueda de documentación y razonamiento; espera incluye descargas,
instalación en ejecución, pausas o interrupciones. No sumar ambas categorías dos
veces. Los tiempos comparados deben corresponder a tareas, preparación y niveles
equivalentes. No convertir una duración corta en evidencia de exactitud.

## 6. Comprensión, facilidad y evidencia

| Comprensión observada | Criterio |
|---|---|
| Pendiente | No se formularon o revisaron las preguntas. |
| Correcta | Explica decisiones y límites, y los relaciona con evidencia concreta. |
| Parcial | Ejecuta o repite parte de la explicación, pero omite una distinción relevante. |
| Incorrecta | Interpreta mal la unidad, relación, validación o resultado. |

Conservar la respuesta inicial y cualquier corrección en el campo de respuestas.
Si aprende después de una pista, puede finalizar con comprensión correcta y
estado con ayuda. Una respuesta parcial o incorrecta requiere revisión; no
cerrar como completada una tarea cuya explicación esencial sigue siendo errónea.
El formulario comprueba que el registro está completo; el observador juzga la
respuesta y justifica su valoración. No evalúa automáticamente conocimiento FHIR.

Preguntar opcionalmente facilidad al terminar cada tarea: **1 muy difícil,
2 difícil, 3 intermedia, 4 fácil, 5 muy fácil**. Es una medida local descriptiva,
no una escala validada ni una puntuación de aprobación. Puede quedar sin respuesta;
explicar qué paso influyó más. No reemplaza tiempos, exactitud o comprensión.

Cada tarea terminada debe tener archivo/referencia de evidencia, respuestas,
comprensión, comprobaciones, tiempo e intervenciones coherentes. Referir archivos
por nombres relativos al paquete de evidencia; el formulario no verifica que
existan. El observador los abre y contrasta antes de marcar revisión completa.

Para documentar repetición, identificar las tareas, el nuevo intento y sus
archivos, resultado e intervenciones. Una primera tarea asistida puede repetirse
sin ayuda; conservar ambas observaciones. La ficha permite declarar autonomía
para un subconjunto explícito de tareas repetidas. No la extiende a las demás.

## 7. Incidencias y criterios de cierre

| Impacto | Ejemplo | Tratamiento |
|---|---|---|
| Crítico | Resultado incorrecto aceptado como válido, asociación falsa o pérdida de integridad. | Suspender cierre favorable; investigar, corregir y repetir el caso. |
| Alto | Una tarea esencial del alcance no puede completarse. | Resolver o repetir en otro entorno; no cerrar como aceptado. |
| Medio | Permite continuar con ayuda o un rodeo documentado. | Priorizar y comprobar la solución; explicitar si queda pendiente. |
| Bajo | Redacción, navegación o presentación confusa sin cambiar resultados. | Registrar mejora y responsable. |

Cada incidencia contiene tarea, pasos mínimos, esperado, observado, entorno,
evidencia, impacto, responsable y siguiente prueba. Corregida significa que se
aplicó una modificación; cerrada exige repetición y quién comprobó el resultado.
Un error de interpretación también puede revelar un problema documental.

**Aceptar para el alcance:** identidad y técnico comprobados; todas las tareas
obligatorias del alcance completadas con comprensión correcta y evidencia
revisada; ausencia de incidencias altas/críticas abiertas; conclusión explícita
y revisión de participante y mantenedor. Puede haber ayuda registrada: la
aceptación de la sesión no afirma autonomía.

**Aceptar con pendientes explícitos:** las mismas condiciones esenciales, con
incidencias medias/bajas descritas, responsable y próxima prueba. No usar esta
opción para obviar laboratorio obligatorio, una interpretación errónea o una
incidencia alta. Si hay incidencias abiertas de cualquier nivel, registrarlas
en la decisión; no seleccionar aceptación sin pendientes.

**Repetir tras correcciones:** falta un criterio esencial, se necesita cambiar
la documentación o hay incertidumbre relevante. También es un resultado útil.
La decisión pendiente se conserva hasta que ambas personas revisen la evidencia.

La tarea F07 se puede completar con un plan de validación explicado; eso deja
los perfiles externos **no evaluados**. Si se realiza una ampliación con servidor,
registrar sus resultados aparte y revisar cada advertencia/rechazo/indeterminado.
Ni el plan ni una sesión local favorable acreditan un perfil propio aprobado.

## 8. Entrevista final y análisis entre sesiones

Pedir respuestas concretas a estas preguntas, sin inducir una recomendación:

1. ¿Qué tarea de tu trabajo intentarías resolver con este flujo?
2. ¿En qué paso dudaste más y qué información faltó?
3. ¿Qué resultado te costó interpretar o comprobar?
4. ¿Qué podrías repetir por tu cuenta y qué ayuda seguirías necesitando?
5. ¿Qué tres cambios priorizarías y por qué?
6. ¿Qué tendrías que comprobar antes de recomendarlo o usarlo con otra fuente?

Analizar por perfil, nivel, alcance, ronda y experiencia. Para cada tarea
informar número intentado, completado sin ayuda, con ayuda, bloqueado, fallido y
excluido; mantener numerador/denominador visibles. Entre tareas obligatorias del
alcance, una no iniciada o bloqueada no sale del denominador para mejorar la
cifra. Las excluidas del alcance se presentan aparte. No mezclar básico y completo
ni sesiones de protocolos distintos en una única tasa de éxito.

Describir tiempos activos y esperas con número de observaciones. Con pocas
personas, mostrar los valores individuales y rango; evitar inferir superioridad
general o satisfacción poblacional. Comparar antes/después con las mismas tareas
e informar cambios de protocolo, entorno y aprendizaje. La repetición tiene
efecto de práctica y no demuestra por sí sola una mejora atribuible al producto.

La conclusión de ronda resume: alcance observado, participantes y experiencia,
resultados por tarea, errores de comprensión, hasta tres prioridades, responsables
y siguiente ensayo. Mantener un registro de qué cambia entre rondas.

## 9. Paquete de evidencia y continuidad

Conservar candidato/hash, protocolo, SESION.json, informes técnicos originales,
scripts, vistas JSON, NDJSON ficticio, comparaciones, fichas JSON/CSV/TXT,
experiencia e incidencias. Abrir las exportaciones para verificar que conservan
alcance, respuestas, comprensión y ayudas. La prueba de importación se realiza
en una ficha vacía, después de exportar la sesión en curso.

El almacenamiento del navegador es auxiliar; exportar antes de cerrar. Revisar
rutas y datos personales antes de compartir, usando solo los archivos acordados.
Las fichas completadas no se incorporan al ZIP distribuido. El mantenedor define
responsables y ubicación de la evidencia revisada; el kit no la transmite.

Si ya se entregó protocolo 2.0, conservarlo y su hash para esa ronda. Este
protocolo 2.1 se utiliza en una ronda nueva o tras acuerdo expreso antes de
iniciar tareas. El paquete R conserva su identidad; las tareas y el ZIP tienen
otra identidad. Una exportación del protocolo anterior no se importa en el nuevo.
