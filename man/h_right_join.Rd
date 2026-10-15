\name{h_right_join}
\alias{h_right_join}
\title{H2O right join}
\description{Row data remain in H2O. Base R handles expressions, column names, configuration and remote object handles. H2O may return schema metadata or scalar reductions to the client; no local table transformation is performed. Equijoins use H2O merge. Missing-key behavior follows H2O, not SQL NULL semantics. Output row order is unspecified; sort explicitly. Full joins combine a left join and unmatched right rows. Character keys are converted to categorical keys remotely. Suffix collisions and violated relationship constraints raise errors.}
\usage{
h_right_join(x, y, by = NULL, suffix = c(".x", ".y"), relationship = NULL)
}
\arguments{
\item{x}{An H2OFrame, an h2o_tbl, or (for selection helpers) a character pattern or vector. Local tables are not accepted.}
\item{y}{A second remote table for joins, or a scalar comparison value for h_na_if.}
\item{by}{Join column names; a named character vector maps left names to right names. For h_count, an optional grouping selection.}
\item{suffix}{Two suffixes for overlapping non-key column names.}
\item{relationship}{Optional one-to-one, one-to-many, many-to-one or many-to-many key constraint.}
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
      rows(h_right_join(h_slice_head(x, 3), h_slice_tail(x, 4), by = "id"), 4)
  }
}
}
