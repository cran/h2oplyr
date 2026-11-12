\name{h_mutate}
\alias{h_mutate}
\title{Create or replace columns remotely}
\description{Row data remain in H2O. Base R handles expressions, column names, configuration and remote object handles. H2O may return schema metadata or scalar reductions to the client; no local table transformation is performed. General mutation is ungrouped. h_mutate additionally supports grouped window calls through h_group_by or .by (see below). Named expressions are evaluated sequentially. The closed expression interpreter accepts arithmetic, comparisons, is.na, membership in literal vectors, supported H2O math/text conversions and h2oplyr vector helpers. Unknown functions and other package namespaces are rejected. One-argument across closures are interpreted, never executed over downloaded rows. Within grouped h_mutate, each expression must be a direct h_lag, h_lead, h_roll_mean, h_min_rank or h_row_number call. Window inputs must be column names (or desc(column) for h_min_rank). Group keys cannot be overwritten. Missing grouping keys form groups. Windows follow the input order within each group; output rows retain the original input order. Arrange by a complete ordering key first for reproducible windows. Other grouped expressions, including cumulative helpers, are rejected. h_transmute and h_mutate_across remain ungrouped.}
\usage{
h_mutate(.data, ..., .by = NULL)
}
\arguments{
\item{.data}{An h2o_tbl. Its frame remains on the H2O cluster.}
\item{...}{Column selections, named expressions, remote tables or conditions, as appropriate to the verb. See the example and details.}
\item{.by}{Per-call grouping selection on ungrouped input. Grouping does not persist in the result.}
}
\value{An h2o_tbl holding a remote H2OFrame; inspection helpers return it invisibly.}
\examples{
# Connect explicitly before running these examples:
# h2o::h2o.init(nthreads = 2, max_mem_size = "2G")
if (h2o_available()) {
  x <- h2o_tbl(h2o::h2o.uploadFile(
    system.file("extdata", "toy.csv", package = "h2oplyr"),
    col.types = c("numeric", "enum", "numeric", "numeric",
                  "string", "numeric", "numeric")))
  p <- h_penguins()
  v <- as_h2o(x)[, "y"]
  rows <- function(z, n) stopifnot(nrow(as_h2o(z)) == n)
  cols <- function(z, nm) stopifnot(identical(names(as_h2o(z)), nm))
  equal_sum <- function(z, value) stopifnot(isTRUE(all.equal(
    h2o::h2o.sum(z, na.rm = TRUE), value, check.attributes = FALSE)))
  {
      z <- h_mutate(x, double = y * 2, next_value = double + 1)
      equal_sum(as_h2o(z)[, "next_value"], 426)
  }
}
}
