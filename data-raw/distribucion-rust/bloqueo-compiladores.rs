// Instrumento de CI; no se incluye en los ZIP publicos del componente.
use std::fs::OpenOptions;
use std::io::Write;

fn main() {
    if let Some(ruta) = std::env::var_os("FHIRVIEWS_COMPILER_MARKER") {
        if let Ok(mut archivo) = OpenOptions::new().create(true).append(true).open(ruta) {
            let _ = writeln!(archivo, "compiler-called");
        }
    }
    std::process::exit(97);
}
