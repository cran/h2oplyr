\name{h_between}
\alias{h_between}
\title{H2O between}
\description{Row data remain in H2O. Base R handles expressions, column names, configuration and remote object handles. H2O may return schema metadata or scalar reductions to the client; no local table transformation is performed.}
\usage{
h_between(x, left, right)
}
\arguments{
\item{x}{An H2OFrame, an h2o_tbl, or (for selection helpers) a character pattern or vector. Local tables are not accepted.}
\item{left}{Inclusive lower bound.}
\item{right}{Inclusive upper bound.}
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
      equal_sum(h_between(v, 20, 40), 3)
  }
}
}
