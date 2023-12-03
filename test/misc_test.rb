# -*- coding: utf-8 -*-


require_relative './shared'


Oktest.scope do


  topic Rack::JetRouter::REQUEST_METHODS do

    spec "[!haggu] contains available request methods." do
      Rack::JetRouter::REQUEST_METHODS.each do |k, v|
        ok {k}.is_a?(String)
        ok {v}.is_a?(Symbol)
        ok {v.to_s} == k
      end
    end

  end


end
