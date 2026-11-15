"""Prepara archivos revisables de Zenodo/GitHub sin publicar ni usar la red."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--ref', required=True, help='Commit o referencia Git que se congela')
parser.add_argument('--paquete', required=True, type=Path, help='tar.gz R previamente comprobado')
parser.add_argument('--salida', required=True, type=Path, help='Carpeta nueva')
args = parser.parse_args()
raiz = Path(__file__).resolve().parents[1]


def git(*argumentos):
    return subprocess.check_output(['git', '-C', str(raiz), *argumentos])


commit = git('rev-parse', '--verify', args.ref + '^{commit}').decode().strip()


def leer(nombre):
    return git('show', commit + ':' + nombre).decode()


version = re.search(r'^Version:\s*(\S+)', leer('DESCRIPTION'), re.M)[1]
cff = leer('CITATION.cff')
metadata = json.loads(leer('.zenodo.json'))
assert metadata['version'] == version, 'Version .zenodo.json incompatible'
assert re.search(r'^version:\s*[\"\']?' + re.escape(version) + r'[\"\']?\s*$', cff, re.M), 'Version CFF incompatible'
orcid = metadata['creators'][0]['orcid']
assert re.fullmatch(r'\d{4}-\d{4}-\d{4}-\d{3}[\dX]', orcid), 'ORCID mal formado'
acumulado = 0
for digito in orcid.replace('-', '')[:-1]:
    acumulado = (acumulado + int(digito)) * 2
control = (12 - acumulado % 11) % 11
assert orcid[-1] == ('X' if control == 10 else str(control)), 'Checksum ORCID incorrecto'
assert 'https://orcid.org/' + orcid in cff and orcid in leer('DESCRIPTION') and orcid in leer('inst/CITATION'), 'ORCID no coincide'
assert metadata['upload_type'] == 'software' and metadata['access_right'] == 'open'
assert metadata['license'].lower() == 'mit'
evidencia = json.loads(leer('data-raw/validacion-0.5.0.9000/cierre-r4/MANIFIESTO.json'))
assert evidencia['version_paquete'] == version, 'Version del paquete probado incompatible'
paquete = args.paquete.resolve(strict=True)
datos = paquete.read_bytes()
assert hashlib.sha256(datos).hexdigest() == evidencia['archivo']['sha256'], 'SHA256 del paquete incompatible'
assert paquete.name == evidencia['archivo']['nombre'], 'Nombre del paquete incompatible'
subprocess.run(['git', '-C', str(raiz), 'diff', '--quiet', evidencia['codigo_commit'], commit,
                '--', 'R', 'inst', 'tests', 'DESCRIPTION', 'NAMESPACE'], check=True)
assert not args.salida.exists(), 'La carpeta de salida ya existe'
args.salida.mkdir(parents=True)
fuente = args.salida / ('fhirviews-' + version + '-source.zip')
subprocess.run(['git', '-C', str(raiz), 'archive', '--format=zip',
                '--prefix=fhirviews-' + version + '/', '--output=' + str(fuente.resolve()), commit], check=True)
shutil.copy2(paquete, args.salida / paquete.name)
(args.salida / 'metadatos-zenodo.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
manifiesto = {
    'estado': 'preparado_sin_publicar', 'version': version, 'etiqueta_prevista': 'v' + version,
    'commit_fuente': commit, 'orcid': orcid, 'doi': None,
    'generado_utc': datetime.now(timezone.utc).isoformat(),
    'fuente_zip': {'nombre': fuente.name, 'sha256': hashlib.sha256(fuente.read_bytes()).hexdigest(), 'bytes': fuente.stat().st_size},
    'paquete_R': {'nombre': paquete.name, 'sha256': hashlib.sha256(datos).hexdigest(), 'bytes': len(datos),
                  'commit_ensayado': evidencia['codigo_commit']},
    'codigo_R_inst_tests_identico_al_ensayo': True,
    'documentacion': 'El ZIP incluye la documentacion del commit fuente; el tar.gz conserva la del candidato ensayado',
    'conexion_zenodo': 'requiere_verificacion_de_la_cuenta', 'registro_publicado': False
}
(args.salida / 'MANIFIESTO-ZENODO.json').write_text(json.dumps(manifiesto, ensure_ascii=False, indent=2) + '\n')
notas = f'''# fhirviews {version}: candidato R4 de desarrollo

Version de desarrollo para archivo y cita, separada del 0.5.0 enviado a CRAN.
Incluye Patient, Observation, Encounter, Condition e Immunization desde tablas
o consultas SQL, salida JSON/NDJSON con escala decimal y vistas SQL on FHIR.

Autor: Ronald Fabricio Salas Guerrero, https://orcid.org/{orcid}.
Codigo fuente fijado: {commit}.

Validacion conservada: 1663 comprobaciones locales, 130 HAPI, 72 PostgreSQL/SQL
Server, R CMD check Status OK y aceptacion instalada basica/completa. La matriz
Windows/macOS/Linux del codigo R4 integro tambien fue aprobada.

El ZIP fuente y el tar.gz R son archivos diferentes; sus identidades figuran
en MANIFIESTO-ZENODO.json. El codigo R/inst/tests coincide con el candidato
ensayado; el ZIP incorpora la documentacion del commit fijado.

Evaluacion externa y perfiles propios pendientes. Rust y conversion R4/R6
no implementados. Esta prerelease no acredita publicacion ni revision por CRAN.
El DOI se anadira despues de comprobar el registro real de Zenodo. Un borrador
de GitHub no genera DOI.
'''
(args.salida / 'notas-release.md').write_text(notas)
print(json.dumps(manifiesto, ensure_ascii=False, indent=2))
