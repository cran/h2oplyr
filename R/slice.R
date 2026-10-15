h_slice_head <- function(.data,n=6) {
  .data <- .tbl(.data); .no_groups(.data,"h_slice_head"); .count_arg(n)
  .data$frame <- if(n==0 || nrow(.data$frame)==0) .empty(.data$frame) else .data$frame[seq_len(min(n,nrow(.data$frame))),]
  .data
}
h_slice_tail <- function(.data,n=6) {
  .data <- .tbl(.data); .no_groups(.data,"h_slice_tail"); .count_arg(n)
  total <- nrow(.data$frame); n <- min(n,total)
  .data$frame <- if(n) .data$frame[seq.int(total-n+1,total),] else .empty(.data$frame)
  .data
}
h_slice_sample <- function(.data,n=NULL,prop=NULL,replace=FALSE,seed=NULL) {
  .data <- .tbl(.data); .no_groups(.data,"h_slice_sample")
  if(!is.null(n)&&!is.null(prop)) stop("Supply n or prop, not both.")
  total <- nrow(.data$frame)
  if(!is.null(prop)) {
    if(length(prop)!=1L||is.na(prop)||!is.finite(prop)||prop<0) stop("prop must be finite and nonnegative.")
    n <- floor(total*prop)
  }
  if(is.null(n)) n <- 1L
  .count_arg(n)
  if(!replace && n>total) n <- total
  if(!n) return(h_slice_head(.data,0))
  if(!total) stop("Cannot sample a nonzero number of rows from an empty frame.")
  f <- .data$frame
  if(!replace) {
    # Let H2O choose its random seed unless the caller supplies one.
    nm <- .tmp(f,".hp_random")
    f[[nm]] <- if(is.null(seed)) h2o::h2o.runif(f) else h2o::h2o.runif(f,seed=seed)
    f <- .sort(f,nm)[seq_len(n),names(.data$frame)]
  } else {
    key <- .tmp(f,".hp_row"); f[[key]] <- h2o::h2o.cumsum(.const(1,total))
    draws <- .const(1,n)
    random <- if(is.null(seed)) h2o::h2o.runif(draws) else h2o::h2o.runif(draws,seed=seed)
    draws[[key]] <- h2o::h2o.floor(random*total)+1
    order <- .tmp(f,".hp_draw"); draws[[order]] <- h2o::h2o.cumsum(.const(1,n))
    f <- h2o::h2o.merge(draws[,c(key,order)],f,by=key)
    f <- .sort(f,order)[,names(.data$frame)]
  }
  .data$frame <- f; .data
}
.slice_extreme <- function(.data,col,n,with_ties,down) {
  .data <- .tbl(.data); .no_groups(.data,"h_slice_min/max"); .count_arg(n)
  f <- .data$frame; .cols_exist(f,col)
  f <- f[!is.na(f[[col]]),]
  n <- min(n,nrow(f))
  if(!n) { .data$frame <- .empty(f); return(.data) }
  f <- .sort(f,col,down)
  if(with_ties && n<nrow(f)) {
    # A scalar reduction is executed in H2O; the threshold frame stays remote
    # and is broadcast by a keyed join, avoiding a row download.
    key <- .tmp(f,".hp_constant"); f[[key]] <- .const(1,nrow(f))
    threshold <- f[n,c(key,col)]; cutoff <- .tmp(f,".hp_cutoff")
    names(threshold) <- c(key,cutoff)
    joined <- h2o::h2o.merge(f,threshold,by=key)
    keep <- if(down) joined[[col]]>=joined[[cutoff]] else joined[[col]]<=joined[[cutoff]]
    f <- .sort(joined[keep,names(.data$frame)],col,down)
  } else f <- f[seq_len(n),]
  .data$frame <- f; .data
}
h_slice_min <- function(.data,order_by,n=1,with_ties=TRUE) .slice_extreme(.data,as.character(substitute(order_by)),n,with_ties,FALSE)
h_slice_max <- function(.data,order_by,n=1,with_ties=TRUE) .slice_extreme(.data,as.character(substitute(order_by)),n,with_ties,TRUE)
