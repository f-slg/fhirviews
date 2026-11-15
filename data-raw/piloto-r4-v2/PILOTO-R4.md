# Piloto externo del alcance R4

Este protocolo acompana al candidato de desarrollo **0.5.0.9002**. Registra
el archivo exacto, su SHA-256 y la plataforma antes de empezar. No es un
lanzamiento estable ni un aval de CRAN. El candidato 0.5.0.9000 tiene un DOI
propio distinto; no se atribuye a 0.5.0.9002. Los datos del piloto son
enteramente ficticios.

## Alcance

La aceptacion tecnica instalada conserva el control historico de seis recursos
y cinco tipos, ademas de pruebas del paquete. Una tarea opcional separada del
perfil completo ejercita Specimen y DiagnosticReport desde SQL. El perfil **completo** incluye
una tarea opcional nueva para ejecutar `examples/laboratorio-r4.R`: construye
Patient, Specimen, dos Observation y DiagnosticReport desde DBI/DuckDB, prueba
referencias variables de informe a resultados y muestras y compara V8 con
DuckDB. El perfil basico no instala DuckDB y no evalua esa tarea.

`fhir_componente_rust()` es una opcion CLI externa. El candidato no descarga ni
instala Rust automaticamente; usar Rust no es requisito para completar este
piloto. Los perfiles base R4 probados con HAPI no sustituyen perfiles
clinicos/nacionales, invariantes ni terminologia del proyecto.

## Preparacion y ejecucion

1. Acordar el perfil basico/completo, identificador de participante, sistema,
   version de R y quien observa. No usar datos de pacientes, credenciales ni
   servidores de produccion.
2. Comparar `CANDIDATO.json`, `MANIFIESTO-KIT.json` y `SHA256SUMS`. El lanzador
   verifica SHA-256, MD5 y tamano antes de instalar en una biblioteca aislada.
3. Seguir `LEEME.md` y el protocolo de perfil R o FHIR. Registrar ayuda y
   conservar un directorio distinto por intento.
4. En el perfil completo, acordar si se hace R09/F09; requiere DBI y DuckDB.
   Abrir y revisar el ejemplo de laboratorio instalado; sus datos siguen
   siendo ficticios. No se requiere componente Rust.
5. Exportar fichas e informe del formulario y revisar personalmente cualquier
   ruta local antes de compartirlos. El kit no transmite resultados.

## Interpretacion y cierre

La comprobacion automatica no completa tareas humanas. En perfil basico,
`recuperacion` es `no_evaluado`; no equivale a aprobacion. Las pruebas nuevas
del ejemplo de laboratorio son una actividad opcional del perfil completo y
no forman un control adicional del esquema de aceptacion. Registrar errores,
advertencias, ayuda, incidencias y limitaciones sin convertirlas en aprobacion.

El cierre requiere revision del participante y del mantenedor. Una sesion con
ayuda no demuestra autonomia sin una repeticion independiente. Validacion de
perfiles propios, instalacion externa y evaluacion humana siguen siendo
resultados separados.
