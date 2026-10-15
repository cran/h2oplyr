library(h2oplyr)
ns <- asNamespace('h2oplyr')
# Scan parsed function calls, not comments. Forbid local table backends and
# unexported H2O entry points in the package's implementation.
forbidden <- c('as.data.frame','data.frame','as.vector','as.matrix','as.h2o',
               'read.csv','read.table','merge','aggregate','split','set.seed')
inspect <- function(e) {
  if(missing(e)) return(invisible(NULL))
  if(!is.call(e)) return(invisible(NULL))
  h <- e[[1L]]
  if(is.symbol(h)) stopifnot(!as.character(h) %in% forbidden,as.character(h)!=':::')
  if(is.call(h)&&identical(h[[1L]],as.name('::'))) {
    stopifnot(as.character(h[[2L]])=='h2o',!as.character(h[[3L]]) %in% forbidden)
  }
  for(i in seq.int(2L,length(e))) if(length(e)>1L) inspect(e[[i]])
  invisible(NULL)
}
for(nm in ls(ns,all.names=TRUE)) {
  f <- get(nm,ns)
  if(is.function(f)) inspect(body(f))
}
stopifnot(inherits(try(h2o_tbl(list()),silent=TRUE),'try-error'))
stopifnot(inherits(everything(),'h2o_selection'))
stopifnot(inherits(where(is.numeric),'h2o_selection'))
cat('Static backend audit passed.\n')
