# Archivo temporal que se borra al terminar la prueba
withr_tempfile <- function(fileext = "", envir = parent.frame()) {
  archivo <- tempfile(fileext = fileext)
  do.call(on.exit, list(substitute(unlink(archivo), list(archivo = archivo)),
                        add = TRUE), envir = envir)
  archivo
}
