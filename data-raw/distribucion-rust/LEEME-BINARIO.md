# fhirviews: componente Rust externo / external Rust component

Este ZIP contiene un ejecutable para un unico sistema y arquitectura. No
contiene el paquete R. Requiere fhirviews >= 0.5.0.9002 para utilizar la API R.
No instala Cargo, rustc ni Rtools y no modifica PATH ni el registro del sistema.

Comprueba el SHA-256 del ZIP contra el catalogo HTTPS del proyecto antes de
descomprimirlo. MANIFIESTO.json identifica version, protocolo, arquitectura,
commit fuente y hashes de cada archivo. SHA256SUMS permite verificarlos de
nuevo. Las licencias y atribuciones se encuentran en licencias/ y
DEPENDENCIAS.json. El ejecutable no esta firmado ni notarizado.

Selecciona la ruta bin/fhirviews-rust-validator (bin/fhirviews-rust-validator.exe
en Windows) con fhirviews::fhir_componente_rust(ruta, fallback = FALSE).
R sigue siendo la opcion predeterminada. El ejecutable valida estructuras
construidas y tipificadas por R; no evalua FHIRPath, convierte versiones ni
sustituye la validacion de perfiles clinicos. No usa la red.

This ZIP contains an executable for one operating system and architecture,
not the R package. It uses fhirviews >= 0.5.0.9002 and does not install Rust,
Rtools, edit PATH or change the system registry. Verify the ZIP SHA-256 against
the project's HTTPS catalogue before extraction. MANIFIESTO.json records
source, platform, protocol and file hashes. Licences and notices are included.
The executable is unsigned and not notarized. R remains the default.

Full instructions / instrucciones:
https://github.com/f-slg/fhirviews/tree/main/componentes/rust
