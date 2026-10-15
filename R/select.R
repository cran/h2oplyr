# Selection functions create metadata specifications, never data tables.
everything <- function() structure(list(kind="everything"), class="h2o_selection")
starts_with <- function(x) structure(list(kind="starts_with", x=x), class="h2o_selection")
ends_with <- function(x) structure(list(kind="ends_with", x=x), class="h2o_selection")
contains <- function(x) structure(list(kind="contains", x=x), class="h2o_selection")
matches <- function(x) structure(list(kind="matches", x=x), class="h2o_selection")
any_of <- function(x) structure(list(kind="any_of", x=x), class="h2o_selection")
all_of <- function(x) structure(list(kind="all_of", x=x), class="h2o_selection")
last_col <- function(offset = 0) structure(list(kind="last_col", x=offset), class="h2o_selection")
num_range <- function(prefix, range, width = NULL) {
  all_of(paste0(prefix, if (is.null(width)) range else sprintf(paste0("%0", width, "d"), range)))
}
where <- function(predicate) {
  # Known predicates map to H2O schema types; no preview is converted to R.
  kind <- if (identical(predicate, base::is.numeric)) "numeric" else if (identical(predicate, base::is.character)) "string" else if (identical(predicate, base::is.factor)) "enum" else stop("where() supports base is.numeric, is.character and is.factor only.")
  structure(list(kind="where", x=kind), class="h2o_selection")
}
.selection <- function(f, e, env) {
  nm <- names(f)
  if (is.symbol(e) && as.character(e) %in% nm) return(as.character(e))
  if (is.call(e) && identical(e[[1L]], as.name(":"))) {
    ends <- vapply(as.list(e)[-1L], as.character, character(1))
    .cols_exist(f, ends)
    return(nm[seq.int(match(ends[1L], nm), match(ends[2L], nm))])
  }
  if (is.call(e) && identical(e[[1L]], as.name("c"))) return(unique(unlist(lapply(as.list(e)[-1L], function(z) .selection(f,z,env)), use.names=FALSE)))
  val <- eval(e, env)
  if (is.character(val)) return(.cols_exist(f, val))
  if (!inherits(val, "h2o_selection")) stop("Invalid column selection.")
  out <- switch(val$kind,
    everything=nm, starts_with=nm[startsWith(nm,val$x)], ends_with=nm[endsWith(nm,val$x)],
    contains=nm[grepl(val$x,nm,fixed=TRUE)], matches=nm[grepl(val$x,nm)],
    any_of=intersect(val$x,nm), all_of=.cols_exist(f,val$x),
    last_col={ .count_arg(val$x); i <- length(nm)-val$x; if(i<1) stop("last_col offset out of range."); nm[i] },
    where={ types <- .types(f); nm[if(val$x=="numeric") types %in% c("int","real") else types==val$x] })
  out
}
.selections <- function(f, dots, env) {
  out <- character()
  for (i in seq_along(dots)) {
    e <- dots[[i]]
    negative <- is.call(e) && identical(e[[1L]], as.name("-"))
    if (negative) {
      if (i==1L) out <- names(f)
      out <- setdiff(out,.selection(f,e[[2L]],env))
    } else out <- union(out,.selection(f,e,env))
  }
  out
}
h_select <- function(.data, ...) {
  .data <- .tbl(.data)
  cols <- .selections(.data$frame, as.list(substitute(list(...)))[-1L], parent.frame())
  cols <- union(.data$groups, cols)
  if (!length(cols)) stop("H2O frames require at least one selected column.")
  .data$frame <- .data$frame[, cols]
  .data
}
h_pick <- function(.data, ...) {
  eval(substitute(h_select(.data, ...)), parent.frame())
}
h_rename <- function(.data, ...) {
  .data <- .tbl(.data)
  dots <- as.list(substitute(list(...)))[-1L]
  .named(dots)
  old <- vapply(dots, as.character, character(1))
  .cols_exist(.data$frame,old)
  nm <- names(.data$frame)
  nm[match(old,nm)] <- names(dots)
  .valid_names(nm)
  g <- match(.data$groups,old)
  .data$groups[!is.na(g)] <- names(dots)[g[!is.na(g)]]
  names(.data$frame) <- nm
  .data
}
h_relocate <- function(.data, ..., .before = NULL, .after = NULL) {
  .data <- .tbl(.data)
  f <- .data$frame
  move <- .selections(f,as.list(substitute(list(...)))[-1L],parent.frame())
  before <- substitute(.before); after <- substitute(.after)
  if (!is.null(before) && !is.null(after)) stop("Use only one of .before and .after.")
  rest <- setdiff(names(f),move)
  target <- if (!is.null(before)) .selection(f,before,parent.frame()) else if (!is.null(after)) .selection(f,after,parent.frame()) else character()
  target <- intersect(target,rest)
  pos <- if (!length(target)) 0L else if (!is.null(before)) min(match(target,rest))-1L else max(match(target,rest))
  .data$frame <- f[,append(rest,move,after=pos)]
  .data
}
.named <- function(dots) {
  if (!length(dots) || is.null(names(dots)) || any(!nzchar(names(dots))) || anyDuplicated(names(dots))) stop("Supply uniquely named expressions.")
}
