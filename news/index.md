# Changelog

## fhirviews (development version)

### Motor DuckDB

- El motor DuckDB
  ([`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md),
  [`vista_sql()`](https://f-slg.github.io/fhirviews/reference/vista_sql.md))
  traduce muchas más funciones de FHIRPath:
  [`union()`](https://rdrr.io/r/base/sets.html), `combine()`,
  [`intersect()`](https://rdrr.io/r/base/sets.html), `exclude()`,
  `isDistinct()`, `subsetOf()`, `supersetOf()`, `allTrue()`,
  `anyTrue()`, `allFalse()`, `anyFalse()`, `indexOf()`,
  `replaceMatches()`, [`split()`](https://rdrr.io/r/base/split.html),
  `toChars()`, `toBoolean()`, `convertsToInteger()`,
  `convertsToDecimal()`, `convertsToBoolean()`, `convertsToString()`,
  [`abs()`](https://rdrr.io/r/base/MathFun.html),
  [`ceiling()`](https://rdrr.io/r/base/Round.html),
  [`floor()`](https://rdrr.io/r/base/Round.html),
  [`round()`](https://rdrr.io/r/base/Round.html),
  [`truncate()`](https://rdrr.io/r/base/seek.html),
  [`sqrt()`](https://rdrr.io/r/base/MathFun.html),
  [`power()`](https://rdrr.io/r/stats/power.html) (exacta),
  [`trace()`](https://rdrr.io/r/base/trace.html), `is()`/`as()` como
  funciones y `lowBoundary()`/`highBoundary()` de fechas y horas. Pasa 7
  de las 11 pruebas experimentales del banco oficial, como el motor V8
  (antes 3).
- Las funciones que ya traducía siguen ahora la semántica de fhirpath.js
  en los casos límite que antes daban otro resultado sin aviso:
  comparaciones de fechas con distinta precisión y zona horaria,
  igualdad entre valores de distinto tipo (`birthDate = '1970-06-15'` es
  falso), números comparados con 8 decimales (`0.1 + 0.2 = 0.3`),
  `toInteger()`/`toDecimal()` de textos,
  [`substring()`](https://rdrr.io/r/base/substr.html) fuera de rango,
  [`replace()`](https://rdrr.io/r/base/replace.html) con patrón vacío,
  `trim()` con espacios de Unicode, `iif()` con condiciones no lógicas,
  el orden de `|` y [`toString()`](https://rdrr.io/r/base/toString.html)
  de números.
- Sigue el tipo FHIR de cada expresión con el modelo R4 (el mismo de
  fhirpath.js), lo que permite elegir solo las variantes de cada
  elemento de elección y comparar fechas, textos y horas según su tipo.
- Lo que no se puede traducir con certeza da un error:
  `fhirviews_error_sql` al traducir (por ejemplo, expresiones regulares
  con construcciones que JavaScript y RE2 interpretan distinto, o
  `lowBoundary()` de decimales) y `fhirviews_error_vista` al ejecutar
  cuando depende de los datos (una fecha sin hora frente a una fecha y
  hora, textos con caracteres que DuckDB pasa a mayúsculas de otra
  forma, `skip()` con un número negativo…).
- Nuevo argumento `diferido` de
  [`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md):
  con `diferido = TRUE` devuelve una tabla de dplyr (dbplyr) sobre la
  consulta, para filtrar y resumir en DuckDB y traer a R solo el
  resultado. dplyr y dbplyr se agregan a Suggests.
- Una columna sin tipo cuyos valores son todos números enteros llega a R
  como entero, como en
  [`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md).

### Terminologías

- Nuevas funciones para trabajar con un servidor de terminología FHIR
  (por ejemplo, [tx.fhir.org](https://tx.fhir.org/r4) o un Snowstorm),
  con la misma conexión de
  [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md),
  su token o su autenticación SMART on FHIR:
  - [`tx_expandir()`](https://f-slg.github.io/fhirviews/reference/tx_expandir.md):
    operación `ValueSet/$expand` con paginación (`offset` y `count`)
    para expansiones grandes; acepta la URL canónica del `ValueSet` o un
    `ValueSet` propio (lista, JSON o archivo) y devuelve un `data.frame`
    con `system`, `code`, `display` y `version`.
  - [`tx_buscar_codigo()`](https://f-slg.github.io/fhirviews/reference/tx_buscar_codigo.md):
    operación `CodeSystem/$lookup`, con el nombre, las designaciones y
    las propiedades del código.
  - [`tx_validar_codigo()`](https://f-slg.github.io/fhirviews/reference/tx_validar_codigo.md):
    operación `ValueSet/$validate-code` para un vector de códigos.
- [`vista_con_valueset()`](https://f-slg.github.io/fhirviews/reference/vista_con_valueset.md)
  agrega a un `ViewDefinition` los códigos de una expansión (como
  constantes y un `where`, o como columna lógica), de modo que un
  indicador definido con un `ValueSet` se calcula con
  [`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
  o
  [`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md)
  sin red. La forma de la condición mantiene la expresión corta con
  miles de códigos.
- Nueva sección sobre terminologías en la viñeta *Servidores reales y
  grandes volúmenes*.

### Catálogo de vistas para salud pública

- Nuevas
  [`vista_catalogo()`](https://f-slg.github.io/fhirviews/reference/vista_catalogo.md)
  y
  [`vista_plantilla()`](https://f-slg.github.io/fhirviews/reference/vista_plantilla.md):
  una biblioteca de `ViewDefinition` listos para usar (JSON estándar de
  SQL on FHIR en `inst/vistas`) con las tablas más comunes en vigilancia
  y salud pública: `pacientes` (sexo, nacimiento, fallecimiento, cantón
  y provincia de residencia), `signos_vitales` (una fila por medición,
  con la presión sistólica y diastólica separadas), `diagnosticos`
  (CIE-10 y SNOMED CT), `notificacion_obligatoria` (dengue, malaria y
  tuberculosis por defecto, con la lista de categorías CIE-10 como
  constante), `inmunizaciones`, `encuentros` y `medicamentos`. Todas
  usan `getResourceKey()` y `getReferenceKey()` para unir las tablas, y
  dan los mismos resultados con
  [`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
  y
  [`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md).
- [`vista_plantilla()`](https://f-slg.github.io/fhirviews/reference/vista_plantilla.md)
  permite cambiar las constantes de una vista con el argumento
  `constantes`.

### Correcciones

- Las operaciones (`$expand`, `$lookup`, `$everything`, `$export`…) con
  parámetros de búsqueda se envían con el `$` sin codificar. Antes la
  URL se reconstruía con
  [`httr2::req_url_query()`](https://httr2.r-lib.org/reference/req_url.html)
  y, según la versión de libcurl, el `$` viajaba como `%24`, que
  servidores como tx.fhir.org rechazan con 404 (*Unknown operation*).

## fhirviews 0.2.0

Esta versión prepara fhirviews para servidores y volúmenes reales:
autenticación SMART on FHIR, exportación masiva con `$export` y un
segundo motor de vistas sobre DuckDB, entre 16 y 37 veces más rápido que
el motor V8 (un millón de pacientes en unos 5,5 segundos). No hay
cambios incompatibles.

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

- Segundo motor de vistas:
  [`vista_sql()`](https://f-slg.github.io/fhirviews/reference/vista_sql.md)
  traduce un `ViewDefinition` a una consulta SQL de DuckDB y
  [`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md)
  la ejecuta directamente sobre archivos NDJSON (también comprimidos o
  con comodines) o Parquet, sin cargar los recursos en R; con `tabla`,
  guarda el resultado en una base DuckDB en lugar de traerlo a R.
  Requiere duckdb 1.3.0 o posterior.
- Admite un subconjunto de FHIRPath: navegación, elementos de elección
  (`value`, `effective`, `onset`…), `where()`,
  [`exists()`](https://rdrr.io/r/base/exists.html), `empty()`,
  `first()`, `join()`, `ofType()`, `extension()`, `getResourceKey()`,
  `getReferenceKey()`, comparaciones, lógica y constantes. Lo que no
  puede traducir con certeza da un error de clase `fhirviews_error_sql`,
  nunca un resultado aproximado.
- Pasa las 133 pruebas *shareable* del banco oficial
  (`vista_conformidad(motor = "duckdb")`) y una prueba diferencial exige
  que dé las mismas tablas (valores y tipos) que
  [`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
  con las vistas de todas las viñetas.
- Rendimiento de punta a punta desde NDJSON: 250 000 pacientes en 1,7 s
  (62 s con el motor V8) y un millón en 5,5 s.

### Documentación

- Nueva viñeta *Servidores reales y grandes volúmenes*: autenticación
  SMART paso a paso, `$export` (con una exportación real contra el
  servidor de referencia de SMART Health IT) y el motor DuckDB.
- README con los nuevos casos de uso, la comparación de rendimiento
  entre motores y la comparación con pathling y fhircrackr; artículo
  *Cómo funciona por dentro* ampliado con las tres piezas nuevas.

### Pruebas

- La autenticación se verificó con un servidor SMART local que comprueba
  la firma de cada JWT con una implementación independiente (Python y
  PyJWT), incluidos la renovación del token, el reintento tras un 401 y
  el rechazo de credenciales o claves incorrectas.
- La exportación se verificó contra
  <https://bulk-data.smarthealthit.org>.
- El servidor simulado de las pruebas decodifica las URL, que según la
  versión de R y de curl llegan con `$` codificado como `%24`.

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
