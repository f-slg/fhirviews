"""Muestrea RSS sumado de R y sus procesos hijos cada 10 ms, en procesos nuevos."""
import argparse
import json
from pathlib import Path
import subprocess
import time
import psutil

parser = argparse.ArgumentParser()
parser.add_argument('binario')
parser.add_argument('salida')
args = parser.parse_args()
salida = Path(args.salida)
salida.mkdir(parents=True, exist_ok=False)
resultados = []
for metodo in ('original', 'preparado', 'rust'):
    archivo = salida / (metodo + '.log')
    with archivo.open('w') as log:
        p = subprocess.Popen(['Rscript', 'data-raw/experimento-rust/memoria.R',
            str(Path(args.binario).resolve()), metodo, '3000', str(salida/(metodo+'-plan.json'))],
            stdout=log, stderr=subprocess.STDOUT)
        padre = psutil.Process(p.pid)
        pico = 0
        muestras = 0
        while p.poll() is None:
            total = 0
            try:
                procesos = [padre] + padre.children(recursive=True)
            except psutil.NoSuchProcess:
                procesos = []
            for proceso in procesos:
                try:
                    total += proceso.memory_info().rss
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
            pico = max(pico, total)
            muestras += 1
            time.sleep(0.01)
        if p.wait() != 0:
            raise RuntimeError('Fallo de medicion: '+metodo+'; revisar '+str(archivo))
    resultados.append({'metodo': metodo, 'recurso': 'Immunization', 'filas': 3000,
        'rss_sumado_pico_bytes': pico, 'muestras': muestras})
    print(metodo, round(pico/1024**2, 2), 'MiB', flush=True)
(salida/'memoria.json').write_text(json.dumps({
    'intervalo_objetivo_segundos': 0.01,
    'alcance': 'Un proceso nuevo por metodo. Pico de suma RSS de R y sus hijos durante carga, preparacion y constructor. Puede contar paginas compartidas mas de una vez; no es memoria exclusiva ni una garantia de pico entre muestras.',
    'resultados': resultados}, indent=2)+'\n')
