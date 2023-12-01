CHANGES
=======


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
