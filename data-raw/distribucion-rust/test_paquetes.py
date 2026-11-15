import importlib.util
import json
from pathlib import Path
import stat
import struct
import tempfile
import unittest
from unittest import mock
import zipfile

spec = importlib.util.spec_from_file_location("paquetes", Path(__file__).with_name("paquetes.py"))
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)
TARGET = "x86_64-unknown-linux-musl"
ROOT = "fhirviews-rust-validator-0.1.0-" + TARGET


def elf(interprete=False, needed=False):
    b = bytearray(136)
    b[:6] = b"\x7fELF\x02\x01"
    struct.pack_into("<H", b, 18, 62)
    struct.pack_into("<Q", b, 32, 64)
    struct.pack_into("<HH", b, 54, 56, 1)
    struct.pack_into("<IIQQQQQQ", b, 64, 3 if interprete else (2 if needed else 1), 0, 120, 0, 0, 16, 16, 8)
    if needed:
        struct.pack_into("<qQ", b, 120, 1, 0)
    return bytes(b)


def pe(dll="KERNEL32.dll"):
    b = bytearray(1280)
    b[:2] = b"MZ"; struct.pack_into("<I", b, 60, 128)
    b[128:132] = b"PE\0\0"
    struct.pack_into("<HH", b, 132, 0x8664, 1)
    struct.pack_into("<H", b, 148, 240)
    opt = 152
    struct.pack_into("<H", b, opt, 0x20B)
    struct.pack_into("<II", b, opt + 120, 0x1000, 40)
    struct.pack_into("<IIII", b, opt + 240 + 8, 768, 0x1000, 768, 512)
    struct.pack_into("<IIIII", b, 512, 1, 0, 0, 0x1100, 1)
    nombre = dll.encode() + b"\0"; b[768:768+len(nombre)] = nombre
    return bytes(b)


def archivos():
    datos = {"bin/fhirviews-rust-validator": elf(), "LICENSE": b"test licence\n", "Cargo.lock": b"version = 3\n",
             "LEEME.md": b"test documentation\n", "DEPENDENCIAS.json": b"[]\n",
             "licencias/rust/COPYRIGHT": b"notice\n", "licencias/rust/LICENSE-MIT": b"MIT\n",
             "licencias/rust/LICENSE-APACHE": b"Apache\n"}
    m = {"formato": 1, "componente": "fhirviews-rust-validator", "version": "0.1.0", "contrato": p.CONTRATO,
         "version_fhir": "4.0.1", "target": TARGET, "directorio": ROOT,
         "ejecutable": "bin/fhirviews-rust-validator", "commit_fuente": "a" * 40,
         "fuente": "https://github.com/f-slg/fhirviews/tree/" + "a" * 40,
         "sistema": "Linux", "arquitectura": "x86_64", "plataforma": "linux-x86_64",
         "sha256_cargo_lock": p.sha(datos["Cargo.lock"]), "binario": p.analizar_binario(elf(), TARGET),
         "ficheros": {n: {"sha256": p.sha(b), "bytes": len(b)} for n, b in datos.items()}}
    datos["MANIFIESTO.json"] = p.json_bytes(m)
    datos["SHA256SUMS"] = "".join(f"{p.sha(b)}  {n}\n" for n, b in sorted(datos.items())).encode()
    return {ROOT + "/" + n: b for n, b in datos.items()}


class Paquetes(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.carpeta = Path(self.tmp.name)

    def zip(self, datos, enlaces=()):
        ruta = self.carpeta / "paquete.zip"
        with zipfile.ZipFile(ruta, "w", compression=zipfile.ZIP_STORED) as z:
            for n, b in datos.items():
                i = zipfile.ZipInfo(n)
                i.create_system = 3
                i.external_attr = (stat.S_IFLNK if n in enlaces else stat.S_IFREG) << 16
                z.writestr(i, b)
        return ruta, p.sha(ruta.read_bytes())

    def rechazo(self, datos, enlaces=()):
        ruta, digest = self.zip(datos, enlaces)
        destino = self.carpeta / "nuevo"
        with self.assertRaises((ValueError, KeyError, zipfile.BadZipFile)):
            p.verificar(ruta, digest, destino)
        self.assertFalse(destino.exists())

    def test_extraer_no_ejecuta_ni_compila(self):
        datos = archivos(); ruta, digest = self.zip(datos)
        destino = self.carpeta / "con espacios"
        with mock.patch.object(p.subprocess, "run", side_effect=AssertionError("No ejecutar")):
            m = p.verificar(ruta, digest, destino)
        for n, b in datos.items():
            self.assertEqual((destino / n).read_bytes(), b)
        self.assertEqual(m["target"], TARGET)
        with self.assertRaises(ValueError):
            p.verificar(ruta, digest, destino)
        self.assertEqual((destino / ROOT / "LICENSE").read_bytes(), datos[ROOT + "/LICENSE"])

    def test_sha_externo_incorrecto_no_extrae(self):
        ruta, _ = self.zip(archivos()); destino = self.carpeta / "nuevo"
        with self.assertRaises(ValueError):
            p.verificar(ruta, "0" * 64, destino)
        self.assertFalse(destino.exists())

    def test_archivo_alterado_no_extrae(self):
        datos = archivos(); datos[ROOT + "/LICENSE"] = b"changed"
        self.rechazo(datos)

    def test_ficheros_ausentes_y_adicionales(self):
        datos = archivos(); del datos[ROOT + "/DEPENDENCIAS.json"]; self.rechazo(datos)
        datos = archivos(); datos[ROOT + "/extra.txt"] = b"extra"; self.rechazo(datos)

    def test_traversal_y_nombres_windows(self):
        for malo in ("../fuera", "/absoluto", ROOT + "/../fuera", ROOT + "/bin\\fuera", ROOT + "/CON.txt", ROOT + "/./archivo", ROOT + "//archivo"):
            datos = archivos(); datos[malo] = b"no"; self.rechazo(datos)
        self.assertFalse((self.carpeta / "fuera").exists())

    def test_enlace_simbolico_no_extrae(self):
        self.rechazo(archivos(), (ROOT + "/bin/fhirviews-rust-validator",))

    def test_colision_de_mayusculas_no_extrae(self):
        datos = archivos(); datos[ROOT + "/license"] = b"duplicate"; self.rechazo(datos)

    def test_manifiesto_de_otra_version_o_target(self):
        for campo, valor in (("contrato", "otro/2"), ("version_fhir", "6.0.0"), ("sistema", "Windows"), ("version", "0.2.0")):
            datos = archivos(); m = json.loads(datos[ROOT + "/MANIFIESTO.json"])
            m[campo] = valor; datos[ROOT + "/MANIFIESTO.json"] = p.json_bytes(m); self.rechazo(datos)

    def test_elf_dinamico_no_se_presenta_como_estatico(self):
        for b in (elf(interprete=True), elf(needed=True), b"invalid" * 20):
            with self.assertRaises(ValueError):
                p.analizar_binario(b, TARGET)

    def test_macho_distingue_intel_y_arm(self):
        for target, cpu in (("x86_64-apple-darwin", 0x01000007), ("aarch64-apple-darwin", 0x0100000C)):
            b = bytearray(64); b[:4] = b"\xcf\xfa\xed\xfe"; struct.pack_into("<I", b, 4, cpu)
            self.assertEqual(p.analizar_binario(bytes(b), target)["formato"], "Mach-O64")
            otro = "aarch64-apple-darwin" if target.startswith("x86") else "x86_64-apple-darwin"
            with self.assertRaises(ValueError):
                p.analizar_binario(bytes(b), otro)

    def test_pe_rechaza_runtime_c_dinamico(self):
        target = "x86_64-pc-windows-msvc"
        self.assertEqual(p.analizar_binario(pe(), target)["dll_sistema"], ["KERNEL32.dll"])
        for dll in ("VCRUNTIME140.dll", "ucrtbase.dll", "api-ms-win-crt-runtime-l1-1-0.dll"):
            with self.assertRaises(ValueError):
                p.analizar_binario(pe(dll), target)


if __name__ == "__main__":
    unittest.main()
