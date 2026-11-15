# Funciones de laboratorio. No se cargan desde R/ ni se distribuyen con el paquete.
crear_experimento <- function(archivo_plan, binario) {
  ns <- asNamespace("fhirviews")
  interno <- function(n) get(n, envir = ns)
  esquema <- interno("esquema_mapeo")()$esquemas
  registros <- new.env(parent = emptyenv())
  clave <- function(ctx) paste(ctx$tipo, ctx$prefijo, sep = "|")
  compilar <- function(ctx) {
    k <- clave(ctx)
    if (exists(k, registros, inherits = FALSE)) return(k)
    assign(k, list(clave = k), registros)
    campos_tipo <- esquema[[ctx$tipo]]
    inicio <- if (nzchar(ctx$prefijo)) paste0(ctx$prefijo, ".") else ""
    hijos <- names(campos_tipo)
    if (is.null(hijos)) hijos <- character()
    hijos <- hijos[startsWith(hijos, inicio)]
    hijos <- hijos[!grepl(".", substring(hijos, nchar(inicio) + 1L), fixed = TRUE)]
    grupos <- list()
    campos <- list()
    for (h in hijos) {
      nombre <- substring(h, nchar(inicio) + 1L)
      e <- campos_tipo[[h]]
      variantes <- if (endsWith(nombre, "[x]"))
        interno("con_sufijo")(sub("\\[x\\]$", "", nombre), unlist(e$tipos)) else nombre
      grupos[[length(grupos) + 1L]] <- list(nombre = nombre,
        nombres = as.list(variantes), min = e$min)
      for (variante in variantes) {
        def <- interno("elemento_mapeo")(ctx, variante)
        complejo <- (!is.null(def$tipo) && grepl("^[A-Z]", def$tipo)) || !is.null(def$ref)
        hijo <- if (complejo) compilar(def$siguiente) else NULL
        campos[[variante]] <- list(nombre = variante, tipo = if (is.null(def$tipo)) "" else def$tipo,
          min = def$min, max = if (def$max == "*") NULL else as.integer(def$max),
          repetido = def$max == "*" || as.numeric(def$max) > 1,
          hijo = hijo, destinos = as.list(unlist(def$destinos)), vinculo = def$vinculo,
          # Solo para el plan R; no se exportan estos elementos redundantes.
          elemento = def)
      }
    }
    assign(k, list(clave = k, grupos = grupos, campos = campos), registros)
    k
  }
  recursos <- unlist(interno("esquema_mapeo")()$recursos)
  raices <- stats::setNames(lapply(recursos, function(t) compilar(list(tipo = t, prefijo = ""))), recursos)
  # Enumerar tipos con el mismo modelo R4 que usa validar_destino_referencia().
  ct <- V8::v8()
  ct$eval("var window = globalThis;")
  interno("cargar_js")(ct, interno("ruta_js")("fhirpath", "fhirpath.r4.min.js"))
  conocidos <- jsonlite::fromJSON(ct$eval(paste0(
    "JSON.stringify(Object.keys(fhirpath_r4_model.type2Parent).concat(['Resource']).filter(function(t){",
    "for(var i=0;t&&i<20;i++){if(t==='Resource')return true;t=fhirpath_r4_model.type2Parent[t];}return false;}))")))
  rm(ct)
  nodos <- lapply(sort(ls(registros)), function(k) {
    x <- get(k, registros)
    x$campos <- unname(lapply(x$campos, function(e) { e$elemento <- NULL; e }))
    x
  })
  jsonlite::write_json(list(raices = raices, recursos_r4 = as.list(conocidos), nodos = nodos),
    archivo_plan, auto_unbox = TRUE, null = "null", pretty = FALSE)
  validar_preparado <- function(r, ctx, fila, prefijo = "") {
    nodo <- get(clave(ctx), registros)
    for (g in nodo$grupos) {
      n <- sum(unlist(g$nombres) %in% names(r))
      if ((g$min > 0 && n == 0L) || n > 1L) interno("error_mapeo")(
        "Falta un campo obligatorio o hay tipos de eleccion incompatibles.", fila, paste0(prefijo, g$nombre))
    }
    for (nombre in setdiff(names(r), "resourceType")) {
      def <- nodo$campos[[nombre]]
      campo <- paste0(prefijo, nombre)
      if (is.null(def)) interno("error_mapeo")("Campo FHIR desconocido.", fila, campo)
      valores <- if (def$repetido) r[[nombre]] else list(r[[nombre]])
      if (length(valores) < def$min || (!is.null(def$max) && length(valores) > def$max)) {
        interno("error_mapeo")("Cardinalidad FHIR incompatible.", fila, campo)
      }
      for (v in valores) {
        interno("validar_vinculo_mapeo")(v, def$elemento, fila, campo)
        if (def$tipo == "Reference") interno("validar_referencia_mapeo")(v, def$elemento$destinos, fila, campo)
      }
      if (!is.null(def$hijo)) for (v in valores) {
        validar_preparado(v, def$elemento$siguiente, fila, paste0(campo, "."))
      }
    }
    invisible(NULL)
  }
  # Copia de la funcion publica con entorno propio: no se altera el namespace.
  preparado <- interno("fhir_desde_tabla")
  environment(preparado) <- list2env(list(validar_recurso_mapeado = validar_preparado), parent = ns)
  mensajes <- c(
    obligatorio_eleccion = "Falta un campo obligatorio o hay tipos de eleccion incompatibles.",
    campo_desconocido = "Campo FHIR desconocido.", cardinalidad = "Cardinalidad FHIR incompatible.",
    coding_requerido = "El binding requerido necesita al menos un Coding con code; text no lo sustituye.",
    binding_requerido = "El codigo o par system/code no pertenece al ValueSet requerido.",
    destino_referencia = "El tipo no es un destino FHIR permitido para esta referencia.",
    referencia_sin_destino = "Una referencia requiere reference, identifier o display; type solo no identifica un destino.",
    referencia_contained = "No se construyen referencias a recursos contained.",
    referencia_relativa = "Una referencia relativa debe tener la forma Tipo/id.",
    reference_type_distinto = "Reference.type no coincide con el tipo de la referencia literal.")
  validar_rust <- function(textos) {
    if (!length(textos)) return(invisible(NULL))
    entrada <- tempfile(fileext = ".ndjson")
    salida <- tempfile(fileext = ".json")
    errores <- tempfile(fileext = ".log")
    on.exit(unlink(c(entrada, salida, errores)), add = TRUE)
    writeLines(enc2utf8(textos), entrada, useBytes = TRUE)
    estado <- system2(binario, c(shQuote(archivo_plan), shQuote(entrada)), stdout = salida, stderr = errores)
    if (estado != 0L) stop("Fallo del ejecutable experimental Rust.", call. = FALSE)
    r <- jsonlite::read_json(salida)
    if (!isTRUE(r$valido)) {
      mensaje <- mensajes[r$error$motivo]
      if (is.na(mensaje)) stop("Resultado Rust fuera del contrato del piloto.", call. = FALSE)
      interno("error_mapeo")(unname(mensaje), as.integer(r$error$fila), r$error$campo)
    }
    invisible(r)
  }
  construir_rust <- function(datos, mapa) {
    interno("comprobar_mapa")(mapa)
    if (!is.data.frame(datos) || anyDuplicated(names(datos))) interno("error_mapeo")("datos debe ser un data.frame con columnas unicas.")
    faltan <- setdiff(unname(mapa$campos), names(datos))
    if (length(faltan)) interno("error_mapeo")("Faltan columnas requeridas por el mapeo.")
    if (!nrow(datos)) return(fhirviews::fhir_recursos(NULL))
    recursos <- vector("list", nrow(datos))
    error_primitivo <- NULL
    completadas <- 0L
    # Mismos conversores primitivos y asignacion del constructor publico.
    # Un error de conversion posterior espera la validacion de las filas previas.
    for (i in seq_len(nrow(datos))) {
      r <- tryCatch({
        r <- list(resourceType = mapa$recurso)
        for (destino in names(mapa$rutas)) {
          valor <- if (destino %in% names(mapa$campos)) datos[[mapa$campos[[destino]]]][[i]] else mapa$constantes[[destino]]
          ruta <- mapa$rutas[[destino]]
          referencia <- mapa$referencias[destino]
          if (!length(referencia) || is.na(referencia)) referencia <- NULL
          convertir <- function(v) interno("valor_mapeo")(v, ruta$tipo, i, destino, referencia)
          if (isTRUE(ruta$coleccion)) {
            valor <- lapply(seq_along(valor), function(j) convertir(valor[[j]]))
            valor <- Filter(Negate(is.null), valor)
            if (!length(valor)) valor <- NULL
          } else valor <- convertir(valor)
          if (!is.null(valor)) r <- interno("asignar_mapeo")(r, ruta$pasos, valor)
        }
        interno("compactar_mapeo")(r)
      }, error = identity)
      if (inherits(r, "error")) { error_primitivo <- r; break }
      recursos[[i]] <- r
      completadas <- i
    }
    recursos <- recursos[seq_len(completadas)]
    textos <- if (completadas) interno("motor_actual")()$serializar_recursos(recursos) else character()
    validar_rust(textos)
    if (!is.null(error_primitivo)) stop(error_primitivo)
    ids <- vapply(recursos, function(r) if (is.null(r$id)) "" else r$id, character(1))
    if (any(!nzchar(ids)) || anyDuplicated(ids)) interno("error_mapeo")("Cada fila debe producir un id no vacio y unico.", campo = "id")
    fhirviews::fhir_recursos(textos)
  }
  list(original = interno("fhir_desde_tabla"), preparado = preparado,
       rust = construir_rust, validar_rust = validar_rust,
       nodos = length(nodos), recursos_r4 = length(conocidos))
}
