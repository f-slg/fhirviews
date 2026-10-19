#' Banco oficial de pruebas de SQL on FHIR
#'
#' Ejecuta las pruebas oficiales de conformidad de SQL on FHIR
#' ([FHIR/sql-on-fhir.js](https://github.com/FHIR/sql-on-fhir.js), carpeta
#' `tests/`) con [vista_ejecutar()] e informa cuántas pasan.
#'
#' Cada prueba aplica un `ViewDefinition` a unos recursos y compara el
#' resultado con las filas esperadas (sin importar su orden, como el
#' ejecutor oficial), con los nombres de columnas esperados o con un error
#' esperado. Las pruebas tienen un perfil: `shareable` (las que debe cumplir
#' toda implementación) o `experimental`.
#'
#' El paquete incluye una copia del banco (ver `FUENTE` en
#' `system.file("sof-tests", package = "fhirviews")`), de modo que no hace
#' falta internet. Con `descargar = TRUE` se usa la versión más reciente.
#'
#' @param archivos Nombres de los archivos de pruebas que se ejecutan (por
#'   ejemplo `"basic.json"`). Por defecto, todos.
#' @param descargar Si es `TRUE`, descarga el banco de GitHub en lugar de usar
#'   la copia incluida. Necesita conexión a internet.
#' @param ref Rama, etiqueta o commit de `FHIR/sql-on-fhir.js` que se descarga
#'   cuando `descargar = TRUE`.
#' @param directorio Carpeta con los archivos JSON del banco, si se tiene una
#'   copia propia. Tiene prioridad sobre `descargar`.
#' @param informe Ruta opcional de un archivo JSON donde se guarda el
#'   resultado en el formato oficial de informes de SQL on FHIR (el que usa
#'   la página de implementaciones).
#'
#' @return Un `data.frame` de clase `fhir_conformidad` con una fila por
#'   prueba: `archivo`, `prueba`, `perfil`, `aprobada` (lógico) y `detalle`
#'   (motivo de la falla). Al imprimirlo muestra el resumen por perfil y las
#'   pruebas que fallan.
#' @export
#' @examples
#' vista_conformidad("basic.json")
#' \donttest{
#' res <- vista_conformidad()
#' table(res$perfil, res$aprobada)
#' }
vista_conformidad <- function(archivos = NULL, descargar = FALSE,
                              ref = "main", directorio = NULL,
                              informe = NULL) {
  if (is.null(directorio)) {
    if (descargar) {
      directorio <- tempfile("sof-tests-")
      on.exit(unlink(directorio, recursive = TRUE), add = TRUE)
      descargar_banco_sof(ref, directorio)
    } else {
      directorio <- system.file("sof-tests", package = "fhirviews",
                                mustWork = TRUE)
    }
  }
  disponibles <- list.files(directorio, pattern = "\\.json$")
  disponibles <- setdiff(disponibles, "tests.schema.json")
  if (is.null(archivos)) {
    archivos <- disponibles
  } else {
    faltan <- setdiff(archivos, disponibles)
    if (length(faltan) > 0L) {
      cli::cli_abort(c(
        "No se encontraron los archivos de pruebas {.file {faltan}}.",
        "i" = "Disponibles: {.file {disponibles}}."
      ), class = "fhirviews_error")
    }
  }

  filas <- lapply(archivos, function(f) {
    banco <- jsonlite::fromJSON(file.path(directorio, f),
                                simplifyVector = FALSE)
    recursos <- fhir_recursos(banco$resources)
    res <- lapply(banco$tests, function(t) {
      r <- ejecutar_prueba_sof(t, recursos)
      etiquetas <- unlist(t$tags)
      data.frame(
        archivo = f,
        prueba = as.character(t$title %||% ""),
        perfil = if (length(etiquetas) > 0L) etiquetas[1] else NA_character_,
        aprobada = r$aprobada,
        detalle = r$detalle,
        stringsAsFactors = FALSE
      )
    })
    do.call(rbind, res)
  })
  res <- do.call(rbind, filas)
  rownames(res) <- NULL
  attr(res, "fuente") <- leer_fuente_sof(directorio)
  class(res) <- c("fhir_conformidad", "data.frame")

  if (!is.null(informe)) {
    escribir_informe_sof(res, informe)
  }
  res
}

#' @export
print.fhir_conformidad <- function(x, ...) {
  fuente <- attr(x, "fuente")
  cat("Banco de pruebas de SQL on FHIR",
      if (!is.null(fuente)) paste0("(", fuente, ")"), "\n")
  cat("fhirviews ", as.character(utils::packageVersion("fhirviews")),
      " \u00b7 fhirpath.js ", fhirviews_version_fhirpath(), "\n\n", sep = "")
  perfiles <- sort(unique(x$perfil[!is.na(x$perfil)]))
  for (p in c(perfiles, if (anyNA(x$perfil)) NA)) {
    sel <- if (is.na(p)) is.na(x$perfil) else x$perfil %in% p
    cat(sprintf("  %-14s %3d de %3d aprobadas\n",
                if (is.na(p)) "(sin perfil)" else p,
                sum(x$aprobada[sel]), sum(sel)))
  }
  cat(sprintf("  %-14s %3d de %3d aprobadas\n", "total", sum(x$aprobada),
              nrow(x)))
  fallas <- x[!x$aprobada, , drop = FALSE]
  if (nrow(fallas) > 0L) {
    cat("\nFallan:\n")
    for (i in seq_len(nrow(fallas))) {
      cat("  [", fallas$perfil[i], "] ", fallas$archivo[i], ": ",
          fallas$prueba[i], "\n      ", fallas$detalle[i], "\n", sep = "")
    }
  }
  invisible(x)
}

# --- Ejecución y comparación -------------------------------------------------

ejecutar_prueba_sof <- function(t, recursos) {
  resultado <- function(ok, detalle = "") {
    list(aprobada = ok, detalle = detalle)
  }
  if (!is.null(t$expectError)) {
    error <- tryCatch({
      vista_ejecutar(recursos, t$view)
      NULL
    }, error = function(e) e)
    if (is.null(error)) {
      return(resultado(FALSE, "se esperaba un error y no lo hubo"))
    }
    return(resultado(TRUE))
  }
  df <- tryCatch(vista_ejecutar(recursos, t$view), error = function(e) e)
  if (inherits(df, "error")) {
    return(resultado(FALSE, paste("error:",
                                  limpiar_mensaje(conditionMessage(df)))))
  }
  if (!is.null(t$expectColumns)) {
    esperadas <- as.character(unlist(t$expectColumns))
    if (identical(names(df), esperadas)) {
      return(resultado(TRUE))
    }
    return(resultado(FALSE, sprintf("columnas (%s); se esperaban (%s)",
                                    paste(names(df), collapse = ", "),
                                    paste(esperadas, collapse = ", "))))
  }
  colecciones <- names(df)[vapply(df, is.list, logical(1))]
  obtenidas <- sort(claves_filas_df(df, colecciones))
  esperadas <- sort(claves_filas_esperadas(t$expect, colecciones))
  if (identical(obtenidas, esperadas)) {
    return(resultado(TRUE))
  }
  if (length(obtenidas) != length(esperadas)) {
    return(resultado(FALSE, sprintf("%d filas; se esperaban %d",
                                    length(obtenidas), length(esperadas))))
  }
  i <- which(obtenidas != esperadas)[1]
  resultado(FALSE, sprintf("fila %s; se esperaba %s", obtenidas[i],
                           esperadas[i]))
}

limpiar_mensaje <- function(x) {
  x <- cli::ansi_strip(x)
  gsub("\\s+", " ", x)
}

# Representación de cada fila como texto, con las columnas ordenadas por
# nombre y los valores en JSON, para comparar sin importar el orden.
valor_json <- function(x, coleccion) {
  if (coleccion) {
    x <- if (is.list(x)) x else as.list(x)
    return(as.character(jsonlite::toJSON(x, auto_unbox = TRUE, digits = NA,
                                         null = "null", na = "null")))
  }
  if (is.null(x) || (is.list(x) && length(x) == 0L) ||
      (length(x) == 1L && is.na(x))) {
    return("null")
  }
  as.character(jsonlite::toJSON(x, auto_unbox = TRUE, digits = NA,
                                null = "null", na = "null"))
}

claves_filas_df <- function(df, colecciones) {
  if (nrow(df) == 0L) {
    return(character())
  }
  nombres <- sort(names(df))
  vapply(seq_len(nrow(df)), function(i) {
    paste(vapply(nombres, function(n) {
      paste0(n, "=", valor_json(df[[n]][[i]], n %in% colecciones))
    }, character(1)), collapse = "|")
  }, character(1))
}

claves_filas_esperadas <- function(filas, colecciones) {
  vapply(filas, function(r) {
    nombres <- sort(names(r))
    paste(vapply(nombres, function(n) {
      paste0(n, "=", valor_json(r[[n]], n %in% colecciones))
    }, character(1)), collapse = "|")
  }, character(1))
}

# --- Informe oficial ---------------------------------------------------------

escribir_informe_sof <- function(res, ruta) {
  informe <- lapply(split(res, factor(res$archivo, unique(res$archivo))),
                    function(d) {
    list(tests = lapply(seq_len(nrow(d)), function(i) {
      r <- list(passed = d$aprobada[i])
      if (!d$aprobada[i]) r$error <- d$detalle[i]
      list(name = d$prueba[i], result = r)
    }))
  })
  writeLines(jsonlite::toJSON(informe, auto_unbox = TRUE, pretty = TRUE),
             ruta, useBytes = TRUE)
  invisible(ruta)
}

# --- Descarga ----------------------------------------------------------------

repo_sof <- "FHIR/sql-on-fhir.js"

descargar_banco_sof <- function(ref, destino) {
  api <- "https://api.github.com/repos/"
  leer_api <- function(url) {
    tryCatch(
      jsonlite::fromJSON(url, simplifyVector = TRUE),
      error = function(e) {
        cli::cli_abort(c(
          "No se pudo descargar el banco de pruebas de SQL on FHIR.",
          "x" = "{limpiar_mensaje(conditionMessage(e))}",
          "i" = "Revisa la conexi\u00f3n o usa la copia incluida
                 ({.code descargar = FALSE})."
        ), class = "fhirviews_error", call = NULL)
      }
    )
  }
  commit <- leer_api(paste0(api, repo_sof, "/commits/", ref))
  sha <- commit$sha
  contenido <- leer_api(paste0(api, repo_sof, "/contents/tests?ref=", sha))
  json <- contenido[grepl("\\.json$", contenido$name), ]
  dir.create(destino, showWarnings = FALSE, recursive = TRUE)
  for (i in seq_len(nrow(json))) {
    utils::download.file(json$download_url[i],
                         file.path(destino, json$name[i]),
                         quiet = TRUE, mode = "wb")
  }
  fecha <- commit$commit$committer$date
  writeLines(c(paste0("repositorio: https://github.com/", repo_sof),
               paste0("commit: ", sha),
               paste0("fecha: ", fecha)),
             file.path(destino, "FUENTE"))
  invisible(list(sha = sha, fecha = fecha))
}

leer_fuente_sof <- function(directorio) {
  archivo <- file.path(directorio, "FUENTE")
  if (!file.exists(archivo)) {
    return(NULL)
  }
  lineas <- readLines(archivo, warn = FALSE)
  valor <- function(clave) {
    l <- grep(paste0("^", clave, ": "), lineas, value = TRUE)
    if (length(l)) sub(paste0("^", clave, ": "), "", l[1]) else NA_character_
  }
  paste0(repo_sof, "@", substr(valor("commit"), 1, 7), ", ",
         substr(valor("fecha"), 1, 10))
}
