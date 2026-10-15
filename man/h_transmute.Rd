\name{h_transmute}
\alias{h_transmute}
\title{H2O transmute}
\description{Row data remain in H2O. Base R handles expressions, column names, configuration and remote object handles. H2O may return schema metadata or scalar reductions to the client; no local table transformation is performed. Mutation is ungrouped. Named expressions are evaluated sequentially. The closed expression interpreter accepts arithmetic, comparisons, is.na, membership in literal vectors, supported H2O math/text conversions and h2oplyr vector helpers. Unknown functions and other package namespaces are rejected. One-argument across closures are interpreted, never executed over downloaded rows.}
\usage{
h_transmute(.data, ...)
}
\arguments{
\item{.data}{An h2o_tbl. Its frame remains on the H2O cluster.}
\item{...}{Column selections, named expressions, remote tables or conditions, as appropriate to the verb. See the example and details.}
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
      z <- h_transmute(x, kg = y/1000)
      cols(z, "kg")
      equal_sum(as_h2o(z), 0.21)
  }
}
}
