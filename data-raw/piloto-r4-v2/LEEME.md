# Guía de participación en el piloto externo R4

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

Hay dos perfiles de competencia y dos niveles técnicos; son decisiones
independientes:

| Elección | Qué significa |
|---|---|
| Perfil **R** | Analista, investigador o epidemiólogo; realiza las tareas R01–R09. |
| Perfil **FHIR** | Persona con experiencia en interoperabilidad o informática sanitaria; realiza F01–F09. |
| Nivel **básico** | Ejecuta los controles instalados y las tareas manuales. No instala ni evalúa DuckDB. |
| Nivel **completo** | Añade DBI/DuckDB a los controles y permite evaluar la tarea opcional R09/F09 de laboratorio. |

Acuerden antes de la sesión el perfil, el nivel, el identificador de
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

En el nivel completo se puede realizar además R09/F09, la tarea opcional de
laboratorio. No es obligatorio para completar los cinco controles técnicos.
Registre como `no_evaluada` y explique el motivo si no se ejecuta.

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

| Perfil R | Perfil FHIR | Tema |
|---|---|---|
| R01 | F01 | Identificar e instalar el candidato. |
| R02 | F02 | Leer los cinco controles y entender su alcance. |
| R03 | F03 | Contrastar recursos R4, tablas y referencias. |
| R04 | F04 | Explicar escala decimal y elecciones de fecha/dosis. |
| R05 | F05 | Crear y modificar un `ViewDefinition`. |
| R06 | F06 | Leer alergias y distinguir registros de filas. |
| R07 | F07 | Repetir en una carpeta nueva conservando ambos intentos. |
| R08 | F08 | Revisar hallazgos y registrar la decisión humana. |
| R09 (opcional) | F09 (opcional) | Construir Specimen y DiagnosticReport desde SQL. |

Los protocolos [Perfil R](PROTOCOLO-PERFIL-R.md) y [Perfil FHIR](PROTOCOLO-PERFIL-FHIR.md)
describen pasos, evidencia y preguntas de cada tarea. Los datos y salidas de
la sesión permanecen locales hasta que participante y mantenedor acuerden qué
compartir.

### Tarea opcional de laboratorio R09/F09

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

- si se completó, quedó incompleta o no se evaluó;
- el tiempo aproximado y los pasos donde hubo duda o bloqueo;
- cada pista, ayuda o consulta al anexo;
- qué esperaba la persona y qué resultado observó;
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
   formulario no guarda ni envía la información de forma automática.
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
| `piloto/r4/` | Recursos NDJSON, tablas, definiciones y salidas de la prueba R4. |

Comparte únicamente los archivos acordados después de revisarlos y
desidentificarlos. No publiques la ficha completa en un issue público si
contiene rutas, nombres o información interna. El kit no tiene un canal de
envío automático: el mantenedor y el participante acuerdan el canal de entrega
antes de comenzar.

## Formulario local

`FORMULARIO-PILOTO.html` funciona sin conexión. Mantiene fichas separadas para
los perfiles R y FHIR y permite exportar JSON, CSV e informe de texto. El
almacenamiento local del navegador puede no estar disponible al abrir un
archivo `file://`; exporte el JSON antes de cerrar el navegador o cambiar de
equipo. Si importa un JSON, compruebe que corresponde al protocolo y al
candidato de esta sesión. Importar sustituye las fichas actualmente abiertas.

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

- `PROTOCOLO-PERFIL-R.md` y `PROTOCOLO-PERFIL-FHIR.md`: tareas detalladas.
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
