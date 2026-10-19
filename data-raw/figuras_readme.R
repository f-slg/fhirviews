# -----------------------------------------------------------------------------
# fhirviews · Figura del README (man/figures/README-tasas.png)
#
# Tasas ficticias de dengue por cantón (inst/extdata/dengue_2025.ndjson.gz)
# con la población 2025 de pobecu.
#
# Requisitos: fhirviews instalado (o devtools::load_all()) y pobecu
# Uso:        Rscript data-raw/figuras_readme.R
# -----------------------------------------------------------------------------
library(fhirviews)

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

azul <- "#0F2233"
dorado <- "#F2B705"
colores <- c("El Oro" = dorado, "Guayas" = azul, "Los Ríos" = "#5B8DB8",
             "Manabí" = "#9A6B00")
png("man/figures/README-tasas.png", width = 1600, height = 900, res = 200,
    type = "cairo")
op <- par(mar = c(4.2, 14, 2.5, 1), family = "sans")
barplot(rev(top$tasa), names.arg = rev(top$canton), horiz = TRUE, las = 1,
        col = colores[rev(top$provincia)], border = NA,
        xlab = "Casos por 100 000 habitantes", cex.names = 0.85)
title("Dengue 2025 por cantón (datos ficticios)", adj = 0, cex.main = 1,
      font.main = 2)
legend("bottomright", legend = names(colores), fill = colores, border = NA,
       bty = "n", cex = 0.8)
par(op)
invisible(dev.off())
message("Escrito: man/figures/README-tasas.png")
