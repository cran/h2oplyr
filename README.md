# h2oplyr

Tidy-style data manipulation with **H2O as the only data backend**.
The only non-base runtime dependency is `h2o`. `knitr` and `rmarkdown` are optional
vignette-building dependencies. No dplyr, tidytable or data.table is used.

```r
# Install h2o first, then this package from its source archive.
install.packages("h2oplyr_0.2.6.tar.gz", repos = NULL, type = "source")
h2o::h2o.init(nthreads = 2, max_mem_size = "2G")
library(h2oplyr)
p <- h_penguins()
h_summarize(p, n = n(), mass = mean(body_mass_g, na.rm = TRUE), .by = species)
vignette("h2oplyr-penguins")
```

The matching H2O server and Java runtime are external system requirements.
This package never starts or shuts down a cluster automatically.

See the vignette for the supported expression language, examples and limits.
Help pages have independently executable examples for all 73 exports. Additional
asserted examples and regression tests are installed under `system.file("examples",
package = "h2oplyr")`.

## Migration from the standalone prototype

- `h2o_tbl()` requires an existing H2OFrame; upload local files with H2O first.
- `h_collect()` returns the H2OFrame; it does not collect rows locally.
- `h_nest_by()` returns remote keys and a list of remote handles.
- Unsupported grouped operations and arbitrary R functions fail explicitly.
- Grouping and join character keys are encoded as factors in H2O. Joins have
  unspecified order. Bind rows requires matching column-name sets.
- Pivots reject duplicate cells; aggregate first. Empty summaries are rejected.
- Selection helpers inspect names/types. They never inspect a local data sample.

## Tests

Start a matching H2O cluster explicitly on a local port, then set
`H2OPLYR_TEST_PORT` when running `R CMD check`. Without that variable, static tests
run and integration tests state that they were skipped. Live integration tests
verify that H2O namespace function bindings remain unchanged. Rebuilding vignettes against a live server can
be requested with `H2OPLYR_VIGNETTE_PORT`.

Copyright 2026 Carlos Ortega. Code: MIT. Included Palmer penguin data: CC0;
see `inst/extdata/PROVENANCE.md`.
