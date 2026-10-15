h_filter <- function(.data, ...) {
  .data <- .tbl(.data)
  for (e in as.list(substitute(list(...)))[-1L]) {
    mask <- .column(.eval_h2o(e,.data$frame,parent.frame()),.data$frame)
    .data$frame <- .data$frame[h2o::h2o.ifelse(is.na(mask),0,mask), ]
  }
  .data
}
h_filter_out <- function(.data, ...) {
  .data <- .tbl(.data)
  exprs <- as.list(substitute(list(...)))[-1L]
  if (!length(exprs)) return(.data)
  masks <- lapply(exprs,.eval_h2o,f=.data$frame,env=parent.frame())
  mask <- Reduce(`&`,masks)
  .data$frame <- .data$frame[h2o::h2o.ifelse(is.na(mask),0,!mask), ]
  .data
}
when_any <- function(...) {
  x <- list(...); if(!length(x)) stop("At least one condition is required.")
  Reduce(`|`,x)
}
when_all <- function(...) {
  x <- list(...); if(!length(x)) stop("At least one condition is required.")
  Reduce(`&`,x)
}
h_mutate <- function(.data, ...) {
  .data <- .tbl(.data)
  .no_groups(.data,"h_mutate")
  dots <- as.list(substitute(list(...)))[-1L]
  for (i in seq_along(dots)) {
    e <- dots[[i]]
    if (is.call(e) && identical(e[[1L]],as.name("h_across"))) {
      specs <- .across_specs(e,.data$frame,parent.frame())
      for (sp in specs) .data$frame[[sp$name]] <- .column(.apply_remote(sp$fn,.data$frame[[sp$col]],parent.frame()),.data$frame)
    } else {
      nm <- names(dots)[i]
      if (is.null(nm) || is.na(nm) || !nzchar(nm)) stop("Mutation expressions must be named.")
      val <- .eval_h2o(e,.data$frame,parent.frame())
      if (is.null(val)) {
        if (nm %in% names(.data$frame)) .data$frame <- .data$frame[,setdiff(names(.data$frame),nm)]
      } else .data$frame[[nm]] <- .column(val,.data$frame)
    }
  }
  .data
}
h_transmute <- function(.data, ...) {
  dots <- as.list(substitute(list(...)))[-1L]
  .named(dots)
  out <- eval(substitute(h_mutate(.data,...)),parent.frame())
  out$frame <- out$frame[,names(dots)]
  out
}
desc <- function(x) x
.sort <- function(f, cols, descending = rep(FALSE,length(cols)), na_last = TRUE) {
  if (!length(cols)) return(f)
  .cols_exist(f,cols)
  original <- names(f); ord <- list()
  # Safe temporary names also avoid h2o.arrange's parsing of names containing 'desc'.
  for (i in seq_along(cols)) {
    miss <- .tmp(f,".hp_na"); f[[miss]] <- is.na(f[[cols[i]]])
    key <- .tmp(f,".hp_key"); f[[key]] <- f[[cols[i]]]
    ord <- c(ord,list(if(na_last) as.name(miss) else call("desc",as.name(miss))),
             list(if(descending[i]) call("desc",as.name(key)) else as.name(key)))
  }
  cl <- as.call(c(list(quote(h2o::h2o.arrange),quote(f)),ord))
  eval(cl)[,original]
}
h_arrange <- function(.data, ..., na_last = TRUE) {
  .data <- .tbl(.data)
  dots <- as.list(substitute(list(...)))[-1L]
  down <- vapply(dots,function(e) is.call(e) && identical(e[[1L]],as.name("desc")),logical(1))
  cols <- vapply(seq_along(dots),function(i) as.character(if(down[i]) dots[[i]][[2L]] else dots[[i]]),character(1))
  .data$frame <- .sort(.data$frame,cols,down,na_last)
  .data
}
h_distinct <- function(.data, ..., .keep_all = FALSE) {
  .data <- .tbl(.data)
  dots <- as.list(substitute(list(...)))[-1L]
  cols <- if(length(dots)) .selections(.data$frame,dots,parent.frame()) else names(.data$frame)
  cols <- union(.data$groups,cols)
  if(!length(cols)) stop("Select at least one column.")
  f <- .factor_keys(.data$frame,cols)
  .data$frame <- h2o::h2o.drop_duplicates(f,cols,keep="first")
  if(!.keep_all) .data$frame <- .data$frame[,cols]
  .data
}
h_bind_rows <- function(...) {
  xs <- lapply(list(...),as_h2o)
  if(!length(xs)) stop("At least one frame is required.")
  nm <- names(xs[[1L]])
  if(any(!vapply(xs,function(x) setequal(names(x),nm),logical(1)))) stop("h_bind_rows requires identical column names.")
  h2o_tbl(Reduce(h2o::h2o.rbind,lapply(xs,function(x) x[,nm])))
}
h_bind_cols <- function(...) {
  xs <- lapply(list(...),as_h2o)
  if(!length(xs)) stop("At least one frame is required.")
  if(length(unique(vapply(xs,nrow,numeric(1))))!=1) stop("Row counts must match.")
  .valid_names(unlist(lapply(xs,names),use.names=FALSE))
  h2o_tbl(Reduce(h2o::h2o.cbind,xs))
}
