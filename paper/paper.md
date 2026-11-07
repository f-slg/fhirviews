---
title: 'fhirviews: a native R engine for SQL on FHIR views and an HL7 FHIR R4 client'
tags:
  - R
  - HL7 FHIR
  - SQL on FHIR
  - FHIRPath
  - health informatics
  - epidemiology
  - public health
authors:
  - name: Ronald Fabricio Salas Guerrero
    orcid: 0000-0000-0000-0000  # PENDIENTE: ORCID real
    corresponding: true
    affiliation: 1
affiliations:
  - name: PENDIENTE (institución, ciudad, país)
    index: 1
date: 6 November 2026
bibliography: paper.bib
---

# Summary

HL7 Fast Healthcare Interoperability Resources (FHIR) is the dominant standard
for exchanging clinical data [@bender2013fhir]. FHIR resources are deeply
nested JSON documents, while statistical analysis in epidemiology and public
health expects flat tables. The SQL on FHIR v2 specification [@sqlonfhir]
closes this gap with the `ViewDefinition`: a portable, declarative description
of the columns, filters and collection expansions that turn FHIR resources into
a table, written with FHIRPath expressions [@fhirpath].

`fhirviews` is an R package that implements SQL on FHIR v2 natively in R, with
no Java virtual machine, Spark cluster or database server. FHIRPath is evaluated
with the reference JavaScript implementation `fhirpath.js` [@fhirpathjs]
through the `V8` package [@V8]. An experimental second engine translates
`ViewDefinition`s to DuckDB SQL [@raasveldt2019duckdb] to process millions of
resources from NDJSON or Parquet files. The package also includes an HL7 FHIR
R4 client built on `httr2` [@httr2] (search with automatic paging, CRUD,
transactions, SMART on FHIR authentication and Bulk Data `$export`) and
terminology operations (`$expand`, `$lookup`, `$validate-code`) to define
cohorts from value sets. The same view can therefore be applied, unchanged, to
a REST search, a local file or a population-level export.

# Statement of need

Researchers and public health analysts increasingly receive data from FHIR
servers and Bulk Data exports, but most work in R. Existing R tools take one of
two approaches. `fhircrackr` [@palm2023fhircrackr] flattens FHIR Bundles with
XPath expressions over XML and a package-specific table description; its
definitions cannot be reused outside the package, and filters on dates or
nested collections must be written as additional R code. Pathling
[@grimes2022pathling] implements SQL on FHIR and offers R bindings, but runs
on Apache Spark and requires a Java runtime, which is a barrier on laptops,
in teaching environments and in under-resourced health institutions.

`fhirviews` targets epidemiologists, public health surveillance teams,
researchers and instructors who need reproducible extractions from FHIR inside
an ordinary R workflow. Because extraction is a standard `ViewDefinition`, the
definition can be stored next to the analysis, reviewed, and executed by any
other conformant implementation. The package ships view templates for public
health indicators, block-wise processing of NDJSON and gzip files with typed
contracts for loading into databases, and integration with the RStudio
Connections pane and addins. Its documentation is written in Spanish, which
addresses a gap for health informatics users in Latin America.

# Conformance and performance

The package bundles the official SQL on FHIR conformance test suite and runs it
as part of its own tests. Both engines pass all 133 tests of the `shareable`
profile. `vista_conformidad()` reports the results in the official format used
by the implementations page of the specification.

We compared `fhirviews` with `fhircrackr` 2.4.0 on synthetic data, producing
the same table with both packages and checking that the outputs were identical
before timing. With 100,000 `Patient` resources (a date filter, four columns and
one row per name), end-to-end times from files to a `data.frame` were 48.5 s
for `fhircrackr` on one core and 15.8 s on eight cores, 15.4 s for the
single-threaded V8 engine and 1.1 s for the DuckDB engine. A second case with
`Observation` resources (coding filters, choice types, references and component
expansion) showed the same pattern on one core; with eight cores `fhircrackr`
matched the V8 engine up to 50,000 resources but exceeded 14 GB of memory at
100,000, a size that both `fhirviews` engines processed. These measurements come from a
single machine and simple synthetic resources; the scripts are included in the
repository so that they can be reproduced.

# Acknowledgements

PENDIENTE: agradecimientos (por ejemplo, participantes del piloto, colegas o
financiación). We thank the authors of `fhirpath.js` and the SQL on FHIR
community for the reference implementation and the conformance suite.

# AI usage disclosure

PENDIENTE: describir el uso de herramientas de IA generativa en el desarrollo
del software y del artículo, según la política vigente de JOSS.

# References
