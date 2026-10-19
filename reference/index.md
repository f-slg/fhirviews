# Package index

## Cliente FHIR

Conectarse a un servidor FHIR R4 y hacer peticiones, como en Postman.

- [`fhir_conectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conectar.md)
  : Conectarse a un servidor FHIR
- [`fhir_buscar()`](https://f-slg.github.io/fhirviews/reference/fhir_buscar.md)
  : Buscar recursos con paginación automática
- [`fhir_leer()`](https://f-slg.github.io/fhirviews/reference/fhir_leer.md)
  : Leer un recurso
- [`fhir_everything()`](https://f-slg.github.io/fhirviews/reference/fhir_everything.md)
  : Todos los datos de un paciente u otro compartimento (\$everything)
- [`fhir_crear()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md)
  [`fhir_actualizar()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md)
  [`fhir_borrar()`](https://f-slg.github.io/fhirviews/reference/fhir_crear.md)
  : Crear, actualizar y borrar recursos
- [`fhir_validar()`](https://f-slg.github.io/fhirviews/reference/fhir_validar.md)
  : Validar un recurso en el servidor (\$validate)
- [`fhir_capacidades()`](https://f-slg.github.io/fhirviews/reference/fhir_capacidades.md)
  : Capacidades del servidor
- [`fhir_peticion()`](https://f-slg.github.io/fhirviews/reference/fhir_peticion.md)
  : Hacer una petición FHIR cualquiera
- [`fhir_ejecutar_texto()`](https://f-slg.github.io/fhirviews/reference/fhir_ejecutar_texto.md)
  : Ejecutar una petición escrita como texto
- [`fhir_vista()`](https://f-slg.github.io/fhirviews/reference/fhir_vista.md)
  : Ejecutar una vista contra un servidor FHIR
- [`fhir_disponible()`](https://f-slg.github.io/fhirviews/reference/fhir_disponible.md)
  : Comprobar si un servidor FHIR responde

## Autenticación SMART on FHIR

OAuth2 para servidores protegidos: client credentials, SMART Backend
Services (JWT firmado) e inicio de sesión en el navegador con PKCE.

- [`fhir_auth_cliente()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md)
  [`fhir_auth_backend()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md)
  [`fhir_auth_interactiva()`](https://f-slg.github.io/fhirviews/reference/fhir_auth.md)
  : Autenticación SMART on FHIR (OAuth2)
- [`fhir_smart_configuracion()`](https://f-slg.github.io/fhirviews/reference/fhir_smart_configuracion.md)
  : Descubrir la configuración SMART de un servidor

## RStudio

Panel Connections, conexión activa y addins.

- [`fhir_conexion_activa()`](https://f-slg.github.io/fhirviews/reference/fhir_conexion_activa.md)
  [`fhir_desconectar()`](https://f-slg.github.io/fhirviews/reference/fhir_conexion_activa.md)
  : Conexión activa y panel Connections de RStudio
- [`addin_peticion()`](https://f-slg.github.io/fhirviews/reference/addin_peticion.md)
  [`addin_vista()`](https://f-slg.github.io/fhirviews/reference/addin_peticion.md)
  : Addins de RStudio

## Recursos FHIR

- [`fhir_recursos()`](https://f-slg.github.io/fhirviews/reference/fhir_recursos.md)
  : Reunir recursos FHIR en una lista
- [`fhir_tabla()`](https://f-slg.github.io/fhirviews/reference/fhir_tabla.md)
  : Tabla rápida de recursos FHIR

## Vistas SQL on FHIR

Convertir recursos FHIR en tablas con un ViewDefinition.

- [`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
  : Ejecutar un ViewDefinition
- [`vista_crear()`](https://f-slg.github.io/fhirviews/reference/vista_crear.md)
  : Crear un ViewDefinition sencillo
- [`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md)
  : Leer un ViewDefinition
- [`vista_validar()`](https://f-slg.github.io/fhirviews/reference/vista_validar.md)
  : Validar un ViewDefinition
- [`vista_json()`](https://f-slg.github.io/fhirviews/reference/vista_json.md)
  : Convertir un ViewDefinition en JSON
- [`vista_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_duckdb.md)
  : Guardar vistas en DuckDB

## Conformidad

- [`vista_conformidad()`](https://f-slg.github.io/fhirviews/reference/vista_conformidad.md)
  : Banco oficial de pruebas de SQL on FHIR

## FHIRPath

- [`vista_fhirpath()`](https://f-slg.github.io/fhirviews/reference/vista_fhirpath.md)
  : Evaluar una expresión FHIRPath
- [`fhirviews_motor()`](https://f-slg.github.io/fhirviews/reference/fhirviews_motor.md)
  [`fhirviews_version_fhirpath()`](https://f-slg.github.io/fhirviews/reference/fhirviews_motor.md)
  : Motor de FHIRPath y versión de fhirpath.js

## Paquete

- [`fhirviews`](https://f-slg.github.io/fhirviews/reference/fhirviews-package.md)
  [`fhirviews-package`](https://f-slg.github.io/fhirviews/reference/fhirviews-package.md)
  : fhirviews: FHIR desde R y vistas tabulares con SQL on FHIR
