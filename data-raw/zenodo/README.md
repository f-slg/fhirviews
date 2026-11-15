# Archivo de fhirviews en Zenodo

El DOI se puede emitir antes de que CRAN publique el paquete. Son procesos
independientes. El candidato R4 de desarrollo 0.5.0.9000 ya esta publicado;
el 0.5.0 enviado a CRAN corresponde a otro artefacto. No se modifica ese envio.

## Publicacion comprobada

- Version: [10.5281/zenodo.24238726](https://doi.org/10.5281/zenodo.24238726).
- Concepto: [10.5281/zenodo.24238725](https://doi.org/10.5281/zenodo.24238725).
- Fuente archivada: commit `565243ec06f4dad88e898761a98a4f23c9fe8f95`.
- GitHub: prerelease `v0.5.0.9000`, sin cambiar la release estable Latest.
- Registro de comprobaciones: [publicacion-0.5.0.9000.json](publicacion-0.5.0.9000.json).

Se descargaron los bytes del archivo que realmente preserva Zenodo, se
comprobo su MD5 publicado y se calculo SHA256. Los 345 archivos del ZIP
coinciden con git archive del commit fijado; el DOI resuelve al registro.
Ese ZIP automatico tiene un prefijo y hash distintos del ZIP preparado como
asset GitHub. El tar.gz R probado solo consta como asset GitHub, no como
archivo de este registro Zenodo. No se modifica un archivo ya publicado para
agregar retroactivamente un DOI que no existia al generar el lanzamiento.

Los comandos de preparacion siguientes deben seguir usando `--ref 565243e`
para reproducir este archivo. Un HEAD posterior con cambios en inst/CITATION
ya no coincide byte a byte con el tar.gz anterior y debe rechazarse como
fuente de ese candidato. Una futura version necesita nuevos metadatos,
artefactos y DOI de version dentro de la misma familia del proyecto.

## Identidad y archivos

- Autor: Ronald Fabricio Salas Guerrero; ORCID 0000-0001-5077-1522.
- Tipo: software; licencia principal MIT y atribuciones incluidas en el codigo.
- Version: DESCRIPTION, CITATION.cff, .zenodo.json y etiqueta deben concordar.
- Fuente: ZIP generado directamente desde un commit Git inmutable. Solo usa
  archivos versionados; no lee tokens del entorno ni incorpora experimentos
  locales sin seguimiento.
- Paquete R: el archivo previamente comprobado, con el SHA256 de su manifiesto.
  Se entrega como asset complementario de GitHub; no se presume que Zenodo
  archive automaticamente todos los assets de una release.
- Manifiesto: identifica ambos archivos, el commit, los hashes y la preparacion.

El script verifica version y ORCID en los metadatos, el checksum ORCID, la
identidad SHA256 del paquete R y que el codigo R/inst/tests del commit coincida
con el candidato probado. Las diferencias de documentacion se declaran aparte.
No instala dependencias, cambia Git ni realiza peticiones a servicios.

```sh
python3 data-raw/preparar-zenodo.py --ref SHA-COMPLETO \
  --paquete /ruta/fhirviews_0.5.0.9000.tar.gz --salida /ruta/nueva-zenodo
```

## Conexion requerida

1. Iniciar sesion en https://zenodo.org/ y vincular GitHub.
2. En https://zenodo.org/account/settings/github/, sincronizar y activar
   f-slg/fhirviews **antes** de publicar la release que se desea archivar.
3. Vincular ORCID en las cuentas conectadas de Zenodo. Es una accion personal
   de la cuenta; un identificador en .zenodo.json no realiza esa vinculacion.

El script y el acceso GitHub no sustituyen la autenticacion en Zenodo. Los
tokens se configuran por un mecanismo seguro, no se guardan en archivos Git
ni se incluyen en un manifiesto o en las notas de la release.

## Publicacion y comprobacion

Para este archivo se preparo un borrador GitHub separado con etiqueta v0.5.0.9000, marcado como
prerelease/candidato R4 de desarrollo. Una vez verificada la conexion se puede
publicar esa version identificada, sin convertirla en una version estable.
Los borradores no emiten DOI. La integracion debe confirmarse con el registro
real de Zenodo; el indicador de prerelease no se usa para suponer que habra o
no habra archivo automatico.

Despues de publicar:

1. Obtener el registro Zenodo, su DOI de version y su DOI de concepto.
2. Comprobar version, autor/ORCID, licencia, origen GitHub y archivos archivados.
3. Verificar el ZIP y los hashes disponibles. El paquete R se identifica con
   su propio manifiesto; el ZIP del repositorio y el tar.gz son archivos distintos.
4. Comprobar que el DOI resuelve al registro correcto. Un identificador reservado
   o un texto con formato DOI no prueban una publicacion.
5. Agregar los DOI reales a CFF, citation(), README y el registro local de archivo,
   manteniendo la asociacion con la version archivada. Evitar atribuir ese DOI
   de version a futuras versiones con otro codigo.

Si la integracion no crea el registro, revisar el error en Zenodo antes de
reintentar. La alternativa es una carga manual del ZIP fuente identificado;
se revisa primero si ya existe un registro para evitar familias DOI duplicadas.
Para Software Heritage se sigue el requisito oficial de un solo archivo
comprimido en el deposito. El borrador GitHub puede conservar assets adicionales.

La emision de un DOI no acredita revision por CRAN, validacion de perfiles
clinicos, evaluacion con usuarios ni rendimiento de Rust.

## Seguimiento de CRAN

La cola publica https://cran.r-project.org/incoming/newbies/ muestra archivos
y fechas, no turnos garantizados. La instantanea cran-estado-20261115.json
conserva el recuento observado: posicion por fecha entre archivos, no una
prioridad oficial ni una estimacion del dia de revision. Ese dato cambia y
no se inserta como un contador permanente en README.

## Fuentes oficiales

- https://help.zenodo.org/docs/github/enable-repository/
- https://help.zenodo.org/docs/github/archive-software/github-upload/
- https://help.zenodo.org/docs/github/archive-software/manual-upload/
- https://help.zenodo.org/docs/github/describe-software/zenodo-json/
