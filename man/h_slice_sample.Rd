\name{h_slice_sample}
\alias{h_slice_sample}
\title{H2O slice sample}
\description{Row data remain in H2O. Base R handles expressions, column names, configuration and remote object handles. H2O may return schema metadata or scalar reductions to the client; no local table transformation is performed. Operations use current frame order. Arrange explicitly before windows. Grouped slicing and filling are rejected. Sampling is performed with H2O random columns; replacement uses a remote draw-index join.}
\usage{
h_slice_sample(.data, n = NULL, prop = NULL, replace = FALSE, seed = NULL)
}
\arguments{
\item{.data}{An h2o_tbl. Its frame remains on the H2O cluster.}
\item{n}{A nonnegative integer row count or shift distance.}
\item{prop}{Sample fraction. Supply either n or prop.}
\item{replace}{For h_replace_na, a scalar or named list of replacements. For h_slice_sample, whether to sample with replacement.}
\item{seed}{Optional H2O random seed. With NULL (the default), h2o.runif() is called without a seed argument so H2O chooses the seed. A supplied seed is forwarded unchanged; reproducibility assumes the same cluster layout and input frame.}
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
      rows(h_slice_sample(x, n = 3, seed = 42), 3)
      rows(h_slice_sample(x, n = 9, replace = TRUE, seed = 42), 9)
  }
}
}
