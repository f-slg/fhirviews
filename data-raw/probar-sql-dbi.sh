#!/usr/bin/env bash
# Bases efimeras propias, datos ficticios y puertos publicados solo en localhost.
set -euo pipefail
raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if (( $# > 1 )); then
  echo "Uso: bash data-raw/probar-sql-dbi.sh [carpeta-nueva-de-resultados]" >&2
  exit 2
fi
motor="${FHIRVIEWS_CONTENEDOR:-}"
if [[ -z "$motor" ]]; then
  if command -v docker >/dev/null; then motor=docker; else motor=podman; fi
fi
case "$motor" in docker|podman) ;; *) echo "Motor permitido: docker o podman" >&2; exit 2 ;; esac
for comando in "$motor" Rscript openssl; do command -v "$comando" >/dev/null; done
Rscript -e 'for (p in c("DBI", "RPostgres", "odbc", "pkgload", "testthat", "duckdb")) if (!requireNamespace(p, quietly = TRUE)) stop("Falta el paquete: ", p)'
pg_imagen="$(cat "$raiz/data-raw/postgres-image.txt")"
ms_imagen="$(cat "$raiz/data-raw/sqlserver-image.txt")"
for imagen in "$pg_imagen" "$ms_imagen"; do
  [[ "$imagen" =~ @sha256:[a-f0-9]{64}$ ]] || { echo "Las imagenes deben fijarse por digest" >&2; exit 2; }
done
if (( $# == 1 )); then
  [[ ! -e "$1" ]] || { echo "La carpeta de resultados ya existe" >&2; exit 2; }
  mkdir -p "$1"
  salida="$(cd "$1" && pwd)"
else
  salida="$(mktemp -d "${TMPDIR:-/tmp}/fhirviews-sql-dbi-XXXXXXXX")"
fi
limpiar() {
  estado=$?
  trap - EXIT
  for nombre in postgres sqlserver; do
    if [[ -s "$salida/$nombre.cid" ]]; then
      cid="$(cat "$salida/$nombre.cid")"
      if [[ "$cid" =~ ^[a-f0-9]{64}$ ]]; then
        "$motor" logs "$cid" > "$salida/$nombre.log" 2>&1 || true
        if ! "$motor" rm -f --volumes "$cid" > "$salida/$nombre-limpieza.log" 2>&1; then
          echo "No se pudo eliminar el contenedor de $nombre; revisar su registro" >&2
          estado=1
        fi
      fi
    fi
  done
  if (( estado != 0 )); then
    for registro in pruebas postgres-arranque sqlserver-arranque; do
      if [[ -f "$salida/$registro.log" ]]; then cat "$salida/$registro.log" >&2; fi
    done
  fi
  printf '%s\n' "$estado" > "$salida/codigo-salida.txt"
  echo "Resultados: $salida"
  exit "$estado"
}
trap limpiar EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
printf 'postgres=%s\nsqlserver=%s\nmotor=%s\n' "$pg_imagen" "$ms_imagen" "$motor" > "$salida/contexto.txt"
# Credenciales aleatorias de un solo uso; no se escriben en los resultados.
export POSTGRES_PASSWORD="Fv1!$(openssl rand -hex 24)"
export MSSQL_SA_PASSWORD="$POSTGRES_PASSWORD"
export FHIRVIEWS_SQL_PASSWORD="$POSTGRES_PASSWORD"
"$motor" run -d --cidfile "$salida/postgres.cid" -p 127.0.0.1::5432 \
  -e POSTGRES_PASSWORD -e POSTGRES_USER=fhirviews -e POSTGRES_DB=fhirviews_pruebas \
  "$pg_imagen" > "$salida/postgres-arranque.log" 2>&1
# Developer se usa exclusivamente para desarrollo y pruebas; ACCEPT_EULA
# acepta las condiciones de la imagen de Microsoft al ejecutar este script.
"$motor" run -d --cidfile "$salida/sqlserver.cid" -p 127.0.0.1::1433 \
  -e MSSQL_SA_PASSWORD -e ACCEPT_EULA=Y -e MSSQL_PID=Developer \
  -e MSSQL_MEMORY_LIMIT_MB=2048 "$ms_imagen" > "$salida/sqlserver-arranque.log" 2>&1
pg_direccion="$("$motor" port "$(cat "$salida/postgres.cid")" 5432/tcp)"
ms_direccion="$("$motor" port "$(cat "$salida/sqlserver.cid")" 1433/tcp)"
export FHIRVIEWS_PG_PORT="${pg_direccion##*:}"
export FHIRVIEWS_MSSQL_PORT="${ms_direccion##*:}"
[[ "$FHIRVIEWS_PG_PORT" =~ ^[0-9]+$ && "$FHIRVIEWS_MSSQL_PORT" =~ ^[0-9]+$ ]] || {
  echo "No se pudieron obtener los puertos de prueba" >&2; exit 1;
}
export TZ=UTC
Rscript "$raiz/data-raw/probar-sql-dbi.R" "$raiz" "$salida" > "$salida/pruebas.log" 2>&1
cat "$salida/pruebas.log"
