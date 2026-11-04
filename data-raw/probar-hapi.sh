#!/usr/bin/env bash
# Prueba aislada. Solo crea recursos ficticios en su propio contenedor.
set -euo pipefail
raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if (( $# > 1 )); then
  echo "Uso: bash data-raw/probar-hapi.sh [carpeta-nueva-de-resultados]" >&2
  exit 2
fi
motor="${FHIRVIEWS_CONTENEDOR:-}"
if [[ -z "$motor" ]]; then
  if command -v docker >/dev/null; then motor=docker; else motor=podman; fi
fi
case "$motor" in docker|podman) ;; *) echo "Motor permitido: docker o podman" >&2; exit 2 ;; esac
for comando in "$motor" Rscript curl; do command -v "$comando" >/dev/null; done
espera="${FHIRVIEWS_HAPI_ESPERA:-180}"
[[ "$espera" =~ ^[1-9][0-9]*$ ]] || { echo "Espera no valida" >&2; exit 2; }
imagen="$(cat "$raiz/data-raw/hapi-image.txt")"
[[ "$imagen" =~ @sha256:[a-f0-9]{64}$ ]] || { echo "La imagen debe fijarse por digest" >&2; exit 2; }
if (( $# == 1 )); then
  [[ ! -e "$1" ]] || { echo "La carpeta de resultados ya existe" >&2; exit 2; }
  mkdir -p "$1"
  salida="$(cd "$1" && pwd)"
else
  salida="$(mktemp -d "${TMPDIR:-/tmp}/fhirviews-integracion-XXXXXXXX")"
fi
limpiar() {
  estado=$?
  trap - EXIT
  if [[ -s "$salida/container.cid" ]]; then
    cid="$(cat "$salida/container.cid")"
    if [[ "$cid" =~ ^[a-f0-9]{64}$ ]]; then
      printf '%s\n' "$cid" > "$salida/contenedor-id.txt"
      "$motor" logs "$cid" > "$salida/hapi.log" 2>&1 || true
      if ! "$motor" rm -f --volumes "$cid" > "$salida/limpieza.log" 2>&1; then
        echo "No se pudo eliminar el contenedor de pruebas; revisar limpieza.log" >&2
        estado=1
      fi
    fi
  fi
  if (( estado != 0 )); then
    if [[ -f "$salida/pruebas.log" ]]; then
      cat "$salida/pruebas.log" >&2
    elif [[ -f "$salida/arranque.log" ]]; then
      cat "$salida/arranque.log" >&2
    fi
  fi
  printf '%s\n' "$estado" > "$salida/codigo-salida.txt"
  echo "Resultados: $salida"
  exit "$estado"
}
trap limpiar EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
printf 'imagen=%s\nmotor=%s\n' "$imagen" "$motor" > "$salida/contexto.txt"
# El puerto aleatorio se publica solamente en localhost. Sin volumenes del host.
"$motor" run -d --cidfile "$salida/container.cid" \
  -p 127.0.0.1::8080 -e hapi.fhir.bulk_export_enabled=true "$imagen" \
  > "$salida/arranque.log" 2>&1
cid="$(cat "$salida/container.cid")"
direccion="$("$motor" port "$cid" 8080/tcp)"
puerto="${direccion##*:}"
[[ "$puerto" =~ ^[0-9]+$ ]] || { echo "No se pudo obtener el puerto" >&2; exit 1; }
url="http://127.0.0.1:$puerto/fhir"
printf 'url=%s\n' "$url" >> "$salida/contexto.txt"
limite=$((SECONDS + espera))
until curl --fail --silent --show-error --max-time 5 "$url/metadata" \
  -o "$salida/metadata.json" 2> "$salida/disponibilidad.log"; do
  if (( SECONDS >= limite )); then echo "HAPI no estuvo disponible a tiempo" >&2; exit 1; fi
  sleep 2
done
export FHIRVIEWS_SERVIDOR_ESCRITURA="$url"
export FHIRVIEWS_SOLO_SERVIDOR_PROPIO=true
export NOT_CRAN=true
export TZ=UTC
Rscript "$raiz/data-raw/test-politica-integracion.R" > "$salida/politica.log" 2>&1
Rscript "$raiz/data-raw/ejecutar-integracion.R" "$raiz" "$salida" \
  > "$salida/pruebas.log" 2>&1
cat "$salida/pruebas.log"
