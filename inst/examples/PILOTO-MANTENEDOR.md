# Aceptación del candidato y operación del piloto

El kit usa únicamente datos ficticios incluidos. Un aprobado técnico no cierra
la evaluación con usuarios ni valida datos clínicos o un servidor del participante.

## Construir y probar el archivo de entrega

Estos pasos se ejecutan desde una copia del repositorio
(<https://github.com/f-slg/fhirviews>), no desde el paquete instalado: el
script
[`data-raw/probar-candidato.R`](https://github.com/f-slg/fhirviews/blob/main/data-raw/probar-candidato.R)
no se distribuye con el paquete. Con las dependencias y herramientas de
construcción instaladas:

```sh
R CMD build . --no-manual
Rscript data-raw/probar-candidato.R fhirviews_0.5.0.tar.gz /ruta/piloto-basico-01 basico
Rscript data-raw/probar-candidato.R fhirviews_0.5.0.tar.gz /ruta/piloto-completo-01 completo
```

Cada salida debe ser nueva. `basico` necesita las dependencias obligatorias del
paquete; `completo` necesita además DBI y duckdb. El instalador reutiliza las
dependencias existentes: comprueba una biblioteca nueva para fhirviews, sin
representar un sistema operativo vacío ni instalar dependencias automáticamente.

La instalación y el piloto se ejecutan en procesos separados. Antes del piloto,
se comprueba la ruta del paquete cargado, su ayuda y las tres viñetas construidas.
El proceso verifica también que el informe final apruebe el perfil solicitado y
corresponda al checksum y versión del candidato. Conserva registros de instalación,
códigos de salida, tamaño y MD5. Este MD5 identifica el archivo ensayado; no es
una firma de autenticidad. Entrega exactamente el archivo probado.

CI ejecuta esta aceptación sobre el archivo generado por R CMD check. Los tres
sistemas con R release usan `completo`; R 4.1 y R-devel usan `basico`, según el
alcance de dependencias de la matriz. Los informes se conservan 14 días como
artefactos `piloto-*`, excluyendo la biblioteca instalada. No se crea un lanzamiento
ni se cambian permisos como parte de esta aceptación.

## Interpretar los informes

`aceptacion.json` incluye `esquema_informe = 1`, el perfil, el checksum disponible,
los controles, advertencias y diagnósticos. `aceptacion.csv` resume los controles.
`sessionInfo.txt` conserva el entorno; `experiencia-usuario.txt` deja pendiente
la evaluación humana. Revise los archivos antes de compartirlos: el entorno puede
contener rutas y nombres locales. El kit no envía resultados automáticamente.

| Estado | Interpretación |
|---|---|
| `aprobado` | El control terminó sin errores ni advertencias |
| `fallo` | El control falló; los siguientes quedan pendientes |
| `requiere_revision` | Hubo advertencias; no se aprueba automáticamente |
| `pendiente` | El control todavía no se ejecutó |
| `no_evaluado` | El perfil excluye ese control, por ejemplo recuperación en `basico` |

`resultado_tecnico` vale `aprobado` solo cuando terminan todos los controles del
perfil sin errores ni advertencias. Un fallo produce `no_aprobado`; si todos
terminan pero hay advertencias, produce `requiere_revision`. Ambos casos hacen
que el comando termine con código distinto de cero. No se deben ignorar ni
transformar esas salidas en una aprobación manual sin investigar y repetir.

Los mensajes originales de errores y advertencias no se copian al informe. Los
diagnósticos usan códigos fijos, con valores numéricos esperados y observados para
los totales de datos ficticios. Los errores no reconocidos usan `error_inesperado`.

| Código | Qué revisar |
|---|---|
| `api_incompatible` | La copia instalada no ofrece la API esperada |
| `ejemplo_ausente` | Reconstruir el candidato con sus ejemplos |
| `dependencia_ausente` | Instalar DBI y duckdb para el perfil completo |
| `total_eventos_incorrecto`, `total_cantones_incorrecto` | Comparar esperado y observado |
| `totales_inconsistentes` | Reconciliar eventos y resúmenes |
| `verificacion_incorrecta`, `formato_dpa_incorrecto` | Revisar filtros y lectura del código territorial como texto |
| `evento_referencia_incorrecto`, `evento_excluido_presente` | Revisar selección y enlace de eventos a pacientes |
| `conteo_territorial_incorrecto`, `conteo_mensual_incorrecto` | Revisar agrupación territorial y temporal |
| `rechazo_estricto_incorrecto` | Revisar bloque rechazado, fase y llamadas al consumidor |
| `advertencias_requieren_revision` | Consultar los códigos en `advertencias`; repetir después de investigar |
| `error_inesperado` | Reproducir el control con datos ficticios y obtener un diagnóstico local |

Las advertencias se clasifican como `advertencia_tipo` o
`advertencia_procesamiento`; sus textos y clases arbitrarias no se persisten.

## Referencias de los datos ficticios

El kit espera 661 eventos confirmados y 65 cantones. Además comprueba:

- `den-c0001` enlaza a `den-p0001`, con residencia `0701` e inicio `2025-02-27`.
- `den-c0002` no aparece entre los confirmados seleccionados.
- Los cantones `0701`, `0702` y `0704` tienen 55, 1 y 1 eventos respectivamente.
- Enero, febrero y marzo de 2025 tienen 5, 73 y 173 eventos respectivamente.
- El contrato estricto entrega el primer bloque y rechaza el segundo antes de
  invocar el consumidor para ese bloque.

Estas referencias permiten detectar asignaciones erróneas que conservarían los
totales. Si cambia el conjunto ficticio o la definición del indicador, revisar
los recursos originales, actualizar las referencias y registrar el motivo;
no ajustar las expectativas únicamente para hacer pasar la prueba.

## Cierre con usuarios

Una persona ajena al desarrollo debe instalar el candidato, interpretar los
controles, modificar una vista y contrastarla con el recurso original. Registrar
el tiempo, la ayuda necesaria, los obstáculos y la conclusión en
`experiencia-usuario.txt`. El mantenedor revisa esa evidencia y acuerda las
mejoras antes de cerrar el piloto. Todos los aprobados automáticos conservan
`validacion_usuario_externo = pendiente`.


## Protocolo del primer piloto externo

Realizar dos sesiones iniciales: una con una persona que use R y otra con una
persona que conozca FHIR. Pueden ser participantes distintos; registrar su
experiencia previa sin asumir que representan a todos los usuarios potenciales.
El mantenedor entrega el mismo candidato identificado por checksum y la guía.
Nadie debe recibir datos de pacientes para esta primera sesión.

Antes de empezar, registrar sistema operativo, versión de R, perfil elegido,
fecha, identificador del participante y checksum del candidato. Identificar
cuáles dependencias ya estaban instaladas. Usar una carpeta nueva en cada intento.

| Paso | Tarea del participante | Evidencia y resultado esperado |
|---|---|---|
| 1 | Instalar el candidato y abrir la ayuda local | Paquete cargado desde la instalación esperada; anotar cualquier ayuda necesaria |
| 2 | Ejecutar el perfil básico y abrir los informes | Aprobación técnica; recuperación marcada como no evaluada |
| 3 | Explicar los controles de vigilancia | 755 eventos de entrada, 661 confirmados, 94 excluidos y 65 cantones; distinguir eventos de pacientes únicos y tasas |
| 4 | Contrastar un evento con el JSON incluido | den-c0001 apunta a den-p0001, residencia 0701 e inicio 2025-02-27 |
| 5 | Crear una vista Patient con id y gender, y modificarla para añadir birthDate | Conservar el JSON de ambas vistas y contrastar al menos un resultado con el recurso original |
| 6 | Ejecutar el perfil completo si el entorno admite DuckDB | Recuperación aprobada; explicar rollback y repetición de la carga completa |
| 7 | Repetir el análisis y registrar la experiencia | Obtener los mismos controles sin sobrescribir el primer informe; completar experiencia-usuario.txt |

En el paso 5 se puede usar el caso clínico incluido. El participante debe encontrar
las funciones y construir la vista con la documentación. El observador registra
las intervenciones; si proporciona la solución, marca la tarea como realizada con
ayuda. No convertir una tarea incompleta en una aprobación.

### Ficha de observación

Registrar por tarea, en una tabla local junto al informe:

| Campo | Qué registrar |
|---|---|
| participante | Identificador acordado, sin datos clínicos |
| tarea e intento | Paso del protocolo y número de intento |
| inicio, fin y minutos | Tiempo real, separando instalación y transformación |
| resultado | completada, completada_con_ayuda o incompleta |
| intervenciones | Número y descripción de la ayuda del mantenedor |
| obstáculo | Mensaje o paso confuso, usando solo ejemplos ficticios |
| evidencia | Archivo de salida o vista que permite revisar el resultado |
| interpretación | Si la persona explicó correctamente el indicador y sus límites |
| próximo_cambio | Corrección concreta propuesta por participante u observador |

No fijar tiempos de éxito sin una medición inicial. La primera sesión establece
una línea base; la repetición después de las correcciones permite comparar tiempo,
ayuda necesaria y exactitud. Separar los resultados del perfil básico de los del
completo. Un control no ejecutado conserva no_evaluado o pendiente.

### Criterios acordados para aceptar la sesión

- Instalación y ayuda disponibles, con sus obstáculos documentados.
- Controles y referencias coinciden, y el participante entiende la unidad contada.
- Vista modificada guardada y contrastada con el recurso original.
- Recuperación verificada si se acordó el perfil completo; en otro caso no evaluada.
- Repetición con controles coincidentes y experiencia registrada.
- El mantenedor revisa la evidencia con el participante y anota los pendientes.

La sesión puede completarse con ayuda registrada. Para afirmar autonomía se
requiere una repetición sin intervención en las tareas acordadas. Una sesión
fallida aporta hallazgos y no se presenta como aprobación de producto.

Un caso del entorno del participante y una comparación con su herramienta habitual
son etapas posteriores: definir primero recursos, salida esperada y criterios
comunes. No extrapolar la demostración ficticia a una implantación clínica.
