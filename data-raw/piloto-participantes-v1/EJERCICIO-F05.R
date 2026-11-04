entrada <- tempfile(fileext = ".ndjson")
writeLines(c(
  '{"resourceType":"Observation","id":"piloto-1","valueQuantity":{"value":1.5}}',
  '{"resourceType":"Observation","id":"piloto-2","valueQuantity":{"value":"incompatible"}}'
), entrada)
vista <- vista_leer(list(resource = "Observation", select = list(list(column = list(
  list(name = "id", path = "getResourceKey()", type = "id"),
  list(name = "valor", path = "value.ofType(Quantity).value", type = "decimal")
)))))
entregas <- 0L
error <- tryCatch(
  vista_ejecutar_lotes(entrada, vista, function(tabla, bloque) {
    entregas <<- entregas + 1L
  }, tamano_lote = 1, estricto = TRUE),
  error = identity
)
list(clase = class(error), bloque = error$bloque, fase = error$fase,
     columna = error$columna, entregas = entregas)
unlink(entrada)
