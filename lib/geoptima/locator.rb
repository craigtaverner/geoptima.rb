#!/usr/bin/env ruby

require 'geoptima/locationrange'

module Geoptima

  SPERDAY = 60*60*24
  MSPERDAY = 1000*SPERDAY

  class LocatorAlgorithm
    def locate(locatable)
      if locatable.next_point
        locatable.location = locatable.next_point
      elsif locatable.previous_point
        locatable.location = locatable.previous_point
      else
        locatable.location = nil
      end
    end
  end
  class BeforeLocatorAlgorithm < LocatorAlgorithm
    def locate(locatable)
      if locatable.previous_point
        locatable.location = locatable.previous_point
      else
        locatable.location = nil
      end
    end
  end
  class AfterLocatorAlgorithm < LocatorAlgorithm
    def locate(locatable)
      if locatable.next_point
        locatable.location = locatable.next_point
      else
        locatable.location = nil
      end
    end
  end
  class ClosestLocatorAlgorithm < LocatorAlgorithm
    def locate(locatable)
      results = [
        [locatable.next_point_gap,locatable.next_point],
        [locatable.previous_point_gap,locatable.previous_point]
      ].reject do |x|
        x[0].nil? && x[1].nil?
      end.sort do |a,b|
        a[0] <=> b[0]
      end[0]
      locatable.location = results && results[1]
    end
  end
  class InterpolationLocatorAlgorithm < ClosestLocatorAlgorithm
    def locate(locatable)
      if locatable.previous_poing && locatable.next_point && locatable.next_point.prev_point
        correlateEvent2Point(point,wavg(point.prev,point.next,point),'interpolated');
      elsif closest = super.locate(locatable)
        correlateEvent2Point(point,closest,'correlated');
      else
        puts "No correlation possible for point: "+point
      end
    end
  end
  module Locatable
    attr_accessor :previous_gps, :previous_point, :next_point, :previous_point_gap, :next_point_gap, :location
    def closer_than(gps,window=0.0)
      if $debug && gps && window > 0
        puts "Comparing times:"
        puts "\tGPS: #{gps.time}"
        puts "\tEvent: #{self.time}"
        puts "\tTDiff: #{(self - gps).abs.to_f}"
        puts "\tWindow: #{window}"
      end
      gps && (window <= 0.0 || (self - gps).abs < window)
    end
    def set_next_if(gps,time_window=0.0)
      if closer_than(gps,time_window)
        self.next_point = gps.location
        self.next_point_gap = (self - gps).abs
      end
    end
    def set_previous_if(gps,time_window=0.0)
      self.previous_gps = gps
      if closer_than(gps,time_window)
        self.previous_point = gps.location
        self.previous_point_gap = (self - gps).abs
      end
    end
  end
  class LocatableImpl
    attr_reader :name, :attributes
    attr_accessor :time
    include Locatable
    def initialize(attributes)
      @attributes = Hash[*attributes.map{|k,v| [k.to_s,v]}.flatten]
      @name = @attributes['name']
      @time = @attributes['time']
    end
    def [](key)
      @attributes[key.to_s] || @attributes[key.to_s.gsub(/#{name}\./,'')]
    end
    def []=(key,value)
      @attributes[key.to_s] = value
    end
    def -(other)
      (self.time - other.time) * SPERDAY
    end
    def to_s
      @attributes.inspect
    end
  end
  class Locator
    attr_reader :sorted, :located, :failed, :options
    def initialize(sorted, options={})
      @sorted = sorted
      @options = Hash[*options.map{|k,v| [k.to_s.intern,v]}.flatten]
      @options[:algorithm] ||= 'window'
      @options[:window] ||= 60
      puts "Initialized geo-location on #{@sorted.length} events with options: #{@options.inspect}" if($debug)
    end
    def start
      @start ||= sorted[0] && sorted[0][:time] || DateTime.now
    end
    def algorithm
      @algorithm ||= case @options[:algorithm].to_s
      when /^\-win/
        BeforeLocatorAlgorithm.new
      when /^\+win/
        AfterLocatorAlgorithm.new
      when /closest/
        ClosestLocatorAlgorithm.new
      when /inter/
        InterpolationLocatorAlgorithm.new
      else
        LocatorAlgorithm.new
      end
    end
    def locate
      gps = nil
      @located = []
      @failed = []
      locatables = []
      time_window = @options[:window].to_i
      time_window = 60 if(time_window<1)
      puts "Locating within window[#{time_window}] using algorithm:#{algorithm.class}" if($debug)
      sorted.each do |event|
        event.time ||= start + event[:timestamp].to_f / Geoptima::MSPERDAY
        if event.name === 'gps'
          gps = event
          puts "Setting GPS location point: #{gps.inspect}" if($debug)
          gps.location = Point.new(gps['latitude'].to_f, gps['longitude'].to_f)
          locatables.each do |event|
            event.set_next_if(gps,time_window)
          end
          locatables = []
        else
          event.set_previous_if(gps,time_window)
          locatables << event
          @located << event
        end
      end
      @located = @located.map do |l|
        if self.algorithm.locate(l)
          l
        else
          @failed << l
          nil
        end
      end.compact
    end
  end
end


