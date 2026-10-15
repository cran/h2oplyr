\name{h2o_tbl}
\alias{h2o_tbl}
\title{Wrap an existing remote H2O frame}
\description{Row data remain in H2O. Base R handles expressions, column names, configuration and remote object handles. H2O may return schema metadata or scalar reductions to the client; no local table transformation is performed.}
\usage{
h2o_tbl(x)
}
\arguments{
\item{x}{An H2OFrame, an h2o_tbl, or (for selection helpers) a character pattern or vector. Local tables are not accepted.}
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
      rows(h2o_tbl(as_h2o(x)), 6)
      stopifnot(all(dim(x) == c(6, 7)), nrow(x) == 6, ncol(x) == 7, identical(names(x), 
          names(as_h2o(x))))
  }
}
}
\alias{dim.h2o_tbl}
\alias{names.h2o_tbl}
\alias{print.h2o_tbl}
