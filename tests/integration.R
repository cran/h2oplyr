library(h2oplyr)
port <- Sys.getenv('H2OPLYR_TEST_PORT')
if(nzchar(port)) {
  h2o::h2o.init(ip='127.0.0.1',port=as.integer(port),startH2O=FALSE)
  h2o::h2o.no_progress()
  # Read function bindings without modifying another package's namespace.
  h2o_namespace <- asNamespace('h2o')
  function_names <- Filter(function(nm) is.function(get(nm, h2o_namespace)),
                           ls(h2o_namespace, all.names = TRUE))
  before <- lapply(function_names, get, envir = h2o_namespace)
  source(system.file('examples','examples.R',package='h2oplyr'),local=TRUE)
  exported <- getNamespaceExports('h2oplyr')
  stopifnot(setequal(names(examples),exported))
  for(nm in names(examples)) { eval(examples[[nm]]); cat('[PASS]',nm,'\n') }
  source(system.file('examples','regressions.R',package='h2oplyr'),local=TRUE)
  after <- lapply(function_names, get, envir = h2o_namespace)
  stopifnot(identical(before, after))
  cat('[PASS] H2O namespace function bindings unchanged\n')
} else cat('H2O integration tests skipped: set H2OPLYR_TEST_PORT to an explicitly started matching cluster.\n')
