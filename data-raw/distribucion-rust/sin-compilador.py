"""Coloca y comprueba bloqueadores de Cargo/rustc/rustup para el consumidor CI."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess

a = argparse.ArgumentParser(description=__doc__)
a.add_argument("carpeta", type=Path)
a.add_argument("--windows-stub", type=Path)
args = a.parse_args()
carpeta = args.carpeta
carpeta.mkdir()
if os.name == "nt":
    stub = args.windows_stub
    assert stub and stub.is_file()
    esperado = Path(str(stub) + ".sha256").read_text().split()[0]
    assert hashlib.sha256(stub.read_bytes()).hexdigest() == esperado
for nombre in ("cargo", "rustc", "rustup"):
    archivo = carpeta / (nombre + (".exe" if os.name == "nt" else ""))
    if os.name == "nt":
        shutil.copyfile(stub, archivo)
    else:
        archivo.write_text('#!/bin/sh\nprintf "compiler-called\\n" >> "$FHIRVIEWS_COMPILER_MARKER"\nexit 97\n')
    archivo.chmod(0o755)
    marcador = carpeta / "autoprueba.txt"
    r = subprocess.run([str(archivo.resolve()), "--version"],
                       env=dict(os.environ, FHIRVIEWS_COMPILER_MARKER=str(marcador.resolve())))
    assert r.returncode == 97 and marcador.read_text().strip() == "compiler-called"
    marcador.unlink()
print(carpeta.resolve())
