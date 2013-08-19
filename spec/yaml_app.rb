# Copyright 2013 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

require "rack"
require "yaml"

class YamlApp
  FULL_PATH = __FILE__

  attr_accessor :allocating_lines

  def initialize
    @allocating_lines = []
  end

  def call(env)
    y = YAML.dump(["one string", "two string"]); @allocating_lines << __LINE__ # lots of objects not from here
    @allocating_lines << __LINE__; [200, {"Content-Type" => "text/html"}, ["Hello Rack!"]]
  end
end
