# Archivo de fhirviews en Zenodo

El DOI se puede emitir antes de que CRAN publique el paquete. Son procesos
independientes. Este archivo prepara el candidato R4 de desarrollo 0.5.0.9000;
el 0.5.0 enviado a CRAN corresponde a otro artefacto. No se modifica ese envio.

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

Se prepara un borrador GitHub separado con etiqueta v0.5.0.9000, marcado como
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
