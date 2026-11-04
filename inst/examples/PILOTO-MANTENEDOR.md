# Aceptación del candidato y operación del piloto

El kit usa únicamente datos ficticios incluidos. Un aprobado técnico no cierra
la evaluación con usuarios ni valida datos clínicos o un servidor del participante.

## Construir y probar el archivo de entrega

Desde el repositorio, con las dependencias y herramientas de construcción instaladas:

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
