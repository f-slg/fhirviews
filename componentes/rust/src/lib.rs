//! Validacion estructural de recursos ya tipados por el constructor R.
//! No es un validador FHIR general ni realiza aritmetica o serializacion de recursos.
use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::{HashMap, HashSet};
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::time::Instant;

#[derive(Deserialize)]
struct PlanEntrada {
    raices: HashMap<String, String>,
    recursos_r4: Vec<String>,
    nodos: Vec<NodoEntrada>,
}

const CONTRATO: &str = "fhirviews-r4-validator/1";

#[derive(Deserialize)]
struct PlanContrato {
    contrato: String,
    version_fhir: String,
    esquema_id: String,
    #[serde(flatten)]
    plan: PlanEntrada,
}

fn comprobar_plan(p: &PlanEntrada) -> bool {
    let claves: HashSet<_> = p.nodos.iter().map(|n| &n.clave).collect();
    !p.raices.is_empty()
        && claves.len() == p.nodos.len()
        && p.raices.values().all(|k| claves.contains(k))
        && p.nodos.iter().all(|n| {
            let campos: HashSet<_> = n.campos.iter().map(|c| &c.nombre).collect();
            campos.len() == n.campos.len()
                && n.campos.iter().all(|c| {
                    c.max.map_or(true, |max| c.min <= max)
                        && c.hijo.as_ref().map_or(true, |k| claves.contains(k))
                })
                && n.grupos.iter().all(|g| {
                    !g.nombres.is_empty() && g.nombres.iter().all(|k| campos.contains(k))
                })
        })
}

/// CLI protocol, deliberately independent of R's ABI. Inputs must already be
/// constructed and primitive-typed by R; this is not general FHIR validation.
pub fn ejecutar_componente(args: &[String]) -> Result<String, Box<dyn std::error::Error>> {
    if args.len() == 2 && args[1] == "--capabilities" {
        return Ok(serde_json::json!({
            "componente": "fhirviews-rust-validator",
            "version": env!("CARGO_PKG_VERSION"),
            "contrato": CONTRATO,
            "version_fhir": "4.0.1",
            "alcance": "recursos-construidos-y-tipados-por-r"
        }).to_string());
    }
    if args.len() != 3 { return Err("Argumentos incompatibles".into()); }
    let inicio = Instant::now();
    let p: PlanContrato = serde_json::from_reader(BufReader::new(File::open(&args[1])?))?;
    if p.contrato != CONTRATO || p.version_fhir != "4.0.1"
        || p.esquema_id.len() != 32 || !p.esquema_id.bytes().all(|b| b.is_ascii_hexdigit())
        || !comprobar_plan(&p.plan) {
        return Err("Plan incompatible".into());
    }
    let plan = Plan::nuevo(p.plan)?;
    let resultado = validar_archivo(plan, &args[2], inicio.elapsed().as_secs_f64())?;
    Ok(serde_json::json!({
        "contrato": CONTRATO,
        "version_fhir": "4.0.1",
        "esquema_id": p.esquema_id,
        "resultado": resultado
    }).to_string())
}
#[derive(Deserialize)]
struct NodoEntrada {
    clave: String,
    grupos: Vec<Grupo>,
    campos: Vec<Campo>,
}
#[derive(Deserialize)]
struct Grupo {
    nombre: String,
    nombres: Vec<String>,
    min: usize,
}
#[derive(Deserialize)]
struct Campo {
    nombre: String,
    tipo: String,
    min: usize,
    max: Option<usize>,
    repetido: bool,
    hijo: Option<String>,
    destinos: Vec<String>,
    vinculo: Option<Vinculo>,
}
#[derive(Deserialize)]
struct Vinculo {
    fuerza: String,
    #[serde(rename = "valueSet")]
    value_set: Option<String>,
    codigos: Option<Vec<Codigo>>,
}
#[derive(Deserialize)]
struct Codigo {
    system: String,
    code: String,
    #[serde(rename = "caseSensitive")]
    case_sensitive: bool,
}
struct Nodo {
    grupos: Vec<Grupo>,
    campos: HashMap<String, Campo>,
}
struct Plan {
    raices: HashMap<String, String>,
    nodos: HashMap<String, Nodo>,
    recursos: HashSet<String>,
    relativo: Regex,
    absoluto: Regex,
    esquema_uri: Regex,
    tipo: Regex,
}
#[derive(Serialize)]
struct ErrorValidacion {
    fila: usize,
    campo: String,
    motivo: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    value_set: Option<String>,
}
#[derive(Serialize)]
struct Respuesta {
    valido: bool,
    recursos: usize,
    segundos_plan: f64,
    segundos_validacion: f64,
    error: Option<ErrorValidacion>,
}
fn fallo(fila: usize, campo: &str, motivo: &str) -> ErrorValidacion {
    ErrorValidacion { fila, campo: campo.into(), motivo: motivo.into(), value_set: None }
}
impl Plan {
    fn nuevo(p: PlanEntrada) -> Result<Self, regex::Error> {
        let patron = r"([A-Z][A-Za-z0-9]+)/[A-Za-z0-9.-]{1,64}(/_history/[A-Za-z0-9.-]{1,64})?$";
        Ok(Self {
            raices: p.raices,
            nodos: p.nodos.into_iter().map(|n| (n.clave, Nodo {
                grupos: n.grupos,
                campos: n.campos.into_iter().map(|c| (c.nombre.clone(), c)).collect(),
            })).collect(),
            recursos: p.recursos_r4.into_iter().collect(),
            relativo: Regex::new(&format!("^{patron}"))?,
            absoluto: Regex::new(&format!("(?s)^https?://.+/{patron}"))?,
            esquema_uri: Regex::new(r"^[A-Za-z][A-Za-z0-9+.-]*:")?,
            tipo: Regex::new(r"^[A-Z][A-Za-z0-9]+$")?,
        })
    }
    fn validar(&self, r: &Value, clave: &str, fila: usize, prefijo: &str) -> Result<(), ErrorValidacion> {
        let nodo = self.nodos.get(clave).ok_or_else(|| fallo(fila, prefijo, "plan_incompatible"))?;
        let obj = r.as_object().ok_or_else(|| fallo(fila, prefijo, "objeto_incompatible"))?;
        for g in &nodo.grupos {
            let presentes = g.nombres.iter().filter(|s| obj.contains_key(*s)).count();
            if (g.min > 0 && presentes == 0) || presentes > 1 {
                return Err(fallo(fila, &format!("{prefijo}{}", g.nombre), "obligatorio_eleccion"));
            }
        }
        for (nombre, valor) in obj {
            if nombre == "resourceType" { continue; }
            let path = format!("{prefijo}{nombre}");
            let e = nodo.campos.get(nombre).ok_or_else(|| fallo(fila, &path, "campo_desconocido"))?;
            let valores: Vec<&Value> = if e.repetido {
                valor.as_array().ok_or_else(|| fallo(fila, &path, "objeto_incompatible"))?.iter().collect()
            } else { vec![valor] };
            if valores.len() < e.min || e.max.map_or(false, |m| valores.len() > m) {
                return Err(fallo(fila, &path, "cardinalidad"));
            }
            for v in &valores {
                self.binding(v, e, fila, &path)?;
                if e.tipo == "Reference" { self.referencia(v, &e.destinos, fila, &path)?; }
            }
            if let Some(hijo) = &e.hijo {
                for v in valores { self.validar(v, hijo, fila, &(path.clone() + "."))?; }
            }
        }
        Ok(())
    }
    fn binding(&self, v: &Value, e: &Campo, fila: usize, campo: &str) -> Result<(), ErrorValidacion> {
        let Some(b) = &e.vinculo else { return Ok(()); };
        if b.fuerza != "required" { return Ok(()); }
        let codings: Vec<&Value> = if e.tipo == "CodeableConcept" {
            v.get("coding").and_then(Value::as_array).map_or_else(Vec::new, |xs| xs.iter().collect())
        } else { vec![v] };
        if e.tipo == "CodeableConcept" && !codings.iter().any(|c| c.get("code").map_or(false, |x| !x.is_null())) {
            return Err(fallo(fila, campo, "coding_requerido"));
        }
        let Some(permitidos) = &b.codigos else { return Ok(()); };
        let coincide = codings.iter().any(|c| {
            let codigo = if e.tipo == "Coding" || e.tipo == "CodeableConcept" { c.get("code") } else { Some(*c) };
            let Some(codigo) = codigo.and_then(Value::as_str) else { return false; };
            permitidos.iter().any(|p| {
                let igual = if p.case_sensitive { codigo == p.code } else { codigo.to_lowercase() == p.code.to_lowercase() };
                igual && (e.tipo != "Coding" && e.tipo != "CodeableConcept" || c.get("system").and_then(Value::as_str) == Some(p.system.as_str()))
            })
        });
        if !coincide {
            let mut e = fallo(fila, campo, "binding_requerido");
            e.value_set = b.value_set.clone();
            return Err(e);
        }
        Ok(())
    }
    fn destino(&self, tipo: &str, destinos: &[String], fila: usize, campo: &str) -> Result<(), ErrorValidacion> {
        if !self.recursos.contains(tipo) || (!destinos.is_empty() && !destinos.iter().any(|x| x == "Resource" || x == tipo)) {
            return Err(fallo(fila, campo, "destino_referencia"));
        }
        Ok(())
    }
    fn referencia(&self, v: &Value, destinos: &[String], fila: usize, campo: &str) -> Result<(), ErrorValidacion> {
        let existe = |k| v.get(k).map_or(false, |x| !x.is_null());
        if !existe("reference") && !existe("identifier") && !existe("display") {
            return Err(fallo(fila, campo, "referencia_sin_destino"));
        }
        let declarada = v.get("type").and_then(Value::as_str).map(|s| s.strip_prefix("http://hl7.org/fhir/StructureDefinition/").unwrap_or(s))
            .filter(|s| self.tipo.is_match(s));
        let literal = v.get("reference").and_then(Value::as_str);
        let mut tipo = None;
        if let Some(s) = literal {
            if s.starts_with('#') { return Err(fallo(fila, &(campo.to_owned() + ".reference"), "referencia_contained")); }
            let absoluto = s.starts_with("https://") || s.starts_with("http://");
            let relativo = !self.esquema_uri.is_match(s);
            if absoluto || relativo {
                let caps = if absoluto { self.absoluto.captures(s) } else { self.relativo.captures(s) };
                if let Some(c) = caps { tipo = c.get(1).map(|m| m.as_str()); }
                else if relativo { return Err(fallo(fila, &(campo.to_owned() + ".reference"), "referencia_relativa")); }
            }
        }
        if let Some(t) = tipo { self.destino(t, destinos, fila, campo)?; }
        if let Some(t) = declarada { self.destino(t, destinos, fila, campo)?; }
        if tipo.is_some() && declarada.is_some() && tipo != declarada {
            return Err(fallo(fila, campo, "reference_type_distinto"));
        }
        Ok(())
    }
}
fn ejecutar(args: &[String]) -> Result<Respuesta, Box<dyn std::error::Error>> {
    if args.len() != 3 { return Err("Se requieren plan.json y recursos.ndjson".into()); }
    let inicio = Instant::now();
    let entrada: PlanEntrada = serde_json::from_reader(BufReader::new(File::open(&args[1])?))?;
    let plan = Plan::nuevo(entrada)?;
    let segundos_plan = inicio.elapsed().as_secs_f64();
    validar_archivo(plan, &args[2], segundos_plan)
}

fn validar_archivo(plan: Plan, archivo: &str, segundos_plan: f64) -> Result<Respuesta, Box<dyn std::error::Error>> {
    let inicio = Instant::now();
    let lector = BufReader::new(File::open(archivo)?);
    let mut recursos = 0;
    for linea in lector.lines() {
        let linea = linea?;
        if linea.trim().is_empty() { continue; }
        recursos += 1;
        // RawValue y arbitrary_precision evitan convertir los literales a f64.
        // El programa no reescribe el JSON de recursos ni devuelve sus valores.
        let raw: &serde_json::value::RawValue = serde_json::from_str(&linea)?;
        let r: Value = serde_json::from_str(raw.get())?;
        let tipo = r.get("resourceType").and_then(Value::as_str).unwrap_or("");
        let error = match plan.raices.get(tipo) {
            Some(clave) => plan.validar(&r, clave, recursos, "").err(),
            None => Some(fallo(recursos, "resourceType", "recurso_fuera_del_piloto")),
        };
        if error.is_some() {
            return Ok(Respuesta { valido: false, recursos, segundos_plan,
                segundos_validacion: inicio.elapsed().as_secs_f64(), error });
        }
    }
    Ok(Respuesta { valido: true, recursos, segundos_plan,
        segundos_validacion: inicio.elapsed().as_secs_f64(), error: None })
}
/// Legacy laboratory entry point. Published timings remain tied to their frozen commit.
pub fn ejecutar_experimento(args: &[String]) -> Result<String, Box<dyn std::error::Error>> {
    Ok(serde_json::to_string(&ejecutar(args)?)?)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn plan() -> Plan {
        Plan::nuevo(serde_json::from_value(json!({
            "raices": {"Observation": "Observation|"},
            "recursos_r4": ["Resource", "Patient", "Group", "Observation", "Practitioner"],
            "nodos": [{"clave": "Observation|", "grupos": [
                {"nombre": "status", "nombres": ["status"], "min": 1},
                {"nombre": "value[x]", "nombres": ["valueString", "valueBoolean"], "min": 0}
            ], "campos": [
                {"nombre": "status", "tipo": "code", "min": 1, "max": 1,
                 "repetido": false, "hijo": null, "destinos": [], "vinculo": {
                    "fuerza": "required", "valueSet": "urn:ficticio", "codigos": [
                        {"system": "urn:status", "code": "final", "caseSensitive": true}]}},
                {"nombre": "valueString", "tipo": "string", "min": 0, "max": 1,
                 "repetido": false, "hijo": null, "destinos": [], "vinculo": null},
                {"nombre": "valueBoolean", "tipo": "boolean", "min": 0, "max": 1,
                 "repetido": false, "hijo": null, "destinos": [], "vinculo": null}
            ]}]
        })).unwrap()).unwrap()
    }

    #[test]
    fn escala_y_numeros_fuera_de_f64_no_se_redondean() {
        for numero in ["0.50", "0.5", "72.00", "12345678901234567890.001"] {
            let raw: &serde_json::value::RawValue = serde_json::from_str(numero).unwrap();
            assert_eq!(raw.get(), numero);
            let v: Value = serde_json::from_str(raw.get()).unwrap();
            assert_eq!(v.to_string(), numero);
        }
    }

    #[test]
    fn obligatorios_y_choice_tienen_prioridad_estable() {
        let p = plan();
        let e = p.validar(&json!({"valueString": "x", "valueBoolean": false}), "Observation|", 3, "").unwrap_err();
        assert_eq!((e.fila, e.campo.as_str()), (3, "status"));
        let e = p.validar(&json!({"status": "final", "valueString": "x", "valueBoolean": false}), "Observation|", 3, "").unwrap_err();
        assert_eq!(e.campo, "value[x]");
        assert!(p.validar(&json!({"status": "final", "valueBoolean": false}), "Observation|", 1, "").is_ok());
    }

    #[test]
    fn binding_requerido_respeta_mayusculas() {
        let p = plan();
        let e = p.validar(&json!({"status": "FINAL"}), "Observation|", 2, "").unwrap_err();
        assert_eq!(e.motivo, "binding_requerido");
        assert_eq!(e.value_set.as_deref(), Some("urn:ficticio"));
    }

    #[test]
    fn referencias_validas_relativas_absolutas_y_urn() {
        let p = plan();
        let destinos = vec!["Patient".to_string()];
        for literal in ["Patient/p1", "Patient/p1/_history/v2", "https://example.invalid/fhir/Patient/p1",
            "https://example.invalid/fhir/Patient/p1/_history/v2", "urn:uuid:00000000-0000-0000-0000-000000000001"] {
            assert!(p.referencia(&json!({"reference": literal, "type": "Patient"}), &destinos, 1, "subject").is_ok());
        }
    }

    #[test]
    fn referencias_rechazan_destino_contenido_y_type_solo() {
        let p = plan();
        let destinos = vec!["Patient".to_string()];
        for (v, motivo, campo) in [
            (json!({"reference": "Observation/o1"}), "destino_referencia", "subject"),
            (json!({"reference": "#p1"}), "referencia_contained", "subject.reference"),
            (json!({"type": "Patient"}), "referencia_sin_destino", "subject"),
            (json!({"reference": "p1"}), "referencia_relativa", "subject.reference"),
        ] {
            let e = p.referencia(&v, &destinos, 4, "subject").unwrap_err();
            assert_eq!((e.fila, e.motivo.as_str(), e.campo.as_str()), (4, motivo, campo));
        }
    }

    #[test]
    fn referencia_declarada_se_compara_con_el_literal() {
        let p = plan();
        let e = p.referencia(&json!({"reference": "Patient/p1", "type": "Group"}),
            &["Resource".to_string()], 1, "focus").unwrap_err();
        assert_eq!(e.motivo, "reference_type_distinto");
    }

    #[test]
    fn respuesta_de_error_no_incluye_valores_del_recurso() {
        let p = plan();
        let e = p.validar(&json!({"status": "VALOR-FICTICIO-PRIVADO"}), "Observation|", 1, "").unwrap_err();
        let s = serde_json::to_string(&e).unwrap();
        assert!(!s.contains("VALOR-FICTICIO-PRIVADO"));
        assert!(s.contains("status"));
    }
}
