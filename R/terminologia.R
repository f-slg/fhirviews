#' Expandir un ValueSet en un servidor de terminología ($expand)
#'
#' Pide a un servidor de terminología FHIR (por ejemplo
#' `https://tx.fhir.org/r4`, un Snowstorm o un HAPI con terminologías
#' cargadas) la lista de códigos de un `ValueSet` con la operación
#' `ValueSet/$expand`. Las expansiones grandes se descargan por páginas
#' (parámetros `offset` y `count`), así que sirve para conjuntos de miles de
#' códigos, como todos los diagnósticos de diabetes de la CIE-10 o de
#' SNOMED CT.
#'
#' Las funciones de terminología llevan el prefijo `tx_` (abreviatura de
#' *terminology* que usa la comunidad FHIR, como en `tx.fhir.org`) para
#' distinguirlas de las que trabajan con recursos clínicos (`fhir_*`) y con
#' vistas (`vista_*`). Usan la misma conexión de [fhir_conectar()], con su
#' token o su autenticación SMART on FHIR, y los mismos errores con el
#' `OperationOutcome` del servidor.
#'
#' @param con Conexión al servidor de terminología creada con
#'   [fhir_conectar()].
#' @param valueset El `ValueSet`: su URL canónica (con versión opcional,
#'   `"http://.../ValueSet/x|2.0"`), o el recurso completo como lista de R,
#'   texto JSON o ruta a un archivo JSON (útil para un `ValueSet` propio que
#'   no está publicado en el servidor; por ejemplo, uno con `compose.include`
#'   y un filtro `is-a` de SNOMED CT).
#' @param filtro Texto opcional para filtrar los códigos por su nombre
#'   (parámetro `filter`; cada servidor decide cómo lo aplica).
#' @param max Número máximo de códigos que se descargan.
#' @param tamano_pagina Códigos que se piden en cada petición.
#' @param parametros Lista con nombre de otros parámetros de `$expand`, por
#'   ejemplo `list(displayLanguage = "es", activeOnly = TRUE)`.
#'
#' @return Un `data.frame` con una fila por código y las columnas `system`,
#'   `code`, `display` y, si el servidor la informa, `version`. Las
#'   jerarquías (`contains` anidados) se aplanan y se omiten los códigos
#'   abstractos (`abstract = true`), que no se usan para codificar. Los
#'   atributos `valueset` (URL), `total` (total que informa el servidor) y
#'   `expansion` (datos de la expansión sin los códigos) documentan de dónde
#'   salió la lista. Se puede pasar a [vista_con_valueset()].
#' @seealso [tx_buscar_codigo()], [tx_validar_codigo()],
#'   [vista_con_valueset()].
#' @export
#' @examplesIf fhir_disponible("https://tx.fhir.org/r4")
#' tx <- fhir_conectar("https://tx.fhir.org/r4", panel = FALSE)
#'
#' # Un ValueSet publicado, por su URL canónica
#' sexo <- tx_expandir(tx, "http://hl7.org/fhir/ValueSet/administrative-gender")
#' sexo
#'
#' # Un ValueSet propio: los descendientes de "diabetes mellitus" en SNOMED CT
#' diabetes <- tx_expandir(tx, list(
#'   resourceType = "ValueSet",
#'   compose = list(include = list(list(
#'     system = "http://snomed.info/sct",
#'     filter = list(list(property = "concept", op = "is-a",
#'                        value = "73211009"))
#'   )))
#' ), max = 200)
#' head(diabetes)
tx_expandir <- function(con, valueset, filtro = NULL, max = Inf,
                        tamano_pagina = 1000L, parametros = list()) {
  comprobar_conexion(con)
  vs <- leer_valueset(valueset)
  if (!is.null(filtro)) texto_simple(filtro, "filtro")
  if (!is.numeric(max) || length(max) != 1L || is.na(max) || max < 1) {
    cli::cli_abort("{.arg max} debe ser un n\u00famero mayor que 0.",
                   class = "fhirviews_error")
  }
  if (!is.numeric(tamano_pagina) || length(tamano_pagina) != 1L ||
      is.na(tamano_pagina) || tamano_pagina < 1) {
    cli::cli_abort("{.arg tamano_pagina} debe ser un n\u00famero mayor que 0.",
                   class = "fhirviews_error")
  }
  extra <- parametros_busqueda(parametros)
  if (!is.null(filtro)) extra$filter <- filtro

  codigos <- list()
  total <- NULL
  expansion <- NULL
  desde <- 0
  anterior <- NULL
  repeat {
    cuantos <- min(tamano_pagina, max - length(codigos))
    pagina <- c(extra, list(offset = format(desde, scientific = FALSE),
                            count = format(cuantos, scientific = FALSE)))
    res <- operacion_tx(con, "ValueSet/$expand", vs, pagina)
    datos <- res$datos
    if (!identical(datos$resourceType, "ValueSet") || is.null(datos$expansion)) {
      cli::cli_abort(c(
        "El servidor no devolvi\u00f3 un ValueSet expandido.",
        "x" = "Devolvi\u00f3 {.val {datos$resourceType %||% 'nada'}}."
      ), class = "fhirviews_error")
    }
    exp <- datos$expansion
    if (is.null(expansion)) {
      expansion <- exp[setdiff(names(exp), "contains")]
      expansion$url <- datos$url
      total <- exp$total
    }
    recibidos <- aplanar_contains(exp$contains)
    n_recibidos <- length(exp$contains)
    # Un servidor que ignora offset repite la primera pagina
    if (n_recibidos > 0L && identical(exp$contains[[1]], anterior)) {
      cli::cli_warn(c(
        "El servidor repiti\u00f3 la misma p\u00e1gina de la expansi\u00f3n; se
         detiene la paginaci\u00f3n.",
        "i" = "Puede que no admita {.field offset}: prueba con un
               {.arg tamano_pagina} mayor."
      ), class = "fhirviews_aviso")
      break
    }
    anterior <- if (n_recibidos > 0L) exp$contains[[1]]
    codigos <- c(codigos, recibidos)
    desde <- desde + n_recibidos
    if (n_recibidos == 0L || length(codigos) >= max ||
        (!is.null(total) && desde >= total) ||
        (is.null(total) && n_recibidos < cuantos) ||
        n_recibidos > cuantos) {
      break
    }
  }
  if (length(codigos) > max) codigos <- codigos[seq_len(max)]
  tabla <- tabla_codigos(codigos)
  attr(tabla, "valueset") <- datos$url %||% vs$url
  attr(tabla, "total") <- total
  attr(tabla, "expansion") <- expansion
  tabla
}

#' Buscar un código en un sistema de codificación ($lookup)
#'
#' Consulta un código en un servidor de terminología con la operación
#' `CodeSystem/$lookup` y devuelve su nombre (*display*), sus designaciones
#' (por ejemplo, en otros idiomas) y sus propiedades (padres, estado,
#' sinónimos, etc., según el sistema).
#'
#' @inheritParams tx_expandir
#' @param sistema URL del sistema de codificación, por ejemplo
#'   `"http://snomed.info/sct"`, `"http://loinc.org"` o
#'   `"http://hl7.org/fhir/sid/icd-10"`.
#' @param codigo El código.
#' @param version Versión opcional del sistema.
#' @param propiedades Vector de caracteres opcional con las propiedades que
#'   se piden (parámetro `property`); por defecto, las que el servidor
#'   devuelva.
#'
#' @return Una lista con `sistema`, `codigo`, `nombre` (nombre del sistema),
#'   `version`, `display`, `designaciones` (`data.frame` con `idioma`, `uso`
#'   y `valor`) y `propiedades` (`data.frame` con `propiedad`, `valor` y
#'   `descripcion`). La respuesta completa (`Parameters`) queda en el
#'   atributo `respuesta`.
#' @seealso [tx_expandir()], [tx_validar_codigo()].
#' @export
#' @examplesIf fhir_disponible("https://tx.fhir.org/r4")
#' tx <- fhir_conectar("https://tx.fhir.org/r4", panel = FALSE)
#' glucosa <- tx_buscar_codigo(tx, "http://loinc.org", "2345-7")
#' glucosa$display
#' head(glucosa$propiedades)
tx_buscar_codigo <- function(con, sistema, codigo, version = NULL,
                             propiedades = NULL) {
  comprobar_conexion(con)
  texto_simple(sistema, "sistema")
  texto_simple(codigo, "codigo")
  parametros <- list(system = sistema, code = codigo)
  if (!is.null(version)) parametros$version <- texto_simple(version, "version")
  if (!is.null(propiedades)) {
    if (!is.character(propiedades)) {
      cli::cli_abort("{.arg propiedades} debe ser un vector de caracteres.",
                     class = "fhirviews_error")
    }
    parametros$property <- propiedades
  }
  res <- peticion_json(con, "GET", "CodeSystem/$lookup",
                       parametros = parametros)
  p <- res$datos$parameter
  designaciones <- Filter(function(x) identical(x$name, "designation"), p)
  props <- Filter(function(x) identical(x$name, "property"), p)
  resultado <- list(
    sistema = sistema,
    codigo = codigo,
    nombre = valor_parametro(p, "name"),
    version = valor_parametro(p, "version"),
    display = valor_parametro(p, "display"),
    designaciones = data.frame(
      idioma = vapply(designaciones, function(d) valor_parametro(d$part, "language"),
                      character(1)),
      uso = vapply(designaciones, function(d) valor_parametro(d$part, "use"),
                   character(1)),
      valor = vapply(designaciones, function(d) valor_parametro(d$part, "value"),
                     character(1)),
      stringsAsFactors = FALSE
    ),
    propiedades = data.frame(
      propiedad = vapply(props, function(d) valor_parametro(d$part, "code"),
                         character(1)),
      valor = vapply(props, function(d) valor_parametro(d$part, "value"),
                     character(1)),
      descripcion = vapply(props, function(d) {
        valor_parametro(d$part, "description")
      }, character(1)),
      stringsAsFactors = FALSE
    )
  )
  attr(resultado, "respuesta") <- res$datos
  resultado
}

#' Validar códigos contra un ValueSet ($validate-code)
#'
#' Pregunta al servidor de terminología si cada código pertenece a un
#' `ValueSet`, con la operación `ValueSet/$validate-code`. Sirve, por
#' ejemplo, para revisar los diagnósticos de una base de datos antes de
#' calcular un indicador.
#'
#' La función se llama `tx_validar_codigo()`, en infinitivo como
#' [fhir_validar()], [tx_expandir()] y [tx_buscar_codigo()].
#'
#' @inheritParams tx_expandir
#' @param sistema URL del sistema de codificación de los códigos; se recicla
#'   si es uno solo.
#' @param codigo Vector de códigos.
#' @param display Vector opcional de nombres (*display*) que el servidor
#'   también comprueba.
#' @param lote Si es `TRUE` (por defecto) y hay varios códigos, se envían en
#'   Bundles `batch` de hasta 100 códigos, con una petición por Bundle. Si el
#'   servidor no admite `batch`, se valida un código por petición, como con
#'   `lote = FALSE`.
#'
#' @return Un `data.frame` con una fila por código y las columnas `sistema`,
#'   `codigo`, `valido` (lógico), `display` (el nombre que da el servidor) y
#'   `mensaje` (la explicación del servidor, sobre todo cuando no es
#'   válido).
#' @seealso [tx_expandir()], [tx_buscar_codigo()].
#' @export
#' @examplesIf fhir_disponible("https://tx.fhir.org/r4")
#' tx <- fhir_conectar("https://tx.fhir.org/r4", panel = FALSE)
#' tx_validar_codigo(tx, "http://hl7.org/fhir/ValueSet/administrative-gender",
#'                   "http://hl7.org/fhir/administrative-gender",
#'                   c("female", "mujer"))
tx_validar_codigo <- function(con, valueset, sistema, codigo, display = NULL,
                              lote = TRUE) {
  comprobar_conexion(con)
  vs <- leer_valueset(valueset)
  if (!is.character(codigo) || length(codigo) == 0L || anyNA(codigo)) {
    cli::cli_abort("{.arg codigo} debe ser un vector de caracteres sin {.code NA}.",
                   class = "fhirviews_error")
  }
  n <- length(codigo)
  if (!is.character(sistema) || !length(sistema) %in% c(1L, n) ||
      anyNA(sistema)) {
    cli::cli_abort(
      "{.arg sistema} debe ser un texto o un vector del largo de {.arg codigo}.",
      class = "fhirviews_error")
  }
  if (!is.null(display) && (!is.character(display) || length(display) != n)) {
    cli::cli_abort(
      "{.arg display} debe ser un vector de caracteres del largo de {.arg codigo}.",
      class = "fhirviews_error")
  }
  if (!rlang::is_bool(lote)) {
    cli::cli_abort("{.arg lote} debe ser {.code TRUE} o {.code FALSE}.",
                   class = "fhirviews_error")
  }
  sistema <- rep_len(sistema, n)
  parametros <- lapply(seq_len(n), function(i) {
    p <- list(system = sistema[[i]], code = codigo[[i]])
    if (!is.null(display) && !is.na(display[[i]])) p$display <- display[[i]]
    p
  })
  ruta <- "ValueSet/$validate-code"
  filas <- NULL
  if (lote && n > 1L) {
    grupos <- split(seq_len(n), ceiling(seq_len(n) / 100L))
    filas <- tryCatch(
      unlist(lapply(grupos, function(g) {
        validar_en_lote(con, ruta, vs, parametros[g])
      }), recursive = FALSE, use.names = FALSE),
      fhirviews_error_lote = function(e) NULL
    )
  }
  if (is.null(filas)) {
    filas <- lapply(parametros, function(p) {
      fila_validacion(operacion_tx(con, ruta, vs, p)$datos)
    })
  }
  data.frame(
    sistema = sistema,
    codigo = codigo,
    valido = vapply(filas, function(f) f$valido, logical(1)),
    display = vapply(filas, function(f) f$display, character(1)),
    mensaje = vapply(filas, function(f) f$mensaje, character(1)),
    stringsAsFactors = FALSE
  )
}

#' Filtrar una vista con los códigos de un ValueSet
#'
#' Agrega a un `ViewDefinition` una condición FHIRPath con los códigos de una
#' expansión (de [tx_expandir()] o hecha a mano), para que la vista quede
#' autocontenida: [vista_ejecutar()] y [vista_ejecutar_duckdb()] la aplican
#' sin consultar el servidor de terminología. Así un indicador definido con
#' un `ValueSet` (por ejemplo, "todas las personas con diagnóstico de
#' diabetes") se expande una vez y se calcula sobre millones de recursos sin
#' red.
#'
#' Cada sistema de codificación y su lista de códigos se guardan como
#' constantes de la vista (`%{nombre}_sistema` y `%{nombre}_codigos`, o
#' `_sistema_1`, `_codigos_1`... si hay varios sistemas); la lista es un texto
#' con los códigos separados por `|`. La condición queda, por ejemplo:
#'
#' `code.coding.where(system = %vs_sistema and %vs_codigos.contains('|' & code & '|')).exists()`
#'
#' Esta forma (y no una cadena de `or`) mantiene la expresión corta aunque el
#' `ValueSet` tenga miles de códigos, y el motor DuckDB la traduce a una sola
#' búsqueda de texto. La vista guarda en su JSON la lista exacta que se usó,
#' lo que también documenta el indicador.
#'
#' @param vista Un `ViewDefinition` en cualquier forma que acepte
#'   [vista_leer()].
#' @param expansion Un `data.frame` con las columnas `system` y `code`, como
#'   el que devuelve [tx_expandir()].
#' @param ruta Expresión FHIRPath, desde el recurso, que lleva a los
#'   `Coding` que se comparan: `"code.coding"` (por defecto, para
#'   `Condition`, `Observation` o `Procedure`),
#'   `"valueCodeableConcept.coding"`,
#'   `"medication.ofType(CodeableConcept).coding"`, `"class"`, etc.
#' @param nombre Prefijo de las constantes que se agregan a la vista. Debe
#'   ser un nombre válido de FHIRPath.
#' @param columna Si es `NULL` (por defecto), la condición se agrega como
#'   `where` y la vista solo devuelve los recursos con algún código del
#'   `ValueSet`. Si es un texto, en vez de filtrar se agrega una columna
#'   lógica con ese nombre que indica si el recurso tiene algún código del
#'   `ValueSet`; sirve para marcar varios grupos en una misma vista.
#'
#' @return La vista modificada, de clase `fhir_vista`.
#' @seealso [tx_expandir()].
#' @export
#' @examples
#' # Expansión hecha a mano (normalmente sale de tx_expandir())
#' diabetes <- data.frame(
#'   system = "http://hl7.org/fhir/sid/icd-10",
#'   code = c("E10", "E11", "E13", "E14")
#' )
#' vista <- vista_crear("Condition", c(
#'   paciente = "subject.getReferenceKey(Patient)",
#'   codigo = "code.coding.first().code"
#' ))
#' vista <- vista_con_valueset(vista, diabetes, nombre = "diabetes")
#' vista$where
#'
#' condiciones <- fhir_recursos(list(
#'   list(resourceType = "Condition", id = "c1",
#'        subject = list(reference = "Patient/p1"),
#'        code = list(coding = list(list(
#'          system = "http://hl7.org/fhir/sid/icd-10", code = "E11")))),
#'   list(resourceType = "Condition", id = "c2",
#'        subject = list(reference = "Patient/p2"),
#'        code = list(coding = list(list(
#'          system = "http://hl7.org/fhir/sid/icd-10", code = "I10"))))
#' ))
#' vista_ejecutar(condiciones, vista)
#'
#' @examplesIf fhir_disponible("https://tx.fhir.org/r4")
#' # Con un servidor de terminología
#' tx <- fhir_conectar("https://tx.fhir.org/r4", panel = FALSE)
#' sexo <- tx_expandir(tx, "http://hl7.org/fhir/ValueSet/administrative-gender")
#' sexo
vista_con_valueset <- function(vista, expansion, ruta = "code.coding",
                               nombre = "vs", columna = NULL) {
  vista <- vista_leer(vista)
  texto_simple(ruta, "ruta")
  texto_simple(nombre, "nombre")
  if (!grepl("^[A-Za-z_][A-Za-z0-9_]*$", nombre)) {
    cli::cli_abort(c(
      "{.arg nombre} debe ser un nombre v\u00e1lido de FHIRPath.",
      "i" = "Usa letras, n\u00fameros y {.code _}, sin empezar con un n\u00famero."
    ), class = "fhirviews_error")
  }
  if (!is.data.frame(expansion) || !all(c("system", "code") %in% names(expansion))) {
    cli::cli_abort(
      "{.arg expansion} debe ser un {.cls data.frame} con las columnas
       {.field system} y {.field code}, como el de {.fn tx_expandir}.",
      class = "fhirviews_error")
  }
  sistemas <- as.character(expansion$system)
  codigos <- as.character(expansion$code)
  vacios <- is.na(sistemas) | !nzchar(sistemas) | is.na(codigos) | !nzchar(codigos)
  if (any(vacios)) {
    cli::cli_abort(
      "{sum(vacios)} c\u00f3digo{?s} de {.arg expansion} no tiene{?n} {.field system} o {.field code}.",
      class = "fhirviews_error")
  }
  if (length(codigos) == 0L) {
    cli::cli_abort("{.arg expansion} no tiene c\u00f3digos.",
                   class = "fhirviews_error")
  }

  if (any(grepl("|", codigos, fixed = TRUE))) {
    cli::cli_abort("Los c\u00f3digos no pueden contener {.code |}.",
                   class = "fhirviews_error")
  }

  unicos <- unique(sistemas)
  sufijo <- if (length(unicos) == 1L) "" else paste0("_", seq_along(unicos))
  nombres_sis <- paste0(nombre, "_sistema", sufijo)
  nombres_cod <- paste0(nombre, "_codigos", sufijo)
  existentes <- vapply(vista$constant, function(k) as.character(k$name %||% NA),
                       character(1))
  repetidas <- intersect(c(nombres_sis, nombres_cod), existentes)
  if (length(repetidas) > 0L) {
    cli::cli_abort(c(
      "La vista ya tiene la constante {.code %{repetidas[1]}}.",
      "i" = "Usa otro {.arg nombre}."
    ), class = "fhirviews_error")
  }
  listas <- vapply(unicos, function(u) {
    paste0("|", paste(unique(codigos[sistemas == u]), collapse = "|"), "|")
  }, character(1), USE.NAMES = FALSE)
  partes <- sprintf("(system = %%%s and %%%s.contains('|' & code & '|'))",
                    nombres_sis, nombres_cod)
  if (length(partes) == 1L) partes <- substr(partes, 2L, nchar(partes) - 1L)
  condicion <- sprintf("%s.where(%s).exists()", ruta,
                       paste(partes, collapse = " or "))

  nuevas <- Map(function(ns, s, nc, l) {
    list(list(name = ns, valueUri = s), list(name = nc, valueString = l))
  }, nombres_sis, unicos, nombres_cod, listas)
  vista$constant <- c(vista$constant, unlist(unname(nuevas), recursive = FALSE))
  if (is.null(columna)) {
    vista$where <- c(vista$where, list(list(path = condicion)))
  } else {
    texto_simple(columna, "columna")
    if (columna %in% columnas_vista(vista)) {
      cli::cli_abort("La vista ya tiene la columna {.field {columna}}.",
                     class = "fhirviews_error")
    }
    vista$select <- c(vista$select, list(list(column = list(list(
      name = columna, path = condicion, type = "boolean")))))
  }
  vista_leer(vista)
}

# --- Internas ----------------------------------------------------------------

# ValueSet: URL canónica (se envía como `url`) o recurso (se envía en un
# Parameters con POST)
leer_valueset <- function(valueset) {
  if (is.character(valueset) && length(valueset) == 1L && !is.na(valueset) &&
      !grepl("^\\s*[[{]", valueset) && !file.exists(valueset)) {
    return(list(url = texto_simple(valueset, "valueset")))
  }
  if (is.character(valueset) && length(valueset) == 1L && !is.na(valueset)) {
    datos <- parsear_json(cuerpo_json(valueset))
  } else if (is.list(valueset)) {
    datos <- unclass(valueset)
  } else {
    cli::cli_abort(
      "{.arg valueset} debe ser una URL can\u00f3nica, un ValueSet como lista,
       texto JSON o la ruta a un archivo.",
      class = "fhirviews_error", call = NULL)
  }
  if (!identical(datos$resourceType, "ValueSet")) {
    cli::cli_abort(c(
      "{.arg valueset} no es un recurso ValueSet.",
      "x" = "Su {.field resourceType} es {.val {datos$resourceType %||% 'ninguno'}}."
    ), class = "fhirviews_error", call = NULL)
  }
  list(url = if (es_texto(datos$url)) datos$url, recurso = datos)
}

# Resultado de $validate-code (Parameters, u OperationOutcome si el servidor
# no pudo validar el código)
fila_validacion <- function(datos) {
  if (identical(datos$resourceType, "OperationOutcome")) {
    mensajes <- tabla_outcome(datos)$mensaje
    mensajes <- mensajes[!is.na(mensajes)]
    return(list(valido = NA, display = NA_character_,
                mensaje = if (length(mensajes)) paste(mensajes, collapse = "; ")
                  else NA_character_))
  }
  p <- datos$parameter
  resultado <- Filter(function(x) identical(x$name, "result"), p)
  list(valido = if (length(resultado)) isTRUE(resultado[[1]]$valueBoolean) else NA,
       display = valor_parametro(p, "display"),
       mensaje = valor_parametro(p, "message"))
}

# Valida varios códigos en un Bundle batch. Si el servidor no responde con
# un batch-response de la misma cantidad de entradas, lanza un error de clase
# fhirviews_error_lote para volver a la validación de a uno.
validar_en_lote <- function(con, ruta, vs, parametros) {
  entradas <- lapply(parametros, function(p) {
    if (is.null(vs$recurso)) {
      list(request = list(method = "GET", url = agregar_consulta(
        ruta, c(list(url = vs$url), p))))
    } else {
      list(resource = parameters_tx(vs, p),
           request = list(method = "POST", url = ruta))
    }
  })
  bundle <- list(resourceType = "Bundle", type = "batch", entry = entradas)
  no_admite <- function(...) {
    rlang::abort("El servidor no admite batch.", class = "fhirviews_error_lote")
  }
  res <- tryCatch(peticion_json(con, "POST", "", cuerpo = cuerpo_json(bundle)),
                  fhirviews_error_http = no_admite)
  respuesta <- res$datos
  if (!identical(respuesta$resourceType, "Bundle") ||
      !identical(respuesta$type, "batch-response") ||
      length(respuesta$entry) != length(parametros)) {
    no_admite()
  }
  lapply(respuesta$entry, function(e) {
    if (is.null(e$resource)) {
      return(list(valido = NA, display = NA_character_,
                  mensaje = paste("El servidor respondi\u00f3",
                                  e$response$status %||% "sin estado")))
    }
    fila_validacion(e$resource)
  })
}

# Operación sobre un ValueSet: GET con `url` o POST con el recurso en un
# Parameters
operacion_tx <- function(con, ruta, vs, parametros) {
  if (is.null(vs$recurso)) {
    return(peticion_json(con, "GET", ruta,
                         parametros = c(list(url = vs$url), parametros)))
  }
  peticion_json(con, "POST", ruta,
                cuerpo = cuerpo_json(parameters_tx(vs, parametros)))
}

# Parameters de una operación con el ValueSet como recurso
parameters_tx <- function(vs, parametros) {
  cuerpo <- list(resourceType = "Parameters", parameter = c(
    list(list(name = "valueSet", resource = vs$recurso)),
    unname(Map(function(n, v) list(name = n, valueString = v),
               names(parametros), parametros))
  ))
  # offset y count son enteros en la definición de la operación
  cuerpo$parameter <- lapply(cuerpo$parameter, function(p) {
    if (p$name %in% c("offset", "count")) {
      list(name = p$name, valueInteger = as.integer(p$valueString))
    } else {
      p
    }
  })
  cuerpo
}

aplanar_contains <- function(contains) {
  unlist(lapply(contains, function(k) {
    propio <- if (!isTRUE(k$abstract) && es_texto(k$code)) list(k)
    c(propio, aplanar_contains(k$contains))
  }), recursive = FALSE)
}

tabla_codigos <- function(codigos) {
  campo <- function(nm) {
    vapply(codigos, function(k) {
      v <- k[[nm]]
      if (is.null(v)) NA_character_ else as.character(v)
    }, character(1))
  }
  tabla <- data.frame(system = campo("system"), code = campo("code"),
                      display = campo("display"), stringsAsFactors = FALSE)
  version <- campo("version")
  if (any(!is.na(version))) tabla$version <- version
  tabla
}

# Valor de un parámetro (value[x]) de un Parameters como texto
valor_parametro <- function(p, nombre) {
  for (x in p) {
    if (identical(x$name, nombre)) {
      campo <- grep("^value", names(x), value = TRUE)
      if (length(campo) == 0L) return(NA_character_)
      v <- x[[campo[1]]]
      if (is.list(v)) {
        # Coding: sistema|codigo (display)
        if (!is.null(v$code)) {
          return(paste0(if (!is.null(v$system)) paste0(v$system, "|"), v$code,
                        if (!is.null(v$display)) paste0(" (", v$display, ")")))
        }
        return(as.character(a_json(v, unbox = TRUE)))
      }
      return(as.character(v))
    }
  }
  NA_character_
}
