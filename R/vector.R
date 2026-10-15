h_if_else <- function(condition, true_val, false_val, missing = NA) {
  if(!inherits(condition,"H2OFrame")) stop("condition must be an H2O column.")
  out <- h2o::h2o.ifelse(condition,true_val,false_val)
  if(length(missing)==1L && !inherits(missing,"H2OFrame") && is.na(missing)) {
    out[is.na(condition),1L] <- NA
    out
  } else h2o::h2o.ifelse(is.na(condition),missing,out)
}
h_between <- function(x,left,right) { as_h2o(x) >= left & as_h2o(x) <= right }
h_coalesce <- function(...) {
  xs <- list(...)
  if(!length(xs) || !inherits(xs[[1L]],"H2OFrame")) stop("The first argument must be an H2O column.")
  out <- xs[[1L]]
  for(x in xs[-1L]) out <- h2o::h2o.ifelse(is.na(out),x,out)
  out
}
h_case_when <- function(..., .default = NA) {
  clauses <- as.list(substitute(list(...)))[-1L]
  env <- parent.frame()
  values <- lapply(clauses,function(z) {
    if(!is.call(z)||!identical(z[[1L]],as.name("~"))) stop("Use condition ~ value.")
    list(cond=.eval_h2o(z[[2L]],NULL,env),value=.eval_h2o(z[[3L]],NULL,env))
  })
  out <- .default
  for(z in rev(values)) {
    if(isTRUE(z$cond)) out <- z$value
    else out <- h2o::h2o.ifelse(h2o::h2o.ifelse(is.na(z$cond),0,z$cond),z$value,out)
  }
  out
}
h_replace_na <- function(x,replace) {
  if(inherits(x,"h2o_tbl")) {
    if(!is.list(replace)) stop("For a table use a named list of replacements.")
    .named(replace); .cols_exist(x$frame,names(replace))
    for(nm in names(replace)) x$frame[[nm]] <- h_coalesce(x$frame[[nm]],replace[[nm]])
    return(x)
  }
  h_coalesce(as_h2o(x),replace)
}
h_replace_na_cols <- function(.data,replace,...) {
  .data <- .tbl(.data)
  cols <- .selections(.data$frame,as.list(substitute(list(...)))[-1L],parent.frame())
  for(nm in cols) .data$frame[[nm]] <- h_coalesce(.data$frame[[nm]],replace)
  .data
}
h_drop_na <- function(.data,...) {
  .data <- .tbl(.data)
  dots <- as.list(substitute(list(...)))[-1L]
  cols <- if(length(dots)) .selections(.data$frame,dots,parent.frame()) else names(.data$frame)
  if(!length(cols)) return(.data)
  mask <- Reduce(`&`,lapply(cols,function(nm) !is.na(.data$frame[[nm]])))
  .data$frame <- .data$frame[mask,]
  .data
}
h_na_if <- function(x,y) h2o::h2o.ifelse(as_h2o(x)==y,NA,as_h2o(x))
.shift <- function(x,n,default,lead) {
  x <- as_h2o(x); .count_arg(n)
  if(ncol(x)!=1L) stop("Use one H2O column.")
  total <- nrow(x)
  if(n==0||total==0) return(x)
  n <- min(n,total)
  pad <- x[seq_len(n),]
  pad[,1L] <- default
  names(pad) <- names(x)
  if(n==total) return(pad)
  keep <- if(lead) x[seq.int(n+1,total),] else x[seq_len(total-n),]
  if(lead) h2o::h2o.rbind(keep,pad) else h2o::h2o.rbind(pad,keep)
}
h_lag <- function(x,n=1,default=NA) .shift(x,n,default,FALSE)
h_lead <- function(x,n=1,default=NA) .shift(x,n,default,TRUE)
h_cumsum <- function(x) h2o::h2o.cumsum(as_h2o(x))
h_cummax <- function(x) h2o::h2o.cummax(as_h2o(x))
h_cummin <- function(x) h2o::h2o.cummin(as_h2o(x))
h_fill <- function(.data,...,.direction=c("down","up")) {
  .data <- .tbl(.data); .no_groups(.data,"h_fill")
  direction <- match.arg(.direction)
  cols <- .selections(.data$frame,as.list(substitute(list(...)))[-1L],parent.frame())
  for(nm in cols) .data$frame[[nm]] <- h2o::h2o.fillna(.data$frame[[nm]],method=if(direction=="down") "forward" else "backward",axis=2,maxlen=as.integer(nrow(.data$frame)))
  .data
}
