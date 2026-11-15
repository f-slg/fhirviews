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
EVIDENCIA = 'data-raw/validacion-0.5.0.9002/MANIFIESTO.json'
ARCHIVOS = ('INICIAR.R', 'LEEME.md', 'ANEXO-OBSERVADOR.md',
            'PROTOCOLO-PERFIL-R.md', 'PROTOCOLO-PERFIL-FHIR.md',
            'PILOTO-R4.md', 'tareas.json', 'formulario.template.html')


def git(ref, archivo):
    return subprocess.check_output(['git', 'show', ref + ':' + archivo], cwd=ROOT)


def construir(paquete, salida, ref='HEAD', kit_dir=None):
    paquete, salida = Path(paquete), Path(salida)
    if salida.exists():
        raise ValueError('La salida ya existe; elige un ZIP nuevo.')
    commit = subprocess.check_output(['git', 'rev-parse', '--verify', '--end-of-options', ref + '^{commit}'],
                                   cwd=ROOT, text=True).strip()
    evidencia = json.loads(git(commit, EVIDENCIA))
    kit_root = Path(kit_dir).resolve() if kit_dir else None
    if kit_root:
        procedencia = json.loads((kit_root / 'MANIFIESTO-KIT.json').read_text(encoding='utf-8'))
        if procedencia.get('esquema') != 'fhirviews-kit-r4-v2':
            raise ValueError('El directorio fuente no contiene un manifiesto de kit reconocido.')
        fuente_kit_commit = procedencia['fuente_kit_commit']
        def archivo_fuente(nombre):
            ruta = kit_root / nombre
            if ruta.is_symlink() or not ruta.is_file():
                raise ValueError('Falta un archivo regular del kit: ' + nombre)
            return ruta.read_bytes()
    else:
        fuente_kit_commit = commit
        rutas_fuente = {'PROBAR-CANDIDATO.R': 'data-raw/probar-candidato.R',
                        'LICENSE.md': 'LICENSE.md'}
        archivo_fuente = lambda nombre: git(commit,
            rutas_fuente.get(nombre, KIT + '/' + nombre))
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
        paquete=esperado, evaluacion_externa='pendiente', participantes='sin_asignar',
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
    protocolo_sha = hashlib.sha256(json.dumps(tareas,ensure_ascii=False,
        sort_keys=True,separators=(',',':')).encode()).hexdigest()
    referencia = dict(version=candidato['version'], commit=candidato['fuente_commit'],
                     sha256=sha, tareas_sha256=protocolo_sha)
    html = archivo_fuente('formulario.template.html').decode()
    for marcador, valor in (('__TAREAS__', tareas), ('__CANDIDATO__', referencia)):
        if html.count(marcador) != 1:
            raise ValueError('Plantilla HTML incompatible.')
        texto = json.dumps(valor, ensure_ascii=False).replace('<', '\\u003c').replace('&', '\\u0026')
        html = html.replace(marcador, texto)
    archivos['FORMULARIO-PILOTO.html'] = html.encode()
    hashes = {n: hashlib.sha256(v).hexdigest() for n, v in sorted(archivos.items())}
    manifiesto = dict(esquema='fhirviews-kit-r4-v2', version_candidato=candidato['version'],
        fuente_kit_commit=commit, fuente_candidato_commit=candidato['fuente_commit'],
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
    args = parser.parse_args()
    try:
        construir(args.paquete, args.salida, args.ref, args.kit_dir)
    except (ValueError, FileNotFoundError) as exc:
        parser.exit(1, str(exc) + '\n')
    print('Kit preparado:', args.salida)
    print('SHA256:', hashlib.sha256(Path(args.salida).read_bytes()).hexdigest())
