# fhirviews 0.2.0

Esta versión prepara fhirviews para servidores y volúmenes reales:
autenticación SMART on FHIR, exportación masiva con `$export` y un segundo
motor de vistas sobre DuckDB, entre 16 y 37 veces más rápido que el motor V8
(un millón de pacientes en unos 5,5 segundos). No hay cambios incompatibles.

## Autenticación SMART on FHIR

* `fhir_conectar()` tiene un nuevo argumento `autenticacion` para servidores
  protegidos con SMART on FHIR / OAuth2 (`token` sigue funcionando igual):
  * `fhir_auth_cliente()`: *client credentials* con secreto (HTTP Basic o en
    el cuerpo, según lo que admita el servidor).
  * `fhir_auth_backend()`: SMART Backend Services, con un JWT firmado
    (RS384 o ES384) a partir de una clave privada y su `kid`. Requiere los
    paquetes jose y openssl.
  * `fhir_auth_interactiva()`: *authorization code* con PKCE y lanzamiento
    *standalone* (`aud`), con inicio de sesión en el navegador.
* `fhir_smart_configuracion()` descubre el *token endpoint* y el
  *authorization endpoint* en `.well-known/smart-configuration` o, como
  respaldo, en las extensiones `oauth-uris` del `CapabilityStatement`.
* El token se pide en la primera petición, se renueva solo al expirar (y una
  vez más si el servidor lo rechaza con 401), solo se envía al servidor de la
  conexión y nunca se imprime, igual que el secreto y la clave.

## Exportación masiva (FHIR Bulk Data)

* `fhir_exportar()` implementa el cliente de
  [FHIR Bulk Data Access](https://hl7.org/fhir/uv/bulkdata/): inicia `$export`
  a nivel de sistema, de pacientes o de un `Group` (con `_type`, `_since` y
  `_typeFilter`), consulta el estado respetando `Retry-After` y mostrando
  `X-Progress`, y descarga los archivos NDJSON del manifiesto (con el token
  solo si `requiresAccessToken` lo pide y solo al mismo servidor). Devuelve
  las rutas por tipo de recurso, listas para `vista_ejecutar()`. Los
  `OperationOutcome` del manifiesto se descargan y se avisan.
* `fhir_exportar_estado()` y `fhir_exportar_cancelar()` para el modo
  asíncrono (`esperar = FALSE`).

## Motor DuckDB (experimental)

* Segundo motor de vistas: `vista_sql()` traduce un `ViewDefinition` a una
  consulta SQL de DuckDB y `vista_ejecutar_duckdb()` la ejecuta directamente
  sobre archivos NDJSON (también comprimidos o con comodines) o Parquet, sin
  cargar los recursos en R; con `tabla`, guarda el resultado en una base
  DuckDB en lugar de traerlo a R. Requiere duckdb 1.3.0 o posterior.
* Admite un subconjunto de FHIRPath: navegación, elementos de elección
  (`value`, `effective`, `onset`...), `where()`, `exists()`, `empty()`,
  `first()`, `join()`, `ofType()`, `extension()`, `getResourceKey()`,
  `getReferenceKey()`, comparaciones, lógica y constantes. Lo que no puede
  traducir con certeza da un error de clase `fhirviews_error_sql`, nunca un
  resultado aproximado.
* Pasa las 133 pruebas *shareable* del banco oficial
  (`vista_conformidad(motor = "duckdb")`) y una prueba diferencial exige que
  dé las mismas tablas (valores y tipos) que `vista_ejecutar()` con las vistas
  de todas las viñetas.
* Rendimiento de punta a punta desde NDJSON: 250 000 pacientes en 1,7 s
  (62 s con el motor V8) y un millón en 5,5 s.

## Documentación

* Nueva viñeta *Servidores reales y grandes volúmenes*: autenticación SMART
  paso a paso, `$export` (con una exportación real contra el servidor de
  referencia de SMART Health IT) y el motor DuckDB.
* README con los nuevos casos de uso, la comparación de rendimiento entre
  motores y la comparación con pathling y fhircrackr; artículo *Cómo funciona
  por dentro* ampliado con las tres piezas nuevas.

## Pruebas

* La autenticación se verificó con un servidor SMART local que comprueba la
  firma de cada JWT con una implementación independiente (Python y PyJWT),
  incluidos la renovación del token, el reintento tras un 401 y el rechazo
  de credenciales o claves incorrectas.
* La exportación se verificó contra https://bulk-data.smarthealthit.org.
* El servidor simulado de las pruebas decodifica las URL, que según la versión
  de R y de curl llegan con `$` codificado como `%24`.

# fhirviews 0.1.0

* Primera versión.

## Correcciones de la auditoría técnica

* `fhir_buscar()` y `fhir_everything()` dejan de paginar (con un aviso) si el
  servidor repite un enlace `next`, en lugar de entrar en un bucle infinito.
* `fhir_crear()` envía los Bundle `transaction` y `batch` a la base del
  servidor (`POST [base]`), que los procesa, en vez de guardarlos como un
  recurso Bundle.
* `vista_validar()` rechaza `column`, `select` y `unionAll` vacíos (antes
  `unionAll: []` daba un error poco claro) y las constantes con nombres
  reservados (`resource`, `rowIndex`...), que quedaban ocultas.
* Las vistas sobre recursos de varios tipos leídos de JSON o NDJSON ya no
  vuelven a convertirlos a JSON: unas 9 veces más rápidas.
* `type` ya no trunca ni convierte en `NA` en silencio: si un valor no es
  compatible, se avisa y se conserva. Las columnas sin `type` y sin valores
  toman el tipo del modelo de FHIR R4, de modo que la misma vista da siempre
  los mismos tipos.
* `fhir_conectar()` avisa si un token viajaría sin cifrar por http.
* `fhir_recursos()` informa claramente si un archivo no existe y acepta un
  vector con varias rutas de archivo.

## Cliente FHIR

* `fhir_conectar()`, `fhir_buscar()` (paginación automática por los enlaces
  `next`), `fhir_leer()`, `fhir_crear()`, `fhir_actualizar()`,
  `fhir_borrar()`, `fhir_everything()`, `fhir_validar()`,
  `fhir_capacidades()`, `fhir_peticion()`, `fhir_ejecutar_texto()` y
  `fhir_disponible()`, con httr2.
* `application/fhir+json`, token *bearer* (solo se envía al servidor de la
  conexión), reintentos ante 429/503 y errores legibles a partir del
  `OperationOutcome`, con una clase por código HTTP.
* `fhir_peticion()` devuelve un objeto `fhir_respuesta` que se imprime con el
  estado y el JSON con sangría, como Postman.

## Vistas SQL on FHIR

* `vista_ejecutar()` aplica un `ViewDefinition` a recursos (listas, Bundles,
  JSON, NDJSON o archivos `.ndjson.gz`) y devuelve un `data.frame`. Admite
  `select` anidados, `column` (`type`, `collection`), `forEach`,
  `forEachOrNull`, `repeat`, `unionAll`, `where`, `constant` y `%rowIndex`.
  Evalúa por lotes, con una llamada a FHIRPath por expresión y nivel.
* `vista_validar()`, `vista_leer()`, `vista_crear()`, `vista_json()`,
  `vista_fhirpath()`, `fhir_recursos()`, `fhir_tabla()` y `fhir_vista()`
  (descargar del servidor y aplicar la vista en un paso).
* FHIRPath con fhirpath.js 5.2.1 (HL7/fhirpath.js) en V8, con
  `getResourceKey()` y `getReferenceKey()`. La capa de FHIRPath está separada
  (`fhirviews_motor()`) para poder sustituirla por un motor en R.
* `vista_conformidad()` ejecuta el banco oficial de pruebas de SQL on FHIR
  (incluido; o el más reciente con `descargar = TRUE`) y genera el informe
  en el formato oficial. Pasan las 133 pruebas *shareable* y 7 de las 11
  experimentales.
* `vista_duckdb()` guarda vistas como tablas de DuckDB (o de otra conexión
  DBI) para consultarlas con SQL.

## RStudio

* El servidor se registra en el panel *Connections* (tipos de recurso,
  columnas, vista previa) y aparece en el diálogo *New Connection*.
* Addins *Ejecutar petición FHIR* y *Ejecutar ViewDefinition*.

## Datos y documentación

* Caso clínico ficticio del taller aprende-fhir
  (`inst/extdata/caso_clinico.ndjson`) y casos ficticios de dengue 2025 por
  cantón (`inst/extdata/dengue_2025.ndjson.gz`).
* Viñetas *Primeros pasos con fhirviews*, *ViewDefinition en detalle* y
  *Tasas por cantón con FHIR y pobecu*.
