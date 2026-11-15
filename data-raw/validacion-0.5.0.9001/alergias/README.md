# Comprobacion de 0.5.0.9001

El manifiesto identifica el commit fuente y el tar.gz exacto construido con
sus vinetas. Ese mismo archivo se instalo en dos bibliotecas nuevas y paso
los perfiles basico y completo. Los informes mantienen pendiente la evaluacion
humana; no son una aprobacion del piloto externo ni de perfiles propios.

R CMD check --no-manual termino con Status: OK, sin errores, advertencias ni
notas. Sus omisiones dependen de skip_on_cran y de los servidores. Las pruebas
dirigidas del catalogo se ejecutaron aparte con NOT_CRAN=true, incluyendo
V8/DuckDB y lotes estrictos. La CI agrega HAPI, DBI, las cinco configuraciones R
y la paridad del laboratorio Rust. Consultar el resultado del commit de la PR.

Los archivos de este directorio se agregan despues del ensayo y quedan fuera
del paquete R. No se cambian los checksums del candidato para incorporar estos
registros. La version 0.5.0.9000 y sus DOI/mediciones permanecen historicos.
