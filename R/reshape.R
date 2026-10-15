h_pivot_longer <- function(.data,cols,names_to="name",values_to="value") {
  .data <- .tbl(.data); .no_groups(.data,"h_pivot_longer")
  f <- .data$frame; cols <- .selection(f,substitute(cols),parent.frame())
  if(!length(cols)) stop("Select at least one value column.")
  ids <- setdiff(names(f),cols); .valid_names(c(ids,names_to,values_to))
  pieces <- lapply(cols,function(nm) {
    sub <- f[,c(ids,nm)]; names(sub)[ncol(sub)] <- values_to
    sub[[names_to]] <- .const(nm,nrow(sub))
    sub[,c(ids,names_to,values_to)]
  })
  h2o_tbl(Reduce(h2o::h2o.rbind,pieces))
}
h_pivot_wider <- function(.data,names_from,values_from,id_cols=NULL,values_fill=NULL) {
  .data <- .tbl(.data); .no_groups(.data,"h_pivot_wider")
  f <- .data$frame
  names_from <- .selection(f,substitute(names_from),parent.frame())
  values_from <- .selection(f,substitute(values_from),parent.frame())
  ids <- if(is.null(substitute(id_cols))) setdiff(names(f),c(names_from,values_from)) else .selection(f,substitute(id_cols),parent.frame())
  if(length(names_from)!=1L||length(values_from)!=1L||!length(ids)) stop("Use one names_from, one values_from and at least one ID column.")
  f <- .factor_keys(f,union(ids,names_from))
  # The category domain is schema metadata, not a downloaded value column.
  f[[names_from]] <- h2o::h2o.asfactor(f[[names_from]])
  levels <- unlist(h2o::h2o.levels(f[[names_from]]),use.names=FALSE)
  if(!length(levels)) stop("names_from has no nonmissing categories.")
  .valid_names(c(ids,levels))
  if(h2o::h2o.any(is.na(f[[names_from]]))) stop("Missing names_from values are not supported.")
  keys <- union(ids,names_from)
  if(nrow(h2o::h2o.drop_duplicates(f[,keys],keys))!=nrow(f)) stop("Duplicate ID/name combinations; aggregate explicitly before widening.")
  out <- h2o::h2o.drop_duplicates(f[,ids],ids)
  for(level in levels) {
    part <- f[f[[names_from]]==level,c(ids,values_from)]
    names(part)[ncol(part)] <- level
    out <- h2o::h2o.merge(out,part,by=ids,all.x=TRUE)
    if(!is.null(values_fill)) out[[level]] <- h_coalesce(out[[level]],values_fill)
  }
  h2o_tbl(out)
}
h_separate <- function(.data,col,into,sep="-") {
  .data <- .tbl(.data)
  col <- .selection(.data$frame,substitute(col),parent.frame())
  if(length(col)!=1L) stop("Select one string column.")
  rest <- setdiff(names(.data$frame),col); .valid_names(c(rest,into))
  pieces <- h2o::h2o.strsplit(h2o::h2o.ascharacter(.data$frame[[col]]),sep)
  if(ncol(pieces)!=length(into)) stop("Number of split fields differs from length(into).")
  names(pieces) <- into
  h2o_tbl(if(length(rest)) h2o::h2o.cbind(.data$frame[,rest],pieces) else pieces)
}
h_unite <- function(.data,col,...,sep="_") {
  .data <- .tbl(.data); f <- .data$frame
  if(length(sep)!=1L || is.na(sep) || grepl("$",sep,fixed=TRUE) || grepl("\\",sep,fixed=TRUE)) stop("sep cannot contain dollar signs or backslashes.")
  cols <- .selections(f,as.list(substitute(list(...)))[-1L],parent.frame())
  if(length(cols)<2L) stop("Select at least two columns.")
  rest <- setdiff(names(f),cols); .valid_names(c(rest,col))
  # H2O interaction concatenates categorical values with underscores. Encode
  # original underscores first so delimiter replacement cannot alter values.
  token <- "H2OPLYRUNDERSCORETOKEN"
  sub <- f[,cols]
  for(nm in cols) {
    x <- h2o::h2o.ascharacter(sub[[nm]])
    if(h2o::h2o.any(h2o::h2o.grep(token,x,output.logical=TRUE))) stop("Input contains reserved encoding token.")
    sub[[nm]] <- h2o::h2o.asfactor(h2o::h2o.gsub("_",token,x))
  }
  out <- h2o::h2o.interaction(sub,factors=cols,pairwise=FALSE,max_factors=max(1,nrow(f)),min_occurrence=1)
  out <- h2o::h2o.ascharacter(out)
  out <- h2o::h2o.gsub("_",sep,out)
  out <- h2o::h2o.gsub(token,"_",out)
  missing <- Reduce(`|`,lapply(cols,function(nm) is.na(f[[nm]])))
  out[missing,1L] <- NA
  names(out) <- col
  h2o_tbl(if(length(rest)) h2o::h2o.cbind(f[,rest],out) else out)
}
