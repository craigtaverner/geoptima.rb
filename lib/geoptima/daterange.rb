#!/usr/bin/env ruby

require 'date'
if $use_dateperformance
  begin
    require 'date/performance'
    require 'date/memoize'
    class DateTime
      def >(other) ; self - other > 0 ; end
      def <(other) ; self - other < 0 ; end
      def >=(other); self - other >= 0; end
      def <=(other); self - other <= 0; end
    end
  rescue LoadError
    puts "No date-performance gem installed, some features will run slower"
  end
end

module Geoptima
  class DateRange
    attr_reader :min, :max, :range
    def initialize(min,max)
      @min = min
      @max = max
      @range = Range.new(min,max)
    end
    if ENV['RUBY_VERSION'] =~ /1\.8/
      puts "Defining Range.include? to wrap for 1.8"
      def include?(time)
        @range.include?(time)
      end
    else
      puts "Defining Range.include? to perform inequality tests for 1.9"
      def include?(time)
        (time >= min) && (time <= @max)
      end
    end
  end
end

