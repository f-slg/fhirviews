# Changelog

## fhirviews (development version)

### Autenticación SMART on FHIR

- [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md)
  tiene un nuevo argumento `autenticacion` para servidores protegidos
  con SMART on FHIR / OAuth2 (`token` sigue funcionando igual):
  - [`fhir_auth_cliente()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md):
    *client credentials* con secreto (HTTP Basic o en el cuerpo, según
    lo que admita el servidor).
  - [`fhir_auth_backend()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md):
    SMART Backend Services, con un JWT firmado (RS384 o ES384) a partir
    de una clave privada y su `kid`. Requiere los paquetes jose y
    openssl.
  - [`fhir_auth_interactiva()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md):
    *authorization code* con PKCE y lanzamiento *standalone* (`aud`),
    con inicio de sesión en el navegador.
- [`fhir_smart_configuracion()`](https://f-slg.github.io/fhirviews/reference/fhir_smart_configuracion.md)
  descubre el *token endpoint* y el *authorization endpoint* en
  `.well-known/smart-configuration` o, como respaldo, en las extensiones
  `oauth-uris` del `CapabilityStatement`.
- El token se pide en la primera petición, se renueva solo al expirar (y
  una vez más si el servidor lo rechaza con 401), solo se envía al
  servidor de la conexión y nunca se imprime, igual que el secreto y la
  clave.

### Exportación masiva (FHIR Bulk Data)

- [`fhir_exportar()`](https://f-slg.github.io/fhirviews/reference/fhir_exportar.md)
  implementa el cliente de [FHIR Bulk Data
  Access](https://hl7.org/fhir/uv/bulkdata/): inicia `$export` a nivel
  de sistema, de pacientes o de un `Group` (con `_type`, `_since` y
  `_typeFilter`), consulta el estado respetando `Retry-After` y
  mostrando `X-Progress`, y descarga los archivos NDJSON del manifiesto
  (con el token solo si `requiresAccessToken` lo pide y solo al mismo
  servidor). Devuelve las rutas por tipo de recurso, listas para
  [`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md).
  Los `OperationOutcome` del manifiesto se descargan y se avisan.
- [`fhir_exportar_estado()`](https://f-slg.github.io/fhirviews/reference/fhir_exportar.md)
  y
  [`fhir_exportar_cancelar()`](https://f-slg.github.io/fhirviews/reference/fhir_exportar.md)
  para el modo asíncrono (`esperar = FALSE`).

### Motor DuckDB (experimental)

- Prototipo de un segundo motor de vistas:
  [`vista_sql()`](https://f-slg.github.io/fhirviews/reference/vista_sql.md)
  traduce un `ViewDefinition` a SQL de DuckDB y
  [`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md)
  lo ejecuta directamente sobre archivos NDJSON o Parquet, sin cargar
  los recursos en R. Admite un subconjunto de FHIRPath y pasa las 133
  pruebas shareable del banco oficial
  (`vista_conformidad(motor = "duckdb")`).

## fhirviews 0.1.0

- Primera versión.

### Correcciones de la auditoría técnica

- [`fhir_buscar()`](https://f-slg.github.io/fhirviews/reference/fhir_buscar.md)
  y
  [`fhir_everything()`](https://f-slg.github.io/fhirviews/reference/fhir_everything.md)
  dejan de paginar (con un aviso) si el servidor repite un enlace
  [`next`](https://rdrr.io/r/base/Control.html), en lugar de entrar en
  un bucle infinito.
- [`fhir_crear()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md)
  envía los Bundle `transaction` y `batch` a la base del servidor
  (`POST [base]`), que los procesa, en vez de guardarlos como un recurso
  Bundle.
- [`vista_validar()`](https://f-slg.github.io/fhirviews/reference/vista_validar.md)
  rechaza `column`, `select` y `unionAll` vacíos (antes `unionAll: []`
  daba un error poco claro) y las constantes con nombres reservados
  (`resource`, `rowIndex`…), que quedaban ocultas.
- Las vistas sobre recursos de varios tipos leídos de JSON o NDJSON ya
  no vuelven a convertirlos a JSON: unas 9 veces más rápidas.
- `type` ya no trunca ni convierte en `NA` en silencio: si un valor no
  es compatible, se avisa y se conserva. Las columnas sin `type` y sin
  valores toman el tipo del modelo de FHIR R4, de modo que la misma
  vista da siempre los mismos tipos.
- [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md)
  avisa si un token viajaría sin cifrar por http.
- [`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md)
  informa claramente si un archivo no existe y acepta un vector con
  varias rutas de archivo.

### Cliente FHIR

- [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md),
  [`fhir_buscar()`](https://f-slg.github.io/fhirviews/reference/fhir_buscar.md)
  (paginación automática por los enlaces
  [`next`](https://rdrr.io/r/base/Control.html)),
  [`fhir_leer()`](https://f-slg.github.io/fhirviews/reference/fhir_leer.md),
  [`fhir_crear()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md),
  [`fhir_actualizar()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md),
  [`fhir_borrar()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md),
  [`fhir_everything()`](https://f-slg.github.io/fhirviews/reference/fhir_everything.md),
  [`fhir_validar()`](https://f-slg.github.io/fhirviews/reference/fhir_validar.md),
  [`fhir_capacidades()`](https://f-slg.github.io/fhirviews/reference/fhir_capacidades.md),
  [`fhir_peticion()`](https://f-slg.github.io/fhirviews/reference/fhir_peticion.md),
  [`fhir_ejecutar_texto()`](https://f-slg.github.io/fhirviews/reference/fhir_ejecutar_texto.md)
  y
  [`fhir_disponible()`](https://f-slg.github.io/fhirviews/reference/fhir_disponible.md),
  con httr2.
- `application/fhir+json`, token *bearer* (solo se envía al servidor de
  la conexión), reintentos ante 429/503 y errores legibles a partir del
  `OperationOutcome`, con una clase por código HTTP.
- [`fhir_peticion()`](https://f-slg.github.io/fhirviews/reference/fhir_peticion.md)
  devuelve un objeto `fhir_respuesta` que se imprime con el estado y el
  JSON con sangría, como Postman.

### Vistas SQL on FHIR

- [`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
  aplica un `ViewDefinition` a recursos (listas, Bundles, JSON, NDJSON o
  archivos `.ndjson.gz`) y devuelve un `data.frame`. Admite `select`
  anidados, `column` (`type`, `collection`), `forEach`, `forEachOrNull`,
  `repeat`, `unionAll`, `where`, `constant` y `%rowIndex`. Evalúa por
  lotes, con una llamada a FHIRPath por expresión y nivel.
- [`vista_validar()`](https://f-slg.github.io/fhirviews/reference/vista_validar.md),
  [`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md),
  [`vista_crear()`](https://f-slg.github.io/fhirviews/reference/vista_crear.md),
  [`vista_json()`](https://f-slg.github.io/fhirviews/reference/vista_json.md),
  [`vista_fhirpath()`](https://f-slg.github.io/fhirviews/reference/vista_fhirpath.md),
  [`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md),
  [`fhir_tabla()`](https://f-slg.github.io/fhirviews/reference/fhir_tabla.md)
  y
  [`fhir_vista()`](https://f-slg.github.io/fhirviews/reference/fhir_vista.md)
  (descargar del servidor y aplicar la vista en un paso).
- FHIRPath con fhirpath.js 5.2.1 (HL7/fhirpath.js) en V8, con
  `getResourceKey()` y `getReferenceKey()`. La capa de FHIRPath está
  separada
  ([`fhirviews_motor()`](https://f-slg.github.io/fhirviews/reference/fhirviews_motor.md))
  para poder sustituirla por un motor en R.
- [`vista_conformidad()`](https://f-slg.github.io/fhirviews/reference/vista_conformidad.md)
  ejecuta el banco oficial de pruebas de SQL on FHIR (incluido; o el más
  reciente con `descargar = TRUE`) y genera el informe en el formato
  oficial. Pasan las 133 pruebas *shareable* y 7 de las 11
  experimentales.
- [`vista_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_duckdb.md)
  guarda vistas como tablas de DuckDB (o de otra conexión DBI) para
  consultarlas con SQL.

### RStudio

- El servidor se registra en el panel *Connections* (tipos de recurso,
  columnas, vista previa) y aparece en el diálogo *New Connection*.
- Addins *Ejecutar petición FHIR* y *Ejecutar ViewDefinition*.

### Datos y documentación

- Caso clínico ficticio del taller aprende-fhir
  (`inst/extdata/caso_clinico.ndjson`) y casos ficticios de dengue 2025
  por cantón (`inst/extdata/dengue_2025.ndjson.gz`).
- Viñetas *Primeros pasos con fhirviews*, *ViewDefinition en detalle* y
  *Tasas por cantón con FHIR y pobecu*.
