CHANGES
=======


Release 1.3.1 (2023-12-10)
--------------------------

* [bugfix] Fixed to correctly handle suffixed URL path pattern such as `/foo(.:format)`.


Release 1.3.0 (2023-12-09)
--------------------------

* [enhance] Performance has improved (about 10%). This improvement was achieved by optimizing regular expressions.
* [enhance] URL path mapping can be nested Hash as well as nested Array. See the document for detail.
* [enhance] Passing the `int_param: /(?:\A|_)id\z/` keyword argument to `JetRouter.new()` changes the router to treat urlpath parameter `id` or `xxx_id` as integer type.
* [enhance] Passing the `env_key:` keyword argument to `JetRouter.new()` changes the key of environemnt to store URL path parameter values.
* [change] Keyword parameter `urlpath_cache_size:` of `JetRouter.new()` is renamed to `cache_size:`. Old parameter name is also available for backward compatibility, but it is recommended to use new parameter name.
* [change] Rename `JetRouter#build_urlpath_parameter_vars()` to `JetRouter#build_param_values()`.
* [change] Update benchmark script to require 'benchmarker' gem.


Release 1.2.0 (2016-10-16)
--------------------------

* Change auto-redirection to be occurred only on GET or HEAD methods.
* Code is rewrited, especially around `Rack::JetRouter#compile_mapping()`.
* Update benchmark script to support `Hanabi::Router`.


Release 1.1.1 (2015-12-29)
--------------------------

* Fix benchmark script.
* Fix document.


Release 1.1.0 (2015-12-28)
--------------------------

* **NOTICE** `Rack::JetRouter#find()` is renamed to `#lookup()`.
  `#find()` is also available for compatibility, but not recommended.
* Performance improved when number of URL path parameter is 1.
* Regular expression generated is improved.
* Benchmark script is improved to take some command-line options.
* Document fixed.


Release 1.0.1 (2015-12-06)
--------------------------

* Fix document


Release 1.0.0 (2015-12-06)
--------------------------

* First release
