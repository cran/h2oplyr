.join_setup <- function(x,y,by,suffix,relationship) {
  fx <- as_h2o(x); fy <- as_h2o(y)
  if(is.null(by)) by <- intersect(names(fx),names(fy))
  if(!is.character(by)||!length(by)||anyDuplicated(by)) stop("by must specify unique join columns; implicit cross joins are not supported.")
  bx <- if(is.null(names(by))) by else names(by)
  by <- unname(by)
  .cols_exist(fx,bx); .cols_exist(fy,by)
  .valid_names(bx)
  if(length(suffix)!=2L) stop("suffix must have length two.")
  fx <- .factor_keys(fx,bx); fy <- .factor_keys(fy,by)
  if(!is.null(relationship)) {
    relationship <- match.arg(relationship,c("one-to-one","one-to-many","many-to-one","many-to-many"))
    dx <- nrow(h2o::h2o.drop_duplicates(fx[,bx],bx))<nrow(fx)
    dy <- nrow(h2o::h2o.drop_duplicates(fy[,by],by))<nrow(fy)
    if((relationship %in% c("one-to-one","one-to-many")&&dx)||(relationship %in% c("one-to-one","many-to-one")&&dy)) stop("Join relationship violated: ",relationship)
  }
  names(fy)[match(by,names(fy))] <- bx
  .valid_names(names(fy))
  overlap <- intersect(setdiff(names(fx),bx),setdiff(names(fy),bx))
  names(fx)[match(overlap,names(fx))] <- paste0(overlap,suffix[1L])
  names(fy)[match(overlap,names(fy))] <- paste0(overlap,suffix[2L])
  .valid_names(c(names(fx),setdiff(names(fy),bx)))
  list(x=fx,y=fy,by=bx)
}
.join <- function(x,y,by,suffix,relationship,kind) {
  z <- .join_setup(x,y,by,suffix,relationship)
  fx <- z$x; fy <- z$y; by <- z$by
  if(kind=="right") {
    f <- h2o::h2o.merge(fy,fx,by=by,all.x=TRUE)
  } else if(kind=="full") {
    marker <- .tmp(fx,".hp_present")
    while(marker %in% names(fy)) marker <- paste0(marker,"_")
    fx[[marker]] <- .const(1,nrow(fx))
    left <- h2o::h2o.merge(fx,fy,by=by,all.x=TRUE)
    right <- h2o::h2o.merge(fy,fx,by=by,all.x=TRUE)
    unmatched <- right[is.na(right[[marker]]),names(left)]
    f <- h2o::h2o.rbind(left,unmatched)
    f <- f[,setdiff(names(f),marker)]
  } else f <- h2o::h2o.merge(fx,fy,by=by,all.x=kind=="left")
  h2o_tbl(f)
}
h_inner_join <- function(x,y,by=NULL,suffix=c(".x",".y"),relationship=NULL) .join(x,y,by,suffix,relationship,"inner")
h_left_join <- function(x,y,by=NULL,suffix=c(".x",".y"),relationship=NULL) .join(x,y,by,suffix,relationship,"left")
h_right_join <- function(x,y,by=NULL,suffix=c(".x",".y"),relationship=NULL) .join(x,y,by,suffix,relationship,"right")
h_full_join <- function(x,y,by=NULL,suffix=c(".x",".y"),relationship=NULL) .join(x,y,by,suffix,relationship,"full")
h_semi_join <- function(x,y,by=NULL) {
  if(is.null(by)) by <- intersect(names(as_h2o(x)),names(as_h2o(y)))
  .cols_exist(as_h2o(y),unname(by))
  z <- .join_setup(x,h2o_tbl(as_h2o(y)[,unname(by)]),by,c(".x",".y"),NULL)
  keys <- h2o::h2o.drop_duplicates(z$y[,z$by],z$by)
  h2o_tbl(h2o::h2o.merge(z$x,keys,by=z$by))
}
h_anti_join <- function(x,y,by=NULL) {
  if(is.null(by)) by <- intersect(names(as_h2o(x)),names(as_h2o(y)))
  .cols_exist(as_h2o(y),unname(by))
  z <- .join_setup(x,h2o_tbl(as_h2o(y)[,unname(by)]),by,c(".x",".y"),NULL)
  keys <- h2o::h2o.drop_duplicates(z$y[,z$by],z$by)
  marker <- .tmp(z$x,".hp_present"); keys[[marker]] <- .const(1,nrow(keys))
  f <- h2o::h2o.merge(z$x,keys,by=z$by,all.x=TRUE)
  h2o_tbl(f[is.na(f[[marker]]),names(z$x)])
}
