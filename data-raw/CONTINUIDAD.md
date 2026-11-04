# Continuidad del proyecto fhirviews

Actualizado: 4 de noviembre de 2026.

## Decisiones del mantenedor

- Repositorio `f-slg/fhirviews` privado por solicitud expresa del mantenedor.
- No enviar el paquete a CRAN todavía. Una comprobación con `--as-cran` no es un envío.
- La versión 0.5.0 queda preparada como borrador de lanzamiento en GitHub, con su archivo `fhirviews_0.5.0.tar.gz`. No publicar el lanzamiento ni enviar a CRAN sin una nueva instrucción.
- Mantener el motor SQL de DuckDB identificado como experimental.

## Trabajo realizado

Se recuperó el contexto de codex1 y se implementaron los seis hallazgos de su auditoría:

1. `fhir_validar()` diferencia `TRUE`, `FALSE` y `NA`; conserva el estado HTTP y evita declarar válido un resultado desconocido. HTTP 400, 412 y 422 o un OperationOutcome incompleto producen `NA`; otros fallos HTTP conservan el manejo de errores.
2. Las descargas de Bulk Data validan NDJSON por bloques, admiten gzip y comprueban tipo y conteo cuando el manifiesto lo incluye antes de registrar el archivo completo. Los registros anteriores se invalidan para aplicar esta comprobación.
3. Los errores HTTP y de respuestas no JSON ocultan el cuerpo del servidor por defecto; `_id` se oculta en la consulta. Depuración explícita mediante `fhirviews.mostrar_detalles` y `fhirviews.mostrar_consulta`.
4. La caché FHIRPath usa objetos sin prototipo para evitar colisiones con `toString`, `constructor` y `__proto__`.
5. La viñeta de grandes volúmenes requiere `FHIRVIEWS_VINETAS_DUCKDB=true` para ejecutar SQL, evitando descargas en la construcción estándar.
6. SMART Backend Services rechaza claves RSA menores de 2048 bits.

También se actualizaron documentación y pruebas de regresión, se preparó la versión 0.5.0 y se reorganizó el README con ejemplos ejecutados, guía de motores, privacidad, conformidad y límites conocidos.

El procesamiento por bloques y la recuperación por archivo de exportaciones, iniciados antes de esta auditoría, forman parte de 0.5.0.

## Commits de implementación

- `d8af5ff`: versión 0.5.0 y correcciones de auditoría.
- `49ca62a`: README profesional y ajuste de compatibilidad de R 4.1.
- `ef76c24`: alcance final de CI y documentación correspondiente.

## Validación y evidencia

- Batería completa con red y DuckDB: 1278 comprobaciones aprobadas, sin fallos ni advertencias; entonces faltaban cuatro pruebas con servidor propio.
- Integración posterior con HAPI aislado: 52 comprobaciones aprobadas, sin fallos ni advertencias. Se omitió una variante de validación con ValueSet en línea porque HAPI no la admite. Escritura, transacciones y exportación de punta a punta se probaron.
- `R CMD build` construyó el paquete con sus viñetas dentro del entorno restringido de red.
- `R CMD check --as-cran --no-manual`: 0 errores, 0 advertencias y 1 NOTE por nueva presentación. El registro conservado corresponde al archivo con el README renovado, antes del último ajuste de alcance de CI; no hubo cambios posteriores en el código R o JavaScript.
- Los ejemplos locales del README se ejecutaron, incluidos DuckDB y la conformidad.
- CI del commit final `ef76c24` aprobado en cinco configuraciones: Windows, macOS y Ubuntu con R release; Ubuntu con R 4.1 y R-devel.
- R 4.1 y R-devel comprueban cliente y V8, con las otras dependencias opcionales salvo DuckDB. Los tres entornos release comprueban también DuckDB y sus pruebas SQL. DuckDB actual exige R >= 4.2 y su compilación desde fuente en R-devel resultó muy costosa.
- pkgdown y la publicación de Pages aprobaron en GitHub antes de convertir el repositorio a privado. No se ha vuelto a verificar la disponibilidad pública de Pages tras ese cambio.

CI final: https://github.com/f-slg/fhirviews/actions/runs/41775133622

Los fallos de R 4.1 de ejecuciones anteriores son históricos; están corregidos. Las ejecuciones anteriores pendientes se cancelaron al ser sustituidas.

Registros conservados en `data-raw/validacion-0.5.0/`: `00check.log` e `integracion-hapi.log`. Este directorio y esta nota quedan excluidos del paquete R por la regla existente `^data-raw$` en `.Rbuildignore`.

## Estado del lanzamiento

El borrador `v0.5.0` apunta al commit de implementación `ef76c24cff1e8bb0a7b2ef157db0381a2064448c` y contiene el archivo fuente. Se puede consultar con `gh release view v0.5.0` usando una cuenta autorizada. Esta nota se guarda después de ese commit y no cambia el código de la versión.

El contenedor de pruebas `fhirviews-release-test` se creó con Podman, imagen `docker.io/hapiproject/hapi:latest`, puerto local `18080`, Bulk Data habilitado. Terminadas las pruebas se detuvo. No se modificaron los contenedores de otros proyectos.

## Pendientes y próximos pasos

- No confundir conformidad técnica con aprobación para uso clínico sin restricciones.
- Validar utilidad con usuarios externos y un caso de uso reproducible; revisar sus resultados y necesidades antes de añadir funciones.
- Mantener explícitos los límites de DuckDB, precisión decimal, tipos por bloque y capacidades del servidor.
- Si se decide publicar más adelante, revisar cambios desde el commit del borrador, reconstruir y comprobar el artefacto que se vaya a distribuir.
- Revisar GitHub Pages y permisos de colaboradores si se quiere ofrecer documentación con el repositorio privado; no cambiar accesos sin instrucciones.

## Archivos ajenos al trabajo de implementación

Al cerrar esta sesión existe un directorio local `reports/` sin seguimiento de Git. No se añadió al repositorio ni se modificó su contenido. Sus archivos no están respaldados en GitHub por estos commits. `.Rbuildignore` lo excluye de la distribución del paquete.

## Para retomar

Leer esta nota, revisar `git status`, `git log` y `NEWS.md`, y confirmar el estado del borrador con `gh release view v0.5.0`. No depender de archivos en `/tmp` ni de recordar la conversación: pueden desaparecer o no estar disponibles en otra sesión.


## Continuación: primera entrega para validar el producto

Se añadió `inst/examples/vigilancia.R`, ejecutable desde una instalación del paquete:

```r
source(system.file("examples", "vigilancia.R", package = "fhirviews"))
```

El flujo usa exclusivamente datos ficticios incluidos. Selecciona eventos Condition A90/A91 confirmados, enlaza la residencia del paciente y genera CSV de eventos, resumen por cantón y mes de inicio, controles, vistas JSON, checksum de entrada y entorno de R. Rechaza carpetas existentes para evitar sobrescrituras. Cuenta eventos, no pacientes únicos ni tasas poblacionales.

Resultado verificado: 755 eventos de entrada, 661 confirmados, 94 excluidos y 65 cantones con eventos. Las 15 comprobaciones nuevas pasaron sin fallos ni advertencias. Se construyó el paquete con las viñetas y se instaló en una biblioteca temporal independiente; el script instalado produjo los mismos resultados. Se actualizó README y NEWS.

Registros de esta entrega: `data-raw/validacion-0.5.0/demo-pruebas.log` y `demo-instalado.log`.

Esta entrega es posterior al archivo del borrador de GitHub. El borrador NO se ha actualizado con esta demostración. Antes de distribuirlo hay que reconstruir y verificar el artefacto que lo sustituya. La CI previa aprobada no debe confundirse con una nueva comprobación de este commit.

### Criterios pendientes para cerrar la preparación del producto

1. **Integración repetible:** automatizar el arranque de HAPI aislado, su disponibilidad, las pruebas de escritura/transacciones/exportación y la limpieza; usar una versión o digest de imagen identificable y registrar omisiones del servidor. La ejecución anterior fue manual.
2. **Operación ETL:** definir y verificar un contrato de esquema entre bloques y una política de errores/recuperación del destino. Declarar tipos actualmente puede generar avisos y conservar valores incompatibles; no existe aún un modo estricto que lo rechace antes de entregar el bloque al consumidor.
3. **Piloto externo:** un usuario que no haya desarrollado el paquete debe poder instalarlo, ejecutar la demostración y reconciliar sus resultados sin ayuda; después, validar una vista con datos representativos de su entorno y acordar criterios de aceptación. Esto no se puede dar por cumplido mediante pruebas automáticas o datos ficticios.
4. **Distribución privada:** decidir el acceso de usuarios piloto y a la documentación, comprobar el efecto de la privacidad sobre Pages y preparar el artefacto final que se entregará. No cambiar permisos ni enviar a CRAN sin autorización.

El primer caso completo reproducible ya está implementado. El siguiente pendiente técnico es automatizar la integración con HAPI; el piloto externo y las decisiones de acceso requieren participación del mantenedor y de usuarios reales.


## Continuación: integración HAPI automatizada

Se implementó el siguiente pendiente técnico:

```sh
bash data-raw/probar-hapi.sh
```

- Usa Docker o Podman; `FHIRVIEWS_CONTENEDOR` permite elegir uno.
- Imagen fijada en `data-raw/hapi-image.txt` por digest SHA-256 de la imagen local previamente probada.
- Puerto aleatorio publicado exclusivamente en localhost, sin montar directorios del host.
- Espera acotada de disponibilidad, comprobación FHIR R4 y precarga de JSON de DuckDB.
- Resultados JSON y CSV, registros del servidor y pruebas, contexto y sesión R.
- Limpieza del contenedor propio tanto al aprobar como al fallar; la carpeta de registros se conserva y no puede existir antes de iniciar.
- Política probada con resultados simulados: no permite fallos, errores, advertencias, grupos obligatorios ausentes/duplicados ni omisiones inesperadas.
- La lectura del servidor público se excluye deliberadamente para no depender de su disponibilidad. La variante de ValueSet en línea se separó del grupo de terminología general; solo se permite su omisión por la limitación conocida de HAPI.
- Workflow `.github/workflows/integracion-hapi.yaml`: mismo script con Docker en Ubuntu/R release, disparo manual o por cambios relevantes, artefactos conservados por 14 días y cancelación de ejecuciones sustituidas.

Validación local con Podman: 46 comprobaciones aprobadas y operaciones obligatorias ejecutadas (escritura, transacciones/V8/DuckDB, terminología básica y exportación). Código de salida 0 y eliminación del contenedor comprobados. Timeout de arranque provocado en otra ejecución: código no cero, registros conservados y eliminación del contenedor comprobados. Registros resumidos conservados en `data-raw/validacion-0.5.0/hapi-automatizado/`.

La primera ejecución del lanzador se repitió porque se editó mientras corría. La evidencia conservada corresponde a la repetición con el archivo estable, que terminó con código 0. Podman elimina el archivo CID al retirar el contenedor; el script guarda ahora `contenedor-id.txt` para conservar esa evidencia.

La confirmación posterior de este workflow en GitHub con Docker se registra a continuación. El siguiente pendiente funcional del producto es el contrato estricto de esquema entre bloques y la política de errores del destino, además del piloto externo y la distribución privada ya descritos. El borrador y su archivo fuente NO se actualizan con estos cambios sin reconstrucción y validación posteriores; no publicar ni enviar a CRAN.


### Confirmación final de integración: Podman y Docker

El primer workflow falló al descargar la imagen: el digest de la caché local ya no estaba publicado en Docker Hub. Se consultó el registro remoto y se fijó **v8.12.0-2** con su digest de manifiesto publicado:

`docker.io/hapiproject/hapi:v8.12.0-2@sha256:0ff86aac4c7bd13a1ee226444a70263bb46ed1c28ef543c30a44f865b80ca04e`

La integración se repitió con esa referencia: 46 comprobaciones aprobadas con Podman local, código de salida cero y eliminación del contenedor comprobada. Los registros locales conservados se actualizaron a esta imagen definitiva. La política de omisiones y el fallo controlado de arranque también quedaron verificados.

GitHub, Docker, commit `75d058c`: **Integracion HAPI aprobada**, 46 comprobaciones, código cero y registros de limpieza conservados. También aprobaron R-CMD-check (las cinco configuraciones) y pkgdown para ese commit.

- Integración: https://github.com/f-slg/fhirviews/actions/runs/41815334804
- R-CMD-check: https://github.com/f-slg/fhirviews/actions/runs/41815334893
- Documentación: https://github.com/f-slg/fhirviews/actions/runs/41815334795

Los resúmenes y registros de Docker se guardan permanentemente en `data-raw/validacion-0.5.0/hapi-ci/`, además de los artefactos temporales del workflow. Los commits que solo conservan esta evidencia no cambian el código probado. El paquete continúa privado y no se publicó el lanzamiento ni se envió a CRAN. El siguiente pendiente funcional es el esquema estricto entre bloques; el piloto externo y la distribución privada siguen pendientes.


## Continuación: esquema estricto y recuperación transaccional

Se implementó `vista_ejecutar_lotes(..., estricto = TRUE)`. El valor por defecto es `FALSE` y conserva el comportamiento habitual.

- Exige `type` primitivo FHIR R4 en todas las columnas y contratos iguales (`type`/`collection`) en cada rama. Falla en bloque 0 antes de leer si la definición no lo permite.
- Valida los valores antes de las coerciones: no convierte entre texto, números y lógicos; comprueba enteros representables/rangos, decimales finitos y elementos de colecciones. Mantiene ausentes y vacíos tipados.
- Comprueba números no finitos en el JSON de entrada y en los resultados de V8 antes de serializar. Se reprodujo y corrigió el caso `1e309` que podía terminar como un ausente.
- Errores `fhirviews_error_lotes` y `fhirviews_error_esquema`: bloque, fase, índice de archivo, columna/tipo/motivo cuando se conocen y contadores de consumidores que retornaron sin error. No incluyen valores ni el error original del destino. No se confía en clases ni metadatos de errores emitidos por el consumidor.
- Los contadores no prueban persistencia ni son checkpoints para omitir bloques. Una escritura del bloque fallido puede ser parcial; la función no revierte ni reintenta efectos externos. Las transacciones pueden revertir incluso bloques cuyos consumidores ya retornaron.
- `inst/examples/lotes-transaccion.R`: ejemplo con datos ficticios y base temporal; una transacción abarca eliminación y carga completa. Demuestra rollback tras escribir y dos cargas completas sin acumular duplicados. No deduplica eventos que ya estén repetidos en el origen.
- Los tipos de texto no validan formatos de fecha/URI/códigos ni perfiles FHIR. Los mensajes propios del consumidor siguen bajo su responsabilidad.

Se actualizaron ayuda, README y NEWS. El motor V8 mantiene su comportamiento por defecto; la comprobación previa a serialización solo se activa para la ejecución estricta.

Validación local: 271 comprobaciones específicas aprobadas, sin fallos/avisos; batería completa con red: 1377 aprobadas, sin fallos/avisos, cinco pruebas con servidor propio omitidas (a ejecutar por el workflow de HAPI). Construcción con viñetas e instalación independiente aprobadas. El ejemplo instalado verificó rollback y dos cargas completas con cinco filas sin acumulación.

`R CMD check --as-cran --no-manual`: 0 errores, 0 advertencias y 2 NOTEs: comprobación incoming (nueva presentación y URLs inaccesibles para un visitante anónimo al estar el proyecto privado) y falta de verificación de hora actual. Los enlaces de Pages también devolvieron 404 en esa revisión anónima; no se verificó acceso autenticado. Se corrigieron las notas preparatorias de `cran-comments.md` para reflejar este estado; no se envió a CRAN.

Evidencia en `data-raw/validacion-0.5.0/estricto/`. Falta confirmar los workflows para este código antes de cerrar la entrega. El borrador y su archivo fuente siguen siendo anteriores: no se actualizan ni publican automáticamente. Tras esta entrega quedan el piloto externo y la distribución/documentación privada, junto con los cambios que ese piloto identifique. No prometer producción clínica sin restricciones a partir de estos resultados técnicos.


### Cierre del modo estricto y actualización del candidato

Código `6c14427`: aprobaron las cinco configuraciones de R-CMD-check, la integración HAPI y pkgdown.

- https://github.com/f-slg/fhirviews/actions/runs/41826263862
- https://github.com/f-slg/fhirviews/actions/runs/41826263929
- https://github.com/f-slg/fhirviews/actions/runs/41826263968

La evidencia de HAPI para este código también se conservó en el directorio `estricto/` con prefijo `hapi-`. El borrador `v0.5.0` se actualizó al commit `6c14427da5f7ea45b6a48e1a46268500c20d9b37`, con el archivo fuente reconstruido y comprobado que contiene el modo estricto, la recuperación transaccional y las entregas anteriores. Sus notas reflejan las 1377 comprobaciones y las 2 NOTEs actuales. El lanzamiento continúa como borrador; no se publicó ni se envió a CRAN.

Los pendientes anteriores sobre un artefacto desactualizado quedan resueltos para este candidato. El contrato estricto entre bloques y su ejemplo de recuperación también quedan implementados y verificados. Quedan el piloto externo y la decisión de acceso/distribución y documentación privada. La accesibilidad anónima de Pages devolvió 404; no cambiar privacidad ni permisos de colaboradores sin instrucciones. El piloto requiere definir usuarios y un entorno representativo, sin inventar resultados de adopción ni garantías clínicas.
