# Aceptacion tecnica con datos FICTICIOS incluidos; no contacta servidores.
# Sys.setenv(FHIRVIEWS_PILOTO_SALIDA = "piloto-01", FHIRVIEWS_PILOTO_PERFIL = "basico")
# Perfil "completo": requiere DBI/duckdb. La carpeta debe ser nueva.
# source(system.file("examples", "piloto.R", package = "fhirviews"))
local({
  ejecutar <- function() {
    library(fhirviews)
    perfil <- Sys.getenv("FHIRVIEWS_PILOTO_PERFIL", unset = "basico")
    if (!perfil %in% c("basico", "completo")) stop("Perfil permitido: basico o completo.")
    carpeta <- Sys.getenv("FHIRVIEWS_PILOTO_SALIDA", unset = "")
    if (!nzchar(carpeta)) stop("Configura FHIRVIEWS_PILOTO_SALIDA con una carpeta nueva.")
    if (file.exists(carpeta)) stop("La carpeta del piloto ya existe; elige una nueva.")
    if (!dir.create(carpeta, recursive = TRUE)) stop("No se pudo crear la salida del piloto.")
    nombres <- c("api_instalada", "vigilancia", "contrato_estricto", "recuperacion")
    controles <- data.frame(prueba = nombres, estado = "pendiente", segundos = 0,
                            clase_error = "", codigo = "", advertencias = 0L,
                            stringsAsFactors = FALSE)
    if (perfil == "basico") controles$estado[4L] <- "no_evaluado"
    completo <- FALSE
    hallazgos <- list()
    diagnosticos <- list()
    advertencias <- list()
    diagnostico_actual <- NULL
    exigir <- function(condicion, codigo, esperado = NULL, observado = NULL,
                       referencia = NULL) {
      if (isTRUE(condicion)) return(invisible(TRUE))
      # Solo valores numericos de los controles ficticios y codigos fijos.
      # Nunca copiar conditionMessage(), rutas ni valores del consumidor.
      diagnostico_actual <<- list(codigo = codigo, esperado = esperado,
                                  observado = observado, referencia = referencia)
      stop("No se cumple un control del piloto.", call. = FALSE)
    }
    on.exit({
      utils::write.csv(controles, file.path(carpeta, "aceptacion.csv"), row.names = FALSE)
      jsonlite::write_json(list(
        resultado_tecnico = if (!completo) "no_aprobado" else
          if (length(advertencias)) "requiere_revision" else "aprobado",
        esquema_informe = 1L,
        politica_advertencias = "Toda advertencia requiere revision; no se aprueba automaticamente",
        advertencias = advertencias,
        diagnosticos = diagnosticos,
        perfil = perfil,
        alcance = "Datos ficticios incluidos; no evalua un servidor ni datos propios",
        validacion_usuario_externo = "pendiente",
        version_fhirviews = as.character(utils::packageVersion("fhirviews")),
        candidato_md5 = Sys.getenv("FHIRVIEWS_CANDIDATO_MD5", unset = "no_disponible"),
        hallazgos = hallazgos,
        datos = "FICTICIOS: dengue_2025 y caso_clinico incluidos",
        controles = controles
      ), file.path(carpeta, "aceptacion.json"), auto_unbox = TRUE, pretty = TRUE)
      writeLines(capture.output(utils::sessionInfo()), file.path(carpeta, "sessionInfo.txt"))
      writeLines(c(
        "EXPERIENCIA DE USUARIO: PENDIENTE DE COMPLETAR POR UNA PERSONA.",
        "La aprobacion tecnica no completa esta evaluacion.",
        "Rol y experiencia con R: ",
        "Instalacion sin ayuda del mantenedor: pendiente", 
        "Ejecucion y lectura del informe: pendiente",
        "Interpretacion de eventos frente a pacientes o tasas: pendiente",
        "Crear o modificar una vista y contrastarla con el recurso original: pendiente",
        "Identificar el bloque rechazado y lo que pudo escribirse: pendiente",
        "Tiempo dedicado y obstaculos: ",
        "Problema minimo reproducible con datos ficticios: ",
        "Conclusion del participante y revision del mantenedor: pendiente",
        "Revise los archivos antes de compartirlos; no se envian automaticamente."
      ), file.path(carpeta, "experiencia-usuario.txt"))
      cat("Informe local del piloto:", normalizePath(carpeta, winslash = "/"), "\n")
    }, add = TRUE)
    verificar <- function(nombre, expr) {
      i <- match(nombre, controles$prueba)
      inicio <- proc.time()[["elapsed"]]
      diagnostico_actual <<- NULL
      n_avisos <- 0L
      error <- tryCatch(withCallingHandlers({ force(expr); NULL },
        warning = function(w) {
          n_avisos <<- n_avisos + 1L
          advertencias[[length(advertencias) + 1L]] <<- list(
            prueba = nombre,
            codigo = if (inherits(w, "fhirviews_aviso_tipo"))
              "advertencia_tipo" else "advertencia_procesamiento")
          invokeRestart("muffleWarning")
        }), error = identity)
      controles$segundos[i] <<- unname(proc.time()[["elapsed"]] - inicio)
      controles$advertencias[i] <<- n_avisos
      controles$estado[i] <<- if (!is.null(error)) "fallo" else
        if (n_avisos) "requiere_revision" else "aprobado"
      if (n_avisos) controles$codigo[i] <<- "advertencias_requieren_revision"
      if (!is.null(error)) {
        # La clase tambien se normaliza: una condicion externa puede tener
        # nombres de clase que contengan datos. No guardar texto arbitrario.
        controles$clase_error[i] <<- if (inherits(error, "fhirviews_error"))
          "fhirviews_error" else "error"
        diagnosticos[[nombre]] <<- if (is.null(diagnostico_actual))
          list(codigo = "error_inesperado") else diagnostico_actual
        controles$codigo[i] <<- diagnosticos[[nombre]]$codigo
        stop(paste("No se completo la prueba", nombre, "; revisar el informe local."),
             call. = FALSE)
      }
    }
    verificar("api_instalada", {
      exigir(identical(formals(vista_ejecutar_lotes)$estricto, FALSE),
             "api_incompatible")
      for (nombre in c("vigilancia.R", "lotes-transaccion.R", "PILOTO-MANTENEDOR.md")) {
        exigir(nzchar(system.file("examples", nombre, package = "fhirviews")),
               "ejemplo_ausente")
      }
    })
    verificar("vigilancia", {
      anterior <- Sys.getenv("FHIRVIEWS_DEMO_SALIDA", unset = NA_character_)
      tryCatch({
        salida <- file.path(carpeta, "vigilancia")
        Sys.setenv(FHIRVIEWS_DEMO_SALIDA = salida)
        source(system.file("examples", "vigilancia.R", package = "fhirviews"))
        leer <- function(nombre) utils::read.csv(file.path(salida, nombre),
                                                colClasses = "character")
        casos <- leer("casos_confirmados.csv")
        canton <- leer("resumen_canton.csv")
        mes <- leer("resumen_mensual.csv")
        exigir(nrow(casos) == 661L, "total_eventos_incorrecto", 661L, nrow(casos))
        exigir(nrow(canton) == 65L, "total_cantones_incorrecto", 65L, nrow(canton))
        exigir(all(casos$verificacion == "confirmed"), "verificacion_incorrecta")
        exigir(sum(as.integer(canton$casos)) == nrow(casos) &&
               sum(as.integer(mes$casos)) == nrow(casos), "totales_inconsistentes")
        exigir(all(nchar(canton$codigo_dpa) == 4L), "formato_dpa_incorrecto")
        # Referencias verificadas directamente en los recursos ficticios incluidos:
        # den-c0001 -> Patient/den-p0001, residencia 0701 e inicio 2025-02-27.
        evento <- casos[casos$id == "den-c0001", , drop = FALSE]
        exigir(nrow(evento) == 1L && identical(evento$paciente, "den-p0001") &&
               identical(evento$codigo_dpa, "0701") &&
               identical(evento$inicio, "2025-02-27"), "evento_referencia_incorrecto", referencia = "den-c0001")
        exigir(sum(casos$id == "den-c0002") == 0L, "evento_excluido_presente")
        esperado_territorio <- c(`0701` = 55L, `0702` = 1L, `0704` = 1L)
        for (dpa in names(esperado_territorio)) {
          fila <- canton[canton$codigo_dpa == dpa, , drop = FALSE]
          observado <- if (nrow(fila) == 1L) as.integer(fila$casos) else NA_integer_
          exigir(nrow(fila) == 1L && observado == esperado_territorio[[dpa]],
                 "conteo_territorial_incorrecto", esperado_territorio[[dpa]],
                 observado, referencia = dpa)
        }
        esperado_mes <- c(`2025-01` = 5L, `2025-02` = 73L, `2025-03` = 173L)
        for (fecha in names(esperado_mes)) {
          fila <- mes[mes$mes_inicio == fecha, , drop = FALSE]
          observado <- if (nrow(fila) == 1L) as.integer(fila$casos) else NA_integer_
          exigir(nrow(fila) == 1L && observado == esperado_mes[[fecha]],
                 "conteo_mensual_incorrecto", esperado_mes[[fecha]], observado,
                 referencia = fecha)
        }
        hallazgos$vigilancia <- list(eventos_confirmados = nrow(casos),
          cantones = nrow(canton),
          evento_referencia = "den-c0001", referencias_territoriales = esperado_territorio,
          referencias_mensuales = esperado_mes)
      }, finally = {
        if (is.na(anterior)) Sys.unsetenv("FHIRVIEWS_DEMO_SALIDA") else
          Sys.setenv(FHIRVIEWS_DEMO_SALIDA = anterior)
      })
    })
    verificar("contrato_estricto", {
      archivo <- file.path(carpeta, "entrada-estricta-ficticia.ndjson")
      writeLines(c(
        '{"resourceType":"Observation","id":"piloto-1","valueQuantity":{"value":1.5}}',
        '{"resourceType":"Observation","id":"piloto-2","valueQuantity":{"value":"incompatible"}}'
      ), archivo)
      vista <- vista_leer(list(resource = "Observation", select = list(list(column = list(
        list(name = "id", path = "getResourceKey()", type = "id"),
        list(name = "valor", path = "value.ofType(Quantity).value", type = "decimal")
      )))))
      recibidos <- 0L
      fallo <- tryCatch(vista_ejecutar_lotes(archivo, vista, function(tabla, bloque) {
        stopifnot(is.double(tabla$valor))
        recibidos <<- recibidos + 1L
      }, tamano_lote = 1L, estricto = TRUE), error = identity)
      exigir(inherits(fallo, "fhirviews_error_esquema") && recibidos == 1L &&
                fallo$bloque == 2L && identical(fallo$columna, "valor") &&
                identical(fallo$fase, "esquema"), "rechazo_estricto_incorrecto")
      hallazgos$contrato_estricto <- list(bloque_rechazado = fallo$bloque,
        columna = fallo$columna, fase = fallo$fase, bloques_entregados = recibidos)
    })
    if (perfil == "completo") verificar("recuperacion", {
      exigir(requireNamespace("DBI", quietly = TRUE) &&
                requireNamespace("duckdb", quietly = TRUE), "dependencia_ausente")
      source(system.file("examples", "lotes-transaccion.R", package = "fhirviews"))
    })
    writeLines(c(
      "PILOTO TECNICO CON DATOS FICTICIOS.",
      paste("Perfil:", perfil),
      "El perfil basico no evalua DuckDB ni recuperacion transaccional.",
      "No se ha validado un servidor FHIR ni un conjunto propio del participante.",
      "Un aprobado tecnico no equivale a un piloto con usuarios aprobado.",
      "Los archivos se conservan localmente; no se envia informacion automaticamente.",
      "Pendiente: realizar las tareas con un usuario externo y registrar su experiencia."
    ), file.path(carpeta, "LEEME.txt"))
    completo <- TRUE
    print(controles[, c("prueba", "estado", "advertencias", "codigo")], row.names = FALSE)
    if (length(advertencias)) {
      stop("El piloto requiere revision de advertencias; consultar aceptacion.json.",
           call. = FALSE)
    }
  }
  ejecutar()
})
