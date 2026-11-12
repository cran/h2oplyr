# Independent, hand-auditable expected values in the bundled synthetic CSV.
# Comparisons are remote; only scalar checks are returned to R.
wref <- h2o::h2o.uploadFile(system.file('extdata','windows.csv',package='h2oplyr'),
  na.strings='NA', col.types=c('numeric','enum','enum',rep('numeric',15)))
w <- h2o_tbl(wref[,c('id','group','subgroup','amount')])
remote_equal <- function(a,b) {
  stopifnot(nrow(a)==nrow(b),h2o::h2o.all(is.na(a)==is.na(b)),
    h2o::h2o.sum(abs(a-b),na.rm=TRUE)<1e-8)
}
run_regression('grouped windows match independent reference', {
  out <- h_mutate(w,prev=h_lag(amount),next_value=h_lead(amount),
    lag2=h_lag(amount,2),lead2=h_lead(amount,2),lag0=h_lag(amount,0),
    wide_lag=h_lag(amount,100),roll=h_roll_mean(amount),
    roll_rm=h_roll_mean(amount,na.rm=TRUE),full=h_roll_mean(amount,partial=FALSE),
    full_rm=h_roll_mean(amount,partial=FALSE,na.rm=TRUE),
    wide_roll=h_roll_mean(amount,k=100,na.rm=TRUE),
    rank_desc=h_min_rank(desc(amount)),rank_asc=h_min_rank(amount),
    row=h_row_number(),.by=c(group,subgroup))
  for(nm in names(wref)[-c(2,3)]) remote_equal(as_h2o(out)[[nm]],wref[[nm]])
  stopifnot(!length(h_group_vars(out)),identical(names(as_h2o(w)),c('id','group','subgroup','amount')))
})
run_regression('persistent groups, sequential windows and defaults', {
  out <- h_mutate(h_group_by(w,group,subgroup),prev=h_lag(amount),
    restored=h_lead(prev),row=h_row_number())
  stopifnot(identical(h_group_vars(out),c('group','subgroup')))
  remote_equal(as_h2o(out)[['prev']],wref[['prev']])
  remote_equal(as_h2o(out)[['row']],wref[['row']])
  first <- h_filter(h_ungroup(out),row==1)
  defaults <- h_mutate(w,prev=h_lag(amount,default=-99),row=h_row_number(),.by=c(group,subgroup))
  stopifnot(h2o::h2o.all(as_h2o(h_filter(defaults,row==1))[['prev']]==-99))
  remote_equal(as_h2o(h_mutate(w,i=h_row_number()))[['i']],wref[['id']])
  remote_equal(as_h2o(h_mutate(w,rank=h_min_rank(amount)))[['rank']],h_min_rank(wref[['amount']]))
})
run_regression('empty frames, all missing values and string keys', {
  empty <- h_filter(w,FALSE)
  out <- h_mutate(empty,a=h_lag(amount),b=h_roll_mean(amount),c=h_min_rank(amount),d=h_row_number(),.by=group)
  rows(out,0)
  missing <- h_filter(w,group=='C')
  out <- h_mutate(missing,a=h_min_rank(amount),b=h_roll_mean(amount,na.rm=TRUE),.by=group)
  stopifnot(h2o::h2o.all(is.na(as_h2o(out)[['a']])),h2o::h2o.all(is.na(as_h2o(out)[['b']])) )
  strings <- h_mutate(w,group=as.character(group))
  out <- h_mutate(strings,prev=h_lag(amount),.by=c(group,subgroup))
  remote_equal(as_h2o(out)[['prev']],wref[['prev']])
})
run_regression('temporary name collisions and categorical shifts', {
  collision <- h_rename(w,.hp_input_row=id,.hp_group_id=amount)
  out <- h_mutate(collision,.hp_input_row_=h_row_number(),new=h_lag(.hp_group_id),.by=c(group,subgroup))
  remote_equal(as_h2o(out)[['new']],wref[['prev']])
  remote_equal(as_h2o(out)[['.hp_input_row']],wref[['id']])
  out <- h_mutate(w,prev=h_lag(subgroup),row=h_row_number(),.by=group)
  stopifnot(h2o::h2o.all(is.na(as_h2o(h_filter(out,row==1))[['prev']])))
})
run_regression('grouped window validation never falls back locally', {
  g <- h_group_by(w,group)
  must_error(h_mutate(g,a=h_cumsum(amount)),'Grouped')
  must_error(h_mutate(g,a=amount+1),'Grouped')
  must_error(h_mutate(g,group=h_lag(amount)),'grouping columns')
  must_error(h_mutate(g,a=h_lag(amount),.by=subgroup),'ungrouped')
  must_error(h_mutate(g,a=h_lag(amount+1)),'column name')
  must_error(h_transmute(g,a=h_lag(amount)),'grouped')
  must_error(h_mutate(g,a=h_roll_mean(amount,k=0)),'positive')
  must_error(h_mutate(g,a=h_roll_mean(amount,k=1.5)),'nonnegative')
  must_error(h_mutate(g,a=h_roll_mean(amount,partial=NA)),'TRUE or FALSE')
  must_error(h_mutate(g,a=h_min_rank(subgroup)),'numeric')
  must_error(h_row_number(),'inside h_mutate')
})
