# Evidencia del candidato R4

`MANIFIESTO.json` identifica el archivo fuente exacto, su SHA256/MD5, version
y commit de codigo. Los commits posteriores que solo conservan esta evidencia
no cambian el paquete comprobado. El archivo binario se entrega aparte; este
directorio no contiene ni publica un lanzamiento.

- R CMD build con vinetas y R CMD check: Status OK, sin notas, avisos o errores.
- Bateria local: 1663 comprobaciones; diez grupos de servidor omitidos en esta
  ejecucion, evaluados por separado mediante la integracion aislada.
- HAPI: 130 comprobaciones, ocho grupos obligatorios y las dos omisiones
  permitidas. Contenedor propio eliminado.
- PostgreSQL y SQL Server: 72 comprobaciones, diez grupos y ninguna omision.
  Registros de limpieza de ambos contenedores conservados en `sql-dbi/`.
- El mismo archivo instalado en bibliotecas nuevas aprobo los perfiles basico
  y completo. Ambos exigen el recorrido de cinco tipos y seis recursos.
- Un candidato anterior con el mismo numero 0.5.0.9000, pero informe antiguo,
  fue rechazado por el protocolo actual. La version sola no identifica el archivo.
- La pagina inicial, la referencia y el articulo de arquitectura pkgdown se
  construyeron localmente. Los 23 diagramas pasaron el parser Mermaid 10.9.1:
  diez en cada README y tres en el articulo. El HTML inicial conserva los
  diez diagramas y sustituye la imagen anterior. Se comprobaron los enlaces
  externos al protocolo. No se atribuye una inspeccion visual de navegador.

Para repetir la aceptacion desde el repositorio, con las dependencias presentes:

```sh
Rscript data-raw/probar-candidato.R /ruta/fhirviews_0.5.0.9000.tar.gz /ruta/nueva-basico basico
Rscript data-raw/probar-candidato.R /ruta/fhirviews_0.5.0.9000.tar.gz /ruta/nueva-completo completo
```

El perfil basico usa tablas R y V8; el completo exige DBI/DuckDB y SQL
parametrizado. La ayuda, las vinetas y los cinco estados esperados se verifican
desde el paquete instalado. Los protocolos estan en `inst/examples/PILOTO-R4.md`
y `inst/examples/PILOTO-MANTENEDOR.md` del codigo identificado.

La evaluacion humana, los perfiles propios, la eleccion de version estable y
el deposito Zenodo con DOI verificado permanecen pendientes. Estos informes
tecnicos no completan esos pasos. La exploracion R6 permanece fuera del paquete.
