#' Componente Rust opcional para la construccion SQL a FHIR R4
#'
#' Selecciona un ejecutable local del componente `fhirviews-rust-validator`.
#' Se usa mediante el argumento `componente` de [fhir_desde_tabla()] o
#' [fhir_desde_sql()]. No descarga, compila ni instala Rust o ejecutables.
#' La instalacion y el uso predeterminado de fhirviews siguen utilizando R.
#'
#' El componente revisa estructuras que R ya construyo y tipifico. No evalua
#' FHIRPath, no convierte versiones FHIR y no sustituye [fhir_validar()].
#' El protocolo es `fhirviews-r4-validator/1`. Se comprueban capacidades,
#' version FHIR, identidad del esquema y numero de recursos revisados.
#' El plan se prepara una vez por sesion y se reutiliza entre llamadas.
#'
#' Ante un error de datos se usa el validador R para emitir el mismo
#' diagnostico, clase, fila y campo que el constructor predeterminado.
#' Ante ausencia, timeout o respuesta incompatible del ejecutable,
#' `fallback = TRUE` avisa y valida el lote con R; `FALSE` produce un error
#' `fhirviews_error_componente`. Un error de datos no activa ese respaldo.
#'
#' La comunicacion usa archivos temporales locales en una carpeta privada,
#' eliminados al terminar. Los recursos no se envian a una red. Se debe elegir
#' un ejecutable de confianza: se ejecuta con los permisos del proceso R.
#' La consulta SQL y el resultado construido siguen residiendo en memoria.
#'
#' @param binario Ruta al ejecutable compilado del componente. Tambien acepta
#'   el nombre de un ejecutable disponible en `PATH`.
#' @param fallback Si se permite validar en R cuando el componente no puede
#'   ejecutar su contrato; avisa en cada llamada afectada.
#' @param tiempo Limite entero de segundos de cada proceso, entre 1 y 3600.
#' @return Un objeto `fhir_componente_rust`. No ejecuta el binario hasta
#'   construir un lote no vacio.
#' @export
#' @examples
#' componente <- fhir_componente_rust("/ruta/al/fhirviews-rust-validator")
#' # fhir_desde_tabla(datos, mapa, componente = componente)
fhir_componente_rust <- function(binario, fallback = TRUE, tiempo = 60L) {
  if (!es_texto(binario) || !is.logical(fallback) || length(fallback) != 1L ||
      is.na(fallback) || !is.numeric(tiempo) || length(tiempo) != 1L ||
      is.na(tiempo) || !is.finite(tiempo) || tiempo != trunc(tiempo) ||
      tiempo < 1 || tiempo > 3600) {
    error_componente_rust("argumentos")
  }
  encontrado <- Sys.which(binario)
  if (nzchar(encontrado)) binario <- unname(encontrado)
  binario <- normalizePath(path.expand(binario), winslash = "/", mustWork = FALSE)
  structure(list(binario = binario, fallback = fallback, tiempo = as.integer(tiempo),
    cache = new.env(parent = emptyenv())), class = "fhir_componente_rust")
}

comprobar_componente_rust <- function(x) {
  if (!inherits(x, "fhir_componente_rust") || !is.list(x) ||
      !es_texto(x$binario) || !is.logical(x$fallback) || length(x$fallback) != 1L ||
      is.na(x$fallback) || !is.integer(x$tiempo) || length(x$tiempo) != 1L ||
      is.na(x$tiempo) || x$tiempo < 1L || x$tiempo > 3600L || !is.environment(x$cache)) {
    error_componente_rust("argumentos")
  }
  invisible(NULL)
}

error_componente_rust <- function(motivo) {
  mensajes <- c(argumentos = "Componente no valido; usa fhir_componente_rust() con una ruta, fallback logico y tiempo entero.",
    ausente = "El ejecutable del componente Rust no esta disponible.",
    proceso = "El proceso Rust no termino correctamente o excedio su tiempo.",
    contrato = "La respuesta Rust no cumple el contrato de fhirviews.")
  cli::cli_abort(unname(mensajes[[motivo]]),
    class = c("fhirviews_error_componente", "fhirviews_error"), motivo = motivo, call = NULL)
}

proceso_componente_rust <- function(componente, argumentos, carpeta) {
  salida <- file.path(carpeta, "respuesta.json")
  errores <- file.path(carpeta, "proceso.log")
  if (!file.exists(componente$binario) || dir.exists(componente$binario) ||
      file.access(componente$binario, 1L) != 0L) error_componente_rust("ausente")
  estado <- tryCatch(suppressWarnings(system2(componente$binario,
    vapply(argumentos, shQuote, character(1)), stdout = salida, stderr = errores,
    timeout = componente$tiempo)), error = function(e) NA_integer_)
  if (!identical(estado, 0L)) error_componente_rust("proceso")
  # Una respuesta es pequena y no debe contener los recursos del lote.
  if (!file.exists(salida) || is.na(file.info(salida)$size) ||
      file.info(salida)$size > 65536) error_componente_rust("contrato")
  r <- tryCatch(jsonlite::read_json(salida, simplifyVector = FALSE), error = function(e) NULL)
  if (!is.list(r) || !identical(r$contrato, "fhirviews-r4-validator/1") ||
      !identical(r$version_fhir, "4.0.1")) error_componente_rust("contrato")
  r
}

plan_componente_rust <- function() {
  if (!is.null(.fhirviews$plan_rust)) return(.fhirviews$plan_rust)
  esquema <- esquema_mapeo()
  registros <- new.env(parent = emptyenv())
  compilar <- function(ctx) {
    clave <- paste(ctx$tipo, ctx$prefijo, sep = "|")
    if (exists(clave, registros, inherits = FALSE)) return(clave)
    assign(clave, NULL, registros)
    inicio <- if (nzchar(ctx$prefijo)) paste0(ctx$prefijo, ".") else ""
    hijos <- names(esquema$esquemas[[ctx$tipo]]) %||% character()
    hijos <- hijos[startsWith(hijos, inicio)]
    hijos <- hijos[!grepl(".", substring(hijos, nchar(inicio) + 1L), fixed = TRUE)]
    grupos <- list()
    campos <- list()
    for (h in hijos) {
      nombre <- substring(h, nchar(inicio) + 1L)
      e <- esquema$esquemas[[ctx$tipo]][[h]]
      variantes <- if (endsWith(nombre, "[x]"))
        con_sufijo(sub("\\[x\\]$", "", nombre), unlist(e$tipos)) else nombre
      grupos[[length(grupos) + 1L]] <- list(nombre = nombre,
        nombres = as.list(variantes), min = e$min)
      for (variante in variantes) {
        def <- elemento_mapeo(ctx, variante)
        complejo <- (!is.null(def$tipo) && grepl("^[A-Z]", def$tipo)) || !is.null(def$ref)
        hijo <- if (complejo) compilar(def$siguiente) else NULL
        campos[[length(campos) + 1L]] <- list(nombre = variante, tipo = def$tipo %||% "",
          min = def$min, max = if (def$max == "*") NULL else as.integer(def$max),
          repetido = def$max == "*" || as.numeric(def$max) > 1,
          hijo = hijo, destinos = as.list(unlist(def$destinos)), vinculo = def$vinculo)
      }
    }
    assign(clave, list(clave = clave, grupos = grupos, campos = campos), registros)
    clave
  }
  recursos <- unlist(esquema$recursos)
  raices <- stats::setNames(lapply(recursos, function(t)
    compilar(list(tipo = t, prefijo = ""))), recursos)
  archivo <- system.file("schema", "mapeo-r4.json", package = "fhirviews", mustWork = TRUE)
  plan <- list(contrato = "fhirviews-r4-validator/1", version_fhir = "4.0.1",
    esquema_id = unname(as.character(tools::md5sum(archivo))), raices = raices,
    recursos_r4 = esquema$recursos_r4,
    nodos = lapply(sort(ls(registros)), function(k) get(k, registros, inherits = FALSE)))
  .fhirviews$plan_rust <- plan
  plan
}

validar_con_componente <- function(recursos, textos, componente, validar_r) {
  carpeta <- tempfile("fhirviews-rust-")
  if (!dir.create(carpeta, mode = "0700")) error_componente_rust("proceso")
  on.exit(unlink(carpeta, recursive = TRUE), add = TRUE)
  tryCatch({
    huella <- unname(as.character(tools::md5sum(componente$binario)))
    if (is.na(huella)) error_componente_rust("ausente")
    if (!identical(componente$cache$huella, huella)) {
      r <- proceso_componente_rust(componente, "--capabilities", carpeta)
      if (!identical(r$componente, "fhirviews-rust-validator") ||
          !identical(r$alcance, "recursos-construidos-y-tipados-por-r")) {
        error_componente_rust("contrato")
      }
      componente$cache$huella <- huella
    }
    plan <- plan_componente_rust()
    archivo_plan <- file.path(carpeta, "plan.json")
    entrada <- file.path(carpeta, "entrada.ndjson")
    jsonlite::write_json(plan, archivo_plan, auto_unbox = TRUE, null = "null")
    writeLines(enc2utf8(textos), entrada, useBytes = TRUE)
    r <- proceso_componente_rust(componente, c(archivo_plan, entrada), carpeta)
    if (!identical(r$esquema_id, plan$esquema_id) || !is.list(r$resultado)) {
      error_componente_rust("contrato")
    }
    r <- r$resultado
    entero <- function(x) is.numeric(x) && length(x) == 1L && !is.na(x) &&
      is.finite(x) && x == trunc(x)
    if (!is.logical(r$valido) || length(r$valido) != 1L || is.na(r$valido) ||
        !entero(r$recursos)) error_componente_rust("contrato")
    if (r$valido) {
      if (r$recursos != length(recursos) || !is.null(r$error)) error_componente_rust("contrato")
    } else {
      if (!is.list(r$error) || !entero(r$error$fila) || r$error$fila < 1 ||
          r$error$fila > length(recursos) || r$recursos != r$error$fila ||
          !es_texto(r$error$campo) || !es_texto(r$error$motivo)) error_componente_rust("contrato")
      # Reproducir el diagnostico completo y su precedencia en R. El rechazo
      # de un dato nunca se interpreta como un fallo del ejecutable.
      validar_r(seq_len(r$error$fila))
      error_componente_rust("contrato")
    }
    invisible(NULL)
  }, fhirviews_error_componente = function(e) {
    if (!componente$fallback) stop(e)
    cli::cli_warn(c("El componente Rust no pudo validar el lote; se valida con R.",
      "i" = "Motivo: {.val {e$motivo}}."), class = "fhirviews_aviso_componente", call = NULL)
    validar_r(seq_along(recursos))
  })
}

construir_con_componente <- function(datos, mapa, componente) {
  recursos <- vector("list", nrow(datos))
  error_primitivo <- NULL
  completadas <- 0L
  for (i in seq_len(nrow(datos))) {
    r <- tryCatch(construir_fila_mapeada(datos, mapa, i), error = identity)
    if (inherits(r, "error")) { error_primitivo <- r; break }
    recursos[[i]] <- r
    completadas <- i
  }
  recursos <- recursos[seq_len(completadas)]
  textos <- if (completadas) motor_actual()$serializar_recursos(recursos) else character()
  validar_r <- function(filas) {
    for (i in filas) validar_recurso_mapeado(recursos[[i]],
      list(tipo = mapa$recurso, prefijo = ""), i)
    invisible(NULL)
  }
  if (completadas) validar_con_componente(recursos, textos, componente, validar_r)
  if (!is.null(error_primitivo)) stop(error_primitivo)
  finalizar_recursos_mapeados(recursos, textos)
}
