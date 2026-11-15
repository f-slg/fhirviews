use serde_json::{json, Value};
use std::fs;
use std::path::PathBuf;
use std::process::{Command, Output};
use std::sync::atomic::{AtomicUsize, Ordering};

static NUMERO: AtomicUsize = AtomicUsize::new(0);
struct Caso(PathBuf);
impl Caso {
    fn nuevo() -> Self {
        let carpeta = std::env::temp_dir().join(format!("fhirviews-contract-{}-{}",
            std::process::id(), NUMERO.fetch_add(1, Ordering::SeqCst)));
        fs::create_dir(&carpeta).unwrap();
        Self(carpeta)
    }
    fn ejecutar(&self, plan: Value, datos: &str) -> Output {
        fs::write(self.0.join("plan.json"), plan.to_string()).unwrap();
        fs::write(self.0.join("entrada.ndjson"), datos).unwrap();
        Command::new(env!("CARGO_BIN_EXE_fhirviews-rust-validator"))
            .arg(self.0.join("plan.json")).arg(self.0.join("entrada.ndjson"))
            .output().unwrap()
    }
}
impl Drop for Caso {
    fn drop(&mut self) { fs::remove_dir_all(&self.0).unwrap(); }
}
fn plan() -> Value {
    json!({"contrato": "fhirviews-r4-validator/1", "version_fhir": "4.0.1",
        "esquema_id": "0123456789abcdef0123456789abcdef",
        "raices": {"Observation": "Observation|"}, "recursos_r4": ["Observation"],
        "nodos": [{"clave": "Observation|", "grupos": [
            {"nombre": "status", "nombres": ["status"], "min": 1}], "campos": [
            {"nombre": "status", "tipo": "code", "min": 1, "max": 1, "repetido": false,
                "hijo": null, "destinos": [], "vinculo": {"fuerza": "required", "valueSet": "urn:ficticio",
                    "codigos": [{"system": "urn:status", "code": "final", "caseSensitive": true}]}},
            {"nombre": "id", "tipo": "id", "min": 0, "max": 1, "repetido": false,
                "hijo": null, "destinos": [], "vinculo": null},
            {"nombre": "valueDecimal", "tipo": "decimal", "min": 0, "max": 1, "repetido": false,
                "hijo": null, "destinos": [], "vinculo": null}]}]})
}

#[test]
fn capacidades_son_json_versionado() {
    let o = Command::new(env!("CARGO_BIN_EXE_fhirviews-rust-validator"))
        .arg("--capabilities").output().unwrap();
    assert!(o.status.success());
    let r: Value = serde_json::from_slice(&o.stdout).unwrap();
    assert_eq!(r["contrato"], "fhirviews-r4-validator/1");
    assert_eq!(r["version_fhir"], "4.0.1");
    assert_eq!(r["alcance"], "recursos-construidos-y-tipados-por-r");
}

#[test]
fn resultado_identifica_esquema_y_cantidad_sin_reescribir_decimales() {
    let c = Caso::nuevo();
    let datos = "{\"resourceType\":\"Observation\",\"status\":\"final\",\"valueDecimal\":12345678901234567890.001}\n";
    let o = c.ejecutar(plan(), datos);
    assert!(o.status.success());
    let r: Value = serde_json::from_slice(&o.stdout).unwrap();
    assert_eq!(r["esquema_id"], plan()["esquema_id"]);
    assert_eq!(r["resultado"]["valido"], true);
    assert_eq!(r["resultado"]["recursos"], 1);
    assert_eq!(fs::read_to_string(c.0.join("entrada.ndjson")).unwrap(), datos);
}

#[test]
fn rechazo_es_resultado_y_conserva_primera_fila_sin_exponer_datos() {
    let c = Caso::nuevo();
    let o = c.ejecutar(plan(), concat!(
        "{\"resourceType\":\"Observation\",\"status\":\"final\"}\n",
        "{\"resourceType\":\"Observation\",\"id\":\"secreto-ficticio\",\"status\":\"invalido\"}\n",
        "{\"resourceType\":\"Observation\"}\n"));
    assert!(o.status.success());
    let r: Value = serde_json::from_slice(&o.stdout).unwrap();
    assert_eq!(r["resultado"]["valido"], false);
    assert_eq!(r["resultado"]["recursos"], 2);
    assert_eq!(r["resultado"]["error"]["fila"], 2);
    assert_eq!(r["resultado"]["error"]["campo"], "status");
    assert_eq!(r["resultado"]["error"]["value_set"], "urn:ficticio");
    assert!(!String::from_utf8_lossy(&o.stdout).contains("secreto-ficticio"));
    assert!(o.stderr.is_empty());
}

#[test]
fn protocolo_rechaza_version_y_plan_incompleto() {
    let c = Caso::nuevo();
    let mut p = plan(); p["contrato"] = json!("otro/2");
    assert!(!c.ejecutar(p, "").status.success());
    let mut p = plan(); p["version_fhir"] = json!("6.0.0");
    assert!(!c.ejecutar(p, "").status.success());
    let mut p = plan(); p["raices"]["Observation"] = json!("ausente");
    assert!(!c.ejecutar(p, "").status.success());
    let mut p = plan(); p["nodos"][0]["campos"][0]["hijo"] = json!("ausente");
    assert!(!c.ejecutar(p, "").status.success());
}

#[test]
fn json_malformado_falla_sin_imprimir_el_contenido() {
    let c = Caso::nuevo();
    let o = c.ejecutar(plan(), "{\"id\":\"secreto-ficticio\", error}");
    assert!(!o.status.success());
    assert!(o.stdout.is_empty());
    assert!(!String::from_utf8_lossy(&o.stderr).contains("secreto-ficticio"));
}
