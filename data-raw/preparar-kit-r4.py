#!/usr/bin/env python3
"""Prepara un kit R4 reproducible desde archivos Git y un candidato comprobado."""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
KIT = 'data-raw/piloto-r4-v2'
EVIDENCIA = 'data-raw/validacion-0.5.0.9003/MANIFIESTO.json'
ARCHIVOS = ('INICIAR.R', 'LEEME.md', 'ANEXO-OBSERVADOR.md',
            'PROTOCOLO-PERFIL-R.md', 'PROTOCOLO-PERFIL-FHIR.md',
            'PILOTO-R4.md', 'EVALUACION-PILOTO.md', 'tareas.json',
            'LEEME.en.md', 'ANEXO-OBSERVADOR.en.md', 'PROTOCOLO-PERFIL-R.en.md',
            'PROTOCOLO-PERFIL-FHIR.en.md', 'PILOTO-R4.en.md',
            'EVALUACION-PILOTO.en.md', 'tareas.en.json', 'formulario.template.html')


def git(ref, archivo):
    return subprocess.check_output(['git', 'show', ref + ':' + archivo], cwd=ROOT)


def construir(paquete, salida, ref='HEAD', kit_dir=None, fuentes_trabajo=False):
    paquete, salida = Path(paquete), Path(salida)
    if salida.exists():
        raise ValueError('La salida ya existe; elige un ZIP nuevo.')
    commit = subprocess.check_output(['git', 'rev-parse', '--verify', '--end-of-options', ref + '^{commit}'],
                                   cwd=ROOT, text=True).strip()
    evidencia = json.loads(git(commit, EVIDENCIA))
    kit_root = Path(kit_dir).resolve() if kit_dir else None
    if kit_root and fuentes_trabajo:
        raise ValueError('Elige reconstruccion desde kit o materiales de trabajo, no ambos.')
    if kit_root:
        procedencia = json.loads((kit_root / 'MANIFIESTO-KIT.json').read_text(encoding='utf-8'))
        if procedencia.get('esquema') != 'fhirviews-kit-r4-v2':
            raise ValueError('El directorio fuente no contiene un manifiesto de kit reconocido.')
        fuente_kit_commit = procedencia['fuente_kit_commit']
        fuente_kit_estado = procedencia.get('fuente_kit_estado', 'commit_git')
        def archivo_fuente(nombre):
            ruta = kit_root / nombre
            if ruta.is_symlink() or not ruta.is_file():
                raise ValueError('Falta un archivo regular del kit: ' + nombre)
            datos = ruta.read_bytes()
            if hashlib.sha256(datos).hexdigest() != procedencia['archivos_sha256'].get(nombre):
                raise ValueError('El material del kit fue alterado: ' + nombre)
            return datos
    else:
        fuente_kit_commit = commit
        fuente_kit_estado = 'archivos_de_trabajo_sobre_commit' if fuentes_trabajo else 'commit_git'
        rutas_fuente = {'PROBAR-CANDIDATO.R': 'data-raw/probar-candidato.R',
                        'LICENSE.md': 'LICENSE.md'}
        def archivo_fuente(nombre):
            ruta = rutas_fuente.get(nombre, KIT + '/' + nombre)
            if fuentes_trabajo:
                local = ROOT / ruta
                if local.is_symlink() or not local.is_file():
                    raise ValueError('Falta un archivo regular de trabajo: ' + nombre)
                return local.read_bytes()
            return git(commit, ruta)
    contenido = paquete.read_bytes()
    sha = hashlib.sha256(contenido).hexdigest()
    esperado = evidencia['paquete']
    if (sha != esperado['sha256'] or len(contenido) != esperado['bytes'] or
            hashlib.md5(contenido).hexdigest() != esperado['md5']):
        raise ValueError('El paquete no coincide con el candidato comprobado.')
    with tarfile.open(fileobj=io.BytesIO(contenido), mode='r:gz') as t:
        descripcion = t.extractfile('fhirviews/DESCRIPTION').read().decode()
        if '\nVersion: ' + evidencia['version'] + '\n' not in '\n' + descripcion:
            raise ValueError('La version del archivo no coincide.')
    fuente_commit = evidencia.get('fuente_commit') or evidencia['paquete'].get('commit_fuente') or evidencia['commit_codigo']
    aceptacion = evidencia.get('aceptacion_instalada') or dict(
        comprobacion=evidencia.get('comprobacion_instalada'),
        conformidad=evidencia.get('conformidad'), ci=evidencia.get('ci'))
    citacion = evidencia.get('citacion') or dict(
        version=evidencia['version'], commit=fuente_commit,
        doi_version=evidencia.get('doi_version'))
    candidato = dict(version=evidencia['version'], fuente_commit=fuente_commit,
        paquete={k: v for k, v in esperado.items() if k != 'alcance'},
        evaluacion_externa='pendiente', participantes='sin_asignar',
        resultado_previo='comprobacion_tecnica_del_mantenedor',
        aceptacion=aceptacion, citacion=citacion)
    archivos = {nombre: archivo_fuente(nombre) for nombre in ARCHIVOS}
    archivos['PROBAR-CANDIDATO.R'] = archivo_fuente('PROBAR-CANDIDATO.R')
    archivos['LICENSE.md'] = archivo_fuente('LICENSE.md')
    archivos['CANDIDATO.json'] = (json.dumps(candidato, ensure_ascii=False, indent=2) + '\n').encode()
    archivos['paquete/' + esperado['archivo']] = contenido
    tareas = json.loads(archivos['tareas.json'])
    for perfil, prefijo in (('r', 'R'), ('fhir', 'F')):
        if (len(tareas[perfil]) != 9 or len({x['id'] for x in tareas[perfil]}) != 9 or
                not all(x['id'].startswith(prefijo) for x in tareas[perfil])):
            raise ValueError('Las tareas del protocolo estan incompletas.')
        for tarea in tareas[perfil]:
            if (not tarea.get('questions') or not tarea.get('checks') or
                    not tarea.get('evidence') or not tarea.get('expected')):
                raise ValueError('Faltan preguntas, criterios o evidencia de ' + tarea['id'])
        if tareas[perfil][-1].get('required_scope') != 'siete':
            raise ValueError('El laboratorio debe ser obligatorio en alcance siete.')
    tareas_en = json.loads(archivos['tareas.en.json'])
    for perfil in ('r', 'fhir'):
        for es, en in zip(tareas[perfil], tareas_en[perfil], strict=True):
            if any(es[k] != en[k] for k in ('id', 'required', 'required_scope', 'code')):
                raise ValueError('La identidad o alcance difiere entre idiomas: ' + es['id'])
            if any(len(es[k]) != len(en[k]) for k in ('steps', 'checks', 'questions')):
                raise ValueError('Contenido incompleto entre idiomas: ' + es['id'])
    protocolo_sha = hashlib.sha256(json.dumps(dict(es=tareas,en=tareas_en),ensure_ascii=False,
        sort_keys=True,separators=(',',':')).encode()).hexdigest()
    referencia = dict(version=candidato['version'], commit=candidato['fuente_commit'],
                     sha256=sha, tareas_sha256=protocolo_sha)
    html = archivo_fuente('formulario.template.html').decode()
    for marcador, valor in (('__TAREAS__', tareas), ('__TAREAS_EN__', tareas_en),
                           ('__CANDIDATO__', referencia)):
        if html.count(marcador) != 1:
            raise ValueError('Plantilla HTML incompatible.')
        texto = json.dumps(valor, ensure_ascii=False).replace('<', '\\u003c').replace('&', '\\u0026')
        html = html.replace(marcador, texto)
    archivos['FORMULARIO-PILOTO.html'] = html.encode()
    hashes = {n: hashlib.sha256(v).hexdigest() for n, v in sorted(archivos.items())}
    manifiesto = dict(esquema='fhirviews-kit-r4-v2', version_candidato=candidato['version'],
        fuente_kit_commit=fuente_kit_commit, fuente_candidato_commit=candidato['fuente_commit'],
        fuente_kit_estado=fuente_kit_estado, revision_protocolo='2.1', idiomas=['es', 'en'],
        paquete_sha256=sha, protocolo_sha256=protocolo_sha,
        evaluacion_externa='pendiente', participantes='sin_asignar',
        archivos_sha256=dict(hashes),
        zip_compresion='stored; el paquete ya esta comprimido, sin depender de la version de zlib',
        zip_tiempos_normalizados='1980-01-01; no representan fechas de sesiones',
        alcance='Datos ficticios; las fichas no contienen resultados humanos. Sin envio automatico.')
    archivos['MANIFIESTO-KIT.json'] = (json.dumps(manifiesto, ensure_ascii=False, indent=2) + '\n').encode()
    hashes['MANIFIESTO-KIT.json'] = hashlib.sha256(archivos['MANIFIESTO-KIT.json']).hexdigest()
    archivos['SHA256SUMS'] = ''.join(h + '  ' + n + '\n' for n, h in sorted(hashes.items())).encode()
    prefijo = 'fhirviews-piloto-r4-' + candidato['version'] + '/'
    # Lista explicita: nunca incorporar formularios completados o salidas locales.
    salida.parent.mkdir(parents=True, exist_ok=True)
    archivo_salida = salida.open('xb')
    try:
        with archivo_salida as f, zipfile.ZipFile(f, 'w', zipfile.ZIP_STORED) as z:
            for nombre, datos in sorted(archivos.items()):
                ruta = PurePosixPath(nombre)
                if ruta.is_absolute() or '..' in ruta.parts:
                    raise ValueError('Ruta de archivo no permitida.')
                info = zipfile.ZipInfo(prefijo + nombre, (1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_STORED
                info.create_system = 3
                info.external_attr = 0o100644 << 16
                z.writestr(info, datos)
    except Exception:
        # Solo se limpia la salida nueva que este proceso acaba de crear.
        if salida.exists():
            salida.unlink()
        raise
    return manifiesto


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--paquete', required=True)
    parser.add_argument('--salida', required=True)
    parser.add_argument('--ref', default='HEAD')
    parser.add_argument('--kit-dir', help='Usa los materiales del kit desempaquetado para una reconstruccion reproducible.')
    parser.add_argument('--fuentes-trabajo', action='store_true',
        help='Lee solo los materiales explicitos del arbol de trabajo; registra el commit base y los hashes, sin afirmar que estan en ese commit.')
    args = parser.parse_args()
    try:
        construir(args.paquete, args.salida, args.ref, args.kit_dir, args.fuentes_trabajo)
    except (ValueError, FileNotFoundError) as exc:
        parser.exit(1, str(exc) + '\n')
    print('Kit preparado:', args.salida)
    print('SHA256:', hashlib.sha256(Path(args.salida).read_bytes()).hexdigest())
