"""Genera metadatos de mapeo a partir de FHIR R4 4.0.1, sin dependencias.

Uso: python3 data-raw/mapeo_r4.py [definitions.json.zip]
Fuente: https://hl7.org/fhir/R4/definitions.json.zip
Incluye bindings base y enumera solo ValueSets simples y completos del paquete.
No sustituye la validacion de perfiles, terminologias externas o invariantes.
"""
import hashlib
import json
import sys
import urllib.request
import zipfile
from pathlib import Path

url = 'https://hl7.org/fhir/R4/definitions.json.zip'
recursos = ['Patient', 'Observation', 'Encounter', 'Condition']
archivo = Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/fhirviews-r4-definitions.zip')
if not archivo.exists():
    urllib.request.urlretrieve(url, archivo)
with zipfile.ZipFile(archivo) as z:
    terminologia = [e['resource'] for f in ['valuesets.json', 'v3-codesystems.json']
                    for e in json.loads(z.read(f))['entry']]
    sistemas = {r['url']: r for r in terminologia
                if r.get('resourceType') == 'CodeSystem' and 'url' in r}
    conjuntos = {r['url']: r for r in terminologia
                 if r.get('resourceType') == 'ValueSet' and 'url' in r}

    def conceptos(elementos):
        for e in elementos:
            if 'code' in e:
                yield e['code']
            yield from conceptos(e.get('concept', []))

    def codigos_binding(canonica):
        """No producir una lista parcial para filtros, imports o fuentes externas."""
        partes = canonica.split('|', 1)
        vs = conjuntos.get(partes[0])
        if not vs or (len(partes) > 1 and partes[1] != vs.get('version')):
            return None
        compose = vs.get('compose', {})
        if not compose.get('include') or compose.get('exclude'):
            return None
        salida = []
        for inc in compose['include']:
            if inc.get('filter') or inc.get('valueSet') or not inc.get('system'):
                return None
            cs = sistemas.get(inc['system'])
            if not cs or cs.get('content') != 'complete':
                return None
            if inc.get('version') and inc['version'] != cs.get('version'):
                return None
            permitidos = list(conceptos(cs.get('concept', [])))
            elegidos = [c['code'] for c in inc['concept']] if 'concept' in inc else permitidos
            if not elegidos or not set(elegidos).issubset(permitidos):
                return None
            salida.extend(dict(system=inc['system'], code=c,
                               caseSensitive=cs.get('caseSensitive', True)) for c in elegidos)
        return salida or None

    defs = {}
    for fuente in ['profiles-types.json', 'profiles-resources.json']:
        for entry in json.loads(z.read(fuente))['entry']:
            sd = entry['resource']
            if (sd.get('resourceType') == 'StructureDefinition' and 'snapshot' in sd
                    and sd.get('url') == 'http://hl7.org/fhir/StructureDefinition/' + sd.get('type', '')
                    and sd.get('derivation') == 'specialization'):
                defs[sd['type']] = sd
    pendientes = list(recursos)
    esquemas = {}
    while pendientes:
        nombre = pendientes.pop()
        if nombre in esquemas or nombre not in defs:
            continue
        sd = defs[nombre]
        if sd.get('version') != '4.0.1':
            raise ValueError('Version inesperada de StructureDefinition: ' + nombre)
        if sd.get('kind') == 'primitive-type':
            continue
        elementos = {}
        for e in sd['snapshot']['element'][1:]:
            # Los snapshots base no tienen slices; no incluir perfiles ajenos.
            ruta = e['path'].split('.', 1)[1]
            tipos = []
            for t in e.get('type', []):
                codigo = t['code']
                for ext in t.get('extension', []):
                    if ext['url'].endswith('/structuredefinition-fhir-type'):
                        codigo = ext['valueUrl']
                tipos.append(codigo)
            if e.get('base', {}).get('path') == 'Resource.id':
                tipos = ['id']
            elementos[ruta] = dict(min=e['min'], max=e['max'], tipos=tipos)
            destinos = [p.rsplit('/', 1)[-1] for t in e.get('type', [])
                        if t['code'] == 'Reference' for p in t.get('targetProfile', [])]
            if destinos:
                elementos[ruta]['destinos'] = sorted(set(destinos))
            if 'binding' in e:
                b = e['binding']
                vinculo = dict(fuerza=b['strength'], valueSet=b.get('valueSet'))
                if b['strength'] == 'required' and b.get('valueSet'):
                    codigos = codigos_binding(b['valueSet'])
                    if codigos is not None:
                        vinculo['codigos'] = codigos
                elementos[ruta]['vinculo'] = vinculo
            if 'contentReference' in e:
                elementos[ruta]['ref'] = e['contentReference'].lstrip('#')
            pendientes.extend(t for t in tipos if t not in esquemas)
        esquemas[nombre] = elementos
    salida = dict(version='4.0.1', fuente=url,
                  sha256=hashlib.sha256(archivo.read_bytes()).hexdigest(), recursos=recursos,
                  esquemas=dict(sorted(esquemas.items())))
    destino = Path(__file__).resolve().parents[1] / 'inst/schema/mapeo-r4.json'
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(json.dumps(salida, ensure_ascii=False, separators=(',', ':')) + '\n')
    print(destino, destino.stat().st_size, 'bytes')
