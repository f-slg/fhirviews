# Autenticación SMART on FHIR (OAuth2)

Crean la configuración de autenticación que se pasa a
[`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md)
en el argumento `autenticacion`, para servidores protegidos con [SMART
on FHIR](https://hl7.org/fhir/smart-app-launch/):

## Usage

``` r
fhir_auth_cliente(
  id,
  secreto,
  alcances = "system/*.read",
  url_token = NULL,
  envio = NULL
)

fhir_auth_backend(
  id,
  clave_privada,
  alcances = "system/*.read",
  kid = NULL,
  contrasena = NULL,
  url_token = NULL
)

fhir_auth_interactiva(
  id,
  alcances = c("openid", "fhirUser", "launch/patient", "patient/*.read"),
  secreto = NULL,
  url_autorizacion = NULL,
  url_token = NULL,
  redireccion = "http://localhost:1410/",
  cache_disco = FALSE
)
```

## Arguments

- id:

  Identificador del cliente (`client_id`) registrado en el servidor de
  autorización.

- secreto:

  Secreto del cliente (`client_secret`). Para no escribirlo en el
  código, guárdalo en una variable de entorno y usa por ejemplo
  `Sys.getenv("FHIR_SECRETO")`. En `fhir_auth_interactiva()` es opcional
  (solo para clientes confidenciales).

- alcances:

  Vector de *scopes* SMART, por ejemplo
  `c("system/Patient.read", "system/Observation.read")` o, en SMART v2,
  `"system/*.rs"`. El valor por defecto usa la sintaxis de SMART v1
  (`.read`), que la mayoría de servidores v2 también aceptan; si el
  servidor solo admite v2, indica los alcances con `.rs`.

- url_token:

  URL del *token endpoint*. Si es `NULL`, se descubre.

- envio:

  Cómo se envía el secreto al pedir el token: `"cabecera"` (HTTP Basic,
  `client_secret_basic`) o `"cuerpo"` (`client_secret_post`). Si es
  `NULL`, se usa la cabecera salvo que el servidor declare que solo
  admite el cuerpo.

- clave_privada:

  Clave privada RSA (de al menos 2048 bits, firma RS384) o EC de la
  curva P-384 (firma ES384): ruta a un archivo PEM, el texto PEM o un
  objeto `key` del paquete openssl. La clave pública correspondiente (su
  JWKS) debe estar registrada en el servidor.

- kid:

  Identificador de la clave (`kid`) que se pone en la cabecera del JWT;
  SMART lo pide para que el servidor elija la clave pública.

- contrasena:

  Contraseña de la clave privada, si está cifrada.

- url_autorizacion:

  URL del *authorization endpoint*. Si es `NULL`, se descubre.

- redireccion:

  URL de redirección registrada para el cliente. Con una dirección local
  (`http://localhost:puerto/`), R recibe la respuesta del navegador
  (requiere el paquete httpuv).

- cache_disco:

  Si es `TRUE`, guarda el token en el disco (cifrado por httr2) para no
  tener que iniciar sesión en cada sesión de R.

## Value

Un objeto de clase `fhir_auth` para el argumento `autenticacion` de
[`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md).

## Details

- `fhir_auth_cliente()`: flujo *client credentials* con un secreto
  compartido (cliente confidencial simétrico).

- `fhir_auth_backend()`: [SMART Backend
  Services](https://hl7.org/fhir/smart-app-launch/backend-services.html),
  *client credentials* en el que el cliente se identifica con un JWT
  firmado (RS384 o ES384) con su clave privada, sin secreto compartido.
  Es el flujo habitual entre sistemas (exportaciones, tableros, ETL).

- `fhir_auth_interactiva()`: flujo *authorization code* con PKCE y
  lanzamiento *standalone*: abre el navegador para que la persona inicie
  sesión y autorice el acceso. Solo en sesiones interactivas.

Si no se indican `url_token` (ni `url_autorizacion`, en el flujo
interactivo),
[`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md)
los descubre con
[`fhir_smart_configuracion()`](https://f-slg.github.io/fhirviews/reference/fhir_smart_configuracion.md).
El token se pide al hacer la primera petición, se guarda en memoria, se
renueva solo cuando expira (o con el *refresh token*, en el flujo
interactivo) y solo se envía a URL del propio servidor FHIR. Ni el token
ni el secreto ni la clave se muestran al imprimir la conexión o este
objeto.

## See also

[`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md),
[`fhir_smart_configuracion()`](https://f-slg.github.io/fhirviews/reference/fhir_smart_configuracion.md).

## Examples

``` r
if (FALSE) { # interactive()
# Cliente con secreto (client credentials)
con <- fhir_conectar(
  "https://fhir.ejemplo.org/r4",
  autenticacion = fhir_auth_cliente(
    "mi-cliente", Sys.getenv("FHIR_SECRETO"),
    alcances = "system/*.read"
  )
)

# SMART Backend Services con clave privada
con <- fhir_conectar(
  "https://fhir.ejemplo.org/r4",
  autenticacion = fhir_auth_backend(
    "mi-cliente", "~/.claves/fhir-privada.pem",
    alcances = c("system/Patient.read", "system/Observation.read"),
    kid = "clave-2026"
  )
)

# Inicio de sesión en el navegador (authorization code + PKCE)
con <- fhir_conectar(
  "https://launch.smarthealthit.org/v/r4/fhir",
  autenticacion = fhir_auth_interactiva("mi-app")
)
}
```
