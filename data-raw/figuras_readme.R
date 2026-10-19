# -----------------------------------------------------------------------------
# fhirviews · Figuras del README (man/figures/README-*.png)
#
#   README-json-tabla.png    de un recurso FHIR a una tabla con un ViewDefinition
#   README-conformidad.png   banco oficial de SQL on FHIR por archivo
#   README-rendimiento.png   tiempo de vista_ejecutar() según el número de
#                            recursos (datos de data-raw/rendimiento.csv)
#   README-tasas.png         tasas ficticias de dengue por cantón con pobecu
#
# Paleta categórica validada (fondo claro): azul #2a78d6 y amarillo #eda100;
# para cuatro categorías se agregan naranja #eb6834 y aqua #1baf7a. El
# amarillo tiene poco contraste con el fondo, por eso las barras llevan su
# valor escrito. El azul marino de la marca se usa para títulos y texto.
#
# Requisitos: fhirviews instalado (o devtools::load_all()) y pobecu
# Uso:        Rscript data-raw/figuras_readme.R
# -----------------------------------------------------------------------------
library(fhirviews)
library(grid)

tinta <- "#0F2233"      # texto principal (azul marino de la marca)
tinta2 <- "#52514e"     # texto secundario
grilla <- "#e4e3df"
fondo <- "#fcfcfb"
azul <- "#2a78d6"
amarillo <- "#eda100"
naranja <- "#eb6834"
aqua <- "#1baf7a"
gris <- "#c3c2b7"
dorado <- "#F2B705"

abrir <- function(archivo, ancho, alto) {
  png(file.path("man", "figures", archivo), width = ancho, height = alto,
      res = 200, type = "cairo", bg = fondo)
}

# --- 1. De JSON a tabla ------------------------------------------------------
abrir("README-json-tabla.png", 2200, 900)
grid.newpage()
panel <- function(x, w, titulo, subtitulo) {
  pushViewport(viewport(x = x, y = 0.47, width = w, height = 0.78,
                        just = c("left", "center")))
  grid.roundrect(r = unit(0.02, "snpc"),
                 gp = gpar(fill = "white", col = grilla, lwd = 1.5))
  grid.text(titulo, x = 0.05, y = 1.08, just = "left",
            gp = gpar(fontsize = 12, fontface = "bold", col = tinta))
  grid.text(subtitulo, x = 0.05, y = 1.025, just = "left",
            gp = gpar(fontsize = 8.5, col = tinta2))
}
codigo <- function(lineas, colores = tinta, tam = 8.2, y0 = 0.93, paso = 0.064) {
  colores <- rep_len(colores, length(lineas))
  for (i in seq_along(lineas)) {
    grid.text(lineas[i], x = 0.05, y = y0 - (i - 1) * paso, just = "left",
              gp = gpar(fontfamily = "mono", fontsize = tam, col = colores[i]))
  }
}
# Recurso
panel(0.02, 0.30, "1. Recurso FHIR (JSON)", "Patient del caso clínico ficticio")
codigo(c('{',
         '  "resourceType": "Patient",',
         '  "id": "patient",',
         '  "gender": "male",',
         '  "birthDate": "1979-03-12",',
         '  "name": [',
         '    {"use": "official",',
         '     "text": "Luis A. Paredes"},',
         '    {"use": "usual",',
         '     "text": "Luis Paredes"}',
         '  ],',
         '  "address": [{"city": "Quito"}]',
         '}'),
       colores = c(tinta, tinta2, azul, azul, azul, naranja, naranja, naranja,
                   naranja, naranja, naranja, azul, tinta))
popViewport()
# Vista
panel(0.355, 0.30, "2. ViewDefinition", "SQL on FHIR · portable")
codigo(c('{"resource": "Patient",',
         ' "select": [',
         '  {"column": [',
         '    {"name": "id",',
         '     "path": "getResourceKey()"},',
         '    {"name": "nacimiento",',
         '     "path": "birthDate"}]},',
         '  {"forEach": "name",',
         '   "column": [',
         '    {"name": "uso",  "path": "use"},',
         '    {"name": "nombre",',
         '     "path": "text"}]}',
         ']}'),
       colores = c(tinta, tinta, azul, azul, azul, azul, azul, naranja,
                   naranja, naranja, naranja, naranja, tinta))
popViewport()
# Tabla
panel(0.69, 0.29, "3. data.frame", "vista_ejecutar(recursos, vista)")
cols <- c("id", "nacimiento", "uso", "nombre")
xs <- c(0.04, 0.215, 0.455, 0.645)
filas <- list(c("patient", "1979-03-12", "official", "Luis A. Paredes"),
              c("patient", "1979-03-12", "usual", "Luis Paredes"))
grid.rect(x = 0.5, y = 0.86, width = 0.92, height = 0.1,
          gp = gpar(fill = "#eef3fb", col = NA))
for (j in seq_along(cols)) {
  grid.text(cols[j], x = xs[j], y = 0.86, just = "left",
            gp = gpar(fontfamily = "mono", fontsize = 7.4, fontface = "bold",
                      col = if (j <= 2) azul else naranja))
  for (i in seq_along(filas)) {
    grid.text(filas[[i]][j], x = xs[j], y = 0.86 - i * 0.1, just = "left",
              gp = gpar(fontfamily = "mono", fontsize = 6.9, col = tinta))
  }
}
grid.lines(x = c(0.04, 0.96), y = c(0.58, 0.58), gp = gpar(col = grilla))
grid.text(paste("Una fila por cada nombre (forEach).",
                "Las columnas del recurso se repiten en cada fila.", sep = "\n"),
          x = 0.05, y = 0.47, just = c("left", "top"),
          gp = gpar(fontsize = 8, col = tinta2, lineheight = 1.15))
grid.text(paste("También: unionAll, repeat, where,", "constant, %rowIndex,",
                "collection, type.", sep = "\n"),
          x = 0.05, y = 0.27, just = c("left", "top"),
          gp = gpar(fontsize = 8, col = tinta2, lineheight = 1.15))
popViewport()
for (x in c(0.335, 0.67)) {
  grid.lines(x = c(x - 0.008, x + 0.012), y = c(0.47, 0.47),
             arrow = arrow(length = unit(0.12, "inches"), type = "closed"),
             gp = gpar(col = dorado, fill = dorado, lwd = 3))
}
grid.text("Azul: columnas del recurso · Naranja: columnas de forEach (una fila por elemento)",
          x = 0.02, y = 0.03, just = "left", gp = gpar(fontsize = 8, col = tinta2))
invisible(dev.off())

# --- 2. Conformidad ----------------------------------------------------------
res <- vista_conformidad()
res$grupo <- ifelse(res$perfil == "shareable", "shareable",
                    ifelse(res$aprobada, "experimental", "falla"))
tabla <- table(factor(res$archivo), factor(res$grupo,
                                           c("shareable", "experimental", "falla")))
tabla <- tabla[order(rowSums(tabla)), , drop = FALSE]
nombres <- sub("\\.json$", "", rownames(tabla))
abrir("README-conformidad.png", 1600, 1300)
op <- par(mar = c(4.2, 9.5, 4.2, 4.5), bg = fondo, col.axis = tinta2,
          col.lab = tinta2, family = "sans", mgp = c(2.4, 0.6, 0))
pos <- barplot(t(tabla), horiz = TRUE, las = 1, names.arg = nombres,
               col = c(azul, amarillo, gris), border = fondo, lwd = 2,
               space = 0.35, xlim = c(0, max(rowSums(tabla)) * 1.12),
               xlab = "Pruebas", cex.names = 0.8, axes = FALSE)
axis(1, col = grilla, col.ticks = grilla, cex.axis = 0.8)
abline(v = pretty(c(0, max(rowSums(tabla)))), col = grilla, lwd = 0.8)
barplot(t(tabla), horiz = TRUE, names.arg = rep("", nrow(tabla)),
        col = c(azul, amarillo, gris), border = fondo, lwd = 2, space = 0.35,
        add = TRUE, axes = FALSE)
aprobadas <- tabla[, "shareable"] + tabla[, "experimental"]
text(rowSums(tabla), pos, paste0(aprobadas, "/", rowSums(tabla)), pos = 4,
     cex = 0.72, col = tinta, xpd = TRUE)
title(main = sprintf("Banco oficial de SQL on FHIR: %d/%d aprobadas",
                     sum(res$aprobada), nrow(res)),
      adj = 0, cex.main = 1.05, col.main = tinta, line = 2.4)
mtext(sprintf("shareable %d/%d · experimental %d/%d · FHIR/sql-on-fhir.js@6677c20",
              sum(res$aprobada & res$perfil == "shareable"),
              sum(res$perfil == "shareable"),
              sum(res$aprobada & res$perfil == "experimental"),
              sum(res$perfil == "experimental")),
      side = 3, adj = 0, line = 1.1, cex = 0.75, col = tinta2)
legend("bottomright", legend = c("shareable (aprobada)",
                                 "experimental (aprobada)",
                                 "experimental (falla)"),
       fill = c(azul, amarillo, gris), border = NA, bty = "n", cex = 0.75,
       text.col = tinta)
par(op)
invisible(dev.off())

# --- 3. Rendimiento ----------------------------------------------------------
r <- utils::read.csv("data-raw/rendimiento.csv")
abrir("README-rendimiento.png", 1600, 900)
op <- par(mar = c(4.2, 4.6, 4.2, 9), bg = fondo, col.axis = tinta2,
          col.lab = tinta2, family = "sans", mgp = c(2.6, 0.6, 0))
x <- r$recursos / 1000
plot(NA, xlim = c(0, max(x)), ylim = c(0, max(r$listas, r$json, na.rm = TRUE)),
     xlab = "Pacientes (miles)", ylab = "Segundos", axes = FALSE)
abline(h = graphics::axTicks(2), col = grilla, lwd = 0.8)
axis(1, col = grilla, col.ticks = grilla, cex.axis = 0.8)
axis(2, col = grilla, col.ticks = grilla, las = 1, cex.axis = 0.8)
lines(x, r$json, col = azul, lwd = 2.5)
points(x, r$json, pch = 21, bg = azul, col = fondo, cex = 1.4, lwd = 1.5)
ok <- !is.na(r$listas)
lines(x[ok], r$listas[ok], col = amarillo, lwd = 2.5)
points(x[ok], r$listas[ok], pch = 21, bg = amarillo, col = fondo, cex = 1.4,
       lwd = 1.5)
n <- nrow(r)
text(x[n], r$json[n], sprintf("desde JSON / NDJSON\n%.1f s", r$json[n]),
     pos = 4, cex = 0.72, col = tinta, xpd = TRUE)
m <- max(which(ok))
text(x[m], r$listas[m], sprintf("desde listas de R\n%.1f s", r$listas[m]),
     pos = 4, cex = 0.72, col = tinta, xpd = TRUE)
title(main = "Tiempo de vista_ejecutar() según el número de recursos",
      adj = 0, cex.main = 1.05, col.main = tinta, line = 2.4)
mtext(sprintf(paste("Vista con where, 4 columnas y forEach sobre name",
                    "(%s filas con %s pacientes) · %s, R %s"),
              format(r$filas[n], big.mark = " "),
              format(r$recursos[n], big.mark = " "),
              "Linux", paste(R.version$major, R.version$minor, sep = ".")),
      side = 3, adj = 0, line = 1.1, cex = 0.75, col = tinta2)
legend("topleft", legend = c("desde JSON / NDJSON", "desde listas de R"),
       col = c(azul, amarillo), lwd = 2.5, pch = 19, bty = "n", cex = 0.75,
       text.col = tinta)
par(op)
invisible(dev.off())

# --- 4. Tasas de dengue (datos ficticios) ------------------------------------
dengue <- fhir_recursos(system.file("extdata", "dengue_2025.ndjson.gz",
                                    package = "fhirviews"))
pacientes <- vista_ejecutar(dengue, vista_crear("Patient", c(
  dpa_canton = paste0("address.extension('https://f-slg.github.io/fhirviews/",
                      "StructureDefinition/codigo-dpa').value.first()"),
  canton = "address.district.first()",
  provincia = "address.state.first()")))
casos <- vista_ejecutar(dengue, vista_crear(
  "Condition", c(paciente = "subject.getReferenceKey(Patient)"),
  columnas_recurso = NULL,
  where = "verificationStatus.coding.where(code = 'confirmed').exists()"))
casos <- merge(casos, pacientes, by.x = "paciente", by.y = "id")
por_canton <- aggregate(paciente ~ dpa_canton + canton + provincia,
                        data = casos, FUN = length)
names(por_canton)[4] <- "casos"
por_canton$anio <- 2025
tasas <- pobecu::pob_tasa(por_canton, "casos")
top <- utils::head(tasas[order(-tasas$tasa), ], 15)
colores <- c("El Oro" = azul, "Guayas" = naranja, "Los Ríos" = aqua,
             "Manabí" = amarillo)
abrir("README-tasas.png", 1600, 1000)
op <- par(mar = c(4.2, 14, 4.2, 2), bg = fondo, col.axis = tinta2,
          col.lab = tinta2, family = "sans", mgp = c(2.4, 0.6, 0))
pos <- barplot(rev(top$tasa), names.arg = rev(top$canton), horiz = TRUE,
               las = 1, col = colores[rev(top$provincia)], border = fondo,
               lwd = 2, xlim = c(0, max(top$tasa) * 1.15), axes = FALSE,
               xlab = "Casos por 100 000 habitantes", cex.names = 0.8)
axis(1, col = grilla, col.ticks = grilla, cex.axis = 0.8)
text(rev(top$tasa), pos, sprintf("%.1f", rev(top$tasa)), pos = 4,
     cex = 0.7, col = tinta, xpd = TRUE)
title(main = "Dengue 2025: los 15 cantones con tasas más altas",
      adj = 0, cex.main = 1.05, col.main = tinta, line = 2.4)
mtext("Datos FICTICIOS · FHIR (Patient + Condition) → vistas → pobecu::pob_tasa()",
      side = 3, adj = 0, line = 1.1, cex = 0.75, col = tinta2)
legend("bottomright", legend = names(colores), fill = colores, border = NA,
       bty = "n", cex = 0.75, text.col = tinta, title = "Provincia",
       title.col = tinta2)
par(op)
invisible(dev.off())

message("Figuras escritas en man/figures/")
