# Componente Rust opcional

Este ejecutable valida estructuras construidas y tipificadas por el paquete R.
R conserva la conversion de columnas, los decimales, el orden de construccion,
la serializacion y los diagnosticos de datos. El componente no evalua FHIRPath,
no valida perfiles clinicos ni convierte versiones FHIR.

## Compilar y utilizar

Requiere Cargo y rustc >= 1.75, instalados por el usuario. Desde la raiz del
repositorio:

```sh
cargo build --release --locked --jobs 2 --manifest-path componentes/rust/Cargo.toml
cargo test --locked --jobs 2 --manifest-path componentes/rust/Cargo.toml
componentes/rust/target/release/fhirviews-rust-validator --capabilities
```

En Windows el ejecutable termina en `.exe`. No hay enlace a la ABI de R ni
dependencia de Rtools para invocar el ejecutable; compilar Rust requiere el
toolchain y enlazador correspondientes a su plataforma. La distribucion del
ejecutable es independiente de la instalacion R. La carpeta `componentes/`
queda fuera del archivo fuente del paquete mediante `.Rbuildignore`.

```r
library(fhirviews)
componente <- fhir_componente_rust(
  "componentes/rust/target/release/fhirviews-rust-validator",
  fallback = FALSE, tiempo = 60L)
mapa <- fhir_mapa("Specimen", c(id = "id", status = "estado"))
datos <- data.frame(id = "s1", estado = "available")
recursos <- fhir_desde_tabla(datos, mapa, componente = componente)
stopifnot(identical(recursos, fhir_desde_tabla(datos, mapa)))

# Un recorrido SQL con colecciones de referencias y los dos motores de vistas:
source(system.file("examples", "laboratorio-r4.R", package = "fhirviews"))
laboratorio <- laboratorio_r4(componente = componente)
laboratorio$tablas$resultados
```

Sin `componente`, las funciones publicas validan en R. `fallback = TRUE`
permite el respaldo R con un aviso si el proceso no esta disponible, falla,
excede el tiempo o no cumple el contrato. `FALSE` convierte esos casos en
`fhirviews_error_componente`. Un rechazo de datos no es un fallo del proceso:
se revisan las filas hasta el rechazo con el validador R para conservar el
primer error y su mensaje completo, incluyendo ValueSet, fila y campo.

## Contrato de comunicacion

`--capabilities` emite un objeto JSON con componente, version de software,
`contrato = "fhirviews-r4-validator/1"`, `version_fhir = "4.0.1"` y
`alcance = "recursos-construidos-y-tipados-por-r"`.

La llamada de validacion recibe dos rutas locales: plan JSON y recursos
NDJSON. R prepara el plan desde `inst/schema/mapeo-r4.json` una vez por sesion,
y el componente lo carga y comprueba en cada proceso. El plan contiene:

- Contrato, version FHIR e identificador MD5 del archivo de metadatos. Este
  identificador detecta esquemas distintos; no autentica un ejecutable.
- Raices de los siete recursos admitidos y nombres de recursos R4 validos
  como destinos de referencia, incluidos tipos que R todavia no construye.
- Nodos con campos, cardinalidades, grupos de eleccion, referencias y bindings
  requeridos enumerables. Las fuentes terminologicas externas no se inventan.

La salida confirma contrato, version FHIR, identificador de esquema y un
`resultado` con `valido`, `recursos`, tiempos internos y `error` opcional. Un
rechazo devuelve codigo de proceso cero y la primera fila, campo, motivo y
ValueSet cuando corresponde. Un fallo de proceso devuelve codigo distinto
de cero. R rechaza conteos incompletos, filas fuera del lote y respuestas
incompatibles; no interpreta una respuesta ausente como un lote valido.

Los recursos no se reescriben ni se devuelven en el diagnostico. El lector
Rust consume una linea por vez y preserva los literales mediante
`serde_json::RawValue` y `arbitrary_precision`. La construccion R y la consulta
DBI siguen reuniendo el lote completo en memoria. La carpeta temporal R se
crea con permisos 0700 en sistemas POSIX y se elimina al terminar, tambien
ante errores. El componente no usa la red. El usuario debe seleccionar un
ejecutable de confianza, pues se ejecuta con los permisos de su proceso R.

## Pruebas y procedencia

El nucleo procede del laboratorio `data-raw/experimento-rust`, bajo la licencia
MIT del proyecto. La CLI de ese laboratorio depende ahora de esta biblioteca;
las mediciones historicas siguen ligadas a su commit original y no cambian.
`Cargo.lock` fija las dependencias transitivas. Este componente no enlaza ni
incorpora codigo de Helios.

La CI `.github/workflows/rust-experimento.yaml` compila el componente y
ejecuta pruebas nativas del nucleo y protocolo, pruebas de la API publica R,
JSON/NDJSON exactos, rutas con espacios, respaldo, diagnosticos y SQL DBI.
Contrasta los siete recursos en Windows, macOS y Linux. Ademas conserva los
controles diferenciales del laboratorio anterior. Los resultados reales de
cada ejecucion deben consultarse en sus artefactos; configurar la matriz no
equivale a haberla aprobado.

Los tiempos antiguos del laboratorio corresponden a 0.5.0.9000. La interfaz
actual introduce sus propias comprobaciones y transporte; sus tiempos deben
medirse por separado sobre un paquete instalado con bytecode.

Licencia del codigo del proyecto: [MIT](LICENSE). Las dependencias conservan
sus respectivas licencias; no se distribuyen sus fuentes ni binarios dentro
del paquete R. Una futura integracion nativa en el paquete exigiria revisar
vendoring, licencias y las [reglas de CRAN para Rust](https://cran.r-project.org/web/packages/using_rust.html).
