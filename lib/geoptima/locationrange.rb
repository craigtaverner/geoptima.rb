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
    def -(other)
      other.respond_to?('latitude') ?
        Point.new(self.latitude - other.latitude, self.longitude - other.longitude) :
        Point.new(self.latitude - other.to_f, self.longitude - other.to_f)
    end
    def +(other)
      other.respond_to?('latitude') ?
        Point.new(self.latitude + other.latitude, self.longitude + other.longitude) :
        Point.new(self.latitude + other.to_f, self.longitude + other.to_f)
    end
    def distance(other)
      Math.sqrt( (self.latitude-other.latitude)**2 + (self.longitude-other.longitude)**2 )
    end
    def to_s
      [@latitude,@longitude].inspect
    end
  end

  class LocationRange
    attr_reader :min, :max
    def initialize(spec)
      f=spec.gsub(/\.\./,':').gsub(/RANGE[\(\[]/i,'').split(/[\,\;\:]/)
      if spec =~ /\.\./
        initialize_min_max(Point.new(f[0],f[2]), Point.new(f[1],f[3]))
      else
        initialize_min_max(Point.new(f[0],f[1]), Point.new(f[2],f[3]))
      end
    end
    def initialize_min_max(min,max)
      @min = min
      @max = max
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
      elsif spec =~ /dist[\(\[]\s*([\d\.\-\+]+)\s*\,\s*([\d\.\-\+]+)\s*\,\s*([\d\.\-\+]+)\s*[\)\]]/i
        LocationDistance.new($1.to_f,Point.new($2,$3))
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
        'range[56.1..57.0,12.0..15.8]',
        'range[56.1,12.0,57.0,15.8]',
        'everywhere',
        '*',
        'dist(70,56.5,12.0)'
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
  # Note that this class does the distance calculation based on a direct translation
  # of distance at the equator. This will be inaccurate far from the equator.
  class LocationDistance <LocationRange
    attr_reader :distance, :distance_in_km, :center
    def initialize(distance_in_km,center)
      @distance_in_km = distance_in_km.to_f
      @center = center
      initialize_min_max(@center - distance, @center + distance)
    end
    def distance
      @distance ||= distance_in_km * 360.0 / 40000.0
    end
    def include?(point)
      super(point) && center.distance(point) < distance
    end
    def to_s
      super.to_s+",(#{distance},#{center})"
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

