# Copyright 2013 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

require 'yajl'

module Rack::AllocationStats
  class Tracer < Action
    include Rack::Utils

    attr_reader :gc_report, :stats

    def initialize(*args)
      super
      request = Rack::Request.new(@env)

      # Once we're here, GET["ras"] better exist
      @scope = request.GET["ras"]["scope"]
      @times = (request.GET["ras"]["times"] || 1).to_i
      @gc_report = request.GET["ras"]["gc_report"]
      @output = (request.GET["ras"]["output"] || :columnar).to_sym
      @alias_paths = request.GET["ras"]["alias_paths"] || false
      @new_env = delete_custom_params(@env)
    end

    def act
      @stats = AllocationStats.trace do
        @times.times do
          @middleware.call_app(@new_env)
        end
      end
    end

    def response
      allocations = scoped_allocations

      if @output == :interactive
        allocations = allocations.all
        @middleware.allocation_stats_response(Formatters::HTML.new(self, allocations).format)
      elsif @output == :json
        allocations = default_groups_and_sort(allocations)
        @middleware.allocation_stats_response(Formatters::JSON.new(self, allocations).format)
      else
        allocations = default_groups_and_sort(allocations)
        @middleware.allocation_stats_response(Formatters::Text.new(self, allocations).format)
      end
    end

    def scoped_allocations
      allocations = @stats.allocations(alias_paths: @alias_paths)

      return allocations if @scope.nil?

      if @scope == "."
        return allocations.from_pwd
      else
        return allocations.from(@scope)
      end
    end

    def default_groups_and_sort(allocations)
      allocations.
        group_by(:sourcefile, :sourceline, :class_plus).
        sort_by_size.
        all
    end

    def delete_custom_params(env)
      new_env = env

      get_params = Rack::Request.new(new_env).GET
      get_params.delete("ras")

      new_env.delete("rack.request.query_string")
      new_env.delete("rack.request.query_hash")

      new_env["QUERY_STRING"] = build_query(get_params)
      new_env
    end
  end
end
