# Rack::JetRouter

($Release: 1.3.0 $)

Rack::JetRouter is crazy-fast router library for Rack application,
derived from [Keight.rb](https://github.com/kwatch/keight/tree/ruby).

Rack::JetRouter requires Ruby >= 2.4.


## Benchmark

Benchmark script is [here](https://github.com/kwatch/rack-jet_router/blob/release/bench/bench.rb).

| Name               | Version |
| ------------------ | ------- |
| Ruby               | 3.2.2   |
| Rack               | 2.2.8   |
| Rack::JetRouter    | 1.3.0   |
| Rack::Multiplexer  | 0.0.8   |
| Sinatra            | 3.1.0   |
| Keight.rb          | 1.0.0   |
| Hanami::Router     | 2.0.2   |

(Macbook Pro, Apple M1 Pro, macOS Ventura 13.6.2)


### JetRouter vs. Rack vs. Sinatra vs. Keight.rb vs. Hanami:

```
## Ranking                         usec/req  Graph (longer=faster)
(JetRouter)      /api/aaa01          0.2816 (100.0%) ********************
(Multiplexer)    /api/aaa01          1.2586 ( 22.4%) ****
(Hanami::Router) /api/aaa01          1.3296 ( 21.2%) ****
(JetRouter)      /api/aaa01/123      1.5861 ( 17.8%) ****
(Rack::Req+Res)  /api/aaa01/123      1.7369 ( 16.2%) ***
(Rack::Req+Res)  /api/aaa01          1.7438 ( 16.1%) ***
(Keight)         /api/aaa01          1.8906 ( 14.9%) ***
(Keight)         /api/aaa01/123      2.8998 (  9.7%) **
(Multiplexer)    /api/aaa01/123      2.9166 (  9.7%) **
(Hanami::Router) /api/aaa01/123      4.0996 (  6.9%) *
(Sinatra)        /api/aaa01         49.6862 (  0.6%)
(Sinatra)        /api/aaa01/123     54.3448 (  0.5%)
```

* If URL path has no path parameter (such as `/api/hello`),
  JetRouter is significantly fast.
* If URL path contains path parameter (such as `/api/hello/:id`),
  JetRouter becomes slower, but it is enough small (about 1.3 usec/req).
* Overhead of JetRouter is smaller than that of Rack::Reqeuast +
  Rack::Response.
* Hanami is slower than JetRouter, but quite enough fast.
* Sinatra is too slow.


### JetRouter vs. Rack::Multiplexer:

```
## Ranking                         usec/req  Graph (longer=faster)
(JetRouter)      /api/aaa01          0.2816 (100.0%) ********************
(JetRouter)      /api/zzz26          0.2823 ( 99.7%) ********************
(Multiplexer)    /api/aaa01          1.2586 ( 22.4%) ****
(JetRouter)      /api/aaa01/123      1.5861 ( 17.8%) ****
(Multiplexer)    /api/aaa01/123      2.9166 (  9.7%) **
(JetRouter)      /api/zzz26/456      3.5767 (  7.9%) **
(Multiplexer)    /api/zzz26         14.8423 (  1.9%)
(Multiplexer)    /api/zzz26/456     16.8930 (  1.7%)
```

* JetRouter is about 4~6 times faster than Rack::Multiplexer.
* Rack::Multiplexer is getting worse in promotion to the number of URL paths.


### JetRouter vs. Hanami::Router

```
## Ranking                         usec/req  Graph (longer=faster)
(JetRouter)      /api/aaa01          0.2816 (100.0%) ********************
(JetRouter)      /api/zzz26          0.2823 ( 99.7%) ********************
(Hanami::Router) /api/zzz26          1.3280 ( 21.2%) ****
(Hanami::Router) /api/aaa01          1.3296 ( 21.2%) ****
(JetRouter)      /api/aaa01/123      1.5861 ( 17.8%) ****
(JetRouter)      /api/zzz26/456      3.5767 (  7.9%) **
(Hanami::Router) /api/zzz26/456      4.0898 (  6.9%) *
(Hanami::Router) /api/aaa01/123      4.0996 (  6.9%) *
```

* Hanami is slower than JetRouter, but it has enough speed.


## Examples

### #1: Depends only on Request Path

```ruby
# -*- coding: utf-8 -*-

require 'rack'
require 'rack/jet_router'

## Assume that welcome_app, books_api, ... are Rack application.
mapping = [
    ['/'                       , welcome_app],
    ['/api', [
        ['/books', [
            [''                , books_api],
            ['/:id(.:format)'  , book_api],
            ['/:book_id/comments/:comment_id', comment_api],
        ]],
    ]],
    ['/admin', [
        ['/books'              , admin_books_app],
    ]],
]

router = Rack::JetRouter.new(mapping)
p router.lookup('/api/books/123.json')
    #=> [book_api, {"id"=>"123", "format"=>"json"}]

status, headers, body = router.call(env)
```


### #2: Depends on both Request Path and Method

```ruby
# -*- coding: utf-8 -*-

require 'rack'
require 'rack/jet_router'

## Assume that welcome_app, book_list_api, ... are Rack application.
mapping = [
    ['/'                       , {GET: welcome_app}],
    ['/api', [
        ['/books', [
            [''                , {GET: book_list_api, POST: book_create_api}],
            ['/:id(.:format)'  , {GET: book_show_api, PUT: book_update_api}],
            ['/:book_id/comments/:comment_id', {POST: comment_create_api}],
        ]],
    ]],
    ['/admin', [
        ['/books'              , {ANY: admin_books_app}],
    ]],
]

router = Rack::JetRouter.new(mapping)
p router.lookup('/api/books/123')
    #=> [{"GET"=>book_show_api, "PUT"=>book_update_api}, {"id"=>"123", "format"=>nil}]

status, headers, body = router.call(env)
```

Notice that `{GET: ..., PUT: ...}` is converted into `{"GET"=>..., "PUT"=>...}`
automatically when passing to `Rack::JetRouter.new()`.


### #3: RESTful Framework

```ruby
# -*- coding: utf-8 -*-

require 'rack'
require 'rack/jet_router'

class API
  def initialize(request, response)
    @request  = request
    @response = response
  end
  attr_reader :request, :response
end

class BooksAPI < API
  def index(); ....; end
  def create(); ....; end
  def show(id); ....; end
  def update(id: nil); ....; end
  def delete(id: nil); ....; end
end

mapping = [
    ['/api', [
        ['/books', [
            [''      , {GET:    [BooksAPI, :index],
                        POST:   [BooksAPI, :create]}],
            ['/:id'  , {GET:    [BooksAPI, :show],
                        PUT:    [BooksAPI, :update],
                        DELETE: [BooksAPI, :delete]}],
        ]],
    ]],
]
router = Rack::JetRouter.new(mapping)
dict, args = router.lookup('/api/books/123')
p dict   #=> {"GET"=>[BooksAPI, :show], "PUT"=>[...], "DELETE"=>[...]}
p args   #=> {"id"=>"123"}
klass, action = dict["GET"]
handler = klass.new(Rack::Request.new(env), Rack::Response.new)
handler.__send__(action, args)
```


## Topics


### Nested Array v.s. Nested Hash

URL path mapping can be not only nested Array but also nested Hash.

```ruby
## nested Array
mapping = [
    ["/api", [
        ["/books", [
            [""      , book_list_api],
            ["/:id"  , book_show_api],
        ]],
    ]],
]

## nested Hash
mapping = {
    "/api" => {
        "/books" => {
            ""      => book_list_api,
            "/:id"  => book_show_api,
        },
    },
}
```

But nested Hash mapping can't include request method mappings, because
it is hard to distinguish between URL path mapping and request method mapping.

```ruby
## NOT OK
mapping = {
    "/api" => {
        "/books" => {
            ""      => {GET: book_list_api, POST: book_create_api},
            "/:id"  => {GET: book_show_api, PUT: book_update_api},
        },
    },
}
```

In this case, define subclass of Hash class and use it instead of Hash.

```ruby
class Map < Hash       # define subclass of Hash class
end

def Map(**kwargs)      # helper method to create subclass object
  return Map.new.update(kwargs)
end

## OK
mapping = {
    "/api" => {
        "/books" => {
            ""      => Map(GET: book_list_api, POST: book_create_api),
            "/:id"  => Map(GET: book_show_api, PUT: book_update_api),
        },
    },
}
```


### URL Path Parameters

In Rack application, URL path parameters (such as `{"id"=>"123"}`) are
available via `env['rack.urlpath_params']`.

```ruby
BookApp = proc {|env|
  p env['rack.urlpath_params']   #=> {"id"=>"123"}
  [200, {}, []]
}
```

Key name can be changed by ``env_key:`` keyword argument of ``JetRouter.new()``.

```ruby
router = Rack::JetRouter.new(mapping, env_key: "rack.urlpath_params")
```

If you want to tweak URL path parameters, define subclass of Rack::JetRouter
and override `#build_param_values(names, values)`.

```ruby
class MyRouter < JetRouter

  def build_param_values(names, values)
    return names.zip(values).each_with_object({}) {|(k, v), d|
      ## converts urlpath pavam value into integer
      v = v.to_i if k == 'id' || k.end_with?('_id')
      d[k] = v
    }
  end

end
```


### Integer Type Parameters

Keyword argument ``int_param:`` of ``JetRouter.new()`` specifies
parameter name pattern (regexp) to treat as integer type.
For example, ``int_param: /(?:\A|_)id\z/`` treats ``id`` or ``xxx_id``
parameter values as integer type.

```ruby
require 'rack'
require 'rack/jet_router'

rack_app = proc {|env|
  params = env['rack.urlpath_params']
  type = params["book_id"].class
  text = "params=#{params.inspect}, type=#{type}"
  [200, {}, [text]]
}

mapping = [
  ["/api/books/:book_id", rack_app]
]
router = Rack::JetRouter.new(mapping, int_param: /(?:\A|_)id\z/

env = Rack::MockRequest.env_for("/api/books/123")
tuple = router.call(env)
puts tuple[2]     #=> params={"book_id"=>123}, type=Integer
```

Integer type parameters match to only integers.

```ruby
env = Rack::MockRequest.env_for("/api/books/FooBar")
tuple = router.call(env)
puts tuple[2]     #=> 404 Not Found
```


<!--

### URL Path Multiple Extension

It is available to specify multiple extension of URL path.

```ruby
mapping = {
    "/api/books" => {
        "/:id(.html|.json)"  => book_api,
    },
}
```

In above example, the following URL path patterns are enabled.

* ``/api/books/:id``
* ``/api/books/:id.html``
* ``/api/books/:id.json``

Notice that ``env['rack.urlpath_params']['format']`` is not set
because ``:format`` is not specified in URL path pattern.

-->


### Auto-redirection

Rack::JetRouter implements auto-redirection.

* When `/foo` is provided and `/foo/` is requested, then Rack::JetRouter redirects to `/foo` automatically.
* When `/foo/` is provided and `/foo` is requested, then Rack::JetRouter redirects to `/foo/` automatically.

Notice that auto-redirection is occurred only on `GET` or `HEAD` methods, because
browser cannot handle redirection on `POST`, `PUT`, and `DELETE` methods correctly.
Don't depend on auto-redirection feature so much.


### Variable URL Path Cache

It is useful to classify URL path patterns into two types: fixed and variable.

* **Fixed URL path pattern** doesn't contain any urlpath paramters.<br>
  Example: `/`, `/login`, `/api/books`
* **Variable URL path pattern** contains urlpath parameters.<br>
  Example: `/api/books/:id`, `/index(.:format)`

`Rack::JetRouter` caches only fixed URL path patterns in default.
It is possible for `Rack::JetRouter` to cache variable URL path patterns
as well as fixed ones. It will make routing much faster.

```ruby
## Enable variable urlpath cache.
router = Rack::JetRouter.new(urlpath_mapping, urlpath_cache_size: 200)
p router.lookup('/api/books/123')   # caches even varaible urlpath
```


### Custom Error Response

```ruby
class MyRouter < Rack::JetRouter

  def error_not_found(env)
    html = ("<h2>404 Not Found</h2>\n" \
            "<p>Path: #{env['PATH_INFO']}</p>\n")
    [404, {"Content-Type"=>"text/html"}, [html]]
  end

  def error_not_allowed(env)
    html = ("<h2>405 Method Not Allowed</h2>\n" \
            "<p>Method: #{env['REQUEST_METHOD']}</p>\n")
    [405, {"Content-Type"=>"text/html"}, [html]]
  end

end
```

Above methods are invoked from `Rack::JetRouter#call()`.


## Todo

* [_] support regular expression such as `/books/{id:\d+}`.


## Copyright and License

$Copyright: copyright(c) 2015 kwatch@gmail.com $

$License: MIT License $
