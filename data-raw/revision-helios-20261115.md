# Revision de Helios y decisiones para fhirviews

Revision documental y de codigo del 15 de noviembre de 2026, fijada al commit
Helios **3cf136209a1e5fc487d4dec8566f4b172c7f6267**. No se ejecuto Helios ni se
realizo una comparacion de rendimiento entre ambos proyectos. Las decisiones
siguientes son inferencias de diseno, no resultados de un benchmark.

## Hallazgos y acciones

| Evidencia en Helios | Situacion de fhirviews | Decision |
|---|---|---|
| API de biblioteca `run_view_definition`, CLI y servidor separados; interfaces comunes para modelos por version. | Tenemos API R, V8 y DuckDB; el validador Rust era un laboratorio aislado. | Incorporar un componente opcional con contrato versionado y pruebas diferenciales, manteniendo una ruta R completa. Implementado en 0.5.0.9002 mediante CLI local, sin enlace nativo a la ABI de R. |
| Escritores Parquet/Arrow con esquema fijado antes de la primera fila; validan que cada lote corresponda al esquema. | La extraccion por lotes ya tiene un contrato estricto y DuckDB trabaja directamente con archivos. La construccion SQL a FHIR todavia recoge toda la consulta. | Conservar los rechazos estrictos; siguiente mejora: cursor DBI por bloques y escritura de salida que identifique correctamente los fallos parciales. Una salida Arrow directa es otra mejora posterior, con medicion de memoria y tipos. |
| Exportacion incremental por lotes y grupos Parquet; sus limites de memoria y fallos durante streaming estan documentados. | El componente Rust lee NDJSON por lineas, pero R mantiene el lote construido y su JSON en memoria. | Documentar ese limite y medir el consumo del flujo completo; no presentar el componente como un conversor completo con memoria acotada. |
| Modelos R4/R4B/R5/R6 seleccionados por version y funciones con interfaces comunes. | El modelo, los constructores y las pruebas actuales son R4. | Estabilizar R4. Compartir una interfaz futura por version y mantener procedencia, equivalencias y perdidas por recurso antes de ofrecer conversion. Tener modelos de dos versiones no demuestra conversion reversible entre ellas. |
| Sesiones de terminologia con cache por ejecucion y presupuesto de llamadas remotas; las respuestas transitorias tienen tratamiento distinto. | Ya existe cliente terminologico y las vistas pueden incorporar expansiones como constantes locales. | Futuro: cache limitada a una ejecucion, con clave que incluya version y parametros, limites de llamadas y tratamiento explicito de errores transitorios. No introducir consultas de red implicitas en el componente estructural Rust. |

## Aplicacion a los constructores de laboratorio

Se incorporaron `Specimen` y `DiagnosticReport` desde snapshots base R4 4.0.1,
con version y SHA-256 del archivo fuente conservados. La lectura de las
definiciones oficiales evita introducir requisitos clinicos ajenos al modelo:
Specimen admite origen ambiental y no exige `subject` ni `status` en la base;
DiagnosticReport exige `status` y `code`, y permite multiples referencias
`result` a Observation y `specimen` a Specimen.

Las colecciones `result[].reference`, `specimen[].reference` y
`parent[].reference` reciben listas de valores primitivos por fila. Se
conservan orden y duplicados, se omiten ausentes y se rechazan destinos que
mezclen otros campos o indices del mismo arreglo. Los objetos complejos
generales siguen requiriendo indices explicitos para evitar uniones
ambiguas entre listas independientes. Los recursos referenciados deben
existir o construirse aparte; el mapa no los obtiene ni los crea por inferencia.

## Fuentes primarias

- [Helios SOF: API, modelos por version y exportacion](https://github.com/HeliosSoftware/hfs/blob/3cf136209a1e5fc487d4dec8566f4b172c7f6267/crates/sof/README.md).
- [Interfaces de modelos por version](https://github.com/HeliosSoftware/hfs/blob/3cf136209a1e5fc487d4dec8566f4b172c7f6267/crates/sof/src/traits.rs).
- [Escritores incrementales Parquet y Arrow](https://github.com/HeliosSoftware/hfs/blob/3cf136209a1e5fc487d4dec8566f4b172c7f6267/crates/sof/src/columnar_stream.rs).
- [Specimen R4](https://hl7.org/fhir/R4/specimen.html) y [DiagnosticReport R4](https://hl7.org/fhir/R4/diagnosticreport.html).
- [Rust y CRAN](https://cran.r-project.org/web/packages/using_rust.html).

Esta revision orienta el diseno. El codigo del componente procede del propio
laboratorio de fhirviews; no se copio ni enlazo el motor Helios, y no se
atribuyen a fhirviews su servidor, conectores cloud o soporte multiversion.
