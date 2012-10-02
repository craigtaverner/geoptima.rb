#!/usr/bin/env ruby

module Geoptima

  class Point
    attr_reader :latitude, :longitude
    def initialize(latitude,longitude)
      @latitude = latitude.to_f
      @longitude = longitude.to_f
    end
    def >(other)
      self.latitude - other.latitude > 0 && self.longitude - other.longitude > 0
    end
    def <(other)
      self.latitude - other.latitude < 0 && self.longitude - other.longitude < 0
    end
    def >=(other)
      self.latitude - other.latitude >= 0 && self.longitude - other.longitude >= 0
    end
    def <=(other)
      self.latitude - other.latitude <= 0 && self.longitude - other.longitude <= 0
    end
    def to_s
      [@latitude,@longitude].inspect
    end
  end

  class LocationRange
    attr_reader :min, :max
    def initialize(spec)
      f=spec.gsub(/\.\./,':').split(/[\,\;\:]/)
      if spec =~ /\.\./
        @min = Point.new(f[0],f[2])
        @max = Point.new(f[1],f[3])
      else
        @min = Point.new(f[0],f[1])
        @max = Point.new(f[2],f[3])
      end
      if @min > @max
        p = @min
        @min = @max
        @max = p
      end
    end
    def include?(point)
      puts "Testing point #{point} in range #{self}" if($debug)
      point && point < @max && point >= @min
    end
    def to_s
      [min,max].join(',')
    end
    def self.from(spec)
      if spec == '*' || spec =~ /everywhere/i
        LocationEverywhere.new
      else
        LocationRange.new(spec)
      end
    end
    def self.everywhere
      @@everywhere ||= LocationEverywhere.new
    end
    def self.test
      [
        '56.1..57.0,12.0..15.8',
        '56.1,12.0,57.0,15.8',
        'everywhere',
        '*'
      ].each do |test|
        puts "Testing: #{test}"
        range = Geoptima::LocationRange.from(test)
        puts "\t#{range}"
        puts "\tTesting MIN: #{range}.include?(#{range.min}) => #{range.include?(range.min)}"
        puts "\tTesting MAX: #{range}.include?(#{range.max}) => #{range.include?(range.max)}"
        (0..10).each do |i|
          latitude = 56.0 + 0.1 * i
          longitude = 11.0 + 0.2 * i
          p = Point.new(latitude,longitude)
          puts "\tTesting #{range}.include?(#{p}) => #{range.include?(p)}"
        end
      end
    end
  end
  class LocationEverywhere <LocationRange
    def initialize()
      super("-90,90,-180,180")
    end
    def to_s
      "everywhere"
    end
    def include?(point)
      true
    end
  end
end

