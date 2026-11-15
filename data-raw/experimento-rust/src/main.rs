// El laboratorio y el componente opcional comparten el mismo nucleo.
fn main() {
    match fhirviews_rust_validator::ejecutar_experimento(&std::env::args().collect::<Vec<_>>()) {
        Ok(respuesta) => println!("{respuesta}"),
        Err(_) => {
            eprintln!("No se pudo ejecutar el experimento Rust; revisar entradas y plan.");
            std::process::exit(2);
        }
    }
}
