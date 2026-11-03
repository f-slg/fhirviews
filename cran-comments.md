## Submission

This is the first submission of 'fhirviews'.

## Test environments

* Local: Ubuntu Linux, R 4.5.2 (`R CMD check --as-cran`, with
  `_R_CHECK_CRAN_INCOMING_REMOTE_=true`)
* GitHub Actions: R release on Windows, macOS and Ubuntu

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Notes for the reviewers

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

* The 'DuckDB' engine needs the 'json' extension, which 'duckdb' downloads
  the first time it is used (`INSTALL json`). It is never downloaded during
  `R CMD check`: the examples that use it run only interactively, the tests
  are skipped on CRAN and the vignette chunks are not evaluated when
  `_R_CHECK_PACKAGE_NAME_` is set.

* Authentication tokens are kept in memory only (on disk only if the user
  asks for it explicitly with `cache_disco = TRUE`, through 'httr2'), are never
  printed and are only sent to the URL of the connected FHIR server.

* Examples that need a FHIR server (the public test servers
  <https://hapi.fhir.org/baseR4> and, for the terminology functions `tx_*`,
  <https://tx.fhir.org/r4>) only run in interactive sessions and when the
  server responds (`@examplesIf interactive() && fhir_disponible(...)`, also
  enabled on the pkgdown site), so `R CMD check` never depends on a public
  server. Examples that write to a server only run interactively against a
  local server. Tests that use the network are skipped on CRAN; all client
  tests use mocked HTTP responses.

* The package does not write to the user's home directory: DuckDB
  connections created by `vista_duckdb()` use `shared_home = FALSE`.

* The documentation is in Spanish (`Language: es`) because the package is
  aimed at users in Ecuador and Latin America; the Title and Description are
  in English.
