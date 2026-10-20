# Filtrar una vista con los códigos de un ValueSet

Agrega a un `ViewDefinition` una condición FHIRPath con los códigos de
una expansión (de
[`tx_expandir()`](https://f-slg.github.io/fhirviews/reference/tx_expandir.md)
o hecha a mano), para que la vista quede autocontenida:
[`vista_ejecutar()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar.md)
y
[`vista_ejecutar_duckdb()`](https://f-slg.github.io/fhirviews/reference/vista_ejecutar_duckdb.md)
la aplican sin consultar el servidor de terminología. Así un indicador
definido con un `ValueSet` (por ejemplo, "todas las personas con
diagnóstico de diabetes") se expande una vez y se calcula sobre millones
de recursos sin red.

## Usage

``` r
vista_con_valueset(
  vista,
  expansion,
  ruta = "code.coding",
  nombre = "vs",
  columna = NULL
)
```

## Arguments

- vista:

  Un `ViewDefinition` en cualquier forma que acepte
  [`vista_leer()`](https://f-slg.github.io/fhirviews/reference/vista_leer.md).

- expansion:

  Un `data.frame` con las columnas `system` y `code`, como el que
  devuelve
  [`tx_expandir()`](https://f-slg.github.io/fhirviews/reference/tx_expandir.md).

- ruta:

  Expresión FHIRPath, desde el recurso, que lleva a los `Coding` que se
  comparan: `"code.coding"` (por defecto, para `Condition`,
  `Observation` o `Procedure`), `"valueCodeableConcept.coding"`,
  `"medication.ofType(CodeableConcept).coding"`, `"class"`, etc.

- nombre:

  Prefijo de las constantes que se agregan a la vista. Debe ser un
  nombre válido de FHIRPath.

- columna:

  Si es `NULL` (por defecto), la condición se agrega como `where` y la
  vista solo devuelve los recursos con algún código del `ValueSet`. Si
  es un texto, en vez de filtrar se agrega una columna lógica con ese
  nombre que indica si el recurso tiene algún código del `ValueSet`;
  sirve para marcar varios grupos en una misma vista.

## Value

La vista modificada, de clase `fhir_vista`.

## Details

Cada sistema de codificación y su lista de códigos se guardan como
constantes de la vista (`%{nombre}_sistema` y `%{nombre}_codigos`, o
`_sistema_1`, `_codigos_1`... si hay varios sistemas); la lista es un
texto con los códigos separados por `|`. La condición queda, por
ejemplo:

`code.coding.where(system = %vs_sistema and %vs_codigos.contains('|' & code & '|')).exists()`

Esta forma (y no una cadena de `or`) mantiene la expresión corta aunque
el `ValueSet` tenga miles de códigos, y el motor DuckDB la traduce a una
sola búsqueda de texto. La vista guarda en su JSON la lista exacta que
se usó, lo que también documenta el indicador.

## See also

[`tx_expandir()`](https://f-slg.github.io/fhirviews/reference/tx_expandir.md).

## Examples

``` r
# Expansión hecha a mano (normalmente sale de tx_expandir())
diabetes <- data.frame(
  system = "http://hl7.org/fhir/sid/icd-10",
  code = c("E10", "E11", "E13", "E14")
)
vista <- vista_crear("Condition", c(
  paciente = "subject.getReferenceKey(Patient)",
  codigo = "code.coding.first().code"
))
vista <- vista_con_valueset(vista, diabetes, nombre = "diabetes")
vista$where
#> [[1]]
#> [[1]]$path
#> [1] "code.coding.where(system = %diabetes_sistema and %diabetes_codigos.contains('|' & code & '|')).exists()"
#> 
#> 

condiciones <- fhir_recursos(list(
  list(resourceType = "Condition", id = "c1",
       subject = list(reference = "Patient/p1"),
       code = list(coding = list(list(
         system = "http://hl7.org/fhir/sid/icd-10", code = "E11")))),
  list(resourceType = "Condition", id = "c2",
       subject = list(reference = "Patient/p2"),
       code = list(coding = list(list(
         system = "http://hl7.org/fhir/sid/icd-10", code = "I10"))))
))
vista_ejecutar(condiciones, vista)
#>   id paciente codigo
#> 1 c1       p1    E11

# Con un servidor de terminología
tx <- fhir_conectar("https://tx.fhir.org/r4", panel = FALSE)
sexo <- tx_expandir(tx, "http://hl7.org/fhir/ValueSet/administrative-gender")
#> Error: El servidor respondió 404 Not Found.
#> ✖ GET https://tx.fhir.org/r4/ValueSet/$expand
#> • [error] Unknown operation: $expand
sexo
#> Error: object 'sexo' not found
```
