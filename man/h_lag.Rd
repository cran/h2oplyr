\name{h_lag}
\alias{h_lag}
\title{H2O lag}
\description{Row data remain in H2O. Base R handles expressions, column names, configuration and remote object handles. H2O may return schema metadata or scalar reductions to the client; no local table transformation is performed. Within grouped h_mutate, each expression must be a direct h_lag, h_lead, h_roll_mean, h_min_rank or h_row_number call. Window inputs must be column names (or desc(column) for h_min_rank). Group keys cannot be overwritten. Missing grouping keys form groups. Windows follow the input order within each group; output rows retain the original input order. Arrange by a complete ordering key first for reproducible windows. Other grouped expressions, including cumulative helpers, are rejected. h_transmute and h_mutate_across remain ungrouped. Operations use current frame order. Arrange explicitly before windows. Grouped slicing and filling are rejected. Sampling is performed with H2O random columns; replacement uses a remote draw-index join.}
\usage{
h_lag(x, n = 1, default = NA)
}
\arguments{
\item{x}{An H2OFrame, an h2o_tbl, or (for selection helpers) a character pattern or vector. Local tables are not accepted.}
\item{n}{A nonnegative integer row count or shift distance.}
\item{default}{Padding value for lag or lead.}
}
\value{An H2OFrame expression (vector helpers return one column).}
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
      equal_sum(h_lag(v, default = 0), 150)
  }
}
}
