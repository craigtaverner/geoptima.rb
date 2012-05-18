require 'date'

module Geoptima
  module FileTime
    @@root=DateTime.parse("1970-01-01 00:00:00")
    DAY_SECONDS = 24 * 60 * 60
    DAY_MILLIS = DAY_SECONDS * 1000
    HUNDRED_YEARS_SECONDS = 100 * 365 * DAY_SECONDS
    HUNDRED_YEARS_MILLIS = HUNDRED_YEARS_SECONDS * 1000
    def self.from_file(arg)
      base,time=arg.to_s.split(/_/)
      self.from(time)
    end
    def self.from(time)
      time = time.to_f
      ms = time > HUNDRED_YEARS_SECONDS
      (@@root + time.to_f/(ms ? DAY_MILLIS : DAY_SECONDS))
    end
  end
end

if $PROGRAM_NAME =~ /\/file_time.rb$/
  puts "Running test cases"
  [123456789,1337089446603].each do |time|
    puts "#{(time.to_s+" "*40)[0..40]} -->   #{Geoptima::FileTime.from time}"
  end
  ["356409048945284_1334764343.json","353491048201465_1337160798.json","3859F91B6B2C_1337097736981.json","\"724044021273460_1337093857605.txt\""].each do |filename|
    puts "#{(filename.to_s+" "*40)[0..40]} -->   #{Geoptima::FileTime.from_file filename}"
  end
end
