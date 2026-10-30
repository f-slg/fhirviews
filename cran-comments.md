## Submission

This is the first submission of 'fhirviews'.

## Test environments

* Local: Ubuntu Linux, R 4.5.2 (`R CMD check --as-cran`)
* GitHub Actions: R 4.6.1 on Windows, macOS and Ubuntu

## R CMD check results

0 errors | 0 warnings | 2 notes

* This is a new submission.
* Suggests or Enhances not in mainstream repositories: pobecu.

## Notes for the reviewers

* 'pobecu' (Suggests) is the companion package with the official population
  of Ecuador by canton; it is used only in one vignette to compute rates.
  It will be submitted to CRAN before 'fhirviews', which will only be
  submitted once 'pobecu' is available there. Its use is conditional
  (`requireNamespace()`): the vignette chunks are not evaluated when it is
  not installed.

* Bundled third-party code and data (listed in `inst/COPYRIGHTS`, with the
  copyright holders also in `Authors@R`):
  - `inst/js/fhirpath/`: the browser build of 'fhirpath.js' 5.2.2
    (<https://github.com/HL7/fhirpath.js>), unmodified, under a BSD-style
    license from the U.S. National Library of Medicine and Health Samurai.
    It bundles 'ucum-lhc' (NLM, BSD-style; includes the UCUM table under the
    UCUM license <https://ucum.org/license>), 'antlr4' (BSD-3), 'date-fns',
    'decimal.js', 'url-join', 'is-finite' (MIT) and 'is-integer' (ISC).
    It is evaluated with the 'V8' package. The minified file contains 0x1A
    bytes inside the ANTLR parser tables, so it is read in binary mode.
  - `inst/sof-tests/`: the official SQL on FHIR conformance test suite
    (<https://github.com/FHIR/sql-on-fhir.js>, MIT), unmodified, used by
    `vista_conformidad()` and the package tests.

* Optional features use packages in Suggests, always checked with
  `rlang::check_installed()` or `requireNamespace()`: 'duckdb' and 'DBI'
  (views as 'DuckDB' tables and the experimental 'DuckDB' SQL engine),
  'jose' and 'openssl' ('SMART on FHIR' Backend Services, signing a JWT with
  the user's private key), 'httpuv' (interactive 'OAuth2' login),
  'rstudioapi' (addins), and 'dplyr' and 'dbplyr' (lazy 'DuckDB' results with
  `diferido = TRUE`). Tests and vignette chunks that need them are skipped
  when they are not installed.

* Authentication tokens are kept in memory only (on disk only if the user
  asks for it explicitly with `cache_disco = TRUE`, through 'httr2'), are never
  printed and are only sent to the URL of the connected FHIR server.

* Terminology functions (`tx_*`) talk to a FHIR terminology server chosen by
  the user; their examples use <https://tx.fhir.org/r4> and are wrapped in
  `@examplesIf fhir_disponible(...)` as below.

* Examples that need a FHIR server are wrapped in
  `@examplesIf fhir_disponible(...)`, which checks quickly whether the public
  test server <https://hapi.fhir.org/baseR4> responds, so they are skipped
  without internet access. Examples that write to a server only run
  interactively against a local server. Tests that use the network are
  skipped on CRAN; all client tests use mocked HTTP responses.

* The package does not write to the user's home directory: DuckDB
  connections created by `vista_duckdb()` use `shared_home = FALSE`.

* The documentation is in Spanish (`Language: es`) because the package is
  aimed at users in Ecuador and Latin America; the Title and Description are
  in English.
