$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/ok'

require 'rack'
require 'rack/mock'
require 'rack/jet_router'

