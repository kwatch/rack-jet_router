$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'oktest'

require 'rack'
require 'rack/mock'
require 'rack/jet_router'


class Map < Hash
end

def Map(dict={}, **kwargs)
  return Map.new.update(dict.merge(kwargs))
end
