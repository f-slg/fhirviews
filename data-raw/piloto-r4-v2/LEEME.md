# Piloto externo R4 de fhirviews

Este kit entrega el candidato **0.5.0.9001** que ya pasó las comprobaciones
técnicas. Las fichas comienzan pendientes: el kit no contiene resultados de
personas reales ni acredita una evaluación clínica. Usa datos ficticios.

## Empezar

1. Extrae el ZIP completo en una carpeta propia y abre R en esa carpeta.
2. Abre `FORMULARIO-PILOTO.html` en un navegador actual. Elige perfil R o FHIR,
   acuerda el alcance y registra un ID de participante, por ejemplo P01 o P02.
3. Instala las dependencias que falten. El lanzador las comprueba y no las
   instala automáticamente:

```r
install.packages(c("cli", "httr2", "jsonlite", "rlang", "V8", "openssl"))
# Solo para el perfil tecnico completo:
# install.packages(c("DBI", "duckdb"))
```

4. Ejecuta el ensayo en una carpeta nueva por intento. Básico requiere R >= 4.1;
   este kit usa R >= 4.2 para completo con DuckDB. No necesitas Rust, Java ni un
   servidor FHIR para estas tareas.

```r
source("INICIAR.R")
iniciar_piloto("basico", "sesion-P01-intento01")
abrir_sesion("sesion-P01-intento01")
```

También se puede usar `Rscript INICIAR.R basico sesion-P01-intento01`.
Para las tareas manuales en RStudio, abre después una sesión nueva de R,
ejecuta `source("INICIAR.R")` y llama a `abrir_sesion()` con la misma carpeta.
Esto carga la copia aislada del candidato, sin depender de otra instalación.

5. Sigue el protocolo de tu perfil y registra ayuda, tiempos y evidencias.
   Repite en `sesion-P01-intento02`, conservando el primer intento.
6. Exporta las fichas JSON y el informe del formulario. Revisa con el mantenedor
   qué archivos compartir por el canal acordado. El kit no envía resultados.

## Qué comprobar

`CANDIDATO.json` identifica versión, commit y archivo. El paquete incluido es
`paquete/fhirviews_0.5.0.9001.tar.gz`. El lanzador comprueba SHA-256, MD5 y tamaño
antes de instalarlo y usa un proceso R nuevo con una biblioteca aislada.
`SHA256SUMS` permite contrastar los archivos del kit; `MANIFIESTO-KIT.json`
identifica el commit con el que se prepararon las instrucciones. Los checksums
detectan cambios; no son una firma de autenticidad.

El ensayo conserva `SESION.json`, instalación, `piloto/aceptacion.json`, CSV,
`sessionInfo.txt`, `experiencia-usuario.txt` y las salidas `piloto/r4/`.
El formato técnico es `esquema_informe = 2`. Hay cinco controles: en básico
recuperación queda `no_evaluado`; los otros cuatro deben aprobarse. En completo
los cinco deben aprobarse. Toda advertencia requiere revisión.

El recorrido R4 construye seis recursos de cinco tipos. La vista de alergias
lee otros tres registros y da cinco filas; es una lectura adicional, no un
sexto constructor. El participante debe explicar estas diferencias.

## Materiales

- `PROTOCOLO-PERFIL-R.md` y `PROTOCOLO-PERFIL-FHIR.md`: tareas por perfil.
- `FORMULARIO-PILOTO.html`: dos fichas locales, incidencias, exportación y cierre.
- `tareas.json`: definiciones de las tareas, iguales a las del formulario.
- `PILOTO-R4.md`: protocolo que acompaña al paquete entregado.
- `ANEXO-OBSERVADOR.md`: soluciones para contrastar después del primer intento.
- `INICIAR.R`: verificación, instalación aislada y apertura de la sesión.
- `PROBAR-CANDIDATO.R`: control técnico usado por el mantenedor y la CI.
- `CANDIDATO.json`, `MANIFIESTO-KIT.json` y `SHA256SUMS`: identidad de entrega.
- `LICENSE.md`: licencia del material; el paquete conserva sus atribuciones.

El formulario funciona sin conexión, salvo los enlaces que abras. El guardado
del navegador puede no estar disponible al abrir archivos locales; exporta JSON
antes de cerrar. Solo importa fichas de este protocolo y candidato. Un aprobado
técnico no marca tareas humanas, autonomía o decisiones de cierre.

## Organización y cierre

El mantenedor acuerda inicialmente una sesión con alguien que use R y otra con
experiencia FHIR. No se han asignado participantes en este kit. Registra quién
observó, qué ayuda dio y qué se acordó evaluar. Las soluciones del anexo se
consultan después del primer intento o se registran como ayuda.

Conserva un intento por carpeta. Ante un fallo, conserva los registros y usa
otra carpeta para repetir tras corregirlo. No marques aceptada una sesión con
tareas obligatorias incompletas o incidencias críticas/altas sin resolver.
El cierre exige revisión del participante y del mantenedor. Una sesión con
ayuda no acredita autonomía sin una repetición independiente.

Esta primera sesión no utiliza datos de pacientes, credenciales ni servidores
propios. Los perfiles clínicos del proyecto y un entorno real se evalúan por
separado. Los registros de entorno pueden contener rutas locales: revísalos
antes de compartirlos. El candidato no tiene DOI de versión; el archivo Zenodo
0.5.0.9000 conserva un DOI distinto que no debe atribuirse a esta entrega.
