# Guía de participación en el piloto externo R4

**Español** · [English](LEEME.en.md) · Protocolo **2.1**

La [evaluación detallada](EVALUACION-PILOTO.md) define observación, comprensión,
ayuda, repetición y cierre. Léala antes de acordar la sesión.

Esta guía explica cómo preparar, ejecutar y documentar una sesión con el kit
de **fhirviews 0.5.0.9002**. Está dirigida a la persona participante y a quien
observe la sesión. El kit contiene datos ficticios y una copia identificada del
paquete; no necesita un servidor FHIR ni datos clínicos.

> **Alcance de la evaluación.** 0.5.0.9002 es un candidato de desarrollo, no
> una versión estable ni una evaluación clínica. La comprobación automática
> acredita solo los controles incluidos en el kit. La evaluación de uso y la
> decisión de cierre deben registrarse por separado.

## Antes de comenzar

### Perfiles y roles

Hay dos perfiles de competencia, dos niveles técnicos y dos alcances humanos;
son tres decisiones independientes:

| Elección | Qué significa |
|---|---|
| Perfil **R** | Analista, investigador o epidemiólogo; realiza las tareas R01–R09. |
| Perfil **FHIR** | Persona con experiencia en interoperabilidad o informática sanitaria; realiza F01–F09. |
| Nivel **básico** | Ejecuta los controles instalados y las tareas manuales. No instala ni evalúa DuckDB. |
| Nivel **completo** | Añade DBI/DuckDB, comparación de motores y recuperación. |
| Alcance **núcleo** | Evalúa los cinco tipos del control y la extracción de alergias; excluye laboratorio con motivo. |
| Alcance **siete** | Añade Specimen y DiagnosticReport: exige completo y R09/F09 terminada. |

Acuerden antes de la sesión el perfil, el nivel, el alcance, el identificador de
participación, el sistema y la persona observadora. No se han asignado
participantes de antemano. Use un identificador acordado, por ejemplo `P01`,
sin incluir nombres, correos ni otros datos personales en los archivos que se
compartan.

La persona participante debe intentar las tareas antes de consultar las
soluciones. La persona observadora registra el tiempo, la ayuda solicitada,
los obstáculos, el resultado y la evidencia sin resolver la tarea por la
persona. Si ofrece una pista o muestra una solución, anótelo; esa tarea cuenta
como asistida. El [anexo del observador](ANEXO-OBSERVADOR.md) contiene los
resultados esperados y se consulta después del intento inicial.

### Requisitos técnicos

| Nivel | Requisitos del kit |
|---|---|
| Básico | R ≥ 4.1.0 y paquetes R `cli`, `httr2`, `jsonlite`, `rlang`, `V8` y `openssl`. |
| Completo | R ≥ 4.2.0, lo anterior, `DBI` y `duckdb` ≥ 1.3.0. |

Instale las dependencias antes de iniciar. El lanzador las comprueba, pero no
las instala. Para instalarlas desde CRAN:

```r
# Básico
install.packages(c("cli", "httr2", "jsonlite", "rlang", "V8", "openssl"))

# Agregue solo si acuerdan el nivel completo
install.packages(c("DBI", "duckdb"))
```

No se necesita Rust, Java, Docker, PostgreSQL, SQL Server, HAPI ni acceso a una
red FHIR. Rust es opcional y no se instala desde este kit. El perfil completo
usa la extensión `json` de DuckDB. Si no está disponible localmente, DuckDB
puede necesitar descargarla la primera vez; anote cualquier bloqueo de red y
no lo registre como fallo de la lógica FHIR.

También hace falta un navegador actual para el formulario local. El formulario
no ejecuta R, no comprueba el paquete y no envía resultados.

## Descargar y verificar el kit

1. Obtenga el ZIP de la versión acordada y, si se lo entregan por separado, el
   archivo `.sha256` correspondiente. No mezcle archivos de versiones distintas.
2. Antes de extraer, verifique el SHA-256 del ZIP:

   - Linux: `sha256sum fhirviews-kit-piloto-r4-v2.zip`.
   - macOS: `shasum -a 256 fhirviews-kit-piloto-r4-v2.zip`.
   - Windows PowerShell: `Get-FileHash .\fhirviews-kit-piloto-r4-v2.zip -Algorithm SHA256`.

   Compare el valor con el publicado o comunicado por el mantenedor. Si no
   coincide, no ejecute el kit: solicite de nuevo el archivo y su hash.
3. Extraiga el ZIP completo en una carpeta de trabajo propia. No mueva ni
   renombre archivos dentro de la carpeta extraída: el lanzador localiza el
   paquete y los protocolos relativos a `INICIAR.R`.
4. Abra `FORMULARIO-PILOTO.html` en el navegador. Seleccione R o FHIR y lea
   `PILOTO-R4.md` y el protocolo del perfil correspondiente antes de la sesión.
5. Compare `CANDIDATO.json`, `MANIFIESTO-KIT.json` y `SHA256SUMS`. El candidato
   incluye versión, commit, tamaño, SHA-256 y MD5 del paquete. El lanzador
   vuelve a verificar tamaño, SHA-256 y MD5 antes de instalar.

En Linux o macOS, desde la raíz extraída, también puedes verificar los archivos
internos con `sha256sum -c SHA256SUMS` o `shasum -a 256 -c SHA256SUMS`,
respectivamente. PowerShell puede comprobar un archivo concreto con
`Get-FileHash .\paquete\fhirviews_0.5.0.9002.tar.gz -Algorithm SHA256` y
comparar el resultado con `CANDIDATO.json`.

Los checksums permiten detectar alteraciones accidentales del contenido. No
son una firma criptográfica ni autentican por sí solos quién publicó el ZIP.
Use la fuente acordada y el enlace del repositorio oficial para obtenerlo.

## Ejecutar el nivel acordado

Extraiga todo el ZIP y abra R o RStudio con el directorio de trabajo en la
carpeta raíz extraída, donde está `INICIAR.R`. En RStudio, abra una sesión
nueva de R antes de cargar fhirviews. Use una carpeta de salida nueva para
cada participante y cada intento; el lanzador se niega a sobrescribirla.

### Nivel básico

```r
source("INICIAR.R")
iniciar_piloto("basico", "sesion-P01-intento01")
abrir_sesion("sesion-P01-intento01")
```

En RStudio, para las tareas manuales, ejecute las dos primeras líneas en la
consola y luego `abrir_sesion()` con el mismo nombre de carpeta. Si ya había
otra copia de fhirviews cargada en esa sesión, reinicie R y abra nuevamente la
sesión aislada.

También puede arrancar la comprobación automática desde una terminal, situada
en la carpeta extraída:

```sh
Rscript INICIAR.R basico sesion-P01-intento01
```

### Nivel completo

Instale DBI y DuckDB según la tabla de requisitos y use otro nombre de carpeta:

```r
source("INICIAR.R")
iniciar_piloto("completo", "sesion-P01-intento01")
abrir_sesion("sesion-P01-intento01")
```

El alcance siete requiere nivel completo y R09/F09. El alcance núcleo excluye
esa tarea como `no_evaluada`, con motivo. Los cinco controles automáticos no
cambian: la aceptación humana de siete añade obligatoriamente el laboratorio.

## Qué hace y qué no hace la comprobación automática

El lanzador verifica la identidad del archivo, lo instala en una biblioteca
R aislada y ejecuta el control técnico en un proceso R nuevo. No reemplaza la
observación de las tareas ni completa el formulario. Al terminar, compruebe
que `SESION.json` y `piloto/aceptacion.json` identifican 0.5.0.9002 y el mismo
checksum del candidato.

Hay cinco controles técnicos:

| Control | Qué comprueba |
|---|---|
| `api_instalada` | Que la copia aislada se instaló y carga. |
| `vigilancia` | Resultados del ejemplo ficticio: 755 eventos de entrada, 661 confirmados, 94 excluidos y 65 cantones. No confunda eventos con personas ni interprete estos datos como tasas reales. |
| `contrato_estricto` | Que se rechace una entrada por bloques incompatible antes de escribir resultados. |
| `recuperacion` | Comportamiento de recuperación/rollback; en el nivel básico queda `no_evaluado`, no aprobado. |
| `r4_cinco_recursos` | Seis recursos ficticios de cinco tipos: Patient, Encounter, Condition, Observation y dos Immunization, con referencias, tipos, ausencias y escala decimal. |

En básico se esperan cuatro controles aprobados y `recuperacion` como
`no_evaluado`. En completo se esperan los cinco aprobados. Un fallo o una
advertencia requiere revisión; no cambie manualmente los estados para obtener
un aprobado. El código de salida, el informe técnico y la evaluación humana son
resultados distintos.

La prueba R4 histórica no significa que el candidato solo construya cinco
recursos. El constructor actual admite siete tipos. La tarea R09/F09 del nivel
completo explora específicamente Specimen y DiagnosticReport.

## Tareas de la sesión

Realice las tareas del protocolo asignado, en orden y con la menor ayuda
posible:

| Perfil R | Énfasis | Perfil FHIR | Énfasis |
|---|---|---|---|
| R01 | Preparación y biblioteca correcta. | F01 | Alcance y capas de validación. |
| R02 | Vigilancia y unidad del indicador. | F02 | Mapas y cardinalidades. |
| R03 | Procedencia, claves y precisión. | F03 | Tipos, elecciones y casos negativos. |
| R04 | Construcción propia y errores. | F04 | Referencias e integridad del grafo. |
| R05 | Diseñar y reutilizar vistas. | F05 | Bindings y coherencia de Coding. |
| R06 | Conteos y relaciones de alergias. | F06 | Proyección y pérdidas de información. |
| R07 | Repetición y recuperación. | F07 | Plan de validación de perfiles. |
| R08 | Utilidad y cierre. | F08 | Repetición y conclusión delimitada. |
| R09 | Laboratorio analítico. | F09 | Auditoría semántica de laboratorio. |

Las tareas 01–08 son obligatorias; 09 también lo es en alcance siete.
Realice laboratorio antes del cierre. Orden R: 01–06, 09 si corresponde, 07, 08;
orden FHIR: 01–07, 09 si corresponde, 08. La tarea F07 exige un plan; ejecutar
un servidor es una ampliación separada y no es necesario para completar el núcleo.

Los protocolos [Perfil R](PROTOCOLO-PERFIL-R.md) y [Perfil FHIR](PROTOCOLO-PERFIL-FHIR.md)
describen pasos, evidencia y preguntas de cada tarea. Los datos y salidas de
la sesión permanecen locales hasta que participante y mantenedor acuerden qué
compartir.

### Laboratorio R09/F09 según el alcance acordado

Solo en nivel completo: abra `examples/laboratorio-r4.R` desde la instalación
aislada y ejecute el ejemplo siguiendo el protocolo. Usa datos ficticios para
crear un Patient, un Specimen, dos Observation y un DiagnosticReport. Revise
que `result[].reference` y `specimen[].reference` apunten a los recursos
esperados y compare las tablas generadas por V8 y DuckDB. Si alguna parte no
puede ejecutarse, registre el motivo; no la cuente como aprobada.

La validación de perfiles base R4 en HAPI es evidencia técnica independiente.
La sesión local no valida perfiles clínicos o nacionales, terminologías
externas, un servidor propio ni la idoneidad clínica de los datos.

## Registrar observaciones y cerrar una sesión

Durante cada tarea, la persona observadora registra:

- estado, criterios contrastados y comprensión correcta/parcial/incorrecta;
- tiempo activo separado de esperas y pasos con duda o bloqueo;
- cada pista, ayuda o consulta al anexo; documentación consultada por iniciativa propia;
- respuestas propias, evidencia y repetición manual por tarea; facilidad 1–5 opcional;
- identificador de incidencia, gravedad, evidencia y si necesita repetición.

No es necesario exigir tiempos idénticos ni que una persona memorice comandos.
Interesa saber si entiende los resultados, encuentra la documentación y puede
repetir el flujo. Si hubo ayuda, registre esa tarea como asistida. Para
documentar autonomía, acuerde una repetición sin ayuda en una carpeta nueva y
conserve los dos intentos.

Antes de terminar:

1. Complete las fichas del perfil en `FORMULARIO-PILOTO.html`; no marque como
   completa una tarea solo porque pasó el control automático.
2. Registre los obstáculos en `experiencia-usuario.txt` o en la ficha e incluya
   los pasos mínimos para reproducirlos.
3. Exporte el JSON y, si sirve para la revisión, CSV e informe de texto. El
   almacenamiento local es auxiliar; la exportación conserva la evidencia y el formulario no envía resultados.
4. Revise cada archivo antes de compartirlo. Las rutas pueden revelar nombres
   de usuario o estructura local. Elimine nombres, credenciales y datos de
   pacientes; este piloto no debe contener datos personales ni clínicos.
5. Revise con el participante las tareas incompletas y las incidencias.
   Incidencias críticas o altas abiertas impiden un cierre favorable; defina
   responsable, siguiente paso y nueva prueba.

El cierre requiere una decisión humana acordada entre participante y
mantenedor. El formulario puede mostrar un resumen, pero no cambia
`evaluacion_externa = pendiente` en los informes técnicos ni convierte una
sesión asistida en evaluación independiente.

## Archivos generados y qué compartir

El directorio de sesión contiene, entre otros:

| Ruta | Contenido |
|---|---|
| `SESION.json` | Perfil técnico, identidad del candidato, código de salida y estado de evaluación externa. |
| `piloto/aceptacion.json` y `piloto/aceptacion.csv` | Resultado estructurado y resumen de los controles automáticos. |
| `piloto/sessionInfo.txt` | Versiones de R y paquetes usados; puede mostrar rutas del sistema. |
| `piloto/experiencia-usuario.txt` | Espacio local para observaciones de uso. |
| `piloto/r4/` | recursos-r4.ndjson, recursos-r4.json y resumen.json del control; guarde por separado las vistas y tablas de las tareas humanas. |

Comparte únicamente los archivos acordados después de revisarlos y
desidentificarlos. No publiques la ficha completa en un issue público si
contiene rutas, nombres o información interna. El kit no tiene un canal de
envío automático: el mantenedor y el participante acuerdan el canal de entrega
antes de comenzar.

## Formulario local

`FORMULARIO-PILOTO.html` funciona sin conexión y ofrece Español/English.
El idioma cambia consignas y rótulos; no traduce las respuestas introducidas
ni cambia estados, identidad, alcance o evidencia. Los documentos tienen pares
`.md`/`.en.md`, con las mismas tareas y criterios. Mantiene fichas separadas para
los perfiles R y FHIR y permite exportar JSON, CSV e informe de texto. El
almacenamiento local del navegador puede no estar disponible al abrir un
archivo `file://`; exporte el JSON antes de cerrar el navegador o cambiar de
equipo. Si importa un JSON, compruebe que corresponde al protocolo y al
candidato de esta sesión. Importar sustituye las fichas actualmente abiertas.

La exportación CSV muestra rótulos en el idioma seleccionado y conserva
columnas `*_codigo` para comparar estados entre idiomas. JSON conserva las
respuestas completas y todas las incidencias al retomar una ficha; los textos
introducidos no se traducen automáticamente.

Abra `FORMULARIO-PILOTO.html` del ZIP extraído. `formulario.template.html` es
un archivo fuente del desarrollo y contiene marcadores que deben procesarse;
no es el formulario ejecutable para participantes.

El formulario sirve para registrar tareas, incidencias, ayudas y decisiones;
no instala el paquete, ejecuta scripts, valida FHIR ni transmite los archivos.
El aviso preparado por el formulario debe revisarse y enviarse manualmente si
se acordó hacerlo.

## Resolución de problemas

| Síntoma | Qué hacer |
|---|---|
| El lanzador dice que falta una dependencia | Instale el paquete indicado con `install.packages()` y vuelva a ejecutar en una carpeta nueva. |
| DuckDB no está disponible o su versión es antigua | Use el nivel básico o instale R ≥ 4.2 y `duckdb` ≥ 1.3.0; registre cualquier limitación del equipo. |
| La carpeta de sesión ya existe | No la borre ni sobrescriba. Use una ruta nueva para el nuevo intento. |
| El checksum del candidato no coincide | Deténgase. No instale el archivo; solicite el ZIP correcto al mantenedor. |
| `abrir_sesion()` detecta otra copia de fhirviews | Reinicie R, ejecute `source("INICIAR.R")` y vuelva a abrir la misma sesión. |
| Un control falla o genera advertencias | Conserve la salida original, anote el entorno y los pasos; no edite el informe. Consulte al mantenedor. |
| El navegador no conserva la ficha | Exporte JSON antes de cerrar; revise también si importará otra ficha, pues reemplaza las abiertas. |
| DuckDB no puede descargar una extensión | Registre el error de red; no lo interprete como discrepancia semántica entre motores. |

Si el problema continúa, anote sistema operativo, versión de R, perfil,
comando, mensaje completo y resultado esperado. Quite información privada antes
de compartir registros.

## Contenido del kit y límites

- `EVALUACION-PILOTO.md`: diseño de evaluación, criterios y análisis de la ronda.
- `PROTOCOLO-PERFIL-R.md` y `PROTOCOLO-PERFIL-FHIR.md`: tareas detalladas.
- Archivos `.en.md` y `tareas.en.json`: contenido equivalente en inglés.
- `PILOTO-R4.md`: alcance, preparación e interpretación del piloto.
- `ANEXO-OBSERVADOR.md`: resultados de contraste, para consultar después del primer intento.
- `FORMULARIO-PILOTO.html` y `tareas.json`: registro local y tareas asociadas.
- `INICIAR.R` y `PROBAR-CANDIDATO.R`: lanzador y control técnico instalado.
- `CANDIDATO.json`, `MANIFIESTO-KIT.json` y `SHA256SUMS`: identidad e integridad.
- `LICENSE.md` y el archivo fuente en `paquete/`: licencias y candidato entregado.

El archivo del kit no tiene un DOI propio. El DOI Zenodo de `0.5.0.9000`
identifica otro archivo y no se transfiere a `0.5.0.9002`. La publicación de
este kit tampoco equivale a aceptación de CRAN, evaluación clínica o
aprobación de perfiles nacionales.

## Cambios de ronda y construcción del kit

El protocolo 2.1 cambia tareas y criterios respecto de 2.0. Conserve las fichas
anteriores con su ZIP y hash; no se importan en esta revisión. Para sesiones
ya iniciadas, mantenga el protocolo acordado o programe una ronda nueva.

El manifiesto identifica la fuente del kit, sus hashes y el candidato intacto.
Si `fuente_kit_estado` indica `archivos_de_trabajo_sobre_commit`, el commit es
la base de edición; los materiales exactos son los archivos hashados del ZIP.
No se afirma que las modificaciones ya estén publicadas en ese commit.
La reconstrucción desde esos materiales debe producir el mismo ZIP y rechaza
fuentes alteradas. El kit nunca incorpora fichas completadas ni sesiones locales.
