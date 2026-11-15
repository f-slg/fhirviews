"""Coloca comandos que fallan delante de Cargo/rustc/rustup para el consumidor CI."""
import os
from pathlib import Path
import sys

carpeta = Path(sys.argv[1])
carpeta.mkdir()
for nombre in ("cargo", "rustc", "rustup"):
    archivo = carpeta / (nombre + (".cmd" if os.name == "nt" else ""))
    contenido = ('@echo compiler-called>>"%FHIRVIEWS_COMPILER_MARKER%"\n@exit /b 97\n' if os.name == "nt" else
                 '#!/bin/sh\nprintf "compiler-called\\n" >> "$FHIRVIEWS_COMPILER_MARKER"\nexit 97\n')
    archivo.write_text(contenido)
    archivo.chmod(0o755)
print(carpeta.resolve())
