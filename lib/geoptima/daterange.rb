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
    def initialize(min,max=nil)
      @min = min
      @max = max || (min + 1.0)
      @range = Range.new(@min,@max)
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
    def to_s
      @range.to_s
    end
    def self.from(spec)
      if spec =~ /\.\./
        puts "New time range spec: #{spec}" if($debug)
        DateRanges.new(spec)
      elsif spec.split(/\,/).length > 2
        puts "New days array: #{spec}" if($debug)
        DaysRange.new(spec)
      else
        puts "Classic time range: #{spec}" if($debug)
        DateRange.new(*spec.split(/\,/).map{|t| DateTime.parse(t)})
      end
    end
    def self.test
      [
        '2012-03-15,2012-03-16',
        '2012-03-15..2012-03-16',
        '2012-03-15..2012-03-20',
        '2012-03-15..2012-03-16,2012-03-20..2012.03.21',
        '2012-03-15..2012-03-16,2012-03-20',
        '2012-03-15,2012-03-16,2012-03-20'
      ].each do |test|
        puts "Testing: #{test}"
        puts "\t#{Geoptima::DateRange.from(test)}"
      end
    end
  end
  class DateRanges
    def initialize(spec)
      @ranges = spec.split(/\,/).map do |range|
        minmax = range.split(/\.\./).map{|t| DateTime.parse t}
        DateRange.new(*minmax)
      end
    end
    def include?(time)
      @ranges.each{|r| return true if(r.include?(time))}
      return false
    end
    def to_s
      @ranges.join(',')
    end
  end
  class DaysRange < DateRanges
    def initialize(spec)
      @ranges = spec.split(/\,/).map do |day|
        min = DateTime.parse(DateTime.parse(day).strftime("%Y-%m-%d"))
        DateRange.new(min)
      end
    end
  end
end

