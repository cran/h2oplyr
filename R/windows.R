# Grouped windows use remote positions and group IDs, never local row data.
.window_names <- function() c("h_lag", "h_lead", "h_roll_mean", "h_min_rank", "h_row_number")
.flag <- function(x, name) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) stop(name, " must be TRUE or FALSE.")
  x
}
.window_numeric <- function(x) {
  x <- as_h2o(x)
  if (ncol(x) != 1L || !h2o::h2o.isnumeric(x)) stop("Use one numeric H2O column.")
  x
}
.row_sequence <- function(n) {
  if (!n) return(.const(0, 0))
  h2o::h2o.cumsum(.const(1, n))
}
.same_group <- function(a, b) {
  h2o::h2o.ifelse(is.na(a) | is.na(b), is.na(a) & is.na(b), a == b)
}
.window_context <- function(f, groups) {
  original <- names(f)
  id <- .tmp(f, ".hp_input_row"); f[[id]] <- .row_sequence(nrow(f))
  keys <- character()
  for (g in groups) {
    key <- .tmp(f, ".hp_group_key")
    f[[key]] <- if (h2o::h2o.ischaracter(f[[g]])) h2o::h2o.asfactor(f[[g]]) else f[[g]]
    keys <- c(keys, key)
  }
  if (length(keys) && nrow(f)) f <- .sort(f, c(keys, id))
  gid <- .tmp(f, ".hp_group_id")
  if (!nrow(f) || !length(keys)) f[[gid]] <- .const(1, nrow(f))
  else {
    same <- Reduce(`&`, lapply(keys, function(k) .same_group(f[[k]], h_lag(f[[k]]))))
    start <- (.row_sequence(nrow(f)) == 1) | !same
    f[[gid]] <- h2o::h2o.cumsum(start)
  }
  list(frame = f, id = id, gid = gid, original = original)
}
.window_position <- function(gid) {
  n <- nrow(gid)
  pos <- .row_sequence(n)
  if (!n) return(pos)
  start <- (pos == 1) | !.same_group(gid, h_lag(gid))
  pos - h2o::h2o.cummax(h2o::h2o.ifelse(start, pos, 0)) + 1
}
.window_shift <- function(x, gid, n, default, lead) {
  .count_arg(n)
  if (n == 0 || nrow(x) == 0) return(x)
  shifted <- .shift(x, n, default, lead)
  other <- .shift(gid, n, NA, lead)
  h2o::h2o.ifelse(.same_group(gid, other), shifted, default)
}
.window_roll <- function(x, gid, k, partial, na.rm) {
  x <- .window_numeric(x); .count_arg(k)
  if (k < 1) stop("k must be a positive integer.")
  .flag(partial, "partial"); .flag(na.rm, "na.rm")
  total <- nrow(x)
  if (!total) return(x)
  sum <- .const(0, total); count <- .const(0, total); slots <- .const(0, total)
  for (offset in seq_len(min(k, total)) - 1) {
    value <- h_lag(x, offset)
    member <- .same_group(gid, h_lag(gid, offset))
    observed <- member & !is.na(value)
    sum <- sum + h2o::h2o.ifelse(observed, value, 0)
    count <- count + observed
    slots <- slots + member
  }
  out <- h2o::h2o.ifelse(count > 0, sum / count, NA)
  if (!na.rm) out <- h2o::h2o.ifelse(count == slots, out, NA)
  if (!partial) out <- h2o::h2o.ifelse(slots == k, out, NA)
  out
}
.window_rank <- function(x, gid, descending) {
  x <- .window_numeric(x)
  n <- nrow(x)
  if (!n) return(.const(NA_real_, 0))
  f <- h2o::h2o.cbind(gid, .row_sequence(n), x)
  names(f) <- c(".wg", ".wi", ".wv")
  valid <- f[!is.na(f[[".wv"]]), ]
  if (!nrow(valid)) return(.const(NA_real_, n))
  sorted <- .sort(valid, c(".wg", ".wv", ".wi"), c(FALSE, descending, FALSE))
  sorted[[".wr"]] <- .window_position(sorted[[".wg"]])
  ranks <- .aggregate(sorted, c(".wg", ".wv"),
                      list(list(fn = "min", col = ".wr", na = TRUE)), ".wr")
  out <- h2o::h2o.merge(f, ranks, by = c(".wg", ".wv"), all.x = TRUE)
  .sort(out, ".wi")[[".wr"]]
}
h_roll_mean <- function(x, k = 3, partial = TRUE, na.rm = FALSE) {
  x <- .window_numeric(x)
  .window_roll(x, .const(1, nrow(x)), k, partial, na.rm)
}
h_min_rank <- function(x) {
  e <- substitute(x)
  down <- is.call(e) && identical(e[[1L]], as.name("desc"))
  if (down) {
    if (length(e) != 2L) stop("desc() requires one column.")
    x <- .eval_h2o(e[[2L]], NULL, parent.frame())
  }
  x <- .window_numeric(x)
  .window_rank(x, .const(1, nrow(x)), down)
}
h_row_number <- function() {
  stop("h_row_number() must be used inside h_mutate().")
}
.window_eval <- function(e, ctx, env) {
  fn <- as.character(e[[1L]])
  fun <- get(fn, envir = environment(.window_eval))
  args <- as.list(match.call(definition = fun, call = e))[-1L]
  f <- ctx$frame; gid <- f[[ctx$gid]]
  if (fn == "h_row_number") return(.window_position(gid))
  if (is.null(args$x)) stop(fn, " requires a column.")
  source <- args$x; down <- FALSE
  if (fn == "h_min_rank" && is.call(source) && identical(source[[1L]], as.name("desc"))) {
    if (length(source) != 2L) stop("desc() requires one column.")
    down <- TRUE; source <- source[[2L]]
  }
  if (!is.symbol(source) || !as.character(source) %in% ctx$original)
    stop("Window input must be a column name; create transformed columns in an ungrouped mutation first.")
  x <- f[[as.character(source)]]
  scalar <- function(name, default) {
    if (!name %in% names(args)) return(default)
    value <- .eval_h2o(args[[name]], NULL, env)
    if (!is.atomic(value) || length(value) != 1L) stop(name, " must be a scalar.")
    value
  }
  if (fn %in% c("h_lag", "h_lead"))
    return(.window_shift(x, gid, scalar("n", 1), scalar("default", NA), fn == "h_lead"))
  if (fn == "h_roll_mean")
    return(.window_roll(x, gid, scalar("k", 3), scalar("partial", TRUE), scalar("na.rm", FALSE)))
  .window_rank(x, gid, down)
}
.grouped_mutate <- function(.data, dots, groups, env) {
  .named(dots)
  if (any(names(dots) %in% groups)) stop("Grouped mutation cannot overwrite grouping columns.")
  for (e in dots) {
    if (!is.call(e) || !is.symbol(e[[1L]]) || !as.character(e[[1L]]) %in% .window_names())
      stop("Grouped h_mutate supports only h_lag, h_lead, h_roll_mean, h_min_rank and h_row_number calls. Ungroup explicitly for other expressions.")
  }
  if (!length(dots)) return(.data)
  ctx <- .window_context(.data$frame, groups)
  # Reserve helper names against every user-supplied output name as well.
  for (key in c("id", "gid")) {
    while (ctx[[key]] %in% names(dots)) {
      old <- ctx[[key]]; new <- .tmp(ctx$frame, paste0(old, "_"))
      names(ctx$frame)[names(ctx$frame) == old] <- new; ctx[[key]] <- new
    }
  }
  for (i in seq_along(dots)) {
    nm <- names(dots)[i]
    ctx$frame[[nm]] <- .column(.window_eval(dots[[i]], ctx, env), ctx$frame)
    ctx$original <- union(ctx$original, nm)
  }
  f <- if (nrow(ctx$frame)) .sort(ctx$frame, ctx$id) else ctx$frame
  .data$frame <- f[, ctx$original]
  .data
}
