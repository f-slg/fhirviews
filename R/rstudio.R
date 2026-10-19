#' Conexión activa y panel Connections de RStudio
#'
#' [fhir_conectar()] guarda la última conexión como *conexión activa*, que
#' usan los addins de RStudio y [fhir_ejecutar_texto()]. En RStudio, además,
#' la registra en el panel *Connections*: allí se ven los tipos de recurso
#' del servidor, sus columnas y una vista previa de los datos (con
#' [fhir_tabla()]), y hay acciones para ver las capacidades del servidor.
#'
#' * `fhir_conexion_activa()` devuelve la conexión activa.
#' * `fhir_desconectar()` la quita del panel y deja de usarla como activa.
#'
#' @param con Conexión creada con [fhir_conectar()].
#'
#' @return `fhir_conexion_activa()` devuelve un objeto `fhir_conexion`.
#'   `fhir_desconectar()` devuelve `TRUE` de forma invisible.
#' @export
#' @examplesIf fhir_disponible("https://hapi.fhir.org/baseR4")
#' con <- fhir_conectar("https://hapi.fhir.org/baseR4", panel = FALSE)
#' identical(fhir_conexion_activa()$url, con$url)
#' fhir_desconectar(con)
fhir_conexion_activa <- function() {
  con <- .fhirviews$activa
  if (is.null(con)) {
    cli::cli_abort(c(
      "No hay una conexi\u00f3n FHIR activa.",
      "i" = "Con\u00e9ctate antes con {.code fhir_conectar(\"https://...\")}."
    ), class = "fhirviews_error")
  }
  con
}

#' @rdname fhir_conexion_activa
#' @export
fhir_desconectar <- function(con) {
  comprobar_conexion(con)
  observador <- getOption("connectionObserver")
  if (!is.null(observador)) {
    observador$connectionClosed(type = "FHIR", host = con$url)
  }
  if (identical(.fhirviews$activa$url, con$url)) {
    .fhirviews$activa <- NULL
  }
  invisible(TRUE)
}

#' Ejecutar una vista contra un servidor FHIR
#'
#' Busca en el servidor los recursos del tipo de la vista (con
#' [fhir_buscar()]) y les aplica el `ViewDefinition` con [vista_ejecutar()].
#' Los `where` de la vista se aplican después de descargar los datos; para
#' descargar menos, filtra también con parámetros de búsqueda en `...`.
#'
#' @param con Conexión creada con [fhir_conectar()].
#' @param vista Un `ViewDefinition` en cualquier forma que acepte
#'   [vista_leer()].
#' @inheritParams fhir_buscar
#'
#' @return Un `data.frame`, como [vista_ejecutar()].
#' @export
#' @examplesIf fhir_disponible("https://hapi.fhir.org/baseR4")
#' con <- fhir_conectar("https://hapi.fhir.org/baseR4")
#' fhir_vista(con, vista_crear("Patient", c(sexo = "gender",
#'                                          nacimiento = "birthDate")),
#'            `_count` = 10, max_paginas = 1)
fhir_vista <- function(con, vista, ..., parametros = list(), max_paginas = Inf,
                       progreso = interactive()) {
  comprobar_conexion(con)
  vista <- vista_leer(vista)
  recursos <- fhir_buscar(con, vista$resource, ..., parametros = parametros,
                          max_paginas = max_paginas, progreso = progreso)
  vista_ejecutar(recursos, vista, validar = FALSE)
}

#' Ejecutar una petición escrita como texto
#'
#' Ejecuta una petición escrita como en Postman o en los archivos `.http` de
#' VS Code: una primera línea con el método y la ruta, líneas opcionales de
#' cabeceras (`Nombre: valor`) y, tras una línea en blanco, el cuerpo JSON.
#' Las líneas que empiezan con `#` o `//` son comentarios. Es lo que hace el
#' addin *Ejecutar petición FHIR* de RStudio con el texto seleccionado.
#'
#' @param texto Texto de la petición, por ejemplo
#'   `"GET Patient?family=Paredes&_count=5"`. Sin método se usa `GET`.
#' @param con Conexión; por defecto, la activa ([fhir_conexion_activa()]).
#'
#' @return La respuesta, como [fhir_peticion()].
#' @export
#' @examplesIf fhir_disponible("https://hapi.fhir.org/baseR4")
#' con <- fhir_conectar("https://hapi.fhir.org/baseR4")
#' fhir_ejecutar_texto("GET Patient?_summary=count", con)
#'
#' fhir_ejecutar_texto('
#' POST Patient/$validate
#' Prefer: return=OperationOutcome
#'
#' {"resourceType": "Patient", "gender": "female"}
#' ', con)
fhir_ejecutar_texto <- function(texto, con = fhir_conexion_activa()) {
  comprobar_conexion(con)
  p <- analizar_peticion(texto)
  fhir_peticion(con, p$metodo, p$ruta, cuerpo = p$cuerpo,
                cabeceras = p$cabeceras)
}

metodos_http <- c("GET", "POST", "PUT", "PATCH", "DELETE", "HEAD")

analizar_peticion <- function(texto) {
  lineas <- unlist(strsplit(paste(texto, collapse = "\n"), "\r?\n"))
  lineas <- lineas[!grepl("^\\s*(#|//)", lineas)]
  while (length(lineas) > 0L && !nzchar(trimws(lineas[1]))) {
    lineas <- lineas[-1]
  }
  if (length(lineas) == 0L) {
    cli::cli_abort(c(
      "No hay ninguna petici\u00f3n en el texto.",
      "i" = "Escribe por ejemplo {.code GET Patient?family=Paredes}."
    ), class = "fhirviews_error", call = NULL)
  }
  partes <- strsplit(trimws(lineas[1]), "\\s+")[[1]]
  if (toupper(partes[1]) %in% metodos_http) {
    metodo <- toupper(partes[1])
    ruta <- partes[2]
  } else {
    metodo <- "GET"
    ruta <- partes[1]
  }
  if (is.na(ruta)) ruta <- ""
  resto <- lineas[-1]
  cabeceras <- list()
  i <- 1L
  while (i <= length(resto) &&
         grepl("^[A-Za-z][A-Za-z0-9-]*:\\s*", resto[i])) {
    nombre <- sub(":.*$", "", resto[i])
    cabeceras[[nombre]] <- trimws(sub("^[^:]*:", "", resto[i]))
    i <- i + 1L
  }
  cuerpo <- if (i <= length(resto)) {
    trimws(paste(resto[i:length(resto)], collapse = "\n"))
  }
  if (!is.null(cuerpo) && !nzchar(cuerpo)) cuerpo <- NULL
  list(metodo = metodo, ruta = ruta, cabeceras = cabeceras, cuerpo = cuerpo)
}

# --- Panel Connections -------------------------------------------------------

icono_fhir <- function() {
  system.file("icons", "fhir.png", package = "fhirviews")
}

codigo_conexion <- function(con) {
  paste0("library(fhirviews)\ncon <- fhir_conectar(\"", con$url, "\"",
         if (!is.null(con$token)) ", token = Sys.getenv(\"FHIR_TOKEN\")",
         ")")
}

abrir_panel <- function(con) {
  observador <- getOption("connectionObserver")
  if (is.null(observador)) {
    return(invisible(FALSE))
  }
  observador$connectionOpened(
    type = "FHIR",
    host = con$url,
    displayName = paste("FHIR", sub("^https?://", "", con$url)),
    icon = icono_fhir(),
    connectCode = codigo_conexion(con),
    disconnect = function() fhir_desconectar(con),
    listObjectTypes = function() {
      list(recurso = list(contains = "data", icon = icono_fhir()))
    },
    listObjects = function(...) panel_objetos(con),
    listColumns = function(recurso = NULL, ...) panel_columnas(con, recurso),
    previewObject = function(rowLimit, recurso = NULL, ...) {
      panel_vista_previa(con, recurso, rowLimit)
    },
    actions = list(
      "Capacidades" = list(icon = icono_fhir(), callback = function() {
        utils::View(fhir_capacidades(con), "Capacidades FHIR")
      }),
      "Abrir metadata" = list(icon = icono_fhir(), callback = function() {
        utils::browseURL(paste0(con$url, "/metadata"))
      })
    ),
    connectionObject = con
  )
  invisible(TRUE)
}

panel_objetos <- function(con) {
  tipos <- tryCatch({
    cap <- fhir_capacidades(con)
    sort(cap$recurso[grepl("search-type", cap$interacciones, fixed = TRUE)])
  }, error = function(e) character())
  data.frame(name = tipos, type = rep("recurso", length(tipos)),
             stringsAsFactors = FALSE)
}

panel_columnas <- function(con, recurso) {
  tabla <- tryCatch(
    panel_vista_previa(con, recurso, 20L),
    error = function(e) data.frame()
  )
  if (ncol(tabla) == 0L) {
    return(data.frame(name = "(sin datos)", type = "", stringsAsFactors = FALSE))
  }
  data.frame(
    name = names(tabla),
    type = vapply(tabla, function(x) class(x)[1], character(1)),
    stringsAsFactors = FALSE
  )
}

panel_vista_previa <- function(con, recurso, filas) {
  filas <- max(1L, min(as.integer(filas), 100L))
  r <- fhir_buscar(con, recurso, `_count` = filas, max_paginas = 1,
                   progreso = FALSE)
  tabla <- fhir_tabla(r, tipo = recurso)
  utils::head(tabla, filas)
}

# --- Addins ------------------------------------------------------------------

#' Addins de RStudio
#'
#' Funciones que llaman los addins de RStudio (menú *Addins*). No hace falta
#' usarlas directamente.
#'
#' * *Ejecutar petición FHIR*: toma el texto seleccionado (o la línea del
#'   cursor) y lo ejecuta con [fhir_ejecutar_texto()] en la consola.
#' * *Ejecutar ViewDefinition*: toma el JSON seleccionado (o el archivo
#'   abierto), lo ejecuta contra el servidor activo con [fhir_vista()] y abre
#'   el resultado. Descarga como mucho `getOption("fhirviews.addin_paginas", 5)`
#'   páginas.
#'
#' @return `NULL`, de forma invisible.
#' @keywords internal
#' @export
addin_peticion <- function() {
  ctx <- contexto_rstudio()
  texto <- ctx$seleccion
  if (!nzchar(trimws(texto))) {
    texto <- ctx$contenido[ctx$linea]
  }
  enviar_a_consola(c(prefijo_conexion(), codigo_addin_peticion(texto)))
}

#' @rdname addin_peticion
#' @export
addin_vista <- function() {
  ctx <- contexto_rstudio()
  vista <- ctx$seleccion
  if (!nzchar(trimws(vista))) {
    guardado <- nzchar(ctx$ruta) && file.exists(ctx$ruta) &&
      identical(readLines(ctx$ruta, warn = FALSE), ctx$contenido)
    vista <- if (guardado) ctx$ruta else paste(ctx$contenido, collapse = "\n")
  }
  enviar_a_consola(c(prefijo_conexion(), codigo_addin_vista(vista)))
}

codigo_addin_peticion <- function(texto) {
  c(paste0("fhir_respuesta <- fhir_ejecutar_texto(", deparse1(texto), ")"),
    "fhir_respuesta")
}

codigo_addin_vista <- function(vista) {
  paginas <- getOption("fhirviews.addin_paginas", 5L)
  c(paste0("fhir_tabla_vista <- fhir_vista(fhir_conexion_activa(), ",
           deparse1(vista), ", max_paginas = ", paginas, ")"),
    "View(fhir_tabla_vista)")
}

# Si no hay conexión activa, pide la URL y agrega el código para conectarse
prefijo_conexion <- function() {
  if (!is.null(.fhirviews$activa)) {
    return(character())
  }
  url <- rstudioapi::showPrompt(
    "Servidor FHIR",
    "No hay una conexi\u00f3n activa. URL del servidor FHIR:",
    "https://hapi.fhir.org/baseR4"
  )
  if (is.null(url) || !nzchar(url)) {
    cli::cli_abort("Se cancel\u00f3 la conexi\u00f3n.", class = "fhirviews_error")
  }
  paste0("con <- fhir_conectar(", deparse1(url), ")")
}

contexto_rstudio <- function() {
  rlang::check_installed("rstudioapi", reason = "para usar los addins.")
  if (!rstudioapi::isAvailable()) {
    cli::cli_abort("Los addins de fhirviews solo funcionan dentro de RStudio.",
                   class = "fhirviews_error")
  }
  ctx <- rstudioapi::getActiveDocumentContext()
  list(
    seleccion = paste(ctx$selection[[1]]$text, collapse = "\n"),
    linea = ctx$selection[[1]]$range$start[[1]],
    contenido = ctx$contents,
    ruta = ctx$path %||% ""
  )
}

enviar_a_consola <- function(codigo) {
  rstudioapi::sendToConsole(paste(codigo, collapse = "\n"), execute = TRUE)
  invisible(NULL)
}
