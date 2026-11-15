"""Publica cuatro paquetes comprobados en Pages, sin crear una release de R.

Las rutas con version y commit son inmutables. Repetir una ejecucion conserva
la publicacion anterior si sus paquetes y pruebas siguen siendo verificables.
El catalogo es el unico puntero mutable. No se ejecuta ningun binario aqui.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess

import paquetes as p

BASE = "https://f-slg.github.io/fhirviews/"


def comprobar_consumidor(datos, manifiesto):
    c = json.loads(datos)
    p.exigir(c.get("estado") == "aprobado" and c.get("compilador_invocado") is False,
             "El consumidor no aprobo sin compilador")
    for campo in ("target", "commit_fuente"):
        p.exigir(c.get(campo) == manifiesto[campo], "El consumidor corresponde a otro paquete")
    p.exigir(c.get("version_componente") == manifiesto["version"] and
             c.get("sha256_binario") == manifiesto["ficheros"][manifiesto["ejecutable"]]["sha256"],
             "El consumidor no probo este ejecutable")
    grupos = c.get("grupos", [])
    p.exigir(isinstance(grupos, list) and len(grupos) >= 10 and
             any("siete recursos" in g.get("test", "") for g in grupos), "Faltan pruebas de los siete recursos")
    p.exigir(all(g.get("failed") == 0 and g.get("error") is False and
                 g.get("warning") == 0 and not g.get("skipped") for g in grupos), "El consumidor tiene fallos o pruebas omitidas")
    p.exigir(c.get("comprobaciones", 0) == sum(g["passed"] for g in grupos) > 0,
             "Conteo de pruebas del consumidor no valido")
    return c


def comprobar_juego(ficheros, version, commit):
    """Comprueba tambien una publicacion anterior antes de reutilizarla."""
    d = json.loads(ficheros["MANIFIESTO-DISTRIBUCION.json"])
    p.exigir(d.get("formato") == 1 and d.get("version") == version and d.get("commit_fuente") == commit
             and d.get("contrato") == p.CONTRATO and d.get("version_fhir") == "4.0.1", "Distribucion anterior incompatible")
    entradas = d["paquetes"]
    p.exigir(set(entradas) == set(p.TARGETS), "La publicacion no contiene las cuatro plataformas")
    esperados = {"MANIFIESTO-DISTRIBUCION.json"}
    # El verificador ZIP recibe rutas: usa un temporal privado, sin extraer ni ejecutar.
    import tempfile
    with tempfile.TemporaryDirectory() as temporal:
        for target, e in entradas.items():
            nombre = f"fhirviews-rust-validator-{version}-{target}.zip"
            p.exigir(e.get("archivo") == nombre, "Nombre de paquete no admitido")
            manifiesto = nombre + ".MANIFIESTO.json"
            consumidor = nombre + ".consumidor.json"
            esperados.update((nombre, nombre + ".sha256", manifiesto, consumidor))
            z = Path(temporal) / nombre
            z.write_bytes(ficheros[nombre])
            m = p.verificar(z, e["sha256"])
            p.exigir(m["target"] == target and m["version"] == version and m["commit_fuente"] == commit,
                     "Fuente del paquete no coincide")
            p.exigir(ficheros[manifiesto] == p.json_bytes(m), "Manifiesto externo no coincide")
            p.exigir(ficheros[nombre + ".sha256"] == f"{e['sha256']}  {nombre}\n".encode(), "SHA externo no coincide")
            c = comprobar_consumidor(ficheros[consumidor], m)
            p.exigir(e.get("bytes") == len(ficheros[nombre]) and e.get("directorio") == m["directorio"] and
                     e.get("ejecutable") == m["ejecutable"] and e.get("plataforma") == m["plataforma"] and
                     e.get("sistema") == m["sistema"] and e.get("arquitectura") == m["arquitectura"] and
                     e.get("comprobaciones") == c["comprobaciones"], "Catalogo no coincide con el paquete")
    p.exigir(set(ficheros) == esperados, "Publicacion incompleta o con archivos inesperados")
    return d


def leer_git(prefijo):
    ref = "refs/remotes/origin/gh-pages"
    nombres = subprocess.check_output(["git", "ls-tree", "-rz", "--name-only", ref, "--", prefijo]).split(b"\0")
    return {n.decode()[len(prefijo)+1:]: subprocess.check_output(["git", "show", ref + ":" + n.decode()])
            for n in nombres if n}


def preparar(artefactos, salida, commit, anterior=leer_git):
    p.exigir(re.fullmatch(r"[0-9a-f]{40}", commit), "Commit no valido")
    p.exigir(not salida.exists(), "La salida ya existe")
    ficheros = {}
    entradas = {}
    versiones = set()
    for target in p.TARGETS:
        carpeta = artefactos / ("binario-" + target)
        zips = list(carpeta.glob("*.zip"))
        p.exigir(len(zips) == 1, "Falta un unico paquete para " + target)
        z = zips[0]
        checksum = (carpeta / (z.name + ".sha256")).read_bytes()
        m = p.verificar(z, checksum.decode().split()[0])
        p.exigir(m["target"] == target and m["commit_fuente"] == commit, "Paquete de otra plataforma o commit")
        consumidor = (artefactos / ("consumidor-" + target) / "consumidor.json").read_bytes()
        c = comprobar_consumidor(consumidor, m)
        versiones.add(m["version"])
        ficheros[z.name] = z.read_bytes()
        ficheros[z.name + ".sha256"] = checksum
        ficheros[z.name + ".MANIFIESTO.json"] = (carpeta / "MANIFIESTO.json").read_bytes()
        ficheros[z.name + ".consumidor.json"] = consumidor
        entradas[target] = {"archivo": z.name, "sha256": p.sha(ficheros[z.name]), "bytes": len(ficheros[z.name]),
            "plataforma": m["plataforma"], "directorio": m["directorio"], "ejecutable": m["ejecutable"],
            "sistema": m["sistema"], "arquitectura": m["arquitectura"], "comprobaciones": c["comprobaciones"]}
    p.exigir(len(versiones) == 1, "Se mezclaron versiones del componente")
    version = versiones.pop()
    d = {"formato": 1, "componente": "fhirviews-rust-validator", "version": version,
         "contrato": p.CONTRATO, "version_fhir": "4.0.1", "commit_fuente": commit,
         "paquetes": entradas}
    ficheros["MANIFIESTO-DISTRIBUCION.json"] = p.json_bytes(d)
    comprobar_juego(ficheros, version, commit)
    prefijo = f"componentes/rust/{version}/{commit}"
    previos = anterior(prefijo)
    if previos:
        # No reemplazar un binario publicado por una recompilacion del mismo commit.
        d = comprobar_juego(previos, version, commit)
        ficheros = previos
    carpeta = salida / prefijo
    carpeta.mkdir(parents=True)
    for nombre, datos in ficheros.items():
        p.ruta_segura(nombre)
        (carpeta / nombre).write_bytes(datos)
    catalogo = {k: v for k, v in d.items() if k != "paquetes"}
    catalogo["inmutable"] = BASE + prefijo + "/MANIFIESTO-DISTRIBUCION.json"
    catalogo["plataformas"] = {e["plataforma"]: dict(e, target=t, url=BASE + prefijo + "/" + e["archivo"])
                               for t, e in d["paquetes"].items()}
    (salida / "componentes/rust/catalogo.json").write_bytes(p.json_bytes(catalogo))
    return catalogo


def main():
    a = argparse.ArgumentParser(description=__doc__)
    a.add_argument("--artefactos", type=Path, required=True)
    a.add_argument("--salida", type=Path, required=True)
    a.add_argument("--commit", required=True)
    args = a.parse_args()
    c = preparar(args.artefactos, args.salida, args.commit)
    print(json.dumps({"version": c["version"], "fuente": c["commit_fuente"], "plataformas": list(c["plataformas"])}))


if __name__ == "__main__":
    main()
