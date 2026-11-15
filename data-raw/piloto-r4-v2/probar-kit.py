#!/usr/bin/env python3
"""Verifica el kit sin completar fichas humanas. Usa solo carpetas temporales."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('zip')
parser.add_argument('--ejecutar-r', action='store_true')
args=parser.parse_args()
archivo=Path(args.zip).resolve()
with tempfile.TemporaryDirectory(prefix='fhirviews-kit-r4-') as temporal:
    temp=Path(temporal)
    with zipfile.ZipFile(archivo) as z:
        assert z.testzip() is None
        assert all(i.compress_type==zipfile.ZIP_STORED for i in z.infolist())
        nombres=z.namelist()
        assert len(nombres)==len(set(nombres))==14
        assert all(not PurePosixPath(n).is_absolute() and '..' not in PurePosixPath(n).parts for n in nombres)
        z.extractall(temp/'Kit con espacios')
    kit=next((temp/'Kit con espacios').iterdir())
    m=json.loads((kit/'MANIFIESTO-KIT.json').read_text())
    c=json.loads((kit/'CANDIDATO.json').read_text())
    assert c['version']=='0.5.0.9002'
    assert m['evaluacion_externa']==c['evaluacion_externa']=='pendiente'
    assert m['participantes']==c['participantes']=='sin_asignar'
    assert len(m['archivos_sha256'])==12
    for n,h in m['archivos_sha256'].items():
        assert hashlib.sha256((kit/n).read_bytes()).hexdigest()==h,n
    sumas=(kit/'SHA256SUMS').read_text().splitlines()
    assert len(sumas)==13
    for linea in sumas:
        h,n=linea.split('  ',1)
        assert hashlib.sha256((kit/n).read_bytes()).hexdigest()==h,n
    paquete=kit/'paquete'/c['paquete']['archivo']
    assert hashlib.sha256(paquete.read_bytes()).hexdigest()==m['paquete_sha256']
    assert paquete.stat().st_size==c['paquete']['bytes']
    builder=ROOT/'data-raw/preparar-kit-r4.py'
    comun=[sys.executable,str(builder),'--paquete',str(paquete),'--ref',m['fuente_kit_commit']]
    copia=temp/'reconstruido.zip'
    subprocess.run(comun+['--salida',str(copia)],check=True,stdout=subprocess.DEVNULL)
    assert copia.read_bytes()==archivo.read_bytes(),'ZIP no reproducible'
    sentinel=temp/'existente.zip'; sentinel.write_bytes(b'CONSERVAR ARCHIVO EXISTENTE')
    r=subprocess.run(comun+['--salida',str(sentinel)],capture_output=True)
    assert r.returncode!=0 and sentinel.read_bytes()==b'CONSERVAR ARCHIVO EXISTENTE'
    mal=temp/'paquete-alterado.tar.gz'; mal.write_bytes(paquete.read_bytes()+b'alterado')
    no_crear=temp/'no-crear'/'rechazado.zip'
    r=subprocess.run([sys.executable,str(builder),'--paquete',str(mal),'--salida',str(no_crear),
        '--ref',m['fuente_kit_commit']],capture_output=True)
    assert r.returncode!=0 and not no_crear.parent.exists()
    print('ZIP: hashes, candidato, reproduccion y rechazos aprobados.',flush=True)
    if args.ejecutar_r:
        for perfil in ('basico','completo'):
            sesion=temp/('Sesion '+perfil)
            subprocess.run(['Rscript','--vanilla',str(kit/'INICIAR.R'),perfil,str(sesion)],check=True)
            ses=json.loads((sesion/'SESION.json').read_text())
            acept=json.loads((sesion/'piloto/aceptacion.json').read_text())
            assert ses['resultado_tecnico']==acept['resultado_tecnico']=='aprobado'
            assert ses['evaluacion_externa']==acept['validacion_usuario_externo']=='pendiente'
            assert acept['candidato_md5']==c['paquete']['md5']
            assert acept['version_fhirviews']==c['version']
            guardado=(sesion/'SESION.json').read_bytes()
            r=subprocess.run(['Rscript','--vanilla',str(kit/'INICIAR.R'),perfil,str(sesion)],capture_output=True)
            assert r.returncode!=0 and (sesion/'SESION.json').read_bytes()==guardado
        script=temp/'abrir.R'
        script.write_text('''args <- commandArgs(trailingOnly=TRUE)
source(args[1], encoding="UTF-8")
abrir_sesion(args[2])
stopifnot(as.character(packageVersion("fhirviews")) == "0.5.0.9002")
f <- system.file("extdata", "alergias_r4.ndjson", package="fhirviews")
x <- vista_ejecutar(f, vista_plantilla("alergias"))
stopifnot(nrow(x)==5L, length(unique(x$id))==3L)
stopifnot(is.null(citation("fhirviews")[[1]]$doi))
''')
        subprocess.run(['Rscript','--vanilla',str(script),str(kit/'INICIAR.R'),str(temp/'Sesion basico')],check=True)
        laboratorio=temp/'laboratorio.R'
        laboratorio.write_text('''source(system.file("examples", "laboratorio-r4.R", package="fhirviews"))
x <- laboratorio_r4(prefijo="piloto-kit")
tipos <- vapply(x$recursos, function(r) r$resourceType, character(1))
stopifnot(sum(tipos == "Specimen") == 1L, sum(tipos == "DiagnosticReport") == 1L,
  sum(tipos == "Observation") == 2L, nrow(x$tablas$resultados) == 2L,
  nrow(x$tablas$muestras) == 1L,
  isTRUE(all.equal(x$tablas$resultados, vista_ejecutar_duckdb(x$recursos, x$vistas$resultados))),
  isTRUE(all.equal(x$tablas$muestras, vista_ejecutar_duckdb(x$recursos, x$vistas$muestras))))
''')
        subprocess.run(['Rscript','--vanilla','-e',
          ".libPaths(c(normalizePath(commandArgs(TRUE)[1]), .libPaths())); library(fhirviews); source(commandArgs(TRUE)[2])",
          str(temp/'Sesion completo'/'biblioteca'),str(laboratorio)],check=True)
        corrupto=temp/'Kit alterado'; shutil.copytree(kit,corrupto)
        (corrupto/'paquete'/c['paquete']['archivo']).write_bytes(mal.read_bytes())
        sesion=temp/'Sesion rechazada'
        r=subprocess.run(['Rscript','--vanilla',str(corrupto/'INICIAR.R'),'basico',str(sesion)],capture_output=True)
        assert r.returncode!=0 and not sesion.exists()
        print('R: perfiles instalados, alergias, laboratorio R4 y rechazo de archivo alterado aprobados.',flush=True)
