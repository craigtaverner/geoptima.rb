begin
  # make sure that this file is not loaded twice
  @_geoptima_rspec_loaded = true

  require 'rubygems'
  require "bundler/setup"
  require 'rspec'
  require 'fileutils'

  $LOAD_PATH.unshift File.join(File.dirname(__FILE__), "..", "lib")

  require 'geoptima'
  require 'geoptima/locator'

  def create_sample
  end

  def create_location_sample
    start = DateTime.parse("2013-01-13 13:13")
    conversion_factor = 2.0 * Math::PI / 40000.0
    [
      {time:  1000, x: 10,  y: 50},
      {time:  2000, x: 50,  y: 60},
      {time:  3000, x: 70,  y: 55},
      {time:  4000, x: 80,  y: 45},
      {time:  4700, x: 100, y: 20, name: 'call'},
      {time:  6000, x: 130, y: 30},
      {time:  7000, x: 160, y: 35},
      {time:  8000, x: 200, y: 36},
      {time: 12000, x: 270, y: 50, name: 'sms'},
      {time: 14000, x: 300, y: 110},
      {time: 15000, x: 310, y: 90},
      {time: 16000, x: 330, y: 92},
      {time: 17000, x: 380, y: 100},
      {time: 18000, x: 390, y: 120, name: 'sms'},
      {time: 19000, x: 410, y: 130},
      {time: 20000, x: 460, y: 130, name: 'call'},
      {time: 21000, x: 470, y: 160},
      {time: 22000, x: 490, y: 190},
      {time: 23000, x: 520, y: 175},
      {time: 24000, x: 580, y: 180}
    ].map do |h|
      h[:name] ||= 'gps'
      h[:longtitude] ||= 13.0 + h[:x].to_f * conversion_factor
      h[:latitude] ||= 56.0 + h[:y].to_f * conversion_factor
      h[:time] = start + h[:time].to_f / Geoptima::MSPERDAY
      Geoptima::LocatableImpl.new h
    end
  end
  
end unless @_geoptima_rspec_loaded
