\name{num_range}
\alias{num_range}
\title{H2O num range}
\description{Row data remain in H2O. Base R handles expressions, column names, configuration and remote object handles. H2O may return schema metadata or scalar reductions to the client; no local table transformation is performed.}
\usage{
num_range(prefix, range, width = NULL)
}
\arguments{
\item{prefix}{A column-name prefix.}
\item{range}{Numeric suffixes to match.}
\item{width}{Optional zero-padding width for num_range; retained metadata-display width for h_glimpse.}
}
\value{A column-selection specification containing metadata only.}
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
      cols(h_select(x, num_range("x", 1:2)), c("x1", "x2"))
  }
}
}
