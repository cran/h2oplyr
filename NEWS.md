# h2oplyr 0.3.0

- Support grouped h_mutate() with h_group_by() or per-call .by for direct
  h_lag(), h_lead(), h_roll_mean(), h_min_rank() and h_row_number() calls.
- Preserve input row order, isolate each group, and support multiple grouping
  keys and missing keys. Keep existing groups; .by grouping is temporary.
- Add right-aligned h_roll_mean() with explicit partial-window and NA policies,
  numeric h_min_rank() with minimum ranks for ties and desc() support, and
  the zero-argument mutation helper h_row_number().
- Reject unsupported grouped expressions and overwriting grouping keys.
  Grouped cumulative operations, grouped across/transmute, and optimized
  large-window algorithms are not part of this release.
- Add independent synthetic reference cases, boundary regressions, examples
  for all 76 exports, and an English vignette section with visible grouped
  window results and an executable transaction-shaped workflow.
- Keep all row transformations on H2O, without new runtime dependencies.

# h2oplyr 0.2.6

- Remove the internal numeric seed assignment from h_slice_sample(). With
  seed = NULL, call h2o.runif() without a seed argument; only forward seeds
  explicitly supplied by the caller, with or without replacement.
- Document optional seeds and test unseeded sampling and explicit-seed
  reproducibility in both sampling modes.

# h2oplyr 0.2.5

- Display a period after section numbers in vignette headings and contents.

# h2oplyr 0.2.4

- Add “à la dplyr” to the vignette title and index entry.
- Separate and highlight the workflow in its own colored box.
- Use the same blue styling for all eight Takeaway boxes.

# h2oplyr 0.2.3

- Add bounded H2O value previews and explicit, visible tutorial assertions.
- Improve vignette typography, tables, navigation and explanatory callouts
  with embedded CSS, without new runtime dependencies or external assets.
- Document scalar retrieval for display and distinguish server-free rebuilds.

# h2oplyr 0.2.2

- Render the species summary in the English vignette as a single formatted
  table, without interleaving Markdown output with the printing code.
- Preserve the H2O calculations and all package functions unchanged.

# h2oplyr 0.2.1

- Remove namespace instrumentation from distributed tests to comply with CRAN
  policy. Integration tests now compare H2O function bindings without mutation.
- Preserve all 73 asserted examples and semantic regression tests.
- Keep runtime download interception in separate maintainer tools that are not
  included in the source package.

# h2oplyr 0.2.0

* First modular R package release, replacing the standalone prototype.
* H2O is the only non-base runtime dependency; no local table fallback.
* Closed remote expression interpreter and metadata-based selectors.
* Remote summaries, including median and n_distinct; .by and .add support.
* Remote full joins, relationship validation, semi and anti joins.
* Correct missing comparisons, multiple sort keys, ties and zero-row slices.
* Remote exact-size sampling, including replacement; remote lag and lead.
* Remote text concatenation, reshaping and missing-value filling.
* Intentional migration changes: h2o_tbl requires H2OFrame; h_collect returns
  H2OFrame; h_nest_by returns remote keys and a list of remote handles.
* Unsupported grouped operations and arbitrary R callbacks fail explicitly.
* Every export has an asserted example; English penguins vignette and tests.
