#' Ejecutar una vista sobre archivos NDJSON por bloques
#'
#' Lee como máximo `tamano_lote` líneas a la vez y entrega cada tabla a
#' `procesar`. Los recursos y nodos V8 de cada bloque se liberan antes del
#' siguiente. La memoria del resultado depende de lo que retenga `procesar`.
#' Una línea debe contener un recurso FHIR completo. Se admiten líneas vacías
#' y archivos gzip. El orden de archivos y recursos se conserva.
#'
#' @param archivos Rutas de archivos NDJSON, incluidos `.ndjson.gz`.
#' @param vista Un ViewDefinition aceptado por [vista_leer()].
#' @param procesar Función que recibe una tabla y su número de bloque
#'   (`function(tabla, bloque)`). Su resultado se descarta. Puede escribir en
#'   una base de datos o acumular resúmenes. Se llama también para bloques sin
#'   filas resultantes. Los tipos sin `type` explícito se infieren por bloque;
#'   declara tipos en la vista si necesitas un esquema fijo para la salida.
#' @param tamano_lote Número máximo de líneas leídas por bloque.
#' @param estricto Con `TRUE`, exige `type` primitivo FHIR R4 en todas las
#'   columnas y el mismo contrato (`type` y `collection`) en cada rama.
#'   Valida cada valor antes de convertirlo y antes de llamar a `procesar`.
#'   No admite conversiones implícitas entre texto, números y lógicos.
#'   Los ausentes se conservan como `NA` del tipo declarado y las colecciones
#'   vacías como vectores vacíos de ese tipo. Por defecto es `FALSE`.
#'
#' @details
#' El modo estricto comprueba tipos de R, cardinalidad y límites numéricos:
#' enteros finitos representables en R, rangos de `positiveInt`/`unsignedInt`
#' y decimales finitos. Rechaza números no finitos en la entrada y en los
#' resultados antes de serializarlos. Los demás primitivos se representan como texto; no
#' se validan aquí formatos de fechas, URI, códigos ni perfiles FHIR.
#'
#' Los errores estrictos tienen clase `fhirviews_error_lotes` (también
#' `fhirviews_error_esquema` si falla el contrato). Incluyen `bloque`, `fase`,
#' `columna` y `tipo_esperado` cuando se conocen, `motivo`, `indice_archivo`
#' y `completados` (totales de llamadas a `procesar` que retornaron sin error).
#' El bloque 0 indica un fallo de definición antes de leer los archivos.
#' Los mensajes no incorporan valores, rutas de entrada ni el error original
#' del destino. Los mensajes o avisos que emita el propio consumidor quedan
#' bajo su responsabilidad. Los avisos de lectura o evaluación detienen el
#' bloque en modo estricto.
#'
#' La función no revierte escrituras, no reintenta y no guarda checkpoints.
#' Si falla `procesar`, el bloque actual puede tener escrituras parciales;
#' `completados` no demuestra persistencia y una transacción externa puede
#' revertir incluso esos bloques. No lo uses para decidir automáticamente
#' qué bloques omitir al reanudar.
#'
#' Para reintentar sin acumular duplicados, usa una transacción que abarque
#' toda la carga y reemplace el resultado, o escribe en un destino temporal
#' nuevo que solo publiques cuando termine. Conserva las mismas entradas,
#' orden, vista y tamaño de bloque. El ejemplo instalado
#' `system.file("examples", "lotes-transaccion.R", package = "fhirviews")`
#' demuestra rollback y reemplazo completo con DuckDB y datos ficticios.
#' @return Invisiblemente, una lista con los totales `bloques`, `recursos`
#'   y `filas`. Si no hay líneas con recursos no se llama a `procesar`.
#'   Si hay un error, se detiene; los efectos previos de `procesar` permanecen.
#' @encoding UTF-8
#' @export
#' @examples
#' archivo <- system.file("extdata", "caso_clinico.ndjson", package = "fhirviews")
#' vista <- vista_crear("Patient", c(sexo = "gender"))
#' vista_ejecutar_lotes(archivo, vista,
#'   function(tabla, bloque) cat(bloque, nrow(tabla), "filas\n"), tamano_lote = 20)
vista_ejecutar_lotes <- function(archivos, vista, procesar, tamano_lote = 10000L,
                                 estricto = FALSE) {
  if (!is.character(archivos) || !length(archivos) || anyNA(archivos) ||
      any(!file.exists(archivos)) || any(dir.exists(archivos))) {
    cli::cli_abort("{.arg archivos} debe contener rutas a archivos existentes.",
                   class = "fhirviews_error")
  }
  if (!is.function(procesar)) {
    cli::cli_abort("{.arg procesar} debe ser una funci\u00f3n.", class = "fhirviews_error")
  }
  if (!is.logical(estricto) || length(estricto) != 1L || is.na(estricto)) {
    cli::cli_abort("{.arg estricto} debe ser TRUE o FALSE.", class = "fhirviews_error")
  }
  if (!is.numeric(tamano_lote) || length(tamano_lote) != 1L ||
      is.na(tamano_lote) || !is.finite(tamano_lote) || tamano_lote < 1 ||
      tamano_lote != floor(tamano_lote) || tamano_lote > .Machine$integer.max) {
    cli::cli_abort("{.arg tamano_lote} debe ser un entero positivo.",
                   class = "fhirviews_error")
  }
  totales <- list(bloques = 0, recursos = 0, filas = 0)
  indice_archivo <- 0L
  bloque <- 0L
  fallando <- FALSE
  fallar <- function(fase, columna = NULL, motivo = NULL, tipo = NULL) {
    fallando <<- TRUE
    mensaje <- paste0("No se pudo completar el bloque {bloque} en la fase {.val {fase}}.")
    if (!is.null(columna)) mensaje <- paste0(mensaje, " Columna {.field {columna}}.")
    if (!is.null(tipo)) mensaje <- paste0(mensaje, " Tipo esperado: {.code {tipo}}.")
    detalle <- switch(motivo %||% "",
      falta_type = "Declare type para esta columna.",
      tipo_no_admitido = "Use un tipo primitivo de FHIR R4.",
      ramas_incompatibles = "Las ramas deben declarar el mismo tipo y collection.",
      tipo_incompatible = "Los valores deben respetar el tipo declarado.",
      numero_no_finito = "La entrada contiene numeros no finitos.", "")
    if (nzchar(detalle)) mensaje <- paste(mensaje, detalle)
    cli::cli_abort(mensaje,
      class = c(if (fase == "esquema") "fhirviews_error_esquema",
                "fhirviews_error_lotes", "fhirviews_error"),
      bloque = bloque, fase = fase, columna = columna, motivo = motivo,
      tipo_esperado = tipo,
      indice_archivo = indice_archivo, completados = totales,
      call = NULL, parent = NULL)
  }
  paso <- function(expr, fase) {
    if (!estricto) return(force(expr))
    tryCatch(withCallingHandlers(force(expr), warning = function(w) {
      # Los avisos del motor o de lectura no pueden permitir un bloque parcial.
      if (fase != "procesar") fallar(fase)
    }), error = function(e) {
      # Solo reenviar errores creados por esta invocacion, no los del destino
      # ni los de una llamada anidada que use la misma clase de condicion.
      if (fallando) {
        fallando <<- FALSE
        stop(e)
      }
      columna <- if (fase == "evaluacion" && is.list(e) &&
                     es_texto(e$columna) && e$columna %in% names(contrato)) e$columna
      fallar(fase, columna)
    })
  }
  vista <- paso(vista_leer(vista), "esquema")
  contrato <- if (estricto) contrato_lotes(vista, function(nm, motivo) {
    fallar("esquema", nm, motivo)
  })
  convertir <- if (estricto) function(valores, def, nombre) {
    convertir_lote_estricto(valores, contrato[[nombre]],
                            function() fallar("esquema", nombre, "tipo_incompatible",
                                               contrato[[nombre]]$type))
  }
  leer_archivo <- function(archivo) {
    con <- paso(if (grepl("\\.gz$", archivo, ignore.case = TRUE)) {
      gzfile(archivo, open = "rt", encoding = "UTF-8")
    } else file(archivo, open = "rt", encoding = "UTF-8"), "lectura")
    on.exit(paso(close(con), "lectura"))
    repeat {
      bloque <<- totales$bloques + 1
      lineas <- paso(readLines(con, n = tamano_lote, warn = FALSE), "lectura")
      if (!length(lineas)) break
      lineas <- lineas[nzchar(trimws(lineas))]
      if (!length(lineas)) next
      recursos <- paso(recursos_ndjson(lineas), "lectura")
      if (estricto && !numeros_finitos_lote(recursos)) {
        fallar("lectura", motivo = "numero_no_finito")
      }
      tabla <- paso(ejecutar_vista(recursos, vista, validar = FALSE,
                                   convertir = convertir), "evaluacion")
      if (estricto && !identical(names(tabla), unname(columnas_vista(vista)))) fallar("esquema")
      paso(procesar(tabla, bloque), "procesar")
      totales$bloques <<- bloque
      totales$recursos <<- totales$recursos + length(recursos)
      totales$filas <<- totales$filas + nrow(tabla)
      rm(recursos, tabla, lineas)
    }
  }
  for (i in seq_along(archivos)) {
    indice_archivo <- i
    leer_archivo(archivos[[i]])
  }
  invisible(totales)
}

# Contrato independiente de los datos y consistente entre ramas de unionAll.
contrato_lotes <- function(vista, fallar) {
  tipos <- c("base64Binary", "boolean", "canonical", "code", "date", "dateTime",
             "decimal", "id", "instant", "integer", "markdown", "oid",
             "positiveInt", "string", "time", "unsignedInt", "uri", "url", "uuid", "xhtml")
  contrato <- list()
  visitar <- function(s) {
    for (cl in s$column) {
      if (is.null(cl$type)) fallar(cl$name, "falta_type")
      if (!cl$type %in% tipos) fallar(cl$name, "tipo_no_admitido")
      firma <- list(type = cl$type, collection = isTRUE(cl$collection))
      if (!is.null(contrato[[cl$name]]) && !identical(contrato[[cl$name]], firma)) {
        fallar(cl$name, "ramas_incompatibles")
      }
      contrato[[cl$name]] <<- firma
    }
    for (sub in c(s$select, s$unionAll)) visitar(sub)
  }
  for (s in vista$select) visitar(s)
  contrato
}

# Validar cada valor antes de unlist(): evita coerciones de mezclas a texto.
convertir_lote_estricto <- function(valores, def, fallar) {
  tipo <- def$type
  prototipo <- vector_tipo(tipo)
  escalar <- function(x) {
    if (is.null(x)) return(prototipo[NA_integer_])
    if (!is.atomic(x) || length(x) != 1L) fallar()
    if (is.na(x) && !is.nan(x)) return(prototipo[NA_integer_])
    if (tipo == "boolean") {
      if (!is.logical(x)) fallar()
      return(x)
    }
    if (tipo %in% c(tipos_enteros, tipos_decimales)) {
      if (!is.numeric(x) || !is.finite(x)) fallar()
      if (tipo == "decimal") return(as.double(x))
      if (x != round(x) || abs(x) > .Machine$integer.max ||
          (tipo == "positiveInt" && x <= 0) ||
          (tipo == "unsignedInt" && x < 0)) fallar()
      return(as.integer(x))
    }
    if (!is.character(x)) fallar()
    x
  }
  if (def$collection) {
    return(lapply(valores, function(x) {
      if (!length(x)) return(prototipo)
      vapply(x, escalar, prototipo[NA_integer_], USE.NAMES = FALSE)
    }))
  }
  vapply(valores, escalar, prototipo[NA_integer_], USE.NAMES = FALSE)
}

# Comprobar la entrada antes de que V8 serialice no finitos como null.
numeros_finitos_lote <- function(x) {
  if (is.numeric(x)) return(all(is.finite(x)))
  if (is.list(x)) return(all(vapply(x, numeros_finitos_lote, logical(1))))
  TRUE
}
