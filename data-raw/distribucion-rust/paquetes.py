"""Paquetes del componente externo; solo usa la biblioteca estandar de Python.

Crear requiere un binario local compilado y metadatos Cargo. Verificar y
extraer nunca ejecutan el contenido del ZIP ni invocan Cargo o rustc.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import struct
import subprocess
import zipfile

REPO = Path(__file__).resolve().parents[2]
CONTRATO = "fhirviews-r4-validator/1"
TARGETS = {
    "x86_64-unknown-linux-musl": ("Linux", "x86_64", "linux-x86_64"),
    "x86_64-pc-windows-msvc": ("Windows", "x86_64", "windows-x86_64"),
    "x86_64-apple-darwin": ("Darwin", "x86_64", "macos-intel"),
    "aarch64-apple-darwin": ("Darwin", "arm64", "macos-apple-silicon"),
}
MAX_TOTAL = 64 * 1024 * 1024
MAX_FILE = 32 * 1024 * 1024
NOMBRE = re.compile(r"[A-Za-z0-9_+-][A-Za-z0-9._+-]*\Z")
LICENCIA = re.compile(r"^(LICENSE|LICENCE|COPYING|COPYRIGHT|NOTICE|AUTHORS|UNICODE-LICENSE)([._-].*)?$", re.I)


def exigir(condicion, mensaje):
    if not condicion:
        raise ValueError(mensaje)


def sha(datos):
    return hashlib.sha256(datos).hexdigest()


def ruta_segura(nombre):
    partes = PurePosixPath(nombre).parts
    exigir(partes and not nombre.startswith("/") and "\\" not in nombre,
           "Ruta absoluta o separador no admitido")
    exigir(nombre == "/".join(partes), "Ruta no canonica")
    reservados = {"con", "prn", "aux", "nul"} | {f"{p}{n}" for p in ("com", "lpt") for n in range(1, 10)}
    for p in partes:
        exigir(p not in (".", "..") and NOMBRE.fullmatch(p) and not p.endswith("."), "Nombre de archivo no admitido")
        exigir(p.split(".")[0].lower() not in reservados, "Nombre reservado en Windows")
    return partes


def json_bytes(objeto):
    return (json.dumps(objeto, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode()


def analizar_binario(datos, target):
    exigir(target in TARGETS and len(datos) >= 64, "Binario o target no admitido")
    sistema, arquitectura, _ = TARGETS[target]
    if sistema == "Linux":
        exigir(datos[:6] == b"\x7fELF\x02\x01" and struct.unpack_from("<H", datos, 18)[0] == 62,
               "Se requiere ELF Linux x86_64")
        inicio = struct.unpack_from("<Q", datos, 32)[0]
        ancho, cantidad = struct.unpack_from("<HH", datos, 54)
        exigir(ancho >= 56 and cantidad > 0 and inicio + ancho * cantidad <= len(datos), "Cabecera ELF incompleta")
        for i in range(cantidad):
            h = struct.unpack_from("<IIQQQQQQ", datos, inicio + i * ancho)
            exigir(h[0] != 3, "El binario Linux requiere un interprete dinamico")
            if h[0] == 2:
                exigir(h[2] + h[5] <= len(datos) and h[5] % 16 == 0, "Tabla dinamica ELF incompleta")
                for j in range(h[2], h[2] + h[5], 16):
                    exigir(struct.unpack_from("<q", datos, j)[0] != 1, "El binario Linux depende de una biblioteca dinamica")
        return {"formato": "ELF64", "enlace": "static-musl"}
    if sistema == "Darwin":
        exigir(datos[:4] == b"\xcf\xfa\xed\xfe", "Se requiere un binario Mach-O de 64 bits")
        esperado = 0x01000007 if arquitectura == "x86_64" else 0x0100000C
        exigir(struct.unpack_from("<I", datos, 4)[0] == esperado, "Arquitectura Mach-O incorrecta")
        return {"formato": "Mach-O64", "enlace": "libSystem", "notarizado": False}
    exigir(datos[:2] == b"MZ", "Se requiere un ejecutable Windows PE")
    pe = struct.unpack_from("<I", datos, 60)[0]
    exigir(pe >= 64 and pe + 24 <= len(datos) and datos[pe:pe+4] == b"PE\0\0", "Cabecera PE incompleta")
    maquina, secciones = struct.unpack_from("<HH", datos, pe + 4)
    ancho = struct.unpack_from("<H", datos, pe + 20)[0]
    opt = pe + 24
    exigir(maquina == 0x8664 and ancho >= 128 and opt + ancho + secciones * 40 <= len(datos), "Se requiere PE Windows x86_64")
    exigir(struct.unpack_from("<H", datos, opt)[0] == 0x20B, "Se requiere PE32+")

    def offset(rva):
        for i in range(secciones):
            h = opt + ancho + i * 40
            virtual_size, virtual, raw_size, raw = struct.unpack_from("<IIII", datos, h + 8)
            if virtual <= rva < virtual + max(virtual_size, raw_size):
                pos = raw + rva - virtual
                exigir(pos < len(datos), "RVA fuera del archivo")
                return pos
        raise ValueError("RVA no encontrado")

    rva, tamano = struct.unpack_from("<II", datos, opt + 120)
    dlls = []
    if rva:
        inicio = offset(rva)
        for i in range(1024):
            pos = inicio + i * 20
            exigir(pos + 20 <= len(datos), "Tabla de importacion PE incompleta")
            entrada = struct.unpack_from("<IIIII", datos, pos)
            if not any(entrada):
                break
            nombre = offset(entrada[3])
            fin = datos.find(b"\0", nombre, nombre + 1024)
            exigir(fin != -1, "Nombre DLL incompleto")
            dlls.append(datos[nombre:fin].decode("ascii"))
        else:
            raise ValueError("Demasiadas importaciones PE")
    exigir(not any(re.search(r"vcruntime|msvcp|msvcr|ucrtbase|api-ms-win-crt", d, re.I) for d in dlls),
           "El ejecutable requiere un runtime C adicional; compilar con +crt-static")
    return {"formato": "PE32+", "enlace": "crt-static", "dll_sistema": sorted(dlls)}


def crear(binario, target, metadata, rust_root, salida, commit, runner, flags=""):
    exigir(re.fullmatch(r"[0-9a-f]{40}", commit), "Commit no valido")
    exigir(target in TARGETS and not salida.exists(), "Target no admitido o salida existente")
    exigir(binario.is_file() and not binario.is_symlink(), "El binario debe ser un archivo regular")
    datos_binario = binario.read_bytes()
    enlace = analizar_binario(datos_binario, target)
    r = subprocess.run([str(binario.resolve()), "--capabilities"], check=True, capture_output=True, timeout=15)
    capacidades = json.loads(r.stdout)
    exigir(capacidades.get("contrato") == CONTRATO and capacidades.get("version_fhir") == "4.0.1"
           and capacidades.get("componente") == "fhirviews-rust-validator"
           and capacidades.get("alcance") == "recursos-construidos-y-tipados-por-r", "Capacidades incompatibles")
    version = capacidades["version"]
    exigir(re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version), "Version no admitida")
    paquetes = json.loads(metadata.read_bytes())["packages"]
    raiz = next(p for p in paquetes if p["name"] == "fhirviews-rust-validator")
    exigir(raiz["version"] == version, "Version Cargo distinta de la del ejecutable")
    nombre_binario = "fhirviews-rust-validator" + (".exe" if TARGETS[target][0] == "Windows" else "")
    ficheros = {"bin/" + nombre_binario: datos_binario,
                "LICENSE": (REPO / "componentes/rust/LICENSE").read_bytes(),
                "Cargo.lock": (REPO / "componentes/rust/Cargo.lock").read_bytes()}
    dependencias = []
    for p in sorted(paquetes, key=lambda p: (p["name"], p["version"])):
        if p["name"] == raiz["name"]:
            continue
        exigir(p.get("license"), "Dependencia sin licencia declarada")
        carpeta = Path(p["manifest_path"]).parent
        avisos = []
        for archivo in sorted(carpeta.rglob("*")):
            if not archivo.is_file() or not LICENCIA.fullmatch(archivo.name):
                continue
            exigir(not archivo.is_symlink() and archivo.resolve().is_relative_to(carpeta.resolve()), "Licencia fuera de su paquete")
            destino = f"licencias/{p['name']}-{p['version']}/{archivo.relative_to(carpeta).as_posix()}"
            ruta_segura(destino)
            ficheros[destino] = archivo.read_bytes()
            avisos.append(destino)
        exigir(avisos, f"No se encontraron avisos de licencia para {p['name']}")
        dependencias.append({"nombre": p["name"], "version": p["version"], "licencia": p["license"],
                            "repositorio": p.get("repository"), "autores": p.get("authors", []), "avisos": avisos})
    for nombre in ("COPYRIGHT", "LICENSE-APACHE", "LICENSE-MIT"):
        ficheros["licencias/rust/" + nombre] = (rust_root / "share/doc/rust" / nombre).read_bytes()
    if target.endswith("linux-musl"):
        aviso = REPO / "data-raw/distribucion-rust/licencias/MUSL-COPYRIGHT-1.2.3"
        exigir(sha(aviso.read_bytes()) == "f9bc4423732350eb0b3f7ed7e91d530298476f8fec0c6c427a1c04ade22655af", "Aviso musl inesperado")
        ficheros["licencias/musl-1.2.3/COPYRIGHT"] = aviso.read_bytes()
    ficheros["DEPENDENCIAS.json"] = json_bytes(dependencias)
    ficheros["LEEME.md"] = (REPO / "data-raw/distribucion-rust/LEEME-BINARIO.md").read_bytes()
    nombre_raiz = f"fhirviews-rust-validator-{version}-{target}"
    for nombre in ficheros:
        ruta_segura(nombre)
    compilador = subprocess.check_output([str(rust_root / "bin" / ("rustc.exe" if os.name == "nt" else "rustc")), "--version"], text=True).strip()
    manifiesto = {"formato": 1, "componente": "fhirviews-rust-validator", "version": version,
        "contrato": CONTRATO, "version_fhir": "4.0.1", "target": target, "directorio": nombre_raiz,
        "ejecutable": "bin/" + nombre_binario, "sistema": TARGETS[target][0], "arquitectura": TARGETS[target][1],
        "plataforma": TARGETS[target][2], "commit_fuente": commit,
        "fuente": "https://github.com/f-slg/fhirviews/tree/" + commit,
        "rustc": compilador, "runner": runner, "rustflags": flags, "binario": enlace,
        "firmado": False, "sha256_cargo_lock": sha(ficheros["Cargo.lock"]),
        "ficheros": {n: {"sha256": sha(b), "bytes": len(b)} for n, b in sorted(ficheros.items())}}
    ficheros["MANIFIESTO.json"] = json_bytes(manifiesto)
    ficheros["SHA256SUMS"] = "".join(f"{sha(b)}  {n}\n" for n, b in sorted(ficheros.items())).encode()
    salida.mkdir(parents=False)
    archivo_zip = salida / (nombre_raiz + ".zip")
    with zipfile.ZipFile(archivo_zip, "x", compression=zipfile.ZIP_STORED) as z:
        for nombre, datos in sorted(ficheros.items()):
            i = zipfile.ZipInfo(nombre_raiz + "/" + nombre, date_time=(1980, 1, 1, 0, 0, 0))
            i.create_system = 3
            i.external_attr = (stat.S_IFREG | (0o755 if nombre.startswith("bin/") else 0o644)) << 16
            z.writestr(i, datos)
    digest = sha(archivo_zip.read_bytes())
    (salida / (archivo_zip.name + ".sha256")).write_bytes(f"{digest}  {archivo_zip.name}\n".encode())
    (salida / "MANIFIESTO.json").write_bytes(ficheros["MANIFIESTO.json"])
    verificar(archivo_zip, digest)
    return archivo_zip


def verificar(archivo, esperado, destino=None):
    exigir(re.fullmatch(r"[0-9a-f]{64}", esperado), "SHA-256 esperado no valido")
    exigir(sha(archivo.read_bytes()) == esperado, "SHA-256 del ZIP no coincide")
    with zipfile.ZipFile(archivo) as z:
        entradas = z.infolist()
        exigir(1 <= len(entradas) <= 1024, "Numero de archivos no admitido")
        nombres = [i.filename for i in entradas]
        exigir(len({n.casefold() for n in nombres}) == len(nombres), "Nombres duplicados")
        partes = [ruta_segura(n) for n in nombres]
        raices = {p[0] for p in partes}
        exigir(len(raices) == 1 and all(len(p) > 1 for p in partes), "Se requiere una raiz unica")
        raiz = next(iter(raices))
        exigir(all(not i.is_dir() and stat.S_IFMT(i.external_attr >> 16) in (0, stat.S_IFREG) for i in entradas), "Entradas no regulares")
        exigir(sum(i.file_size for i in entradas) <= MAX_TOTAL and all(i.file_size <= MAX_FILE for i in entradas), "Paquete demasiado grande")
        m = json.loads(z.read(raiz + "/MANIFIESTO.json"))
        exigir(m.get("formato") == 1 and m.get("componente") == "fhirviews-rust-validator"
               and m.get("contrato") == CONTRATO and m.get("version_fhir") == "4.0.1", "Manifiesto no admitido")
        exigir(m.get("target") in TARGETS and m.get("directorio") == raiz, "Target o raiz incompatible")
        exigir(re.fullmatch(r"[0-9a-f]{40}", m.get("commit_fuente", "")), "Commit del paquete no valido")
        exigir(re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", m.get("version", "")) and
               raiz == f"fhirviews-rust-validator-{m['version']}-{m['target']}", "Version o directorio no coincide")
        exigir(m.get("fuente") == "https://github.com/f-slg/fhirviews/tree/" + m["commit_fuente"], "Fuente no admitida")
        exigir((m.get("sistema"), m.get("arquitectura"), m.get("plataforma")) == TARGETS[m["target"]], "Plataforma no coincide")
        ficheros = m["ficheros"]
        obligatorios = {m["ejecutable"], "LICENSE", "DEPENDENCIAS.json", "Cargo.lock", "LEEME.md",
                        "licencias/rust/COPYRIGHT", "licencias/rust/LICENSE-MIT", "licencias/rust/LICENSE-APACHE"}
        exigir(isinstance(ficheros, dict) and obligatorios.issubset(ficheros), "Faltan archivos obligatorios")
        esperados = {raiz + "/" + n for n in ficheros} | {raiz + "/MANIFIESTO.json", raiz + "/SHA256SUMS"}
        exigir(set(nombres) == esperados, "Archivos adicionales o ausentes")
        datos = {}
        for n, info in ficheros.items():
            ruta_segura(n)
            b = z.read(raiz + "/" + n)
            exigir(len(b) == info["bytes"] and sha(b) == info["sha256"], "Hash de archivo no coincide")
            datos[n] = b
        exigir(m["ejecutable"] == "bin/fhirviews-rust-validator" + (".exe" if TARGETS[m["target"]][0] == "Windows" else ""), "Ejecutable no admitido")
        exigir(analizar_binario(datos[m["ejecutable"]], m["target"]) == m["binario"], "Formato o enlace no coincide")
        exigir(sha(datos["Cargo.lock"]) == m["sha256_cargo_lock"], "Cargo.lock no coincide")
        sumas = "".join(f"{sha(z.read(raiz + '/' + n))}  {n}\n" for n in sorted(list(ficheros) + ["MANIFIESTO.json"]))
        exigir(z.read(raiz + "/SHA256SUMS") == sumas.encode(), "SHA256SUMS no coincide")
        if destino is not None:
            exigir(not destino.exists() and not destino.is_symlink(), "La carpeta de destino ya existe")
            destino.mkdir(mode=0o700)
            try:
                for nombre, b in datos.items():
                    p = destino / raiz / nombre
                    p.parent.mkdir(parents=True, exist_ok=True)
                    with p.open("xb") as f:
                        f.write(b)
                for nombre in ("MANIFIESTO.json", "SHA256SUMS"):
                    (destino / raiz / nombre).write_bytes(z.read(raiz + "/" + nombre))
                (destino / raiz / m["ejecutable"]).chmod(0o755)
            except BaseException:
                shutil.rmtree(destino)
                raise
    return m


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="accion", required=True)
    c = sub.add_parser("crear")
    for nombre in ("binario", "metadata", "rust-root", "salida"):
        c.add_argument("--" + nombre, type=Path, required=True)
    for nombre in ("target", "commit", "runner"):
        c.add_argument("--" + nombre, required=True)
    c.add_argument("--flags", default="")
    v = sub.add_parser("verificar")
    v.add_argument("archivo", type=Path)
    v.add_argument("--sha256", required=True)
    v.add_argument("--extraer", type=Path)
    a = p.parse_args()
    if a.accion == "crear":
        print(crear(a.binario, a.target, a.metadata, a.rust_root, a.salida, a.commit, a.runner, a.flags))
    else:
        m = verificar(a.archivo, a.sha256, a.extraer)
        print(json.dumps({k: m[k] for k in ("componente", "version", "target", "commit_fuente")}))


if __name__ == "__main__":
    main()
