"""Genera metadatos de mapeo a partir de FHIR R4 4.0.1, sin dependencias.

Uso: python3 data-raw/mapeo_r4.py [definitions.json.zip]
Fuente: https://hl7.org/fhir/R4/definitions.json.zip
No es un validador de perfiles ni incluye los ValueSets o invariantes FHIRPath.
"""
import json
import sys
import urllib.request
import zipfile
from pathlib import Path

url = 'https://hl7.org/fhir/R4/definitions.json.zip'
archivo = Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/fhirviews-r4-definitions.zip')
if not archivo.exists():
    urllib.request.urlretrieve(url, archivo)
with zipfile.ZipFile(archivo) as z:
    defs = {}
    for fuente in ['profiles-types.json', 'profiles-resources.json']:
        for entry in json.loads(z.read(fuente))['entry']:
            sd = entry['resource']
            if (sd.get('resourceType') == 'StructureDefinition' and 'snapshot' in sd
                    and sd.get('url') == 'http://hl7.org/fhir/StructureDefinition/' + sd.get('type', '')
                    and sd.get('derivation') == 'specialization'):
                defs[sd['type']] = sd
    pendientes = ['Patient', 'Observation']
    esquemas = {}
    while pendientes:
        nombre = pendientes.pop()
        if nombre in esquemas or nombre not in defs:
            continue
        sd = defs[nombre]
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
            if 'contentReference' in e:
                elementos[ruta]['ref'] = e['contentReference'].lstrip('#')
            pendientes.extend(t for t in tipos if t not in esquemas)
        esquemas[nombre] = elementos
    salida = dict(version='4.0.1', fuente=url, recursos=['Patient', 'Observation'],
                  esquemas=dict(sorted(esquemas.items())))
    destino = Path(__file__).resolve().parents[1] / 'inst/schema/mapeo-r4.json'
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(json.dumps(salida, ensure_ascii=False, separators=(',', ':')) + '\n')
    print(destino, destino.stat().st_size, 'bytes')
