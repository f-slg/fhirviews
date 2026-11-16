# Verificacion R4 y componente Rust 0.5.0.9002

Codigo comprobado: **8d6a122356d9a23f6d71e690ee542108fa15ce8a**.
La [PR 26](https://github.com/f-slg/fhirviews/pull/26) incorpora siete
constructores R4, colecciones de referencias y la API de una CLI externa
opcional. Los commits posteriores de documentacion no cambian este codigo.

## Archivo fuente instalado

Se exporto el commit con `git archive`, sin archivos de trabajo no versionados,
se construyeron las vinetas y se instalo el mismo archivo en una biblioteca
R nueva con bytecode:

- Archivo: `fhirviews_0.5.0.9002.tar.gz`, 1.209.166 bytes.
- SHA-256: `305e5db0d637aecfbea612201abd4efc1995e6769a7026d29be1fc52308e8833`.
- `R CMD check --as-cran --no-manual`: **0 errores, 0 advertencias, 1 nota**.
- Nota: `Version contains large components (0.5.0.9002)`, por la numeracion
  de desarrollo. No se presenta como una entrega estable CRAN.
- Testthat instalado: **1.626 comprobaciones aprobadas, 19 omisiones**.
  El [registro](testthat-instalado.Rout) identifica las omisiones; los grupos
  de servidor se ejecutaron aparte con HAPI.
- El paquete incluye el ejemplo de laboratorio y la API del componente.
  No incluye Cargo, Rust, sus fuentes o binarios, ni los instala.

Durante el check se selecciono explicitamente el ejecutable externo.
R sigue siendo la ruta predeterminada y ofrece respaldo con aviso.
Los hashes identifican los archivos comprobados; construir en otra maquina
puede producir otros bytes de R o Cargo.

## CI y conformidad

[CI.json](CI.json) registra **diez comprobaciones aprobadas** del commit:
cinco configuraciones R, Rust en Windows/macOS/Linux, HAPI y SQL DBI.
[FUENTES-CI.json](FUENTES-CI.json) conserva los identificadores y SHA-256
de cuatro ZIP, cotejados con GitHub antes de extraer los informes seleccionados.
Se conservan sus bytes originales, incluidos CRLF y espacios de los registros;
los atributos Git impiden normalizarlos y alterar sus SHA-256.

Cada plataforma Rust ejecuto **286 comprobaciones dirigidas** sin fallos,
avisos ni omisiones: siete tipos, JSON/NDJSON, mensajes completos, primer
error, colecciones, respaldo, contrato, rutas con espacios y SQL parametrizado.
Tambien ejecuto los **587 controles diferenciales** anteriores: 251 generales
y 336 comparaciones de 168 escenarios de referencias. El nucleo conserva
**12 pruebas nativas**, siete del validador y cinco del protocolo CLI.

HAPI comprobo **164 aserciones**, incluidas **34 del nuevo grupo** de
Specimen/DiagnosticReport: perfiles base, persistencia, lectura, referencias,
tablas V8/DuckDB y casos invalidos. Se permiten dos omisiones expresas:
lectura del servidor publico y ValueSet en linea no ofrecido por el contenedor.
La politica rechaza otras omisiones. El ensayo local con el componente
activado tambien antes de guardar tuvo una asercion adicional: 165 en total.

El archivo instalado paso **144/144** casos del banco incluido con V8 y con
DuckDB. Se conservan ambos informes JSON. Ese resultado acredita el banco
fijado; los perfiles propios, invariantes y terminologia externa necesitan
su entorno. No es cobertura completa de FHIR/FHIRPath ni certificacion clinica.

## Rendimiento de la API actual

El [manifiesto](rendimiento/MANIFIESTO.json),
[tiempos](rendimiento/tiempos.csv) y [resumen](rendimiento/resumen.csv)
corresponden a **126 muestras**: siete mapas ficticios, 300 y 3.000 filas,
tres metodos y tres repeticiones. Orden aleatorio, semilla 20261115.
Cada resultado coincide exactamente con el objeto R y su fuente JSON.

Se comparan R publico, un plan R preparado experimental y la API publica con
componente Rust. El plan preparado procede del laboratorio y no es una API
instalada. R conserva conversiones, construccion y serializacion.
Con 3.000 filas el componente fue 2,19-3,38 veces mas rapido que R publico
y 1,21-2,91 frente al plan R. Con 300 Patient, R publico gano: 0,341 s frente
a 0,437 s; el plan R tardo 0,166 s. El plan R gano tambien en otros lotes
pequenos. La seleccion sigue siendo explicita, sin umbral universal.

Se registran aparte 0,692 s de preparacion del plan R y 0,437 s de primera
llamada al componente con tres Patient. Cada lote incluye comprobacion del
ejecutable, inicio del proceso, transporte y lectura del plan. Se excluyen
compilacion, instalacion, filas/mapas, comparacion y GC previo. Las muestras
muestran variacion; tres repeticiones no establecen resultados generales.
No se ejecutaron otras compilaciones ni pruebas locales durante la medicion.

Entorno: Ubuntu 26.04.1, Intel i7-10750H, 12 procesadores logicos, R 4.5.2,
V8 8.2.0 y rustc/cargo 1.75.0. No se midieron memoria de esta API, velocidad
en Windows/macOS, consultas SQL on FHIR, perfiles clinicos ni Helios.
Las medidas de 0.5.0.9000 conservan su manifiesto historico propio.

Para reproducir desde una copia limpia del commit, construye e instala el
paquete con bytecode y compila la CLI con `--release --locked --jobs 2`.
Desde la raiz, con una salida nueva y sin otras mediciones simultaneas:

```sh
FHIRVIEWS_RUST_LIB=/ruta/biblioteca-R Rscript --vanilla \
  data-raw/medir-componente-rust.R \
  componentes/rust/target/release/fhirviews-rust-validator \
  /ruta/resultados-nuevos /ruta/fhirviews_0.5.0.9002.tar.gz
```

## Limites de entrega

La CLI `fhirviews-r4-validator/1` revisa estructuras tipificadas por R; no
enlaza a su ABI ni es un validador FHIR general. La distribución de binarios se completó después de este ensayo; véase
[distribución actual](../distribucion-rust/README.md). Otras cargas, memoria
y posibles mejoras del coste fijo requieren trabajo adicional. R mantiene la consulta y el lote completo en memoria.

Al realizar este ensayo, el kit disponible era **0.5.0.9001**. El
[kit actual](../piloto-r4-v2/LEEME.md) entrega el mismo candidato **0.5.0.9002**
y el [protocolo bilingüe 2.1](../piloto-r4-v2/EVALUACION-PILOTO.md), con
laboratorio obligatorio para evaluar siete tipos. La actualización de los
materiales no modifica las mediciones históricas ni acredita participación
humana; las fichas distribuidas comienzan pendientes. 0.5.0.9002 no tiene DOI de versión.
El DOI de 0.5.0.9000 conserva su identidad.
