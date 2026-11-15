"""Pruebas de publicacion con cabeceras sinteticas; no son pruebas FHIR."""
import json
from pathlib import Path
import shutil
import stat
import struct
import tempfile
import unittest
import zipfile

import paquetes as p
import publicar
from test_paquetes import archivos, ROOT, TARGET, pe

COMMIT = "a" * 40


class Publicacion(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.artefactos = self.base / "artefactos"
        self.artefactos.mkdir()
        for target, (sistema, arquitectura, plataforma) in p.TARGETS.items():
            datos = {n[len(ROOT)+1:]: b for n, b in archivos().items()}
            m = json.loads(datos.pop("MANIFIESTO.json")); datos.pop("SHA256SUMS")
            if sistema == "Windows":
                datos["bin/fhirviews-rust-validator.exe"] = pe()
                datos.pop("bin/fhirviews-rust-validator")
            elif sistema == "Darwin":
                b = bytearray(64); b[:4] = b"\xcf\xfa\xed\xfe"
                struct.pack_into("<I", b, 4, 0x01000007 if arquitectura == "x86_64" else 0x0100000C)
                datos["bin/fhirviews-rust-validator"] = bytes(b)
            root = "fhirviews-rust-validator-0.1.0-" + target
            exe = "bin/fhirviews-rust-validator" + (".exe" if sistema == "Windows" else "")
            m.update(target=target, sistema=sistema, arquitectura=arquitectura, plataforma=plataforma,
                     directorio=root, ejecutable=exe, binario=p.analizar_binario(datos[exe], target))
            m["ficheros"] = {n: {"sha256": p.sha(b), "bytes": len(b)} for n, b in datos.items()}
            datos["MANIFIESTO.json"] = p.json_bytes(m)
            datos["SHA256SUMS"] = "".join(f"{p.sha(b)}  {n}\n" for n, b in sorted(datos.items())).encode()
            carpeta = self.artefactos / ("binario-" + target); carpeta.mkdir()
            z = carpeta / (root + ".zip")
            with zipfile.ZipFile(z, "x") as f:
                for n, b in datos.items():
                    i = zipfile.ZipInfo(root + "/" + n); i.create_system = 3
                    i.external_attr = (stat.S_IFREG | 0o644) << 16
                    f.writestr(i, b)
            (carpeta / (z.name + ".sha256")).write_bytes(f"{p.sha(z.read_bytes())}  {z.name}\n".encode())
            (carpeta / "MANIFIESTO.json").write_bytes(datos["MANIFIESTO.json"])
            c = {"estado": "aprobado", "compilador_invocado": False, "target": target,
                 "commit_fuente": COMMIT, "version_componente": "0.1.0", "sha256_binario": p.sha(datos[exe]),
                 "comprobaciones": 10,
                 "grupos": [dict(test="siete recursos " + str(i), failed=0, error=False, warning=0, skipped=False, passed=1) for i in range(10)]}
            carpeta = self.artefactos / ("consumidor-" + target); carpeta.mkdir()
            (carpeta / "consumidor.json").write_bytes(p.json_bytes(c))

    def preparar(self, anterior=lambda _: {}):
        return publicar.preparar(self.artefactos, self.base / "publicar", COMMIT, anterior)

    def test_publica_cuatro_plataformas_con_fuente_y_hashes(self):
        c = self.preparar()
        self.assertEqual(set(c["plataformas"]), {v[2] for v in p.TARGETS.values()})
        for e in c["plataformas"].values():
            ruta = self.base / "publicar" / e["url"][len(publicar.BASE):]
            self.assertEqual(p.sha(ruta.read_bytes()), e["sha256"])
            self.assertEqual(e["comprobaciones"], 10)
        self.assertTrue(c["inmutable"].endswith(COMMIT + "/MANIFIESTO-DISTRIBUCION.json"))

    def test_no_publica_si_falta_una_plataforma(self):
        shutil.rmtree(self.artefactos / "binario-aarch64-apple-darwin")
        with self.assertRaises(ValueError): self.preparar()
        self.assertFalse((self.base / "publicar").exists())

    def test_rechaza_consumidor_de_otro_binario_o_con_fallos(self):
        ruta = self.artefactos / ("consumidor-" + TARGET) / "consumidor.json"
        original = json.loads(ruta.read_bytes())
        for cambio in ({"sha256_binario": "b" * 64}, {"commit_fuente": "b" * 40}, {"compilador_invocado": True}, {"comprobaciones": 0}):
            ruta.write_bytes(p.json_bytes(dict(original, **cambio)))
            with self.assertRaises(ValueError): self.preparar()
        original["grupos"][0]["skipped"] = True
        ruta.write_bytes(p.json_bytes(original))
        with self.assertRaises(ValueError): self.preparar()

    def test_sha_alterado_y_fuente_distinta_no_publican(self):
        z = next((self.artefactos / ("binario-" + TARGET)).glob("*.zip"))
        z.write_bytes(z.read_bytes() + b"tamper")
        with self.assertRaises(ValueError): self.preparar()
        with self.assertRaises(ValueError):
            publicar.preparar(self.artefactos, self.base / "nuevo", "b" * 40, lambda _: {})

    def test_repetir_conserva_bytes_publicados_aunque_cambie_el_nuevo_zip(self):
        c = self.preparar()
        prefijo = "componentes/rust/0.1.0/" + COMMIT
        carpeta = self.base / "publicar" / prefijo
        previos = {f.name: f.read_bytes() for f in carpeta.iterdir()}
        z = next((self.artefactos / ("binario-" + TARGET)).glob("*.zip"))
        z.write_bytes(z.read_bytes() + b"new-build-metadata")
        (z.parent / (z.name + ".sha256")).write_bytes(f"{p.sha(z.read_bytes())}  {z.name}\n".encode())
        nuevo = publicar.preparar(self.artefactos, self.base / "repetir", COMMIT, lambda _: previos)
        self.assertEqual(nuevo, c)
        for f in (self.base / "repetir" / prefijo).iterdir(): self.assertEqual(f.read_bytes(), previos[f.name])

    def test_publicacion_previa_incompleta_no_se_sobrescribe(self):
        self.preparar()
        carpeta = self.base / "publicar/componentes/rust/0.1.0" / COMMIT
        previos = {f.name: f.read_bytes() for f in carpeta.iterdir() if not f.name.endswith(".sha256")}
        with self.assertRaises(KeyError):
            publicar.preparar(self.artefactos, self.base / "repetir", COMMIT, lambda _: previos)
        self.assertFalse((self.base / "repetir").exists())


if __name__ == "__main__":
    unittest.main()
