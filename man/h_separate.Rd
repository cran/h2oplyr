\name{h_separate}
\alias{h_separate}
\title{H2O separate}
\description{Row data remain in H2O. Base R handles expressions, column names, configuration and remote object handles. H2O may return schema metadata or scalar reductions to the client; no local table transformation is performed. H2O splits using a regular expression. The maximum number of split fields must equal length(into); shorter rows are padded by H2O. The source column is removed.}
\usage{
h_separate(.data, col, into, sep = "-")
}
\arguments{
\item{.data}{An h2o_tbl. Its frame remains on the H2O cluster.}
\item{col}{The source column for h_separate, or the new output name for h_unite.}
\item{into}{Names of split output columns.}
\item{sep}{Regular expression separator for h_separate; literal separator for h_unite (see its restrictions).}
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
      z <- h_separate(x, txt, c("letter", "number"))
      rows(z, 6)
      stopifnot(all(c("letter", "number") \%in\% names(as_h2o(z))))
  }
}
}
