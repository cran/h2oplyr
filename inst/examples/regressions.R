# Boundary and semantic regression checks. x, p and helper assertions are
# supplied by examples.R. No reference table is downloaded for comparison.
must_error <- function(expr,pattern=NULL) {
  err <- tryCatch({force(expr);NULL},error=identity)
  stopifnot(inherits(err,'error'))
  if(!is.null(pattern)) stopifnot(grepl(pattern,conditionMessage(err),fixed=TRUE))
}
run_regression <- function(label,expr) { force(expr);cat('[REGRESSION]',label,'\n') }
run_regression('forbid local expression evaluation',{
  must_error(h_mutate(x,z=as.data.frame(y)),'Unsupported function')
  must_error(h_mutate(x,z=dplyr::lead(y)),'Only whitelisted')
  must_error(h_mutate_across(x,'y',list(bad=function(z) as.vector(z))),'Unsupported function')
})
run_regression('strict column selection and preserved grouping',{
  must_error(h_select(x,all_of('absent')),'Unknown columns')
  cols(h_select(x,-x1,-x2),c('id','grp','x','y','txt'))
  cols(h_select(x,id:grp),c('id','grp'))
  cols(h_select(h_group_by(x,grp),y),c('grp','y'))
  stopifnot(identical(h_group_vars(h_rename(h_group_by(x,grp),group=grp)),'group'))
  must_error(h_group_by(x,g=grp),'Renaming')
  must_error(h_rename(x,grp=id),'unique')
  must_error(h_mutate(h_group_by(x,grp),z=y),'grouped')
})
run_regression('missing comparisons and filters',{
  rows(h_filter(x,x==NA),0)
  rows(h_filter_out(x,x>=3),2)
  rows(h_drop_na(p),333)
  rows(h_filter(x,x>=3),3)
  rows(h_filter(x,FALSE),0)
})
run_regression('aggregation NA handling and aliases',{
  a<-h_summarize(x,s=sum(x,na.rm=TRUE),m=mean(x,na.rm=TRUE),lo=min(y),hi=max(y),med=median(y),sd=sd(y),var=var(y),u=n_distinct(grp))
  equal_sum(as_h2o(a)[,'s'],16);equal_sum(as_h2o(a)[,'m'],3.2)
  equal_sum(as_h2o(a)[,'med'],35);equal_sum(as_h2o(a)[,'var'],350)
  equal_sum(as_h2o(a)[,'u'],3)
  a<-h_summarize(x,m=mean(x),.by=grp)
  stopifnot(h2o::h2o.sum(is.na(as_h2o(a)[,'m']))==1)
  a<-h_summarize_across(x,'y',list(average=mean))
  equal_sum(as_h2o(a)[,'y_average'],35)
  a<-h_count(x,grp,wt=y);equal_sum(as_h2o(a)[,'n'],210)
  must_error(h_summarize(h_group_by(x,grp),n=n(),.by=grp),'ungrouped')
})
run_regression('distinct keep all and tie semantics',{
  a<-h_distinct(x,grp,.keep_all=TRUE);rows(a,3);equal_sum(as_h2o(a)[,'id'],9)
  ties<-h_mutate(x,score=h_if_else(id<=3,10,20))
  rows(h_slice_min(ties,score,n=2),3)
  rows(h_slice_max(ties,score,n=2),3)
  rows(h_slice_min(ties,score,n=2,with_ties=FALSE),2)
  rows(h_slice_head(x,0),0);rows(h_slice_tail(x,0),0)
  rows(h_slice_min(x,y,n=0),0)
  must_error(h_slice_head(x,-1),'nonnegative')
})
run_regression('sort NA placement and seed determinism',{
  a<-h_arrange(x,x)
  equal_sum(as_h2o(h_slice_head(a,1))[,'id'],1)
  a<-h_arrange(x,x,na_last=FALSE)
  equal_sum(as_h2o(h_slice_head(a,1))[,'id'],5)
  a<-h_slice_sample(x,n=4,seed=211);b<-h_slice_sample(x,n=4,seed=211)
  stopifnot(h2o::h2o.all(as_h2o(a)[,'id']==as_h2o(b)[,'id']))
  rows(h_slice_sample(x,n=0),0)
})
run_regression('optional seeds with and without replacement',{
  for(replace in c(FALSE,TRUE)) {
    # Fixed seeds belong in caller-controlled tests, not inside package functions.
    sample_n <- if(replace) 9 else 4
    a<-h_slice_sample(x,n=sample_n,replace=replace,seed=211)
    b<-h_slice_sample(x,n=sample_n,replace=replace,seed=211)
    stopifnot(h2o::h2o.all(as_h2o(a)[,'id']==as_h2o(b)[,'id']))
    rows(a,sample_n)
    # Default and explicit NULL both delegate randomness to H2O. The caller
    # can reproduce the sequence through R's RNG without the wrapper resetting it.
    set.seed(1701)
    before_seed <- .Random.seed
    a<-h_slice_sample(x,n=4,replace=replace)
    stopifnot(!identical(before_seed,.Random.seed))
    set.seed(1701)
    b<-h_slice_sample(x,n=4,replace=replace,seed=NULL)
    rows(a,4);rows(b,4)
    stopifnot(h2o::h2o.all(as_h2o(a)[,'id']==as_h2o(b)[,'id']))
    stopifnot(h2o::h2o.all(as_h2o(a)[,'id']>=1 & as_h2o(a)[,'id']<=6))
    if(!replace) rows(h_distinct(h_select(a,id)),4)
  }
})
run_regression('joins multiplicity and relationship guards',{
  a<-h_select(h_slice_head(x,2),grp,id)
  b<-h_select(h_slice_head(x,2),grp,y)
  rows(h_inner_join(a,b,by='grp'),4)
  rows(h_full_join(a,b,by='grp'),4)
  rows(h_semi_join(a,b,by='grp'),2)
  cols(h_semi_join(x,x,by='id'),names(as_h2o(x)))
  cols(h_anti_join(x,h_slice_head(x,2),by='id'),names(as_h2o(x)))
  rows(h_anti_join(a,b,by='grp'),0)
  must_error(h_left_join(a,b,by='grp',relationship='one-to-one'),'relationship violated')
  rows(h_left_join(a,h_distinct(b,grp,.keep_all=TRUE),by='grp',relationship='many-to-one'),2)
  rows(h_inner_join(a,h_rename(b,g=grp),by=c(grp='g')),4)
  must_error(h_inner_join(a,b,by=character()),'by must')
})
run_regression('pivot duplicate rejection and metadata-only domains',{
  long<-h_pivot_longer(h_select(x,id,x1,x2),c('x1','x2'))
  wide<-h_pivot_wider(long,name,value)
  equal_sum(as_h2o(wide)[,'x1'],57)
  must_error(h_pivot_wider(h_bind_rows(long,long),name,value),'Duplicate ID/name')
})
run_regression('remote string concatenation and source immutability',{
  z<-h_mutate(x,a='left_part',b='right_part')
  z<-h_unite(z,'joined',a,b,sep='-')
  rows(h_filter(z,joined=='left_part-right_part'),6)
  stopifnot(identical(names(as_h2o(x)),c('id','grp','x','y','txt','x1','x2')))
  equal_sum(as_h2o(x)[,'x'],16)
})
run_regression('window boundaries',{
  equal_sum(h_lag(v,n=0),210)
  equal_sum(h_lag(v,n=100,default=0),0)
  equal_sum(h_lead(v,n=100,default=0),0)
  equal_sum(h_coalesce(v),210)
  must_error(h_lag(v,n=-1),'nonnegative')
})
run_regression('categorical conditions retain labels',{
 z<-h_mutate(p,chosen=h_if_else(body_mass_g>4000,species,'other'))
 rows(h_filter(z,chosen=='other'),nrow(as_h2o(h_filter(p,body_mass_g<=4000))))
 z<-h_replace_na(p,list(sex='unknown'))
 rows(h_filter(z,sex=='unknown'),11)
 z<-h_mutate(x,label=h_case_when(y>=40~'high',TRUE~'low'))
 rows(h_filter(z,label=='high'),3)
 z<-h_lag(as_h2o(p)[,'species'])
 stopifnot(h2o::h2o.sum(is.na(z))==1)
})

cat('All semantic regressions passed.\n')
