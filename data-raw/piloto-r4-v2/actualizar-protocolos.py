#!/usr/bin/env python3
"""Sincroniza guías ES/EN con sus tareas; --comprobar no escribe."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def documentos():
    fuentes = {lang: json.loads((ROOT / name).read_text(encoding='utf-8'))
               for lang, name in [('es', 'tareas.json'), ('en', 'tareas.en.json')]}
    for perfil in ('r', 'fhir'):
        for a, b in zip(fuentes['es'][perfil], fuentes['en'][perfil], strict=True):
            for key in ('id', 'required', 'required_scope', 'code'):
                if a[key] != b[key]:
                    raise ValueError('Identidad/alcance distinto entre idiomas: ' + a['id'])
            for key in ('steps', 'checks', 'questions'):
                if len(a[key]) != len(b[key]):
                    raise ValueError('Contenido incompleto entre idiomas: ' + a['id'])
    salidas = {}
    for lang, tareas in fuentes.items():
        english = lang == 'en'
        ext = '.en.md' if english else '.md'
        for perfil in ('r', 'fhir'):
            base = 'PROTOCOLO-PERFIL-' + perfil.upper()
            titulo = ({'r': 'R profile: analysis, independence and usefulness',
                       'fhir': 'FHIR profile: semantics and R4 interoperability'} if english else
                      {'r': 'Perfil R: análisis, autonomía y utilidad',
                       'fhir': 'Perfil FHIR: semántica e interoperabilidad R4'})[perfil]
            texto = ['# ' + titulo, '',
                f'[Español]({base}.md) · **English**' if english else
                f'**Español** · [English]({base}.en.md)', '']
            if english:
                texto += ['Protocol **2.1**, candidate **0.5.0.9002**, fictional data.', '',
                    'Read [the evaluation](EVALUACION-PILOTO.en.md) and',
                    '[technical preparation](LEEME.en.md) first. Record participant profile,',
                    'basic/full technical level and core/seven scope as three separate choices.', '',
                    'Tasks 01–08 are required. Task 09 is required for **seven** scope and',
                    'needs full level; explicitly exclude it for core. Perform 09 before closure 08.',
                    'Answer in your own words. Self-directed documentation is allowed.', '',
                    'The observer records state, active/wait time, interventions, understanding,',
                    'answers, consulted documentation, evidence and manual repeats. Do not consult',
                    'reference answers before the first attempt. Memorized commands are not required.', '']
            else:
                texto += ['Protocolo **2.1**, candidato **0.5.0.9002**, datos ficticios.', '',
                    'Lea [la evaluación](EVALUACION-PILOTO.md) y',
                    '[la preparación técnica](LEEME.md). Registre perfil de persona, nivel',
                    'básico/completo y alcance núcleo/siete como tres elecciones distintas.', '',
                    'Las tareas 01–08 son obligatorias. La 09 es obligatoria en alcance',
                    '**siete** y requiere completo; en núcleo se excluye expresamente.',
                    'Realice 09 antes del cierre 08. Responda con sus palabras;',
                    'consultar documentación por iniciativa propia está permitido.', '',
                    'El observador registra estado, tiempo activo/esperas, intervenciones,',
                    'comprensión, respuestas, documentos consultados, evidencia y repetición.',
                    'No consulte soluciones antes del primer intento. No se exige memorizar comandos.', '']
            for t in tareas[perfil]:
                scope = ('Required for core and seven.' if t['required'] else
                         'Required for seven; exclude with a reason for core.') if english else (
                         'Obligatoria en núcleo y siete.' if t['required'] else
                         'Obligatoria en siete; excluida con justificación en núcleo.')
                texto += ['## ' + t['id'] + '. ' + t['title'], '',
                    ('**Purpose:** ' if english else '**Objetivo:** ') + t['goal'], '',
                    ('**Scope:** ' if english else '**Alcance:** ') + scope, '',
                    '### Prompt and steps' if english else '### Consigna y pasos', '']
                texto += [f'{i}. {s}' for i, s in enumerate(t['steps'], 1)]
                texto += ['', '### Understanding questions' if english else '### Preguntas de comprensión', '']
                texto += ['- ' + s for s in t['questions']]
                texto += ['', '### Observable criteria' if english else '### Criterios observables', '']
                texto += ['- ' + s for s in t['checks']]
                texto += ['', ('**Evidence to retain:** ' if english else '**Evidencia a conservar:** ') + t['evidence'], '']
                if t['code']:
                    texto += ['### Operational preparation' if english else '### Preparación operativa', '',
                        'Adapt the ID, directory and technical level to the agreement. API names and filenames stay unchanged.' if english else
                        'Adapte identificador, carpeta y nivel al acuerdo. Los ejemplos no sustituyen su explicación.',
                        '', '```r', t['code'], '```', '']
                texto += ['**Task record:** state; active/wait minutes; interventions and assistance;' if english else
                    '**Registro:** estado; minutos activos/espera; intervenciones y ayuda;',
                    'observed understanding; answers; documentation; evidence; repeat outcome/files if performed.' if english else
                    'comprensión; respuestas; documentación; evidencia; resultado/archivos de repetición si se realizó.', '']
            salidas[base + ext] = '\n'.join(texto)
        marcador = '## References by task\n' if english else '## Referencias por tarea\n'
        nombre = 'ANEXO-OBSERVADOR' + ext
        anexo = (ROOT / nombre).read_text(encoding='utf-8').split(marcador)[0].rstrip() + '\n\n' + marcador
        for grupo in tareas.values():
            for t in grupo:
                anexo += f"\n### {t['id']}. {t['title']}\n\n"
                for label, key in ([('Reference answer', 'expected'), ('Errors to detect', 'mistakes'), ('Evidence', 'evidence')]
                                   if english else [('Contraste', 'expected'), ('Errores a detectar', 'mistakes'), ('Evidencia', 'evidence')]):
                    anexo += f'**{label}:** {t[key]}\n\n'
        salidas[nombre] = anexo.rstrip() + '\n'
    return salidas


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--comprobar', action='store_true')
    args = p.parse_args()
    distintos = []
    for nombre, contenido in documentos().items():
        ruta = ROOT / nombre
        if not ruta.exists() or ruta.read_text(encoding='utf-8') != contenido:
            distintos.append(nombre)
            if not args.comprobar:
                ruta.write_text(contenido, encoding='utf-8')
    if args.comprobar and distintos:
        p.exit(1, 'Guías desincronizadas: ' + ', '.join(distintos) + '\n')
    print('Protocolos ES/EN y referencias sincronizados con las 18 tareas.')
