\name{h_relocate}
\alias{h_relocate}
\title{H2O relocate}
\description{Row data remain in H2O. Base R handles expressions, column names, configuration and remote object handles. H2O may return schema metadata or scalar reductions to the client; no local table transformation is performed.}
\usage{
h_relocate(.data, ..., .before = NULL, .after = NULL)
}
\arguments{
\item{.data}{An h2o_tbl. Its frame remains on the H2O cluster.}
\item{...}{Column selections, named expressions, remote tables or conditions, as appropriate to the verb. See the example and details.}
\item{.before}{Column selection before which the selected columns are moved.}
\item{.after}{Column selection after which the selected columns are moved.}
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
      stopifnot(names(as_h2o(h_relocate(x, y, .before = id)))[1] == "y")
  }
}
}
