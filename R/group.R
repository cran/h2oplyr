.factor_keys <- function(f,cols) {
  for(nm in cols) if(h2o::h2o.ischaracter(f[[nm]])) f[[nm]] <- h2o::h2o.asfactor(f[[nm]])
  f
}
h_group_by <- function(.data, ..., .add = FALSE) {
  .data <- .tbl(.data)
  dots <- as.list(substitute(list(...)))[-1L]
  if(length(names(dots)) && any(nzchar(names(dots)))) stop("Renaming in h_group_by is not supported; use h_rename.")
  cols <- .selections(.data$frame,dots,parent.frame())
  .data$groups <- if(.add) union(.data$groups,cols) else cols
  .data
}
h_ungroup <- function(.data) { .data <- .tbl(.data); .data$groups <- character(); .data }
h_group_vars <- function(.data) .tbl(.data)$groups
.group_spec <- function(.data, by, env) {
  if(is.null(by)) return(.data$groups)
  if(length(.data$groups)) stop("Use .by on ungrouped input only.")
  .selection(.data$frame,by,env)
}
.agg_parse <- function(e,env) {
  if(!is.call(e)) stop("Use a supported aggregation call.")
  fn <- as.character(e[[1L]])
  if(fn=="n" && length(e)==1L) return(list(fn="nrow",col=NULL,na=TRUE))
  if(!fn %in% c("mean","sum","min","max","sd","var","median","n_distinct")) stop("Unsupported aggregation: ",fn)
  if(length(e)<2L || !(is.symbol(e[[2L]]) || is.character(e[[2L]]))) stop("Aggregate a column name; create transformed columns first.")
  extra <- as.list(e)[-(1:2)]
  if(length(extra) && (is.null(names(extra)) || any(names(extra)!="na.rm"))) stop("Only na.rm is supported after the column argument.")
  na <- if(length(extra)) eval(extra[[1L]],env) else FALSE
  if(!is.logical(na) || length(na)!=1 || is.na(na)) stop("na.rm must be TRUE or FALSE.")
  list(fn=fn,col=as.character(e[[2L]]),na=na)
}
.aggregate <- function(f,groups,aggs,out_names) {
  if(!length(aggs)) stop("At least one summary is required.")
  .valid_names(c(groups,out_names))
  f <- .factor_keys(f,groups)
  special <- vapply(aggs,function(a) a$fn=="n_distinct",logical(1))
  if(any(special)) {
    regular <- which(!special)
    out <- if(length(regular)) .aggregate(f,groups,aggs[regular],out_names[regular]) else if(length(groups)) h2o::h2o.drop_duplicates(f[,groups],groups) else NULL
    for(i in which(special)) {
      a <- aggs[[i]]; .cols_exist(f,a$col)
      keys <- union(groups,a$col)
      u <- h2o::h2o.drop_duplicates(.factor_keys(f[,keys],a$col),keys)
      marker <- .tmp(u,".hp_unique"); u[[marker]] <- if(a$na) !is.na(u[[a$col]]) else .const(1,nrow(u))
      one <- .aggregate(u,groups,list(list(fn="sum",col=marker,na=TRUE)),out_names[i])
      out <- if(is.null(out)) one else if(length(groups)) h2o::h2o.merge(out,one,by=groups,all.x=TRUE) else h2o::h2o.cbind(out,one)
    }
    return(out[,c(groups,out_names)])
  }
  synthetic <- !length(groups)
  if(synthetic) {
    key <- .tmp(f,".hp_global"); f[[key]] <- .const(1,nrow(f)); groups <- key
  }
  if(nrow(f)==0L) stop("Summaries of empty frames are not supported by this H2O adapter.")
  # Give each aggregation a private source column. H2O may sort aggregation
  # names internally; output names are recovered explicitly rather than by position.
  calls <- list(); sources <- character(); modes <- character()
  for(i in seq_along(aggs)) {
    a <- aggs[[i]]
    if(!is.null(a$col)) .cols_exist(f,a$col)
    src <- .tmp(f,".hp_value")
    f[[src]] <- if(a$fn=="nrow") .const(1,nrow(f)) else f[[a$col]]
    if(a$fn=="n_distinct" && h2o::h2o.ischaracter(f[[src]])) f[[src]] <- h2o::h2o.asfactor(f[[src]])
    fn <- switch(a$fn,n_distinct="count_unique",nrow="sum",a$fn)
    calls[[i]] <- call(fn,match(src,names(f)))
    sources[i] <- paste0(if(fn=="sd") "sdev" else fn,"_",src)
    modes[i] <- if(a$na) "rm" else "all"
  }
  cl <- as.call(c(list(quote(h2o::h2o.group_by),quote(f),by=groups),calls,
                  list(gb.control=list(na.methods=modes))))
  out <- eval(cl)
  actual <- setdiff(names(out),groups)
  # Public group_by emits operation_source names; enforce correspondence.
  if(!all(sources %in% actual)) stop("Unexpected H2O aggregation schema: ",paste(actual,collapse=", "))
  out <- out[,c(groups,sources)]
  names(out) <- c(groups,out_names)
  if(synthetic) out <- out[,out_names]
  out
}
h_summarize <- function(.data, ..., .by = NULL) {
  .data <- .tbl(.data)
  groups <- .group_spec(.data,substitute(.by),parent.frame())
  dots <- as.list(substitute(list(...)))[-1L]
  aggs <- list(); nm <- character()
  for(i in seq_along(dots)) {
    e <- dots[[i]]
    if(is.call(e) && identical(e[[1L]],as.name("h_across"))) {
      specs <- .across_specs(e,.data$frame,parent.frame())
      for(sp in specs) {
        fn <- .agg_function(sp$fn)
        aggs[[length(aggs)+1L]] <- list(fn=fn,col=sp$col,na=FALSE)
        nm <- c(nm,sp$name)
      }
    } else {
      name <- names(dots)[i]
      if(is.null(name)||is.na(name)||!nzchar(name)) stop("Name every summary.")
      aggs[[length(aggs)+1L]] <- .agg_parse(e,parent.frame()); nm <- c(nm,name)
    }
  }
  h2o_tbl(.aggregate(.data$frame,groups,aggs,nm))
}
h_summarise <- h_summarize
h_count <- function(.data, ..., wt = NULL, sort = FALSE, name = "n", by = NULL) {
  .data <- .tbl(.data)
  dots <- as.list(substitute(list(...)))[-1L]
  groups <- union(.data$groups,.selections(.data$frame,dots,parent.frame()))
  if(!is.null(substitute(by))) groups <- union(groups,.selection(.data$frame,substitute(by),parent.frame()))
  w <- substitute(wt)
  agg <- if(is.null(w)) list(fn="nrow",col=NULL,na=TRUE) else list(fn="sum",col=as.character(w),na=TRUE)
  out <- h2o_tbl(.aggregate(.data$frame,groups,list(agg),name))
  if(sort) out$frame <- .sort(out$frame,name,TRUE)
  out
}
h_group_keys <- function(.data) {
  .data <- .tbl(.data)
  if(!length(.data$groups)) return(h2o_tbl(.const(nrow(.data$frame),1)))
  f <- .factor_keys(.data$frame,.data$groups)
  h2o_tbl(h2o::h2o.drop_duplicates(f[,.data$groups],.data$groups))
}
h_nest_by <- function(.data, ...) {
  grouped <- eval(substitute(h_group_by(.data,...)),parent.frame())
  keys <- h_group_keys(grouped)
  if(!length(grouped$groups)) return(list(keys=keys,data=list(h_ungroup(.data))))
  f <- .factor_keys(.data$frame,grouped$groups)
  # A local list of remote handles, not a local list-column of observations.
  pieces <- lapply(seq_len(nrow(keys$frame)),function(i) h2o_tbl(h2o::h2o.merge(f,keys$frame[i,],by=grouped$groups)))
  list(keys=keys,data=pieces)
}
h_across <- function(.cols, .fns, .names = "{col}_{fn}") {
  structure(list(cols=substitute(.cols),fns=.fns,names=.names),class="h2o_across")
}
.across_specs <- function(e,f,env) {
  cols <- .selection(f,e[[2L]],env)
  fns <- eval(e[[3L]],env)
  if(is.function(fns)) fns <- list(fn=fns)
  if(!is.list(fns)||!length(fns)||!all(vapply(fns,is.function,logical(1)))) stop(".fns must be a function or named list of functions.")
  if(is.null(names(fns))) names(fns) <- paste0("fn",seq_along(fns))
  .valid_names(names(fns))
  template <- if(length(e)>=4L) eval(e[[4L]],env) else "{col}_{fn}"
  out <- list()
  for(col in cols) for(nm in names(fns)) out[[length(out)+1L]] <- list(col=col,fn=fns[[nm]],name=gsub("{col}",col,gsub("{fn}",nm,template,fixed=TRUE),fixed=TRUE))
  .valid_names(vapply(out,`[[`,character(1),"name"))
  out
}
.agg_function <- function(fn) {
  names <- c("mean","sum","min","max","sd","var","median")
  for(nm in names) {
    ref <- if(nm %in% c("sd","var","median")) getExportedValue("stats",nm) else get(nm,baseenv())
    if(identical(fn,ref) || identical(fn,getExportedValue("h2o",paste0("h2o.",nm)))) return(nm)
  }
  stop("Summary across supports mean, sum, min, max, sd, var and median functions.")
}
.apply_remote <- function(fn,x,env) {
  if(is.primitive(fn)) {
    if(identical(fn,base::abs)) return(h2o::h2o.abs(x))
    if(identical(fn,base::sqrt)) return(h2o::h2o.sqrt(x))
    stop("Use a one-argument function with supported H2O expressions.")
  }
  params <- names(formals(fn))
  if(length(params)!=1L) stop("Across mutation functions must have one argument.")
  # Interpret the body, rather than execute arbitrary closures over data.
  .eval_h2o(body(fn),x,environment(fn),bindings=structure(list(x),names=params))
}
h_mutate_across <- function(.data, .cols, .fns, .names = "{col}_{fn}") {
  cl <- substitute(h_mutate(.data,h_across(.cols,.fns,.names)))
  eval(cl,parent.frame())
}
h_summarize_across <- function(.data, .cols, .fns, .names = "{col}_{fn}") {
  cl <- substitute(h_summarize(.data,h_across(.cols,.fns,.names)))
  eval(cl,parent.frame())
}
