# Rack::JetRouter

Rack::JetRouter is crazy-fast router library for Rack application,
derived from [Keight.rb](https://github.com/kwatch/keight/tree/ruby).


## Examples

### #1: Depends only on Request Path

```ruby
# -*- coding: utf-8 -*-

require 'rack'
require 'rack/jet_router'

urlpath_mapping = [
    ['/'                       , WelcomeApp],
    ['/api', [
        ['/books', [
            [''                , BooksAPI],
            ['/:id(.:format)'  , BookAPI],
            ['/:book_id/comments/:comment_id', CommentAPI],
        ]],
    ]],
    ['/admin', [
        ['/books'              , AdminBooksApp],
    ]],
]

router = Rack::JetRouter.new(urlpath_mapping)
p router.find('/api/books/123.html')
    #=> [BookAPI, {"id"=>"123", "format"=>"html"}]

status, headers, body = router.call(env)
```


### #2: Depends on both Request Path and Method

```ruby
# -*- coding: utf-8 -*-

require 'rack'
require 'rack/jet_router'

urlpath_mapping = [
    ['/'                       , {GET: WelcomeApp}],
    ['/api', [
        ['/books', [
            [''                , {GET: BookListAPI, POST: BookCreateAPI}],
            ['/:id(.:format)'  , {GET: BookShowAPI, PUT: BookUpdateAPI}],
            ['/:book_id/comments/:comment_id', {POST: CommentCreateAPI}],
        ]],
    ]],
    ['/admin', [
        ['/books'              , {ANY: AdminBooksApp}],
    ]],
]

router = Rack::JetRouter.new(urlpath_mapping)
router.find('/api/books/123')
    #=> [{"GET"=>BookShowAPI, "PUT"=>BookUpdateAPI}, {"id"=>"123", "format"=>nil}]

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

urlpath_mapping = [
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
router = Rack::JetRouter.new(urlpath_mapping)
p router.find('/api/books/123')
    #=> [{"GET"=>[BooksAPI, :show], "PUT"=>..., "DELETE"=>...}, {"id"=>"123"}]

dict, args = router.find('/api/books/123')
klass, action = dict["GET"]
handler = klass.new(Rack::Request.new(env), Rack::Response.new)
handler.__send__(action, args)
```


## Topics


### URL Path Parameters

URL path parameters (such as `{"id"=>"123"}`) is available via
`env['rack.urlpath_params']`.

```ruby
BookApp = proc {|env|
  p env['rack.urlpath_params']   #=> {"id"=>"123"}
  [200, {}, []]
}
```

If you want to tweak URL path parameters, define subclass of Rack::JetRouter
and override `#build_urlpath_parameter_vars(env, vars)`.

```ruby
class MyRouter < JetRouter

  def build_urlpath_parameter_vars(names, values)
    return names.zip(values).each_with_object({}) {|(k, v), d|
      ## converts urlpath pavam value into integer
      v = v.to_i if k == 'id' || k.end_with?('_id')
      d[k] = v
    }
  end

end
```


### Variable URL Path Cache

It is possible to classify URL path patterns into two types: fixed and variable.

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
p router.find('/api/books/123')   # caches even varaible urlpath
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


## Copyright and License

$Copyright: copyright(c) 2015 kuwata-lab.com all rights reserved $

$License: MIT License $


## History

### 2015-12-06: Release 0.1.0

* First release
