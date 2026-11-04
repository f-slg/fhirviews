# Kit para organizar el piloto de fhirviews

Este kit acompaña el candidato 0.5.0. No registra resultados de personas reales:
las fichas empiezan pendientes y deben completarse durante la sesión.

## Archivos

- `FORMULARIO-PILOTO.html`: abrir en un navegador para marcar comprobaciones,
  registrar tareas e incidencias, preparar avisos y exportar o imprimir informes.
- `PROTOCOLO-PERFIL-R.md`: tareas detalladas del perfil analista que utiliza R.
- `PROTOCOLO-PERFIL-FHIR.md`: tareas detalladas del perfil de interoperabilidad.
- `tareas.json`: catálogo de las tareas utilizado por el formulario.
- `ANEXO-OBSERVADOR.md`: soluciones de contraste; entregar después del primer intento o registrar su uso como ayuda del observador.
- `EJERCICIO-F05.R`: ejemplo ficticio de rechazo estricto; ejecutar después de `library(fhirviews)`.
- `REFERENCIA-CANDIDATO.json`: identidad del candidato inicial, no resultado de una sesión de usuario.
- `VALIDACION-KIT.txt`: alcance de las comprobaciones realizadas sobre el kit.

El formulario HTML es autocontenido: se puede copiar y abrir sin servidor, sin
instalar paquetes JavaScript y sin conexión. Tiene instrucciones y fragmentos R
para las tareas; el ejercicio F05 completo está además en el protocolo Markdown.
El guardado local depende del navegador. Exportar JSON antes de cerrar y para
continuar en otro equipo. No se envía nada automáticamente.

## Secuencia del mantenedor

1. Elegir dos participantes externos y acordar el canal de contacto.
2. Asignar un ID y una carpeta por participante/intento; explicar qué se registrará.
3. Entregar el protocolo de su perfil, este formulario y el candidato identificado.
4. Elegir el perfil de persona en el formulario y completar la ficha inicial.
5. Observar las tareas; anotar tiempos, ayudas y problemas sin resolver la tarea
   antes del primer intento. Las soluciones de R05/F04 quedan para el contraste
   posterior con el mantenedor.
6. Registrar incidencias y preparar el aviso; revisar y enviar manualmente.
7. Exportar JSON (para continuar), CSV (resumen) y texto (informe/aviso).
8. Revisar con el participante el cierre; corregir y repetir lo que corresponda.

El formulario mantiene fichas separadas para los dos perfiles dentro del mismo
archivo de exportación. Para iniciar otra pareja de sesiones sin mezclar registros,
exportar primero y utilizar el botón de nueva ficha del perfil; el otro perfil no
se borra. La decisión humana siempre se selecciona manualmente y se contrasta con
los pendientes que indique el formulario.

## Candidato de referencia inicial

- Archivo: `fhirviews_0.5.0.tar.gz`.
- Versión: 0.5.0.
- Commit: `f9d758ca67435b1e417c57bce79b6c6aafe6e7e7`.
- SHA-256: `babcae8cc46e91a7114a95376d2fb7d9fc499cc42ad5ac747d6a5f76bee781e9`.
- Manifiesto de referencia: `data-raw/validacion-0.5.0/cierre-piloto/MANIFIESTO.json` en el repositorio.

El lanzamiento continúa como borrador. El mantenedor proporciona el archivo;
no asumir que existe un enlace de release pública. Si se cambia el candidato,
actualizar su identidad y empezar un intento nuevo. Un aprobado anterior no se
transfiere automáticamente a otro archivo.

## Privacidad y notificaciones

Usar seudónimos si es suficiente. Este ensayo utiliza datos ficticios. Los
informes de entorno pueden mostrar rutas locales: revisarlos antes de compartir.
No incluir credenciales ni recursos reales de pacientes. El botón de aviso genera
texto para revisión; no envía correo, no crea issues y no contacta GitHub.

La valoración clínica, pruebas con datos propios y comparación con otras
herramientas requieren un alcance posterior acordado; no quedan aprobadas por
completar este protocolo.
