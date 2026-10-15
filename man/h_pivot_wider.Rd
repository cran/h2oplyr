\name{h_pivot_wider}
\alias{h_pivot_wider}
\title{Widen unique ID and name combinations}
\description{Row data remain in H2O. Base R handles expressions, column names, configuration and remote object handles. H2O may return schema metadata or scalar reductions to the client; no local table transformation is performed. Duplicate ID/name combinations and missing names are rejected; summarize first. Category levels are schema metadata. All output cells are formed by remote joins. values_fill replaces both absent combinations and existing missing cells. No list-columns or implicit aggregation are supported.}
\usage{
h_pivot_wider(.data, names_from, values_from, id_cols = NULL, values_fill = NULL)
}
\arguments{
\item{.data}{An h2o_tbl. Its frame remains on the H2O cluster.}
\item{names_from}{One column whose category domain becomes output column names.}
\item{values_from}{One column containing cell values.}
\item{id_cols}{ID column selection; defaults to all columns other than names_from and values_from.}
\item{values_fill}{Optional replacement for missing output cells.}
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
      long <- h_pivot_longer(h_select(x, id, x1, x2), c("x1", "x2"))
      wide <- h_pivot_wider(long, name, value)
      rows(wide, 6)
      equal_sum(as_h2o(wide)[, "x2"], 570)
  }
}
}
