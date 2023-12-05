# -*- coding: utf-8 -*-
# frozen_string_literal: true

Dir.glob(File.dirname(__FILE__) + '/*_test.rb').each do |filename|
  require File.absolute_path(filename)
end
