# Control objects, metadata and expression translation stay in base R.
# All row-bearing objects and all data operations stay in H2O.
h2o_tbl <- function(x) {
  if (!inherits(x, "H2OFrame")) stop("x must be an H2OFrame; import files with h2o.uploadFile().")
  .valid_names(names(x))
  structure(list(frame = x, groups = character()), class = "h2o_tbl")
}
as_h2o <- function(x) {
  if (inherits(x, "h2o_tbl")) return(x$frame)
  if (inherits(x, "H2OFrame")) return(x)
  stop("Expected an h2o_tbl or H2OFrame.")
}
h_collect <- function(.data) as_h2o(.data)
`%.%` <- function(lhs, rhs) {
  rhs <- substitute(rhs)
  if (!is.call(rhs)) rhs <- as.call(list(rhs))
  eval(as.call(c(list(rhs[[1L]], substitute(lhs)), as.list(rhs)[-1L])), parent.frame())
}
.tbl <- function(x) {
  if (!inherits(x, "h2o_tbl")) stop("Expected an h2o_tbl.")
  x
}
.valid_names <- function(x) {
  if (anyNA(x) || any(!nzchar(x)) || anyDuplicated(x)) stop("Column names must be nonempty and unique.")
}
.cols_exist <- function(f, x) {
  if (length(setdiff(x, names(f)))) stop("Unknown columns: ", paste(setdiff(x, names(f)), collapse = ", "))
  x
}
.tmp <- function(f, prefix = ".h2oplyr") {
  z <- prefix
  while (z %in% names(f)) z <- paste0(z, "_")
  z
}
.const <- function(value, n) {
  if (length(value) != 1L || !is.atomic(value)) stop("Only scalar local constants are supported.")
  # rep_len is a public H2O primitive: no local vector allocation/upload.
  out <- if (is.character(value)) h2o::h2o.ifelse(h2o::h2o.rep_len(1, max(1,n)), value, value) else h2o::h2o.rep_len(value, max(1, n))
  if (n == 0) out <- out[h2o::h2o.rep_len(0,1), ]
  out
}
.column <- function(value, f) {
  if (!inherits(value, "H2OFrame")) return(.const(value, nrow(f)))
  if (ncol(value) != 1L || nrow(value) != nrow(f)) stop("Result must be a scalar or one H2O column with the input row count.")
  value
}
.no_groups <- function(x, verb) {
  if (length(x$groups)) stop(verb, " does not support grouped input; call h_ungroup() explicitly.")
}
.count_arg <- function(n) {
  if (length(n) != 1L || is.na(n) || !is.finite(n) || n < 0 || n != floor(n)) stop("n must be one nonnegative integer.")
  n
}
.types <- function(f) h2o::h2o.getTypes(f)
print.h2o_tbl <- function(x, ...) {
  cat("<h2o_tbl> ", nrow(x$frame), " rows x ", ncol(x$frame), " columns; remote H2O frame\n", sep = "")
  cat("Columns: ", paste(names(x$frame), collapse = ", "), "\n", sep = "")
  if (length(x$groups)) cat("Groups: ", paste(x$groups, collapse = ", "), "\n", sep = "")
  invisible(x)
}
h_glimpse <- function(.data, width = 60) {
  f <- as_h2o(.data)
  print(.tbl(.data))
  cat(paste(paste(names(f), .types(f), sep = ": "), collapse = "\n"), "\n")
  invisible(.data)
}
h_explain <- function(.data) {
  print(.tbl(.data))
  cat("Backend: H2O. This is metadata, not a query-cost estimate.\n")
  invisible(.data)
}
h_penguins <- function() {
  h2o_tbl(h2o::h2o.uploadFile(system.file("extdata", "penguins.csv", package = "h2oplyr", mustWork = TRUE),
                           na.strings = rep(list("NA"),8), col.types = c("enum", "enum", "numeric", "numeric", "numeric", "numeric", "enum", "numeric")))
}
h2o_available <- function() {
  # Never start a JVM from a package example or on package load.
  tryCatch(isTRUE(h2o::h2o.clusterIsUp()), error = function(e) FALSE)
}

# Closed expression interpreter: unknown R functions never receive row data.
.eval_h2o <- function(e, f, env, bindings = list()) {
  if (is.atomic(e) || is.null(e)) return(e)
  if (is.symbol(e)) {
    nm <- as.character(e)
    if (nm %in% names(bindings)) return(bindings[[nm]])
    if (nm %in% names(f)) return(f[[nm]])
    val <- get(nm, env, inherits = TRUE)
    if (!inherits(val,"H2OFrame") && (!is.atomic(val) || length(val) != 1L)) stop("External values must be scalar constants or H2O columns.")
    return(val)
  }
  if (!is.call(e)) stop("Unsupported expression.")
  head <- e[[1L]]
  if (is.call(head)) {
    if (!identical(head[[1L]], as.name("::")) || as.character(head[[2L]]) != "h2o") stop("Only whitelisted h2o:: calls are allowed.")
    fn <- as.character(head[[3L]])
  } else fn <- as.character(head)
  if (fn %in% c("h_row_number", "h_roll_mean", "h_min_rank") && !is.null(f)) {
    return(.window_eval(e, .window_context(f, character()), env))
  }
  if (fn == "h_case_when") {
    clauses <- as.list(e)[-1L]
    default <- if (".default" %in% names(clauses)) .eval_h2o(clauses[[".default"]], f, env, bindings) else NA
    clauses[[".default"]] <- NULL
    out <- .column(default, f)
    for (z in rev(clauses)) {
      if (!is.call(z) || !identical(z[[1L]], as.name("~"))) stop("Use condition ~ value in h_case_when().")
      cond <- .column(.eval_h2o(z[[2L]], f, env, bindings), f)
      yes <- .eval_h2o(z[[3L]], f, env, bindings)
      out <- h2o::h2o.ifelse(h2o::h2o.ifelse(is.na(cond), 0, cond), yes, out)
    }
    return(out)
  }
  ops <- c("+", "-", "*", "/", "^", "%%", "%/%", ">", "<", ">=", "<=", "==", "!=", "&", "|", "!", "(")
  maps <- c(abs="h2o.abs", sqrt="h2o.sqrt", log="h2o.log", log2="h2o.log2", log10="h2o.log10", exp="h2o.exp",
            round="h2o.round", floor="h2o.floor", ceiling="h2o.ceiling", trunc="h2o.trunc",
            nchar="h2o.nchar", toupper="h2o.toupper", tolower="h2o.tolower", trimws="h2o.trim",
            as.numeric="h2o.asnumeric", as.character="h2o.ascharacter", as.factor="h2o.asfactor")
  helpers <- c("h_if_else", "h_between", "h_coalesce", "h_replace_na", "h_na_if", "h_lag", "h_lead", "h_cumsum", "h_cummax", "h_cummin", "when_any", "when_all")
  if (fn == "is.na") fun <- base::is.na
  else if (fn %in% ops) fun <- get(fn, baseenv())
  else if (fn == "%in%") fun <- function(x, table) h2o::h2o.match(x, table, nomatch = 0) > 0
  else if (fn == "c") fun <- base::c
  else if (fn %in% names(maps)) fun <- getExportedValue("h2o", maps[[fn]])
  else if (fn %in% unname(maps)) fun <- getExportedValue("h2o", fn)
  else if (fn %in% helpers) fun <- get(fn, envir = environment(.eval_h2o))
  else stop("Unsupported function in H2O expression: ", fn, ". No local fallback is allowed.")
  args <- lapply(as.list(e)[-1L], .eval_h2o, f = f, env = env, bindings = bindings)
  if (fn == "c" && any(vapply(args, inherits, logical(1), "H2OFrame"))) stop("c() accepts literal constants only.")
  out <- do.call(fun, args)
  if (fn %in% c(">", "<", ">=", "<=", "==", "!=")) {
    masks <- lapply(args, function(a) if(inherits(a,"H2OFrame")) is.na(a) else is.na(a))
    mask <- Reduce(`|`, masks)
    if(inherits(mask,"H2OFrame")) out <- h2o::h2o.ifelse(mask,NA,out)
  }
  out
}

.empty <- function(f) {
  if(nrow(f)==0) return(f)
  f[h2o::h2o.rep_len(0,nrow(f)),]
}

# Base nrow/ncol dispatch through dim; no custom nrow/ncol generic is needed.
dim.h2o_tbl <- function(x) dim(x$frame)
names.h2o_tbl <- function(x) names(x$frame)
