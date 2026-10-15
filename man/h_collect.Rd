\name{h_collect}
\alias{h_collect}
\title{Return the remote frame without downloading}
\description{Row data remain in H2O. Base R handles expressions, column names, configuration and remote object handles. H2O may return schema metadata or scalar reductions to the client; no local table transformation is performed. This intentionally differs from the standalone prototype: it returns an H2OFrame, never a local table.}
\usage{
h_collect(.data)
}
\arguments{
\item{.data}{An h2o_tbl. Its frame remains on the H2O cluster.}
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
      stopifnot(inherits(h_collect(x), "H2OFrame"))
  }
}
}
