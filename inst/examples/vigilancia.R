# Demostracion reproducible con datos FICTICIOS de dengue incluidos.
# Uso: source(system.file("examples", "vigilancia.R", package = "fhirviews"))
# Opcional: Sys.setenv(FHIRVIEWS_DEMO_SALIDA = "/ruta/a/carpeta-nueva")
local({
  library(fhirviews)
  carpeta <- Sys.getenv("FHIRVIEWS_DEMO_SALIDA", unset = "")
  if (!nzchar(carpeta)) carpeta <- tempfile("fhirviews-vigilancia-")
  if (file.exists(carpeta)) {
    stop("La carpeta de salida ya existe; elige una carpeta nueva.")
  }

  entrada <- system.file("extdata", "dengue_2025.ndjson.gz", package = "fhirviews")
  vista_casos <- vista_plantilla("notificacion_obligatoria")
  vista_pacientes <- vista_plantilla("pacientes")
  casos <- vista_ejecutar(entrada, vista_casos)
  pacientes <- vista_ejecutar(entrada, vista_pacientes)

  # Un evento Condition confirmado por fila. No se deduplican pacientes.
  # El conjunto ficticio usa CIE-10 A90/A91; no se extrapola a otros codigos.
  seleccion <- !is.na(casos$verificacion) & casos$verificacion == "confirmed" &
    !is.na(casos$cie10) & casos$cie10 %in% c("A90", "A91")
  confirmados <- casos[seleccion, , drop = FALSE]
  stopifnot(nrow(confirmados) > 0L, !anyNA(casos$id), !anyDuplicated(casos$id),
            !anyNA(pacientes$id), !anyDuplicated(pacientes$id))
  posicion <- match(confirmados$paciente, pacientes$id)
  stopifnot(!anyNA(posicion))
  confirmados$provincia <- pacientes$provincia[posicion]
  confirmados$canton <- pacientes$canton[posicion]
  confirmados$codigo_dpa <- pacientes$codigo_dpa[posicion]
  stopifnot(!anyNA(confirmados[c("provincia", "canton", "codigo_dpa", "inicio")]),
            all(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", confirmados$inicio)))

  territorial <- stats::aggregate(
    list(casos = rep(1L, nrow(confirmados))),
    confirmados[c("codigo_dpa", "provincia", "canton")], sum
  )
  territorial <- territorial[order(territorial$codigo_dpa), ]
  mensual <- stats::aggregate(
    list(casos = rep(1L, nrow(confirmados))),
    list(mes_inicio = substr(confirmados$inicio, 1L, 7L)), sum
  )
  stopifnot(sum(territorial$casos) == nrow(confirmados),
            sum(mensual$casos) == nrow(confirmados))
  controles <- data.frame(
    metrica = c("eventos_entrada", "eventos_confirmados", "eventos_excluidos",
                "pacientes", "cantones_con_eventos"),
    valor = c(nrow(casos), nrow(confirmados), sum(!seleccion),
              nrow(pacientes), nrow(territorial))
  )

  # Solo se escribe despues de verificar relaciones y totales.
  if (!dir.create(carpeta, recursive = TRUE)) stop("No se pudo crear la salida.")
  csv <- function(x, nombre) utils::write.csv(
    x, file.path(carpeta, nombre), row.names = FALSE, na = "", fileEncoding = "UTF-8"
  )
  csv(confirmados, "casos_confirmados.csv")
  csv(territorial, "resumen_canton.csv")
  csv(mensual, "resumen_mensual.csv")
  csv(controles, "controles.csv")
  writeLines(vista_json(vista_casos), file.path(carpeta, "vista_notificacion.json"))
  writeLines(vista_json(vista_pacientes), file.path(carpeta, "vista_pacientes.json"))
  writeLines(capture.output(utils::sessionInfo()), file.path(carpeta, "sessionInfo.txt"))
  jsonlite::write_json(list(
    datos = "FICTICIOS: dengue_2025.ndjson.gz incluido en fhirviews",
    entrada_md5 = unname(tools::md5sum(entrada)),
    version_fhirviews = as.character(utils::packageVersion("fhirviews")),
    definicion = "Eventos Condition A90/A91 con verificacion confirmed",
    fecha_agrupacion = "inicio (fecha de inicio del evento)",
    unidad = "eventos; no pacientes unicos ni tasas poblacionales"
  ), file.path(carpeta, "procedencia.json"), auto_unbox = TRUE, pretty = TRUE)
  writeLines(c(
    "DEMOSTRACION CON DATOS FICTICIOS. No representa vigilancia real.",
    "Unidad: eventos Condition confirmados con CIE-10 A90/A91.",
    "Se excluyen eventos refutados, sin verificacion u otros codigos.",
    "Agrupacion temporal: mes de inicio; territorial: residencia del paciente.",
    "Los conteos no son pacientes unicos ni tasas; no hay denominadores.",
    "Leer codigo_dpa como texto para conservar los ceros iniciales.",
    "controles.csv permite reconciliar los eventos y los resumenes.",
    "Las vistas JSON, procedencia.json y sessionInfo.txt documentan el proceso."
  ), file.path(carpeta, "LEEME.txt"))
  print(controles, row.names = FALSE)
  cat("Salida:", normalizePath(carpeta, winslash = "/"), "\n")
})
