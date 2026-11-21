# Piloto externo del alcance R4

**Español** · [English](PILOTO-R4.en.md)

Protocolo **2.1**, candidato **0.5.0.9003**, datos ficticios. Registre archivo,
commit, SHA-256 y entorno. Los informes técnicos, la decisión humana y la
validación de perfiles son evidencias separadas. El candidato no tiene DOI
propio y no hereda el de 0.5.0.9000.

## Elegir y preparar la sesión

Acordar tres decisiones: perfil de persona R/FHIR, nivel básico/completo y
alcance núcleo/siete. Núcleo cubre cinco tipos constructores y extracción de
alergias; siete añade Specimen y DiagnosticReport y exige nivel completo y
R09/F09 terminada. Son siete tipos cubiertos entre casos; el ejemplo de
laboratorio produce cinco recursos de cuatro tipos.

La [evaluación detallada](EVALUACION-PILOTO.md) define preguntas, observación,
comprensión, ayuda, repetición, incidencias y criterios de cierre. La
[guía de preparación](LEEME.md) describe dependencias, hashes, instalación,
apertura de sesión y archivos. Use el protocolo [R](PROTOCOLO-PERFIL-R.md) o
[FHIR](PROTOCOLO-PERFIL-FHIR.md); el [anexo](ANEXO-OBSERVADOR.md) contiene las
soluciones para contrastar después del primer intento.

## Ejecutar y registrar

1. Preparar dependencias, identidad y carpeta nueva por intento. El lanzador
   verifica el candidato y lo instala en una biblioteca aislada.
2. Realizar tareas y preguntas sin consultar soluciones anticipadamente.
   Documentación espontánea está permitida; cada intervención del observador
   se registra con contenido, tipo y cantidad.
3. En R, realizar 01–06, 09 si corresponde, 07 y 08; en FHIR, 01–07, 09 si
   corresponde y 08. Laboratorio precede al cierre de alcance siete.
4. Registrar estado, comprensión, respuestas, evidencia, minutos activos y
   esperas. Repetir tareas manuales identificadas conservando ambos intentos.
5. Revisar incidencias y conclusión, exportar JSON/CSV/TXT y comprobar archivos
   antes de compartirlos por el canal acordado. El formulario es bilingüe,
   funciona localmente y no envía resultados.

## Interpretar y cerrar

Los cinco controles automáticos mantienen el esquema del candidato: básico
excluye recuperación; completo la exige. El laboratorio humano no añade un
control automático al informe. F07 requiere un plan de validación; ejecutar un
servidor de pruebas es una ampliación opcional que se acuerda y registra aparte.
Rust también es opcional. No se requieren servidores ni datos de pacientes.

Una aceptación humana exige tareas del alcance completas con comprensión
correcta, evidencia contrastada y revisión de ambas personas. Incidencias
críticas/altas abiertas impiden cierre favorable. La ayuda se conserva; autonomía
solo se declara para tareas repetidas sin ayuda y con archivos del nuevo intento.
Una validación de perfiles no ejecutada queda no evaluada aunque la sesión
local se acepte. Se pueden aceptar pendientes menores explícitos o repetir
tras correcciones; la decisión automática nunca sustituye la humana.

## Continuidad entre rondas

Conserve 2.0 con sus fichas y hashes si ya comenzó esa ronda. Use 2.1 en una
ronda nueva o tras acuerdo antes de iniciar tareas; las exportaciones anteriores
no se importan aquí. Los idiomas comparten tareas, criterios e identidad;
cambiar idioma conserva las respuestas sin traducirlas. El paquete R sigue
siendo el mismo candidato comprobado.
