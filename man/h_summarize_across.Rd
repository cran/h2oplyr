\name{h_summarize_across}
\alias{h_summarize_across}
\title{H2O summarize across}
\description{Row data remain in H2O. Base R handles expressions, column names, configuration and remote object handles. H2O may return schema metadata or scalar reductions to the client; no local table transformation is performed. Supported reductions: mean, sum, min, max, sd, var, median, n() and n_distinct(). A reduction accepts one column and optional na.rm. Summary results are ungrouped. Empty-input summaries raise an error. Across summaries use the default na.rm = FALSE; drop missing rows explicitly when needed.}
\usage{
h_summarize_across(.data, .cols, .fns, .names = "{col}_{fn}")
}
\arguments{
\item{.data}{An h2o_tbl. Its frame remains on the H2O cluster.}
\item{.cols}{A column selection or character vector of column names.}
\item{.fns}{A function or named list. Summary functions must be supported aggregates; mutation functions must have one argument and a supported expression body.}
\item{.names}{Output naming template using col and fn tokens enclosed in braces.}
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
      z <- h_summarize_across(h_group_by(x, grp), "y", list(mean = mean))
      equal_sum(as_h2o(z)[, "y_mean"], 105)
  }
}
}
