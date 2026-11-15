fn main() {
    match fhirviews_rust_validator::ejecutar_componente(&std::env::args().collect::<Vec<_>>()) {
        Ok(respuesta) => println!("{respuesta}"),
        Err(_) => {
            // No imprimir entradas, rutas temporales ni valores clinicos.
            eprintln!("No se pudo completar la validacion estructural Rust.");
            std::process::exit(2);
        }
    }
}
