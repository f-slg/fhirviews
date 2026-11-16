#!/usr/bin/env python3
"""Verifica el kit sin completar fichas humanas. Usa solo carpetas temporales."""
import argparse
import hashlib
import importlib.util
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
parser.add_argument('--contrastar-fuentes', action='store_true',
    help='Exige que los materiales del ZIP coincidan con los archivos actuales del repositorio.')
args=parser.parse_args()
archivo=Path(args.zip).resolve()
with tempfile.TemporaryDirectory(prefix='fhirviews-kit-r4-') as temporal:
    temp=Path(temporal)
    with zipfile.ZipFile(archivo) as z:
        assert z.testzip() is None
        assert all(i.compress_type==zipfile.ZIP_STORED for i in z.infolist())
        nombres=z.namelist()
        assert len(nombres)==len(set(nombres))==23
        assert all(not PurePosixPath(n).is_absolute() and '..' not in PurePosixPath(n).parts for n in nombres)
        z.extractall(temp/'Kit con espacios')
    kit=next((temp/'Kit con espacios').iterdir())
    m=json.loads((kit/'MANIFIESTO-KIT.json').read_text(encoding='utf-8'))
    c=json.loads((kit/'CANDIDATO.json').read_text(encoding='utf-8'))
    assert c['version']=='0.5.0.9002'
    assert m['evaluacion_externa']==c['evaluacion_externa']=='pendiente'
    assert m['participantes']==c['participantes']=='sin_asignar'
    assert m['revision_protocolo']=='2.1'
    assert m['fuente_kit_estado'] in ('commit_git','archivos_de_trabajo_sobre_commit')
    assert m['idiomas']==['es','en']
    assert len(m['archivos_sha256'])==21
    for n,h in m['archivos_sha256'].items():
        assert hashlib.sha256((kit/n).read_bytes()).hexdigest()==h,n
    sumas=(kit/'SHA256SUMS').read_text(encoding='utf-8').splitlines()
    assert len(sumas)==22
    for linea in sumas:
        h,n=linea.split('  ',1)
        assert hashlib.sha256((kit/n).read_bytes()).hexdigest()==h,n
    paquete=kit/'paquete'/c['paquete']['archivo']
    assert hashlib.sha256(paquete.read_bytes()).hexdigest()==m['paquete_sha256']
    assert paquete.stat().st_size==c['paquete']['bytes']
    tareas=json.loads((kit/'tareas.json').read_text(encoding='utf-8'))
    assert len(tareas['r'])==len(tareas['fhir'])==9
    assert tareas['r'][-1]['required_scope']==tareas['fhir'][-1]['required_scope']=='siete'
    assert sum(a['title']!=b['title'] for a,b in zip(tareas['r'],tareas['fhir']))>=7
    for perfil in ('r','fhir'):
        protocolo=(kit/('PROTOCOLO-PERFIL-'+perfil.upper()+'.md')).read_text(encoding='utf-8')
        for tarea in tareas[perfil]:
            assert tarea['title'] in protocolo
            assert all(pregunta in protocolo for pregunta in tarea['questions'])
    tareas_en=json.loads((kit/'tareas.en.json').read_text(encoding='utf-8'))
    for perfil in ('r','fhir'):
        protocolo=(kit/('PROTOCOLO-PERFIL-'+perfil.upper()+'.en.md')).read_text(encoding='utf-8')
        for es,en in zip(tareas[perfil],tareas_en[perfil],strict=True):
            assert es['id']==en['id'] and es['required']==en['required']
            assert es['required_scope']==en['required_scope']
            assert en['title'] in protocolo
            assert all(pregunta in protocolo for pregunta in en['questions'])
    builder=ROOT/'data-raw/preparar-kit-r4.py'
    if args.contrastar_fuentes:
        spec=importlib.util.spec_from_file_location('preparador_kit',builder)
        preparador=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(preparador)
        rutas={nombre: ROOT/'data-raw/piloto-r4-v2'/nombre for nombre in preparador.ARCHIVOS}
        rutas.update({'PROBAR-CANDIDATO.R': ROOT/'data-raw/probar-candidato.R',
                      'LICENSE.md': ROOT/'LICENSE.md'})
        diferentes=[nombre for nombre,ruta in rutas.items()
                    if not ruta.is_file() or ruta.read_bytes()!=(kit/nombre).read_bytes()]
        if diferentes:
            raise AssertionError('El ZIP no incorpora los materiales actuales: '+', '.join(diferentes))
    comun=[sys.executable,str(builder),'--paquete',str(paquete),'--ref','HEAD',
           '--kit-dir',str(kit)]
    copia=temp/'reconstruido.zip'
    subprocess.run(comun+['--salida',str(copia)],check=True,stdout=subprocess.DEVNULL)
    if copia.read_bytes()!=archivo.read_bytes():
        with zipfile.ZipFile(copia) as original, zipfile.ZipFile(archivo) as entregado:
            nombres_o, nombres_e = original.namelist(), entregado.namelist()
            distintos = [n for n in nombres_o if n in nombres_e and
                         original.read(n)!=entregado.read(n)]
            metadata = [n for n in nombres_o if n in nombres_e and
                        original.getinfo(n).header_offset!=entregado.getinfo(n).header_offset]
            detalle = ('nombres_iguales='+str(nombres_o==nombres_e)+
                       '; contenido_distinto='+repr(distintos[:5])+
                       '; offsets_distintos='+repr(metadata[:5])+
                       '; bytes_reconstruido='+str(copia.stat().st_size)+
                       '; bytes_entregado='+str(archivo.stat().st_size))
        raise AssertionError('ZIP no reproducible: '+detalle)
    sentinel=temp/'existente.zip'; sentinel.write_bytes(b'CONSERVAR ARCHIVO EXISTENTE')
    r=subprocess.run(comun+['--salida',str(sentinel)],capture_output=True)
    assert r.returncode!=0 and sentinel.read_bytes()==b'CONSERVAR ARCHIVO EXISTENTE'
    mal=temp/'paquete-alterado.tar.gz'; mal.write_bytes(paquete.read_bytes()+b'alterado')
    no_crear=temp/'no-crear'/'rechazado.zip'
    r=subprocess.run([sys.executable,str(builder),'--paquete',str(mal),'--salida',str(no_crear),
        '--ref','HEAD'],capture_output=True)
    assert r.returncode!=0 and not no_crear.parent.exists()
    assert b'El paquete no coincide con el candidato comprobado.' in r.stderr
    alterado=temp/'material-alterado'
    shutil.copytree(kit,alterado)
    with (alterado/'EVALUACION-PILOTO.md').open('ab') as f:
        f.write(b'ALTERADO')
    r=subprocess.run([sys.executable,str(builder),'--paquete',str(paquete),
        '--ref','HEAD','--kit-dir',str(alterado),'--salida',str(temp/'alterado.zip')],capture_output=True)
    assert r.returncode!=0 and not (temp/'alterado.zip').exists()
    print('ZIP: hashes, candidato, reproduccion y rechazos aprobados.',flush=True)
    if args.ejecutar_r:
        for perfil in ('basico','completo'):
            sesion=temp/('Sesion '+perfil)
            subprocess.run(['Rscript','--vanilla',str(kit/'INICIAR.R'),perfil,str(sesion)],check=True)
            ses=json.loads((sesion/'SESION.json').read_text(encoding='utf-8'))
            acept=json.loads((sesion/'piloto/aceptacion.json').read_text(encoding='utf-8'))
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
