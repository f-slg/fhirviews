# -----------------------------------------------------------------------------
# fhirviews · Logo (hexágono)
#
# Mismo estilo que pobecu y geoecu (azul marino y dorado). Muestra un recurso
# FHIR (llaves de JSON con un árbol de elementos) que se convierte en una
# tabla: la idea de un ViewDefinition.
#
# Requisitos: solo R base (grid)
# Uso:        Rscript data-raw/logo.R
# -----------------------------------------------------------------------------
library(grid)

azul   <- "#0F2233"
azul2  <- "#1B3A52"
dorado <- "#F2B705"
blanco <- "#F4F6F8"

# --- Lienzo ------------------------------------------------------------------
alto <- 1200
ancho <- round(alto * sqrt(3) / 2)
dir.create("man/figures", showWarnings = FALSE, recursive = TRUE)
png("man/figures/logo.png", width = ancho, height = alto, bg = "transparent",
    type = "cairo", antialias = "subpixel")

hexagono <- function(r) {
  ang <- pi / 2 + (0:5) * pi / 3
  list(x = 0.5 + r * cos(ang) * alto / ancho / 2, y = 0.5 + r * sin(ang) / 2)
}
h_ext <- hexagono(0.995)
h_med <- hexagono(0.955)
h_int <- hexagono(0.925)

grid.newpage()
grid.polygon(h_ext$x, h_ext$y, gp = gpar(fill = dorado, col = NA))
grid.polygon(h_med$x, h_med$y,
             gp = gpar(col = NA, fill = radialGradient(c(azul2, azul),
                                                       cx1 = 0.5, cy1 = 0.6, r2 = 0.7)))
grid.polygon(h_int$x, h_int$y,
             gp = gpar(fill = NA, col = adjustcolor(dorado, 0.35), lwd = 1.6))

# --- Recurso FHIR: llaves y árbol de elementos -------------------------------
pushViewport(viewport(x = 0.30, y = 0.58, width = 0.30, height = 0.36))
grid.text("{", x = 0.06, y = 0.5,
          gp = gpar(col = blanco, fontsize = 210, fontface = "bold"))
grid.text("}", x = 0.94, y = 0.5,
          gp = gpar(col = blanco, fontsize = 210, fontface = "bold"))
# Nodos: raíz, dos hijos y tres nietos
nodos <- data.frame(
  x = c(0.30, 0.50, 0.50, 0.70, 0.70, 0.70),
  y = c(0.74, 0.53, 0.27, 0.63, 0.43, 0.27)
)
aristas <- list(c(1, 2), c(1, 3), c(2, 4), c(2, 5), c(3, 6))
for (a in aristas) {
  grid.lines(x = c(nodos$x[a[1]], nodos$x[a[1]], nodos$x[a[2]]),
             y = c(nodos$y[a[1]], nodos$y[a[2]], nodos$y[a[2]]),
             gp = gpar(col = adjustcolor(blanco, 0.75), lwd = 7))
}
grid.circle(nodos$x, nodos$y, r = 0.055,
            gp = gpar(fill = c(dorado, rep(blanco, 5)), col = NA))
popViewport()

# --- Flecha ------------------------------------------------------------------
grid.lines(x = c(0.47, 0.55), y = c(0.58, 0.58),
           arrow = arrow(angle = 30, length = unit(0.035, "npc"), type = "closed"),
           gp = gpar(col = dorado, fill = dorado, lwd = 9, lineend = "round"))

# --- Tabla -------------------------------------------------------------------
pushViewport(viewport(x = 0.715, y = 0.58, width = 0.25, height = 0.30))
n_fil <- 5
n_col <- 3
for (i in seq_len(n_fil)) {
  for (j in seq_len(n_col)) {
    encabezado <- i == 1
    grid.rect(x = (j - 1) / n_col, y = 1 - i / n_fil,
              width = 1 / n_col * 0.9, height = 1 / n_fil * 0.82,
              just = c("left", "bottom"),
              gp = gpar(col = NA,
                        fill = if (encabezado) dorado else
                          adjustcolor(blanco, if (i %% 2 == 0) 0.95 else 0.7)))
  }
}
popViewport()

# --- Nombre ------------------------------------------------------------------
tam <- 118
g1 <- textGrob("fhir", gp = gpar(fontsize = tam, fontface = "bold", col = blanco))
g2 <- textGrob("views", gp = gpar(fontsize = tam, fontface = "bold", col = dorado))
w1 <- convertWidth(grobWidth(g1), "npc", valueOnly = TRUE)
w2 <- convertWidth(grobWidth(g2), "npc", valueOnly = TRUE)
x0 <- 0.5 - (w1 + w2) / 2
grid.text("fhir", x = x0, y = 0.255, just = "left",
          gp = gpar(fontsize = tam, fontface = "bold", col = blanco))
grid.text("views", x = x0 + w1, y = 0.255, just = "left",
          gp = gpar(fontsize = tam, fontface = "bold", col = dorado))

invisible(dev.off())
message("Escrito: man/figures/logo.png")

# --- Icono del panel Connections de RStudio (inst/icons/fhir.png) ------------
dir.create("inst/icons", showWarnings = FALSE, recursive = TRUE)
png("inst/icons/fhir.png", width = 64, height = 64, bg = "transparent",
    type = "cairo", antialias = "subpixel")
grid.newpage()
h <- list(x = 0.5 + 0.48 * cos(pi / 2 + (0:5) * pi / 3),
          y = 0.5 + 0.48 * sin(pi / 2 + (0:5) * pi / 3))
grid.polygon(h$x, h$y, gp = gpar(fill = azul, col = dorado, lwd = 3))
for (i in 1:3) {
  for (j in 1:2) {
    grid.rect(x = 0.27 + (j - 1) * 0.24, y = 0.70 - (i - 1) * 0.19,
              width = 0.21, height = 0.15, just = c("left", "top"),
              gp = gpar(col = NA, fill = if (i == 1) dorado else blanco))
  }
}
invisible(dev.off())
message("Escrito: inst/icons/fhir.png")
